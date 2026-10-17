import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_logs/features/notes/application/note_providers.dart';
import 'package:my_logs/features/notes/domain/models/note_item.dart';
import 'package:my_logs/features/notes/domain/note_repository.dart';

class InMemoryNoteRepository implements NoteRepository {
  final Map<String, NoteItem> _items = {};

  @override
  Future<List<NoteItem>> getAll() async => _items.values.toList();

  @override
  Future<NoteItem?> getById(String id) async => _items[id];

  @override
  Future<NoteItem> add(NoteItem item) async {
    _items[item.id] = item;
    return item;
  }

  @override
  Future<NoteItem> update(NoteItem item) async {
    _items[item.id] = item;
    return item;
  }

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
  }
}

void main() {
  group('Notes Flow & Deduplication Tests', () {
    test('Adding a note creates exactly 1 note in state and repository', () async {
      final repo = InMemoryNoteRepository();
      final container = ProviderContainer(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final now = DateTime.now();
      final note = NoteItem(
        id: 'test-note-1',
        title: 'Meeting Notes',
        content: 'Review Q4 strategy',
        createdAt: now,
        updatedAt: now,
      );

      await container.read(noteListProvider.notifier).add(note);

      final state = container.read(noteListProvider).valueOrNull ?? [];
      expect(state.length, equals(1));
      expect(state.first.id, equals('test-note-1'));
      expect(state.first.title, equals('Meeting Notes'));

      final repoItems = await repo.getAll();
      expect(repoItems.length, equals(1));
      expect(repoItems.first.id, equals('test-note-1'));
    });

    test('Deleting a note completely removes it without resurrecting', () async {
      final repo = InMemoryNoteRepository();
      final container = ProviderContainer(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final now = DateTime.now();
      final note1 = NoteItem(
        id: 'note-1',
        title: 'Grocery',
        content: 'Milk, Eggs',
        createdAt: now,
        updatedAt: now,
      );
      final note2 = NoteItem(
        id: 'note-2',
        title: 'Todo',
        content: 'Clean desk',
        createdAt: now,
        updatedAt: now,
      );

      await container.read(noteListProvider.notifier).add(note1);
      await container.read(noteListProvider.notifier).add(note2);

      var state = container.read(noteListProvider).valueOrNull ?? [];
      expect(state.length, equals(2));

      // Delete note-1
      await container.read(noteListProvider.notifier).delete('note-1');

      state = container.read(noteListProvider).valueOrNull ?? [];
      expect(state.length, equals(1));
      expect(state.first.id, equals('note-2'));

      final inRepo = await repo.getAll();
      expect(inRepo.length, equals(1));
      expect(inRepo.first.id, equals('note-2'));
    });

    test('Updating a note updates in place without duplicating', () async {
      final repo = InMemoryNoteRepository();
      final container = ProviderContainer(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final now = DateTime.now();
      final note = NoteItem(
        id: 'note-edit-1',
        title: 'Draft',
        content: 'Initial text',
        createdAt: now,
        updatedAt: now,
      );

      await container.read(noteListProvider.notifier).add(note);
      expect((container.read(noteListProvider).valueOrNull ?? []).length, equals(1));

      // Update same note
      final updated = note.copyWith(
        title: 'Final Draft',
        content: 'Updated content',
        updatedAt: DateTime.now(),
      );
      await container.read(noteListProvider.notifier).updateItem(updated);

      final state = container.read(noteListProvider).valueOrNull ?? [];
      expect(state.length, equals(1));
      expect(state.first.title, equals('Final Draft'));
      expect(state.first.content, equals('Updated content'));
    });
  });
}
