import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

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
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings);

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
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final location = tz.local;
    var tzTime = tz.TZDateTime.from(scheduledTime, location);

    // If periodic and original time has already passed, advance to the next occurrence
    if (matchDateTimeComponents != null && tzTime.isBefore(tz.TZDateTime.now(location))) {
      if (matchDateTimeComponents == DateTimeComponents.time) {
        tzTime = tzTime.add(const Duration(days: 1));
      } else if (matchDateTimeComponents == DateTimeComponents.dayOfWeekAndTime) {
        tzTime = tzTime.add(const Duration(days: 7));
      } else if (matchDateTimeComponents == DateTimeComponents.dayOfMonthAndTime) {
        tzTime = tz.TZDateTime(location, tzTime.year, tzTime.month + 1, tzTime.day, tzTime.hour, tzTime.minute);
      }
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  /// Cancel a scheduled notification by its [id].
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all pending notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Converts a String id to a stable int for the plugin.
  static int idFromString(String id) => id.hashCode.abs() % 2147483647;
}
