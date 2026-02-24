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
  final StreamController<String> _tapController =
      StreamController<String>.broadcast();

  bool _initialized = false;
  bool _notificationsGranted = true;
  bool _canUseExactAlarms = true;

  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get notificationsGranted => _notificationsGranted;
  AndroidScheduleMode get androidScheduleMode => _canUseExactAlarms
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;
  Stream<String> get tapStream => _tapController.stream;

  Future<void> initialize() async {
    if (_initialized || !isSupported) return;

    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone));
    } catch (error) {
      debugPrint('Timezone detection failed, using default timezone: $error');
    }

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
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidPermission = await android?.requestNotificationsPermission();
    if (androidPermission != null) {
      _notificationsGranted = androidPermission;
    }
    await android?.requestExactAlarmsPermission();
    final canExact = await android?.canScheduleExactNotifications();
    if (canExact != null) {
      _canUseExactAlarms = canExact;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosPermission = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (iosPermission != null) {
      _notificationsGranted = _notificationsGranted && iosPermission;
    }

    _initialized = true;
  }

  Future<void> cancelDailyReminder() async {
    await cancelAllScheduledNotifications();
  }

  Future<void> cancelAllScheduledNotifications() async {
    if (!isSupported) return;
    await initialize();
    await _plugin.cancelAll();
  }

  Future<void> scheduleReminder({
    required int id,
    required tz.TZDateTime schedule,
    required String title,
    required String body,
    String? payload,
    bool repeatDaily = false,
  }) async {
    if (!isSupported) return;
    await initialize();
    if (!_notificationsGranted) return;
    await _plugin.cancel(id);

    final androidDetails = AndroidNotificationDetails(
      'quote_reminder_channel',
      'QuoteFlow Reminder',
      channelDescription: 'Daily quote reminders',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    try {
      await _scheduleWithMode(
        id: id,
        title: title,
        body: body,
        schedule: schedule,
        details: details,
        payload: payload,
        mode: androidScheduleMode,
        repeatDaily: repeatDaily,
      );
    } catch (error) {
      if (!Platform.isAndroid ||
          androidScheduleMode == AndroidScheduleMode.inexactAllowWhileIdle) {
        rethrow;
      }
      debugPrint(
        'Exact alarm scheduling failed for id=$id, retrying inexact mode: $error',
      );
      _canUseExactAlarms = false;
      await _scheduleWithMode(
        id: id,
        title: title,
        body: body,
        schedule: schedule,
        details: details,
        payload: payload,
        mode: AndroidScheduleMode.inexactAllowWhileIdle,
        repeatDaily: repeatDaily,
      );
    }
  }

  Future<void> _scheduleWithMode({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime schedule,
    required NotificationDetails details,
    required String? payload,
    required AndroidScheduleMode mode,
    required bool repeatDaily,
  }) {
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      schedule,
      details,
      payload: payload,
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
    );
  }

  void dispose() {
    _tapController.close();
  }
}
