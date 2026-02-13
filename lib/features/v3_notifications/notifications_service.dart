import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class V3NotificationsService {
  V3NotificationsService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _tapController = StreamController<String>.broadcast();

  bool _initialized = false;

  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  Stream<String> get tapStream => _tapController.stream;

  Future<void> initialize() async {
    if (_initialized || !isSupported) return;

    tz.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _tapController.add(payload);
        }
      },
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> cancelDailyReminder() async {
    if (!isSupported) return;
    await _plugin.cancel(7001);
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String body,
    String? payload,
  }) async {
    if (!isSupported) return;
    await initialize();

    await _plugin.cancel(7001);

    final now = tz.TZDateTime.now(tz.local);
    var schedule = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (schedule.isBefore(now)) {
      schedule = schedule.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      7001,
      'Quote reminder',
      body,
      schedule,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'quote_reminder_channel',
          'Quote Reminder',
          channelDescription: 'Daily quote reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  void dispose() {
    _tapController.close();
  }
}
