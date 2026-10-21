import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:my_logs/core/services/auth_service.dart';
import 'package:my_logs/features/learning_paths/data/firestore_learning_path_repository.dart';
import 'package:my_logs/features/learning_paths/domain/learning_path_repository.dart';
import 'package:my_logs/features/learning_paths/domain/models/learning_path.dart';
import 'package:my_logs/features/workspaces/application/workspace_providers.dart';

// ── Repository Provider ───────────────────────────────────────────────────────
final learningPathRepositoryProvider = Provider<LearningPathRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  return FirestoreLearningPathRepository(authService: authService);
});

// ── Notifier ──────────────────────────────────────────────────────────────────
class LearningPathListNotifier extends AsyncNotifier<List<LearningPath>> {
  LearningPathRepository get _repo => ref.read(learningPathRepositoryProvider);

  @override
  Future<List<LearningPath>> build() async => _repo.getAll();

  /// Optimistically adds learning path immediately
  Future<void> add(LearningPath path) async {
    final current = state.valueOrNull ?? (await future);
    final id = path.id.isNotEmpty ? path.id : const Uuid().v4();
    final optimisticPath = path.copyWith(id: id);
    state = AsyncData([optimisticPath, ...current.where((p) => p.id != id)]);

    try {
      final created = await _repo.add(optimisticPath);
      final updatedList = (state.valueOrNull ?? [])
          .map((p) => p.id == id ? created : p)
          .toList();
      state = AsyncData(updatedList);
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }

  /// Optimistically updates learning path immediately
  Future<void> updateItem(LearningPath path) async {
    final current = state.valueOrNull ?? (await future);
    final previous = current;
    state = AsyncData(current.map((p) => p.id == path.id ? path : p).toList());

    try {
      await _repo.update(path);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Optimistically deletes learning path immediately
  Future<void> delete(String id) async {
    final current = state.valueOrNull ?? (await future);
    final previous = current;
    state = AsyncData(current.where((p) => p.id != id).toList());

    try {
      await _repo.delete(id);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Optimistically toggles a single step's completion immediately (0ms lag)
  Future<void> toggleStep(String pathId, String stepId) async {
    final current = state.valueOrNull ?? [];
    final previous = current;
    final path = current.where((p) => p.id == pathId).firstOrNull;
    if (path == null) return;

    final updatedSteps = path.steps.map((s) {
      return s.id == stepId ? s.copyWith(isCompleted: !s.isCompleted) : s;
    }).toList();

    final optimisticPath = path.copyWith(steps: updatedSteps);
    state = AsyncData(
      current.map((p) => p.id == pathId ? optimisticPath : p).toList(),
    );

    try {
      await _repo.toggleStep(pathId, stepId);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

final learningPathListProvider =
    AsyncNotifierProvider<LearningPathListNotifier, List<LearningPath>>(
  LearningPathListNotifier.new,
);

final workspaceFilteredLearningPathsProvider =
    Provider<AsyncValue<List<LearningPath>>>((ref) {
  final pathsAsync = ref.watch(learningPathListProvider);
  final activeId = ref.watch(activeWorkspaceIdProvider).valueOrNull;
  final workspaces = ref.watch(workspaceListProvider).valueOrNull ?? [];

  return pathsAsync.whenData((paths) => filterWorkspaceItems(
        items: paths,
        activeWorkspaceId: activeId,
        allWorkspaces: workspaces,
      ));
});

final learningPathByIdProvider =
    Provider.family<LearningPath?, String>((ref, id) {
  return ref
      .watch(learningPathListProvider)
      .valueOrNull
      ?.where((p) => p.id == id)
      .firstOrNull;
});

/// Computed progress for a path (0.0 – 1.0) — never stored, always derived.
final pathProgressProvider = Provider.family<double, String>((ref, pathId) {
  final path = ref.watch(learningPathByIdProvider(pathId));
  if (path == null || path.steps.isEmpty) return 0.0;
  final completed = path.steps.where((s) => s.isCompleted).length;
  return completed / path.steps.length;
});

/// Computed status label from progress — never stored.
final pathStatusProvider = Provider.family<String, String>((ref, pathId) {
  final progress = ref.watch(pathProgressProvider(pathId));
  if (progress <= 0.0) return 'Not Started';
  if (progress >= 1.0) return 'Completed';
  return 'In Progress';
});
