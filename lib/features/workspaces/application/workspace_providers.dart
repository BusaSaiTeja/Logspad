import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_logs/core/domain/workspace_scoped.dart';
import 'package:my_logs/core/services/auth_service.dart';
import 'package:my_logs/core/utils/provider_reset_utils.dart';
import 'package:my_logs/features/workspaces/data/firestore_workspace_repository.dart';
import 'package:my_logs/features/workspaces/domain/models/workspace_item.dart';
import 'package:my_logs/features/workspaces/domain/workspace_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  return FirestoreWorkspaceRepository(authService: authService);
});

// ── Workspace List Notifier ──────────────────────────────────────────────────
class WorkspaceListNotifier extends AsyncNotifier<List<WorkspaceItem>> {
  WorkspaceRepository get _repo => ref.read(workspaceRepositoryProvider);

  @override
  Future<List<WorkspaceItem>> build() async {
    final list = await _repo.getAll();
    if (list.isEmpty) {
      // Auto-create default Personal workspace if none exists
      final now = DateTime.now();
      final defaultWs = await _repo.add(WorkspaceItem(
        id: '',
        name: 'Personal',
        iconName: 'person_outline_rounded',
        colorValue: 0xFF4F46E5,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ));
      return [defaultWs];
    }
    return list;
  }

  Future<WorkspaceItem> addWorkspace({
    required String name,
    String iconName = 'folder_outlined',
    int colorValue = 0xFF6366F1,
  }) async {
    final now = DateTime.now();
    final item = await _repo.add(WorkspaceItem(
      id: '',
      name: name.trim(),
      iconName: iconName,
      colorValue: colorValue,
      isDefault: false,
      createdAt: now,
      updatedAt: now,
    ));

    final current = state.valueOrNull ?? [];
    state = AsyncData([...current, item]);

    // Automatically set as active workspace
    await ref.read(activeWorkspaceIdProvider.notifier).setActive(item.id);
    return item;
  }

  Future<void> updateWorkspace(WorkspaceItem item) async {
    final current = state.valueOrNull ?? [];
    final previous = current;
    state = AsyncData(current.map((w) => w.id == item.id ? item : w).toList());

    try {
      final updated = await _repo.update(item);
      final list = (state.valueOrNull ?? []).map((w) => w.id == updated.id ? updated : w).toList();
      state = AsyncData(list);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  final _togglingFeatureKeys = <String>{};

  Future<void> toggleFeature(String workspaceId, String featureKey) async {
    final lockKey = '$workspaceId:$featureKey';
    if (_togglingFeatureKeys.contains(lockKey)) return;
    _togglingFeatureKeys.add(lockKey);
    try {
      final current = state.valueOrNull ?? [];
      final ws = current.where((w) => w.id == workspaceId).firstOrNull;
      if (ws == null) return;

      final updatedFeatures = List<String>.from(ws.enabledFeatures);
      if (updatedFeatures.contains(featureKey)) {
        if (updatedFeatures.length <= 1) return; // Keep at least one feature
        updatedFeatures.remove(featureKey);
      } else {
        updatedFeatures.add(featureKey);
      }

      final updatedWs = ws.copyWith(
        enabledFeatures: updatedFeatures,
        updatedAt: DateTime.now(),
      );
      await updateWorkspace(updatedWs);
    } finally {
      _togglingFeatureKeys.remove(lockKey);
    }
  }

  Future<void> deleteWorkspace(String id) async {
    final current = state.valueOrNull ?? [];
    final previous = current;
    final remaining = current.where((w) => w.id != id).toList();
    state = AsyncData(remaining);

    // If active workspace was deleted, fall back to default or first workspace
    final activeId = ref.read(activeWorkspaceIdProvider).valueOrNull;
    final fallbackWs = remaining.where((w) => w.isDefault).firstOrNull ?? remaining.firstOrNull;
    final fallbackId = fallbackWs?.id ?? '';

    if (activeId == id && fallbackId.isNotEmpty) {
      await ref.read(activeWorkspaceIdProvider.notifier).setActive(fallbackId);
    }

    try {
      // Reassign all orphaned documents to the fallback workspace in Firestore
      if (fallbackId.isNotEmpty) {
        final authService = ref.read(authServiceProvider);
        final uid = authService.currentUserId;
        if (uid != null) {
          final firestore = FirebaseFirestore.instance;
          final userDoc = firestore.collection('users').doc(uid);
          final collections = [
            'notes',
            'tasks',
            'reminders',
            'books',
            'media',
            'learning_paths',
          ];
          for (final col in collections) {
            try {
              final snap = await userDoc.collection(col).where('workspaceId', isEqualTo: id).get();
              for (final doc in snap.docs) {
                await doc.reference.update({'workspaceId': fallbackId});
              }
            } catch (_) {}
          }
        }
      }

      await _repo.delete(id);
      invalidateDomainEntityProviders(ref);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

final workspaceListProvider =
    AsyncNotifierProvider<WorkspaceListNotifier, List<WorkspaceItem>>(
  WorkspaceListNotifier.new,
);

// ── Active Workspace ID Notifier ─────────────────────────────────────────────
class ActiveWorkspaceIdNotifier extends AsyncNotifier<String> {
  static const _prefKey = 'active_workspace_id';

  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);

    final workspaces = await ref.watch(workspaceListProvider.future);
    if (workspaces.isEmpty) return '';

    if (saved != null && workspaces.any((w) => w.id == saved)) {
      return saved;
    }

    final defaultId = workspaces.first.id;
    await prefs.setString(_prefKey, defaultId);
    return defaultId;
  }

  Future<void> setActive(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, id);
    state = AsyncData(id);
  }
}

final activeWorkspaceIdProvider =
    AsyncNotifierProvider<ActiveWorkspaceIdNotifier, String>(
  ActiveWorkspaceIdNotifier.new,
);

// ── Active Workspace Provider ────────────────────────────────────────────────
final activeWorkspaceProvider = Provider<WorkspaceItem?>((ref) {
  final activeId = ref.watch(activeWorkspaceIdProvider).valueOrNull;
  final workspaces = ref.watch(workspaceListProvider).valueOrNull ?? [];
  if (activeId == null || workspaces.isEmpty) return workspaces.firstOrNull;
  return workspaces.where((w) => w.id == activeId).firstOrNull ?? workspaces.firstOrNull;
});

/// Helper to determine if an item belongs to the active workspace.
/// Legacy items without a workspaceId (empty string) belong to the default workspace.
bool itemMatchesWorkspace({
  required String itemWorkspaceId,
  required String? activeWorkspaceId,
  required List<WorkspaceItem> allWorkspaces,
}) {
  if (activeWorkspaceId == null || activeWorkspaceId.isEmpty) return true;
  if (itemWorkspaceId == activeWorkspaceId) return true;
  if (itemWorkspaceId.isEmpty) {
    final defaultWs = allWorkspaces.where((w) => w.isDefault).firstOrNull ?? allWorkspaces.firstOrNull;
    if (defaultWs == null) return true;
    return activeWorkspaceId == defaultWs.id;
  }
  return false;
}

/// Filters any list of WorkspaceScoped entities according to the currently active workspace.
List<T> filterWorkspaceItems<T extends WorkspaceScoped>({
  required List<T> items,
  required String? activeWorkspaceId,
  required List<WorkspaceItem> allWorkspaces,
}) {
  return items
      .where((item) => itemMatchesWorkspace(
            itemWorkspaceId: item.workspaceId,
            activeWorkspaceId: activeWorkspaceId,
            allWorkspaces: allWorkspaces,
          ))
      .toList();
}

