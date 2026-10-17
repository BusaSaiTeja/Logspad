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
    final current = await future;
    final id = item.id.isNotEmpty ? item.id : const Uuid().v4();
    final optimisticItem = item.copyWith(id: id);
    state = AsyncData([optimisticItem, ...current.where((r) => r.id != id)]);

    try {
      final created = await _repo.add(optimisticItem);
      if (created.isEnabled) {
        await _scheduleNotification(created);
      }
      final listNow = state.valueOrNull ?? current;
      final contains = listNow.any((r) => r.id == id);
      final updatedList = contains
          ? listNow.map((r) => r.id == id ? created : r).toList()
          : [created, ...listNow];
      state = AsyncData(updatedList);
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }

  /// Optimistically updates reminder immediately
  Future<void> updateItem(ReminderItem item) async {
    final current = await future;
    final previous = state.valueOrNull ?? current;
    final contains = previous.any((r) => r.id == item.id);
    final updated = contains
        ? previous.map((r) => r.id == item.id ? item : r).toList()
        : [item, ...previous];
    state = AsyncData(updated);

    try {
      final updatedItem = await _repo.update(item);
      await NotificationService.instance.cancelReminderNotifications(
        NotificationService.idFromString(updatedItem.id),
      );
      if (updatedItem.isEnabled) await _scheduleNotification(updatedItem);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Optimistically deletes reminder immediately
  Future<void> delete(String id) async {
    final current = await future;
    final previous = state.valueOrNull ?? current;
    state = AsyncData(previous.where((r) => r.id != id).toList());

    try {
      await NotificationService.instance.cancelReminderNotifications(
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
        await NotificationService.instance.cancelReminderNotifications(
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
    if (item.recurrence == ReminderRecurrence.custom) {
      final days = ReminderWeekdayUtils.parseWeekdays(item.customDaysText).toList();
      if (days.isNotEmpty) {
        await NotificationService.instance.scheduleCustomWeekdaysNotification(
          baseId: NotificationService.idFromString(item.id),
          title: 'Logspad Reminder',
          body: item.title,
          scheduledTime: item.scheduledTime,
          weekdays: days,
          isVibrationAlarm: item.isVibrationAlarm,
        );
        return;
      }
    }

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
      isVibrationAlarm: item.isVibrationAlarm,
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
  final now = DateTime.now();
  final list = reminders.where((r) {
    if (!r.isEnabled) return false;
    switch (r.recurrence) {
      case ReminderRecurrence.none:
        return AppDateUtils.isToday(r.scheduledTime);
      case ReminderRecurrence.daily:
        return true;
      case ReminderRecurrence.weekly:
        return r.scheduledTime.weekday == now.weekday;
      case ReminderRecurrence.monthly:
        return r.scheduledTime.day == now.day;
      case ReminderRecurrence.custom:
        final days = ReminderWeekdayUtils.parseWeekdays(r.customDaysText);
        return days.contains(now.weekday);
    }
  }).toList();

  list.sort((a, b) {
    final aMinutes = a.scheduledTime.hour * 60 + a.scheduledTime.minute;
    final bMinutes = b.scheduledTime.hour * 60 + b.scheduledTime.minute;
    return aMinutes.compareTo(bMinutes);
  });
  return list;
});
