import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../models/quote_model.dart';
import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../providers/storage_provider.dart';
import '../../services/quote_service.dart';
import 'notification_settings_model.dart';
import 'notifications_service.dart';

const _kEnabled = 'v3.notifications_enabled';
const _kHour = 'v3.notification_hour';
const _kMinute = 'v3.notification_minute';
const _kSource = 'v3.notification_source';
const _kScheduleWindowDays = 30;

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

class NotificationSettingsNotifier
    extends StateNotifier<NotificationSettingsModel> {
  NotificationSettingsNotifier(this._ref)
    : super(NotificationSettingsModel.defaults) {
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
    try {
      if (!state.enabled) {
        await service.cancelDailyReminder();
        return;
      }
      await service.initialize();
      if (!service.notificationsGranted) {
        debugPrint(
          'Notifications permission not granted; skipping scheduling.',
        );
        return;
      }

      final repo = _ref.read(quoteRepositoryProvider);
      final quoteService = _ref.read(quoteServiceProvider);
      final allQuotes = await repo.getAllQuotes();
      if (allQuotes.isEmpty) return;

      final savedIds = _ref.read(savedQuoteIdsProvider);
      final savedQuotes = allQuotes
          .where((q) => savedIds.contains(q.id))
          .toList(growable: false);

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

      final firstLocalDate = DateTime(
        firstTrigger.year,
        firstTrigger.month,
        firstTrigger.day,
      );
      final firstDailyRemote = state.source == 'daily'
          ? await repo.getDailyQuote(firstLocalDate)
          : null;

      for (var offset = 0; offset < _kScheduleWindowDays; offset++) {
        final schedule = firstTrigger.add(Duration(days: offset));
        final localDate = DateTime(schedule.year, schedule.month, schedule.day);

        final quote = await _pickQuoteForReminder(
          localDate: localDate,
          allQuotes: allQuotes,
          savedQuotes: savedQuotes,
          quoteService: quoteService,
          firstDailyRemote: offset == 0 ? firstDailyRemote : null,
        );
        final body = _compactBody(quote.quote, quote.author);

        await service.scheduleReminder(
          id: 7001 + offset,
          schedule: schedule,
          title: 'Today\'s Quote',
          body: body,
          payload: '/today',
        );
      }
    } catch (error, stack) {
      debugPrint('Notification scheduling failed: $error');
      debugPrint('$stack');
    }
  }

  Future<QuoteModel> _pickQuoteForReminder({
    required DateTime localDate,
    required List<QuoteModel> allQuotes,
    required List<QuoteModel> savedQuotes,
    required QuoteService quoteService,
    required QuoteModel? firstDailyRemote,
  }) async {
    if (state.source == 'saved' && savedQuotes.isNotEmpty) {
      return quoteService.pickQuoteForDate(savedQuotes, localDate);
    }

    if (state.source == 'random') {
      final index = localDate.millisecondsSinceEpoch.abs() % allQuotes.length;
      return allQuotes[index];
    }

    if (firstDailyRemote != null) {
      return firstDailyRemote;
    }
    return quoteService.pickQuoteForDate(allQuotes, localDate);
  }

  String _compactBody(String quote, String author) {
    final cleanQuote = quote.replaceAll(RegExp(r'\s+'), ' ').trim();
    final clipped = cleanQuote.length > 112
        ? '${cleanQuote.substring(0, 109).trimRight()}...'
        : cleanQuote;
    return '"$clipped" - $author';
  }
}

final notificationSettingsProvider =
    StateNotifierProvider<
      NotificationSettingsNotifier,
      NotificationSettingsModel
    >((ref) {
      return NotificationSettingsNotifier(ref);
    });
