import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:my_logs/core/services/auth_service.dart';
import 'package:my_logs/features/read/data/firestore_book_repository.dart';
import 'package:my_logs/features/read/data/google_books_service.dart';
import 'package:my_logs/features/read/domain/book_repository.dart';
import 'package:my_logs/features/read/domain/models/book_item.dart';
import 'package:my_logs/features/workspaces/application/workspace_providers.dart';

// ── Repository Provider ───────────────────────────────────────────────────────
final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  return FirestoreBookRepository(authService: authService);
});

final googleBooksServiceProvider = Provider<GoogleBooksService>((ref) {
  return GoogleBooksService();
});

// ── Notifier ──────────────────────────────────────────────────────────────────
class BookListNotifier extends AsyncNotifier<List<BookItem>> {
  BookRepository get _repo => ref.read(bookRepositoryProvider);

  @override
  Future<List<BookItem>> build() async => _repo.getAll();

  /// Optimistically adds book to local state immediately
  Future<void> add(BookItem item) async {
    final current = await future;
    final id = item.id.isNotEmpty ? item.id : const Uuid().v4();
    final optimisticItem = item.copyWith(id: id);
    state = AsyncData([optimisticItem, ...current.where((b) => b.id != id)]);

    try {
      final saved = await _repo.add(optimisticItem);
      final listNow = state.valueOrNull ?? current;
      final contains = listNow.any((b) => b.id == id);
      final updatedList = contains
          ? listNow.map((b) => b.id == id ? saved : b).toList()
          : [saved, ...listNow];
      state = AsyncData(updatedList);
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }

  /// Optimistically updates book in local state immediately
  Future<void> updateItem(BookItem item) async {
    final current = await future;
    final previous = state.valueOrNull ?? current;
    final contains = previous.any((b) => b.id == item.id);
    final updated = contains
        ? previous.map((b) => b.id == item.id ? item : b).toList()
        : [item, ...previous];
    state = AsyncData(updated);

    try {
      await _repo.update(item);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Optimistically deletes book from local state immediately
  Future<void> delete(String id) async {
    final current = await future;
    final previous = state.valueOrNull ?? current;
    state = AsyncData(previous.where((b) => b.id != id).toList());

    try {
      await _repo.delete(id);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Optimistically updates status immediately
  Future<void> updateStatus(String id, BookStatus status) async {
    final existing = (state.valueOrNull ?? []).where((b) => b.id == id).firstOrNull;
    if (existing == null) return;
    final wasInCollection = existing.isCollection || existing.status == BookStatus.collection;
    await updateItem(existing.copyWith(
      status: status,
      isCollection: wasInCollection,
    ));
  }

  /// Optimistically toggles collection flag immediately
  Future<void> toggleCollection(String id, bool isCollection) async {
    final existing = (state.valueOrNull ?? []).where((b) => b.id == id).firstOrNull;
    if (existing == null) return;
    final effectiveStatus = (existing.status == BookStatus.collection)
        ? (existing.currentPage > 0 ? BookStatus.reading : BookStatus.toRead)
        : existing.status;
    await updateItem(existing.copyWith(
      isCollection: isCollection,
      status: effectiveStatus,
    ));
  }

  /// Optimistically updates reading progress immediately
  Future<void> updateProgress(String id, int currentPage) async {
    final existing = (state.valueOrNull ?? []).where((b) => b.id == id).firstOrNull;
    if (existing == null) return;
    await updateItem(existing.copyWith(currentPage: currentPage));
  }

  /// Optimistically updates rating immediately
  Future<void> updateRating(String id, double rating) async {
    final existing = (state.valueOrNull ?? []).where((b) => b.id == id).firstOrNull;
    if (existing == null) return;
    await updateItem(existing.copyWith(rating: rating));
  }

  /// Optimistically updates notes immediately
  Future<void> updateNotes(String id, String notes) async {
    final existing = (state.valueOrNull ?? []).where((b) => b.id == id).firstOrNull;
    if (existing == null) return;
    await updateItem(existing.copyWith(notes: notes));
  }
}

final bookListProvider =
    AsyncNotifierProvider<BookListNotifier, List<BookItem>>(BookListNotifier.new);

// ── Workspace Filtered Books Provider ────────────────────────────────────────
final workspaceFilteredBooksProvider = Provider<List<BookItem>>((ref) {
  final books = ref.watch(bookListProvider).valueOrNull ?? [];
  final activeId = ref.watch(activeWorkspaceIdProvider).valueOrNull;
  final workspaces = ref.watch(workspaceListProvider).valueOrNull ?? [];

  return filterWorkspaceItems(
    items: books,
    activeWorkspaceId: activeId,
    allWorkspaces: workspaces,
  );
});

// ── Derived Providers ─────────────────────────────────────────────────────────
final booksByStatusProvider =
    Provider.family<List<BookItem>, BookStatus>((ref, status) {
  final allBooks = ref.watch(workspaceFilteredBooksProvider);
  if (status == BookStatus.collection) {
    return allBooks.where((b) => b.isCollection || b.status == BookStatus.collection).toList();
  }
  return allBooks.where((b) {
    final effectiveStatus = (b.status == BookStatus.collection)
        ? (b.currentPage > 0 ? BookStatus.reading : BookStatus.toRead)
        : b.status;
    return effectiveStatus == status;
  }).toList();
});

final bookByIdProvider = Provider.family<BookItem?, String>((ref, id) {
  return ref.watch(bookListProvider).valueOrNull?.where((b) => b.id == id).firstOrNull;
});

final currentlyReadingProvider = Provider<List<BookItem>>((ref) {
  final books = ref.watch(workspaceFilteredBooksProvider);
  return (books.where((b) {
        final effectiveStatus = (b.status == BookStatus.collection)
            ? (b.currentPage > 0 ? BookStatus.reading : BookStatus.toRead)
            : b.status;
        return effectiveStatus == BookStatus.reading;
      }).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
      .take(5)
      .toList();
});

