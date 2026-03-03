import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

bool _timezoneInitialized = false;
Future<void>? _timezoneInitializationFuture;
const AndroidNotificationChannel _quoteReminderChannel =
    AndroidNotificationChannel(
      'quote_reminder_channel',
      'QuoteFlow Reminder',
      description: 'Daily quote reminders',
      importance: Importance.high,
    );

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
  final now = tz.TZDateTime.now(tz.local);
  debugPrint(
    '[Notifications] Timezone initialized. detected="$detectedTimeZone", active="${tz.local.name}", now="$now"',
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
  AndroidScheduleMode get androidScheduleMode =>
      AndroidScheduleMode.inexactAllowWhileIdle;
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

      await android?.createNotificationChannel(_quoteReminderChannel);
      debugPrint(
        '[Notifications] Ensured Android channel: id=${_quoteReminderChannel.id}',
      );

      final enabled = await _areAndroidNotificationsEnabled(android);
      if (enabled != null) {
        _notificationsGranted = enabled;
      }

      final canExact = await _canAndroidScheduleExactNotifications(android);
      if (canExact != null) {
        _canUseExactAlarms = canExact;
      }

      debugPrint(
        '[Notifications] Android init: notificationsGranted=$_notificationsGranted, canUseExactAlarms=$_canUseExactAlarms',
      );
    }

    _initialized = true;
  }

  Future<bool> ensurePermissions({required bool requestIfNeeded}) async {
    if (!isSupported) return false;
    await initialize();

    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      final enabledBefore = await _areAndroidNotificationsEnabled(android);
      if (enabledBefore != null) {
        _notificationsGranted = enabledBefore;
      }

      if (requestIfNeeded && !_notificationsGranted) {
        final requested = await _requestAndroidPermission(android);
        if (requested != null) {
          _notificationsGranted = requested;
        }
        final enabledAfter = await _areAndroidNotificationsEnabled(android);
        if (enabledAfter != null) {
          _notificationsGranted = enabledAfter;
        }
      }

      if (requestIfNeeded) {
        await _requestAndroidExactAlarmPermission(android);
      }
      final canExact = await _canAndroidScheduleExactNotifications(android);
      if (canExact != null) {
        _canUseExactAlarms = canExact;
      }

      debugPrint(
        '[Notifications] Android permission check: requestIfNeeded=$requestIfNeeded, notificationsGranted=$_notificationsGranted, canUseExactAlarms=$_canUseExactAlarms',
      );
    }

    if (Platform.isIOS) {
      final iosImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (requestIfNeeded) {
        final granted = await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        if (granted != null) {
          _notificationsGranted = granted;
        }
      }
      debugPrint(
        '[Notifications] iOS permission check: requestIfNeeded=$requestIfNeeded, notificationsGranted=$_notificationsGranted',
      );
    }

    return _notificationsGranted;
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

  Future<bool?> _areAndroidNotificationsEnabled(
    AndroidFlutterLocalNotificationsPlugin? implementation,
  ) async {
    if (implementation == null) return null;
    try {
      return await implementation.areNotificationsEnabled();
    } catch (_) {
      try {
        final dynamic dynamicImplementation = implementation;
        final result = await dynamicImplementation.areNotificationsEnabled();
        return result is bool ? result : null;
      } catch (error) {
        debugPrint(
          '[Notifications] Failed to read Android notification enabled state: $error',
        );
        return null;
      }
    }
  }

  Future<void> _requestAndroidExactAlarmPermission(
    AndroidFlutterLocalNotificationsPlugin? implementation,
  ) async {
    if (implementation == null) return;
    try {
      await implementation.requestExactAlarmsPermission();
    } catch (_) {
      try {
        final dynamic dynamicImplementation = implementation;
        await dynamicImplementation.requestExactAlarmsPermission();
      } catch (error) {
        debugPrint(
          '[Notifications] Android exact alarm permission request failed: $error',
        );
      }
    }
  }

  Future<bool?> _canAndroidScheduleExactNotifications(
    AndroidFlutterLocalNotificationsPlugin? implementation,
  ) async {
    if (implementation == null) return null;
    try {
      return await implementation.canScheduleExactNotifications();
    } catch (_) {
      try {
        final dynamic dynamicImplementation = implementation;
        final result = await dynamicImplementation
            .canScheduleExactNotifications();
        return result is bool ? result : null;
      } catch (error) {
        debugPrint(
          '[Notifications] Failed to read exact alarm capability: $error',
        );
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
    await _logPendingRequests();
  }

  Future<void> scheduleReminder({
    required int id,
    required tz.TZDateTime schedule,
    required String title,
    required String body,
    String? authorName,
    String? authorImageUrl,
    String? payload,
    bool showReadFullAction = false,
    bool repeatDaily = false,
  }) async {
    if (!isSupported) return;
    await initialize();
    final allowed = await ensurePermissions(requestIfNeeded: false);
    if (!allowed) {
      debugPrint(
        '[Notifications] Skipping schedule for id=$id because notifications are not allowed.',
      );
      return;
    }
    await _plugin.cancel(id);
    debugPrint('[Notifications] Cleared existing notification with id=$id.');

    final authorImagePath = await _resolveAuthorImagePath(authorImageUrl);
    final androidStyle = _buildAndroidStyle(
      body: body,
      authorName: authorName,
      authorImagePath: authorImagePath,
    );

    final androidDetails = AndroidNotificationDetails(
      _quoteReminderChannel.id,
      _quoteReminderChannel.name,
      channelDescription: _quoteReminderChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      subText: authorName,
      largeIcon: authorImagePath == null
          ? null
          : FilePathAndroidBitmap(authorImagePath),
      styleInformation: androidStyle,
      actions: showReadFullAction
          ? const [
              AndroidNotificationAction(
                'read_full_quote',
                'Read full quote',
                showsUserInterface: true,
              ),
            ]
          : null,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        subtitle: authorName,
        attachments: authorImagePath == null
            ? null
            : [DarwinNotificationAttachment(authorImagePath)],
      ),
    );

    debugPrint(
      '[Notifications] Scheduling id=$id, mode=${androidScheduleMode.name}, repeatDaily=$repeatDaily, timezone=${tz.local.name}, nextTrigger=${schedule.toIso8601String()}',
    );

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
    await _logPendingRequests();
  }

  StyleInformation _buildAndroidStyle({
    required String body,
    required String? authorName,
    required String? authorImagePath,
  }) {
    // Keep text-first layout in the notification panel so author + quote remain visible.
    return BigTextStyleInformation(
      body,
      summaryText: authorName,
      htmlFormatSummaryText: false,
    );
  }

  Future<String?> _resolveAuthorImagePath(String? imageUrl) async {
    if (!isSupported || imageUrl == null || imageUrl.trim().isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(imageUrl.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    try {
      final cacheDir = await getTemporaryDirectory();
      final ext = uri.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final fileName = 'author_${uri.toString().hashCode.abs()}.$ext';
      final file = File('${cacheDir.path}${Platform.pathSeparator}$fileName');

      if (await file.exists() && await file.length() > 0) {
        return file.path;
      }

      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.isEmpty) {
        debugPrint(
          '[Notifications] Failed to download author image: status=${response.statusCode}, url=$uri',
        );
        return null;
      }

      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file.path;
    } catch (error) {
      debugPrint('[Notifications] Failed to resolve author image: $error');
      return null;
    }
  }

  Future<void> _logPendingRequests() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      final ids = pending.map((request) => request.id.toString()).join(', ');
      debugPrint(
        '[Notifications] Pending requests count=${pending.length}${ids.isEmpty ? '' : ', ids=[$ids]'}',
      );
    } catch (error) {
      debugPrint('[Notifications] Failed to read pending requests: $error');
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
