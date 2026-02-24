import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../models/quote_model.dart';
import '../../models/quote_viewer_filter.dart';
import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../providers/storage_provider.dart';
import '../../providers/streak_provider.dart';
import 'notification_settings_model.dart';
import 'notifications_service.dart';

const _kDailyEnabled = 'notifications.daily_enabled';
const _kDailyHour = 'notifications.daily_hour';
const _kDailyMinute = 'notifications.daily_minute';

const _kExtraEnabled = 'notifications.extra_enabled';
const _kExtraHour = 'notifications.extra_hour';
const _kExtraMinute = 'notifications.extra_minute';
const _kExtraSource = 'notifications.extra_source';
const _kExtraSelectedTags = 'notifications.extra_selected_tags';

const _kStreakEnabled = 'notifications.streak_enabled';
const _kLastStreakNotificationDate =
    'notifications.last_streak_notification_date';

const _kNotificationDailyId = 1;
const _kNotificationExtraId = 2;
const _kNotificationStreakId = 3;
const _kTagOptionLimit = 20;

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

// Startup integration point: app boot triggers cancel+reschedule from persisted settings.
final notificationBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.read(notificationSettingsProvider.notifier).rescheduleFromStartup();
});

final notificationTagOptionsProvider = FutureProvider<List<String>>((
  ref,
) async {
  final categories = await ref.watch(categoryCountsProvider.future);
  final ordered = categories.keys
      .map((c) => c.trim().toLowerCase())
      .where((c) => c.isNotEmpty && c != 'all')
      .toList(growable: true);
  final top = ordered.take(_kTagOptionLimit).toList(growable: true);

  for (final requiredTag in const ['movies', 'series']) {
    if (top.contains(requiredTag)) continue;
    if (top.length >= _kTagOptionLimit) {
      top.removeLast();
    }
    top.add(requiredTag);
  }
  return top;
});

class NotificationSettingsNotifier
    extends StateNotifier<NotificationSettingsModel> {
  NotificationSettingsNotifier(this._ref)
    : super(NotificationSettingsModel.defaults) {
    _ensureLoaded();
  }

  final Ref _ref;
  Future<void>? _loadFuture;
  bool _isRescheduling = false;

  Future<void> _ensureLoaded() {
    _loadFuture ??= _loadInternal();
    return _loadFuture!;
  }

  Future<void> _loadInternal() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final parsedTags = _decodeTagList(
      prefs.getString(_kExtraSelectedTags),
      fallback: NotificationSettingsModel.defaults.extraSelectedTags,
    );

    state = NotificationSettingsModel(
      dailyEnabled:
          prefs.getBool(_kDailyEnabled) ??
          NotificationSettingsModel.defaults.dailyEnabled,
      dailyHour:
          prefs.getInt(_kDailyHour) ??
          NotificationSettingsModel.defaults.dailyHour,
      dailyMinute:
          prefs.getInt(_kDailyMinute) ??
          NotificationSettingsModel.defaults.dailyMinute,
      extraEnabled:
          prefs.getBool(_kExtraEnabled) ??
          NotificationSettingsModel.defaults.extraEnabled,
      extraHour:
          prefs.getInt(_kExtraHour) ??
          NotificationSettingsModel.defaults.extraHour,
      extraMinute:
          prefs.getInt(_kExtraMinute) ??
          NotificationSettingsModel.defaults.extraMinute,
      extraSource: _normalizeExtraSource(
        prefs.getString(_kExtraSource) ??
            NotificationSettingsModel.defaults.extraSource,
      ),
      extraSelectedTags: parsedTags,
      streakEnabled:
          prefs.getBool(_kStreakEnabled) ??
          NotificationSettingsModel.defaults.streakEnabled,
    );
  }

  Future<void> rescheduleFromStartup() async {
    await _ensureLoaded();
    await _applySchedule();
  }

  Future<void> update(NotificationSettingsModel next) async {
    await _ensureLoaded();
    final sanitized = _sanitize(next);
    state = sanitized;
    await _persist(sanitized);
    await _applySchedule();
  }

  Future<void> _persist(NotificationSettingsModel settings) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setBool(_kDailyEnabled, settings.dailyEnabled);
    await prefs.setInt(_kDailyHour, settings.dailyHour);
    await prefs.setInt(_kDailyMinute, settings.dailyMinute);

    await prefs.setBool(_kExtraEnabled, settings.extraEnabled);
    await prefs.setInt(_kExtraHour, settings.extraHour);
    await prefs.setInt(_kExtraMinute, settings.extraMinute);
    await prefs.setString(_kExtraSource, settings.extraSource);
    await prefs.setString(
      _kExtraSelectedTags,
      jsonEncode(settings.extraSelectedTags),
    );

    await prefs.setBool(_kStreakEnabled, settings.streakEnabled);
  }

  Future<void> _applySchedule() async {
    if (_isRescheduling) return;
    _isRescheduling = true;

    final service = _ref.read(notificationsServiceProvider);
    try {
      await service.initialize();

      // Hard reset on each pass to avoid stale schedules from previous models.
      await service.cancelAllScheduledNotifications();

      if (!service.notificationsGranted) {
        debugPrint('Notifications not granted; skipping scheduling.');
        return;
      }

      if (state.dailyEnabled) {
        await _scheduleDailyQuote();
      }

      if (state.extraEnabled) {
        await _scheduleOptionalExtra();
      }

      if (state.streakEnabled) {
        await _scheduleStreakReminder();
      }
    } catch (error, stack) {
      debugPrint('Notification scheduling failed: $error');
      debugPrint('$stack');
    } finally {
      _isRescheduling = false;
    }
  }

  Future<void> _scheduleDailyQuote() async {
    final service = _ref.read(notificationsServiceProvider);
    final quote = await _ref.read(dailyQuoteProvider.future);
    final schedule = _nextDailyTrigger(
      hour: state.dailyHour,
      minute: state.dailyMinute,
    );

    await service.scheduleReminder(
      id: _kNotificationDailyId,
      schedule: schedule,
      title: 'Your Daily Quote',
      body: _trimQuoteBody(quote.quote),
      payload: '/today',
      repeatDaily: true,
    );
  }

  Future<void> _scheduleOptionalExtra() async {
    final service = _ref.read(notificationsServiceProvider);
    final planned = await _buildExtraNotification();
    if (planned == null) {
      return;
    }

    final schedule = _nextDailyTrigger(
      hour: state.extraHour,
      minute: state.extraMinute,
    );
    await service.scheduleReminder(
      id: _kNotificationExtraId,
      schedule: schedule,
      title: planned.title,
      body: _trimQuoteBody(planned.quote.quote),
      payload: planned.payload,
      repeatDaily: true,
    );
  }

  Future<_PlannedExtraNotification?> _buildExtraNotification() async {
    if (state.extraSource == 'saved') {
      final savedIds = _ref.read(savedQuoteIdsProvider);
      if (savedIds.isEmpty) return null;

      final allQuotes = await _ref.read(allQuotesProvider.future);
      final savedQuotes = allQuotes
          .where((q) => savedIds.contains(q.id))
          .toList(growable: false);
      if (savedQuotes.isEmpty) return null;

      final quote = _pickRandom(savedQuotes);
      return _PlannedExtraNotification(
        title: 'From Your Collection',
        quote: quote,
        payload: '/viewer/saved/all?quoteId=${quote.id}',
      );
    }

    final tags = _normalizeTags(state.extraSelectedTags).toList(growable: true);
    if (tags.isEmpty) return null;

    tags.shuffle(Random());
    final quoteService = _ref.read(quoteServiceProvider);
    for (final tag in tags) {
      final quotes = await _ref.read(
        quotesByFilterProvider(
          QuoteViewerFilter(type: 'category', tag: tag),
        ).future,
      );
      if (quotes.isEmpty) continue;

      final quote = _pickRandom(quotes);
      final routeTag = tag == 'series' ? 'movies/series' : tag;
      final title = tag == 'series'
          ? 'From Movies/Series'
          : 'From ${quoteService.toTitleCase(tag)}';
      return _PlannedExtraNotification(
        title: title,
        quote: quote,
        payload:
            '/viewer/category/${Uri.encodeComponent(routeTag)}?quoteId=${quote.id}',
      );
    }

    return null;
  }

  Future<void> _scheduleStreakReminder() async {
    final currentStreak = _ref.read(streakProvider);
    if (currentStreak <= 0) return;

    final streakNotifier = _ref.read(streakProvider.notifier);
    if (streakNotifier.hasMetTodayRequirement()) return;

    final now = tz.TZDateTime.now(tz.local);
    if (now.hour < 18) return;

    final prefs = _ref.read(sharedPreferencesProvider);
    final todayKey = _ymd(now);
    final alreadyShown =
        prefs.getString(_kLastStreakNotificationDate) == todayKey;
    if (alreadyShown) return;

    final service = _ref.read(notificationsServiceProvider);
    final schedule = now.add(const Duration(seconds: 5));
    await service.scheduleReminder(
      id: _kNotificationStreakId,
      schedule: schedule,
      title: 'Don\'t break your streak 🔥',
      body: 'Read 3 quotes today to keep it going.',
      payload: '/today',
      repeatDaily: false,
    );

    await prefs.setString(_kLastStreakNotificationDate, todayKey);
  }

  NotificationSettingsModel _sanitize(NotificationSettingsModel input) {
    final dailyHour = input.dailyHour.clamp(0, 23);
    final dailyMinute = input.dailyMinute.clamp(0, 59);
    final extraHour = input.extraHour.clamp(0, 23);
    final extraMinute = input.extraMinute.clamp(0, 59);

    return NotificationSettingsModel(
      dailyEnabled: input.dailyEnabled,
      dailyHour: dailyHour,
      dailyMinute: dailyMinute,
      extraEnabled: input.extraEnabled,
      extraHour: extraHour,
      extraMinute: extraMinute,
      extraSource: _normalizeExtraSource(input.extraSource),
      extraSelectedTags: _normalizeTags(
        input.extraSelectedTags,
      ).toList(growable: false),
      streakEnabled: input.streakEnabled,
    );
  }

  String _normalizeExtraSource(String source) {
    return source.trim().toLowerCase() == 'tags' ? 'tags' : 'saved';
  }

  Set<String> _normalizeTags(List<String> values) {
    return values
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty && item != 'all')
        .toSet();
  }

  List<String> _decodeTagList(String? raw, {required List<String> fallback}) {
    if (raw == null || raw.trim().isEmpty) {
      return _normalizeTags(fallback).toList(growable: false);
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return _normalizeTags(fallback).toList(growable: false);
      }
      return _normalizeTags(
        decoded.map((item) => item.toString()).toList(growable: false),
      ).toList(growable: false);
    } catch (_) {
      return _normalizeTags(fallback).toList(growable: false);
    }
  }

  QuoteModel _pickRandom(List<QuoteModel> quotes) {
    final index = Random().nextInt(quotes.length);
    return quotes[index];
  }

  tz.TZDateTime _nextDailyTrigger({required int hour, required int minute}) {
    final now = tz.TZDateTime.now(tz.local);
    var schedule = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!schedule.isAfter(now)) {
      schedule = schedule.add(const Duration(days: 1));
    }
    return schedule;
  }

  String _trimQuoteBody(String quote) {
    final clean = quote.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= 120) return clean;
    return '${clean.substring(0, 117).trimRight()}...';
  }

  String _ymd(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _PlannedExtraNotification {
  const _PlannedExtraNotification({
    required this.title,
    required this.quote,
    required this.payload,
  });

  final String title;
  final QuoteModel quote;
  final String payload;
}

final notificationSettingsProvider =
    StateNotifierProvider<
      NotificationSettingsNotifier,
      NotificationSettingsModel
    >((ref) => NotificationSettingsNotifier(ref));
