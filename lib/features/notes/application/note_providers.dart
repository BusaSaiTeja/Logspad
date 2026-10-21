import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:my_logs/core/services/auth_service.dart';
import 'package:my_logs/features/notes/data/firestore_note_repository.dart';
import 'package:my_logs/features/notes/domain/models/note_item.dart';
import 'package:my_logs/features/notes/domain/note_repository.dart';
import 'package:my_logs/features/workspaces/application/workspace_providers.dart';

// ── Repository Provider ───────────────────────────────────────────────────────
final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  return FirestoreNoteRepository(authService: authService);
});

// ── Categories State ──────────────────────────────────────────────────────────
class NoteCategoriesNotifier extends StateNotifier<List<String>> {
  static const _prefKey = 'note_custom_categories';
  static const _defaultCategories = ['All', 'Study', 'Shopping', 'Work', 'Personal', 'Ideas'];

  NoteCategoriesNotifier() : super(_defaultCategories) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefKey);
    if (saved != null && saved.isNotEmpty) {
      state = {..._defaultCategories, ...saved}.toList();
    }
  }

  Future<void> addCategory(String category) async {
    final trimmed = category.trim();
    if (trimmed.isNotEmpty && !state.contains(trimmed)) {
      state = [...state, trimmed];
      final prefs = await SharedPreferences.getInstance();
      final custom = state.where((c) => !_defaultCategories.contains(c)).toList();
      await prefs.setStringList(_prefKey, custom);
    }
  }
}

final noteCategoriesProvider =
    StateNotifierProvider<NoteCategoriesNotifier, List<String>>(
        (ref) => NoteCategoriesNotifier());

// ── Notifier ──────────────────────────────────────────────────────────────────
class NoteListNotifier extends AsyncNotifier<List<NoteItem>> {
  NoteRepository get _repo => ref.read(noteRepositoryProvider);

  @override
  Future<List<NoteItem>> build() async => _repo.getAll();

  /// Optimistically adds note to local state immediately
  Future<void> add(NoteItem item) async {
    final current = await future;
    final id = item.id.isNotEmpty ? item.id : const Uuid().v4();
    final optimisticNote = item.copyWith(id: id);
    state = AsyncData([optimisticNote, ...current.where((n) => n.id != id)]);

    try {
      final savedItem = await _repo.add(optimisticNote);
      final listNow = state.valueOrNull ?? current;
      final contains = listNow.any((n) => n.id == id);
      final updatedList = contains
          ? listNow.map((n) => n.id == id ? savedItem : n).toList()
          : [savedItem, ...listNow];
      state = AsyncData(updatedList);
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }

  /// Optimistically updates note in local state immediately
  Future<void> updateItem(NoteItem item) async {
    final current = await future;
    final previous = state.valueOrNull ?? current;
    final contains = previous.any((n) => n.id == item.id);
    final updated = contains
        ? previous.map((n) => n.id == item.id ? item : n).toList()
        : [item, ...previous];
    state = AsyncData(updated);

    try {
      await _repo.update(item);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Optimistically deletes note from local state immediately
  Future<void> delete(String id) async {
    final current = await future;
    final previous = state.valueOrNull ?? current;
    state = AsyncData(previous.where((n) => n.id != id).toList());

    try {
      await _repo.delete(id);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

final noteListProvider =
    AsyncNotifierProvider<NoteListNotifier, List<NoteItem>>(NoteListNotifier.new);

final workspaceFilteredNotesProvider = Provider<AsyncValue<List<NoteItem>>>((ref) {
  final notesAsync = ref.watch(noteListProvider);
  final activeId = ref.watch(activeWorkspaceIdProvider).valueOrNull;
  final workspaces = ref.watch(workspaceListProvider).valueOrNull ?? [];

  return notesAsync.whenData((notes) => filterWorkspaceItems(
        items: notes,
        activeWorkspaceId: activeId,
        allWorkspaces: workspaces,
      ));
});

final noteByIdProvider = Provider.family<NoteItem?, String>((ref, id) {
  return ref.watch(noteListProvider).valueOrNull?.where((n) => n.id == id).firstOrNull;
});

