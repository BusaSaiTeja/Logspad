import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Background notification response handler (invoked when user taps actions in background)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Tapping "Stop Reminder" with cancelNotification: true automatically dismisses
  // the notification and stops the vibration pattern.
}

/// Wraps flutter_local_notifications for the app.
/// Call [initialize] from main() before using.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'logspad_reminders';
  static const String _channelName = 'Logspad Reminders';
  static const String _channelDesc = 'Scheduled reminders from Logspad';

  static const String _alarmChannelId = 'logspad_reminders_alarm';
  static const String _alarmChannelName = 'Logspad Alarm Reminders';
  static const String _alarmChannelDesc =
      'High priority alarm reminders with continuous vibration';

  static const String stopAlarmActionId = 'stop_alarm_action';

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Failed to set local timezone, falling back to system/UTC: $e');
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final darwinNotificationCategories = <DarwinNotificationCategory>[
      DarwinNotificationCategory(
        'alarm_category',
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.plain(
            stopAlarmActionId,
            'Stop Reminder',
            options: <DarwinNotificationActionOption>{
              DarwinNotificationActionOption.destructive,
            },
          ),
        ],
      ),
    ];

    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: darwinNotificationCategories,
    );
    final settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        if (response.actionId == stopAlarmActionId && response.id != null) {
          await _plugin.cancel(response.id!);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Request Android 13+ notification permission
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// Schedule a local notification at [scheduledTime].
  /// [id] must be stable for the same reminder so cancel works.
  /// [matchDateTimeComponents] enables periodic repetition (daily, weekly, monthly).
  /// [isVibrationAlarm] toggles continuous alarm vibration with a "Stop Reminder" action.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    DateTimeComponents? matchDateTimeComponents,
    bool isVibrationAlarm = false,
  }) async {
    final location = tz.local;
    final now = tz.TZDateTime.now(location);
    var tzTime = tz.TZDateTime.from(scheduledTime, location);

    // If periodic and original time has already passed, advance to the next occurrence
    if (matchDateTimeComponents != null) {
      while (tzTime.isBefore(now)) {
        if (matchDateTimeComponents == DateTimeComponents.time) {
          tzTime = tzTime.add(const Duration(days: 1));
        } else if (matchDateTimeComponents == DateTimeComponents.dayOfWeekAndTime) {
          tzTime = tzTime.add(const Duration(days: 7));
        } else if (matchDateTimeComponents == DateTimeComponents.dayOfMonthAndTime) {
          tzTime = tz.TZDateTime(
            location,
            tzTime.month == 12 ? tzTime.year + 1 : tzTime.year,
            tzTime.month == 12 ? 1 : tzTime.month + 1,
            tzTime.day,
            tzTime.hour,
            tzTime.minute,
          );
        } else {
          tzTime = tzTime.add(const Duration(days: 1));
        }
      }
    } else {
      // One-off reminder (recurrence: none)
      if (tzTime.isBefore(now)) {
        if (now.difference(tzTime).inMinutes < 2) {
          tzTime = now.add(const Duration(seconds: 5));
        } else {
          debugPrint('[NotificationService] One-off reminder is in the past: $tzTime');
          return;
        }
      }
    }

    final androidDetails = AndroidNotificationDetails(
      isVibrationAlarm ? _alarmChannelId : _channelId,
      isVibrationAlarm ? _alarmChannelName : _channelName,
      channelDescription: isVibrationAlarm ? _alarmChannelDesc : _channelDesc,
      importance: isVibrationAlarm ? Importance.max : Importance.high,
      priority: isVibrationAlarm ? Priority.max : Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      vibrationPattern: isVibrationAlarm
          ? Int64List.fromList([
              0, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000,
            ])
          : null,
      audioAttributesUsage: isVibrationAlarm
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,
      category: isVibrationAlarm
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.reminder,
      actions: isVibrationAlarm
          ? const [
              AndroidNotificationAction(
                stopAlarmActionId,
                'Stop Reminder',
                cancelNotification: true,
                showsUserInterface: false,
              ),
            ]
          : null,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: isVibrationAlarm ? 'alarm_category' : null,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } catch (e) {
      debugPrint('[NotificationService] exactAllowWhileIdle failed, falling back to inexact: $e');
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    }
  }

  /// Schedule repeating alarms for specific days of the week (e.g. Mon, Wed, Fri)
  Future<void> scheduleCustomWeekdaysNotification({
    required int baseId,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required List<int> weekdays, // 1 = Monday .. 7 = Sunday
    bool isVibrationAlarm = false,
  }) async {
    // Cancel existing alarms for this reminder across all 7 days
    await cancelReminderNotifications(baseId);

    final now = DateTime.now();
    for (final day in weekdays) {
      var targetDate = DateTime(
        now.year,
        now.month,
        now.day,
        scheduledTime.hour,
        scheduledTime.minute,
      );
      while (targetDate.weekday != day || targetDate.isBefore(now)) {
        targetDate = targetDate.add(const Duration(days: 1));
      }

      await scheduleNotification(
        id: (baseId + day) % 2147483647,
        title: title,
        body: body,
        scheduledTime: targetDate,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        isVibrationAlarm: isVibrationAlarm,
      );
    }
  }

  /// Cancel a scheduled notification by its [id].
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel a reminder and all its custom day sub-alarms.
  Future<void> cancelReminderNotifications(int baseId) async {
    await _plugin.cancel(baseId);
    for (int day = 1; day <= 7; day++) {
      await _plugin.cancel((baseId + day) % 2147483647);
    }
  }

  /// Cancel all pending notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Converts a String id to a stable int for the plugin.
  static int idFromString(String id) => id.hashCode.abs() % 2147483647;
}
