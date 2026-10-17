import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:my_logs/core/services/auth_service.dart';
import 'package:my_logs/core/utils/date_utils.dart';
import 'package:my_logs/core/utils/notification_service.dart';
import 'package:my_logs/features/reminders/data/firestore_reminder_repository.dart';
import 'package:my_logs/features/reminders/domain/models/reminder_item.dart';
import 'package:my_logs/features/reminders/domain/reminder_repository.dart';

// ── Repository Provider ───────────────────────────────────────────────────────
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  return FirestoreReminderRepository(authService: authService);
});

// ── Notifier ──────────────────────────────────────────────────────────────────
class ReminderListNotifier extends AsyncNotifier<List<ReminderItem>> {
  ReminderRepository get _repo => ref.read(reminderRepositoryProvider);

  @override
  Future<List<ReminderItem>> build() async => _repo.getAll();

  /// Optimistically adds reminder immediately
  Future<void> add(ReminderItem item) async {
    final current = state.valueOrNull ?? [];
    final id = item.id.isNotEmpty ? item.id : const Uuid().v4();
    final optimisticItem = item.copyWith(id: id);
    state = AsyncData([optimisticItem, ...current.where((r) => r.id != id)]);

    try {
      final created = await _repo.add(optimisticItem);
      if (created.isEnabled) {
        await _scheduleNotification(created);
      }
      final updatedList = (state.valueOrNull ?? [])
          .map((r) => r.id == id ? created : r)
          .toList();
      state = AsyncData(updatedList);
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }

  /// Optimistically updates reminder immediately
  Future<void> updateItem(ReminderItem item) async {
    final current = state.valueOrNull ?? [];
    final previous = current;
    state = AsyncData(current.map((r) => r.id == item.id ? item : r).toList());

    try {
      final updated = await _repo.update(item);
      await NotificationService.instance.cancelNotification(
        NotificationService.idFromString(updated.id),
      );
      if (updated.isEnabled) await _scheduleNotification(updated);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Optimistically deletes reminder immediately
  Future<void> delete(String id) async {
    final current = state.valueOrNull ?? [];
    final previous = current;
    state = AsyncData(current.where((r) => r.id != id).toList());

    try {
      await NotificationService.instance.cancelNotification(
        NotificationService.idFromString(id),
      );
      await _repo.delete(id);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  final _togglingIds = <String>{};

  /// Optimistically toggles enabled switch immediately (0ms delay)
  Future<void> toggle(String id) async {
    if (_togglingIds.contains(id)) return;
    _togglingIds.add(id);
    final current = state.valueOrNull ?? [];
    final previous = current;
    final existing = current.where((r) => r.id == id).firstOrNull;
    if (existing == null) {
      _togglingIds.remove(id);
      return;
    }

    final toggledOptimistic = existing.copyWith(isEnabled: !existing.isEnabled);
    state = AsyncData(
      current.map((r) => r.id == id ? toggledOptimistic : r).toList(),
    );

    try {
      final toggled = await _repo.toggleEnabled(id);
      if (toggled.isEnabled) {
        await _scheduleNotification(toggled);
      } else {
        await NotificationService.instance.cancelNotification(
          NotificationService.idFromString(toggled.id),
        );
      }
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    } finally {
      _togglingIds.remove(id);
    }
  }

  Future<void> _scheduleNotification(ReminderItem item) async {
    DateTimeComponents? matchComponents;
    switch (item.recurrence) {
      case ReminderRecurrence.daily:
        matchComponents = DateTimeComponents.time;
      case ReminderRecurrence.weekly:
        matchComponents = DateTimeComponents.dayOfWeekAndTime;
      case ReminderRecurrence.monthly:
        matchComponents = DateTimeComponents.dayOfMonthAndTime;
      case ReminderRecurrence.none:
      case ReminderRecurrence.custom:
        matchComponents = null;
    }

    await NotificationService.instance.scheduleNotification(
      id: NotificationService.idFromString(item.id),
      title: 'Logspad Reminder',
      body: item.title,
      scheduledTime: item.scheduledTime,
      matchDateTimeComponents: matchComponents,
    );
  }
}

final reminderListProvider =
    AsyncNotifierProvider<ReminderListNotifier, List<ReminderItem>>(
  ReminderListNotifier.new,
);

// ── Derived Providers ─────────────────────────────────────────────────────────
final todayRemindersProvider = Provider<List<ReminderItem>>((ref) {
  final reminders = ref.watch(reminderListProvider).valueOrNull ?? [];
  return reminders.where((r) => r.isEnabled && AppDateUtils.isToday(r.scheduledTime)).toList()
    ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
});
