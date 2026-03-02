import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

bool _timezoneInitialized = false;
Future<void>? _timezoneInitializationFuture;

Future<void> initializeNotificationTimezone() {
  if (_timezoneInitialized) return Future.value();
  _timezoneInitializationFuture ??= _initializeNotificationTimezoneInternal();
  return _timezoneInitializationFuture!;
}

Future<void> _initializeNotificationTimezoneInternal() async {
  if (kIsWeb) {
    _timezoneInitialized = true;
    return;
  }

  tz.initializeTimeZones();

  String? detectedTimeZone;
  try {
    detectedTimeZone = await FlutterTimezone.getLocalTimezone();
  } catch (error) {
    debugPrint('[Notifications] Failed to detect device timezone: $error');
  }

  final selectedTimeZone =
      (detectedTimeZone != null && detectedTimeZone.trim().isNotEmpty)
      ? detectedTimeZone.trim()
      : 'UTC';

  try {
    tz.setLocalLocation(tz.getLocation(selectedTimeZone));
  } catch (error) {
    debugPrint(
      '[Notifications] Unknown timezone "$selectedTimeZone", falling back to UTC: $error',
    );
    tz.setLocalLocation(tz.getLocation('UTC'));
  }

  _timezoneInitialized = true;
  debugPrint(
    '[Notifications] Timezone initialized. detected="$detectedTimeZone", active="${tz.local.name}"',
  );
}

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

    await initializeNotificationTimezone();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
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

    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      final androidPermission = await _requestAndroidPermission(android);
      if (androidPermission != null) {
        _notificationsGranted = androidPermission;
      }

      await android?.requestExactAlarmsPermission();
      final canExact = await android?.canScheduleExactNotifications();
      if (canExact != null) {
        _canUseExactAlarms = canExact;
      }

      debugPrint(
        '[Notifications] Android permissions: notificationsGranted=$_notificationsGranted, canUseExactAlarms=$_canUseExactAlarms',
      );
    }

    if (Platform.isIOS) {
      final iosImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final iosPermission = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (iosPermission != null) {
        _notificationsGranted = _notificationsGranted && iosPermission;
      }
      debugPrint(
        '[Notifications] iOS permissions: notificationsGranted=$_notificationsGranted',
      );
    }

    _initialized = true;
  }

  Future<bool?> _requestAndroidPermission(
    AndroidFlutterLocalNotificationsPlugin? implementation,
  ) async {
    if (implementation == null) return null;

    try {
      // flutter_local_notifications >= 17 API
      return await implementation.requestNotificationsPermission();
    } catch (_) {
      try {
        // Backward-compatible fallback API
        final dynamic dynamicImplementation = implementation;
        final result = await dynamicImplementation.requestPermission();
        return result is bool ? result : null;
      } catch (error) {
        debugPrint('[Notifications] Android permission request failed: $error');
        return null;
      }
    }
  }

  tz.TZDateTime nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  Future<void> cancelDailyReminder() async {
    await cancelAllScheduledNotifications();
  }

  Future<void> cancelAllScheduledNotifications() async {
    if (!isSupported) return;
    await initialize();
    await _plugin.cancelAll();
    debugPrint('[Notifications] Cancelled all scheduled notifications.');
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
    debugPrint('[Notifications] Cleared existing notification with id=$id.');

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

    debugPrint(
      '[Notifications] Scheduling id=$id, repeatDaily=$repeatDaily, timezone=${tz.local.name}, nextTrigger=$schedule',
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
      debugPrint('[Notifications] Scheduled id=$id successfully.');
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
      debugPrint(
        '[Notifications] Scheduled id=$id with fallback inexact mode.',
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
