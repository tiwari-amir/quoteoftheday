import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../providers/quote_providers.dart';
import '../../providers/storage_provider.dart';
import 'notification_settings_model.dart';
import 'notifications_service.dart';

const _kEnabled = 'v3.notifications_enabled';
const _kHour = 'v3.notification_hour';
const _kMinute = 'v3.notification_minute';
const _kSource = 'v3.notification_source';

final notificationsServiceProvider = Provider<V3NotificationsService>((ref) {
  final service = V3NotificationsService();
  ref.onDispose(service.dispose);
  return service;
});

final notificationTapProvider = StreamProvider<String>((ref) async* {
  final service = ref.read(notificationsServiceProvider);
  await service.initialize();
  yield* service.tapStream;
});

class NotificationSettingsNotifier extends StateNotifier<NotificationSettingsModel> {
  NotificationSettingsNotifier(this._ref) : super(NotificationSettingsModel.defaults) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    state = NotificationSettingsModel(
      enabled: prefs.getBool(_kEnabled) ?? false,
      hour: prefs.getInt(_kHour) ?? 9,
      minute: prefs.getInt(_kMinute) ?? 0,
      source: prefs.getString(_kSource) ?? 'daily',
    );

    await _applySchedule();
  }

  Future<void> update(NotificationSettingsModel next) async {
    state = next;
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setBool(_kEnabled, next.enabled);
    await prefs.setInt(_kHour, next.hour);
    await prefs.setInt(_kMinute, next.minute);
    await prefs.setString(_kSource, next.source);

    await _applySchedule();
  }

  Future<void> _applySchedule() async {
    final service = _ref.read(notificationsServiceProvider);
    if (!state.enabled) {
      await service.cancelDailyReminder();
      return;
    }
    await service.initialize();

    final repo = _ref.read(quoteRepositoryProvider);
    final quoteService = _ref.read(quoteServiceProvider);
    final allQuotes = await repo.getAllQuotes();
    if (allQuotes.isEmpty) return;

    await service.cancelDailyReminder();

    final now = tz.TZDateTime.now(tz.local);
    var firstTrigger = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      state.hour,
      state.minute,
    );
    if (!firstTrigger.isAfter(now)) {
      firstTrigger = firstTrigger.add(const Duration(days: 1));
    }

    for (var offset = 0; offset < 30; offset++) {
      final schedule = firstTrigger.add(Duration(days: offset));
      final localDate = DateTime(
        schedule.year,
        schedule.month,
        schedule.day,
      );
      final remote = await repo.getDailyQuote(localDate);
      final quote = remote ?? quoteService.pickQuoteForDate(allQuotes, localDate);
      final body = '"${quote.quote}" — ${quote.author}';

      await service.scheduleReminder(
        id: 7001 + offset,
        schedule: schedule,
        title: 'Today\'s Quote',
        body: body,
        payload: '/today',
      );
    }
  }
}

final notificationSettingsProvider = StateNotifierProvider<
    NotificationSettingsNotifier, NotificationSettingsModel>((ref) {
  return NotificationSettingsNotifier(ref);
});
