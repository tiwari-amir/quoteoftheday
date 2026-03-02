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
    _loadFuture = _loadInternal();
    await _loadFuture;
    debugPrint('[Notifications] Startup reschedule requested.');
    await _applySchedule(requestPermissions: false);
  }

  Future<void> update(NotificationSettingsModel next) async {
    await _ensureLoaded();
    final sanitized = _sanitize(next);
    state = sanitized;
    await _persist(sanitized);
    await _applySchedule(requestPermissions: true);
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

  Future<void> _applySchedule({required bool requestPermissions}) async {
    if (_isRescheduling) return;
    _isRescheduling = true;

    final service = _ref.read(notificationsServiceProvider);
    try {
      await service.initialize();
      final permissionsGranted = await service.ensurePermissions(
        requestIfNeeded: requestPermissions,
      );

      // Hard reset on each pass to avoid stale schedules from previous models.
      await service.cancelAllScheduledNotifications();
      debugPrint(
        '[Notifications] Cleared existing schedules before reschedule.',
      );

      if (!permissionsGranted) {
        debugPrint(
          '[Notifications] Permissions not granted; skipping schedule.',
        );
        return;
      }

      if (state.dailyEnabled) {
        try {
          await _scheduleDailyQuote();
        } catch (error, stack) {
          debugPrint('[Notifications] Daily reminder schedule failed: $error');
          debugPrint('[Notifications] $stack');
        }
      }

      if (state.extraEnabled) {
        try {
          await _scheduleOptionalExtra();
        } catch (error, stack) {
          debugPrint('[Notifications] Extra reminder schedule failed: $error');
          debugPrint('[Notifications] $stack');
        }
      }

      if (state.streakEnabled) {
        try {
          await _scheduleStreakReminder();
        } catch (error, stack) {
          debugPrint('[Notifications] Streak reminder schedule failed: $error');
          debugPrint('[Notifications] $stack');
        }
      }
    } catch (error, stack) {
      debugPrint('[Notifications] Scheduling failed: $error');
      debugPrint('[Notifications] $stack');
    } finally {
      _isRescheduling = false;
    }
  }

  Future<void> _scheduleDailyQuote() async {
    final service = _ref.read(notificationsServiceProvider);
    final schedule = _nextInstanceOfTime(state.dailyHour, state.dailyMinute);
    String quoteBody;
    String authorName = 'QuoteFlow';
    String? authorImageUrl;
    bool showReadFullAction = false;
    try {
      final quote = await _ref.read(dailyQuoteProvider.future);
      quoteBody = _trimQuoteBody(quote.quote);
      authorName = quote.author;
      authorImageUrl = await _loadAuthorImageUrl(quote.author);
      showReadFullAction = _isLongQuote(quote.quote);
    } catch (error) {
      debugPrint(
        '[Notifications] Failed to load daily quote content, using fallback copy: $error',
      );
      quoteBody = 'Open QuoteFlow for your daily quote.';
    }
    debugPrint(
      '[Notifications] Scheduling daily quote: id=$_kNotificationDailyId, trigger=$schedule',
    );
    final title = authorName.trim().isEmpty ? 'QuoteFlow' : authorName.trim();

    await service.scheduleReminder(
      id: _kNotificationDailyId,
      schedule: schedule,
      title: title,
      body: quoteBody,
      authorName: authorName,
      authorImageUrl: authorImageUrl,
      payload: '/today',
      showReadFullAction: showReadFullAction,
      repeatDaily: true,
    );
  }

  Future<void> _scheduleOptionalExtra() async {
    final service = _ref.read(notificationsServiceProvider);
    final planned = await _buildExtraNotification();
    if (planned == null) {
      return;
    }

    final schedule = _nextInstanceOfTime(state.extraHour, state.extraMinute);
    debugPrint(
      '[Notifications] Scheduling extra quote: id=$_kNotificationExtraId, trigger=$schedule',
    );
    final title = planned.quote.author.trim().isEmpty
        ? planned.title
        : planned.quote.author.trim();
    final showReadFullAction = _isLongQuote(planned.quote.quote);
    await service.scheduleReminder(
      id: _kNotificationExtraId,
      schedule: schedule,
      title: title,
      body: _trimQuoteBody(planned.quote.quote),
      authorName: planned.quote.author,
      authorImageUrl: planned.authorImageUrl,
      payload: planned.payload,
      showReadFullAction: showReadFullAction,
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
      final authorImageUrl = await _loadAuthorImageUrl(quote.author);
      return _PlannedExtraNotification(
        title: 'From Your Collection',
        quote: quote,
        authorImageUrl: authorImageUrl,
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
      final authorImageUrl = await _loadAuthorImageUrl(quote.author);
      final routeTag = tag == 'series' ? 'movies/series' : tag;
      final title = tag == 'series'
          ? 'From Movies/Series'
          : 'From ${quoteService.toTitleCase(tag)}';
      return _PlannedExtraNotification(
        title: title,
        quote: quote,
        authorImageUrl: authorImageUrl,
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
    debugPrint(
      '[Notifications] Scheduling streak reminder: id=$_kNotificationStreakId, trigger=$schedule',
    );
    await service.scheduleReminder(
      id: _kNotificationStreakId,
      schedule: schedule,
      title: 'Don\'t break your streak',
      body: 'Read 3 quotes today to keep it going.',
      authorName: 'QuoteFlow',
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

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
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

  String _trimQuoteBody(String quote) {
    final clean = quote.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= 120) return clean;
    return '${clean.substring(0, 117).trimRight()}...';
  }

  bool _isLongQuote(String quote) {
    final clean = quote.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.length > 120;
  }

  Future<String?> _loadAuthorImageUrl(String author) async {
    final normalized = author.trim();
    if (normalized.isEmpty) return null;
    try {
      final profile = await _ref
          .read(authorWikiServiceProvider)
          .fetchAuthor(normalized);
      final imageUrl = profile?.imageUrl?.trim();
      if (imageUrl == null || imageUrl.isEmpty) return null;
      return imageUrl;
    } catch (error) {
      debugPrint(
        '[Notifications] Failed to resolve author image for "$author": $error',
      );
      return null;
    }
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
    required this.authorImageUrl,
    required this.payload,
  });

  final String title;
  final QuoteModel quote;
  final String? authorImageUrl;
  final String payload;
}

final notificationSettingsProvider =
    StateNotifierProvider<
      NotificationSettingsNotifier,
      NotificationSettingsModel
    >((ref) => NotificationSettingsNotifier(ref));
