import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/quote_model.dart';
import 'quote_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Action taps are handled in the foreground isolate when app UI is shown.
}

class NotificationService {
  NotificationService();

  static const String _channelId = 'daily_quote_channel';
  static const int _baseNotificationId = 9000;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _requestPermissions();
    _isInitialized = true;
  }

  Future<void> scheduleMorningQuotes(List<QuoteModel> quotes) async {
    if (!_isInitialized || quotes.isEmpty) return;

    for (var i = 0; i < 14; i++) {
      await _plugin.cancel(_baseNotificationId + i);
    }

    final quoteService = QuoteService();
    final now = DateTime.now();

    for (var i = 0; i < 14; i++) {
      final date = now.add(Duration(days: i));
      final quote = quoteService.pickQuoteForDate(quotes, date);
      final scheduledTime = _atEightAM(date, now);
      if (scheduledTime == null) continue;

      final message = '"${quote.quote}"\n\n- ${quote.author}';

      await _plugin.zonedSchedule(
        _baseNotificationId + i,
        'Quote of the Day',
        message,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Daily Quotes',
            channelDescription: 'Morning daily quote notifications',
            importance: Importance.max,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(message),
            actions: const [
              AndroidNotificationAction(
                'share_quote',
                'Share',
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                'open_app',
                'Open',
                showsUserInterface: true,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: message,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> _requestPermissions() async {
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.requestNotificationsPermission();

    final iosImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    if (response.actionId == 'share_quote' && response.payload != null) {
      Share.share(response.payload!);
    }
  }

  tz.TZDateTime? _atEightAM(DateTime targetDay, DateTime now) {
    final scheduled = tz.TZDateTime(
      tz.local,
      targetDay.year,
      targetDay.month,
      targetDay.day,
      8,
    );

    if (scheduled.isBefore(tz.TZDateTime.from(now, tz.local))) {
      return null;
    }
    return scheduled;
  }
}
