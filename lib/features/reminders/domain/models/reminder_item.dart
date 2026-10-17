import 'package:freezed_annotation/freezed_annotation.dart';

part 'reminder_item.freezed.dart';
part 'reminder_item.g.dart';

enum ReminderRecurrence { none, daily, weekly, monthly, custom }

extension ReminderRecurrenceExt on ReminderRecurrence {
  String get label {
    switch (this) {
      case ReminderRecurrence.none:
        return 'None';
      case ReminderRecurrence.daily:
        return 'Daily';
      case ReminderRecurrence.weekly:
        return 'Weekly';
      case ReminderRecurrence.monthly:
        return 'Monthly';
      case ReminderRecurrence.custom:
        return 'Custom';
    }
  }
}

class ReminderWeekdayUtils {
  /// Parses weekday string (e.g. "Mon, Wed, Fri", "Weekdays", "Every day") into 1..7 (Mon..Sun)
  static Set<int> parseWeekdays(String? text) {
    if (text == null || text.trim().isEmpty) return {};
    final lower = text.toLowerCase().trim();
    if (lower == 'every day' || lower == 'daily') {
      return {1, 2, 3, 4, 5, 6, 7};
    }
    if (lower == 'weekdays') {
      return {1, 2, 3, 4, 5};
    }
    if (lower == 'weekends') {
      return {6, 7};
    }
    final result = <int>{};
    final parts = text
        .split(RegExp(r'[,|/\s]+'))
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty);
    for (final p in parts) {
      if (p.startsWith('mon')) {
        result.add(1);
      } else if (p.startsWith('tue')) {
        result.add(2);
      } else if (p.startsWith('wed')) {
        result.add(3);
      } else if (p.startsWith('thu')) {
        result.add(4);
      } else if (p.startsWith('fri')) {
        result.add(5);
      } else if (p.startsWith('sat')) {
        result.add(6);
      } else if (p.startsWith('sun')) {
        result.add(7);
      } else {
        final n = int.tryParse(p);
        if (n != null && n >= 1 && n <= 7) result.add(n);
      }
    }
    return result;
  }

  /// Formats a set of 1..7 weekdays into a human-readable alarm label
  static String formatWeekdays(Set<int> days) {
    if (days.isEmpty) return '';
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && days.containsAll({1, 2, 3, 4, 5})) return 'Weekdays';
    if (days.length == 2 && days.containsAll({6, 7})) return 'Weekends';

    final sorted = days.toList()..sort();
    const names = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    return sorted.map((d) => names[d]!).join(', ');
  }
}


@freezed
class ReminderItem with _$ReminderItem {
  const factory ReminderItem({
    required String id,
    required String title,
    String? description,
    required DateTime scheduledTime,
    @Default(ReminderRecurrence.none) ReminderRecurrence recurrence,
    String? customDaysText,
    @Default(true) bool isEnabled,
    @Default(false) bool isVibrationAlarm,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ReminderItem;

  factory ReminderItem.fromJson(Map<String, dynamic> json) =>
      _$ReminderItemFromJson(json);
}
