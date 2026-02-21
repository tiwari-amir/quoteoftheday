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
const _kCategories = 'v3.notification_categories';
const _kScheduleWindowDays = 30;
const _kReminderCategoryLimit = 20;

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

final reminderCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final categories = await ref.watch(categoryCountsProvider.future);
  final ordered = categories.keys
      .map((c) => c.trim().toLowerCase())
      .where((c) => c.isNotEmpty && c != 'all')
      .toList(growable: true);
  final top = ordered.take(_kReminderCategoryLimit).toList(growable: true);

  for (final requiredTag in const ['movies', 'series']) {
    if (top.contains(requiredTag)) continue;
    if (top.length >= _kReminderCategoryLimit) {
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
      categories: _normalizeCategories(
        prefs.getStringList(_kCategories) ??
            NotificationSettingsModel.defaults.categories,
      ).toList(growable: false),
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
    await prefs.setStringList(
      _kCategories,
      _normalizeCategories(next.categories).toList(growable: false),
    );

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
      final selectedCategories = _normalizeCategories(state.categories);
      final localCategoryQuotes = _filterQuotesByCategories(
        quotes: allQuotes,
        selectedCategories: selectedCategories,
      );

      final wantsFreeMediaQuotes =
          selectedCategories.isEmpty ||
          selectedCategories.contains('movies') ||
          selectedCategories.contains('series');
      final freeMediaCategories = selectedCategories.isEmpty
          ? const {'movies', 'series'}
          : selectedCategories
                .where((item) => item == 'movies' || item == 'series')
                .toSet();
      final freeMediaQuotes = wantsFreeMediaQuotes
          ? await _ref
                .read(freeMediaQuotesServiceProvider)
                .fetchQuotesForCategories(categories: freeMediaCategories)
          : const <QuoteModel>[];
      final categoryQuotes = _mergeQuotes(localCategoryQuotes, freeMediaQuotes);
      final effectiveAllQuotes = categoryQuotes.isNotEmpty
          ? categoryQuotes
          : allQuotes;

      final savedIds = _ref.read(savedQuoteIdsProvider);
      final savedQuotes = allQuotes
          .where((q) => savedIds.contains(q.id))
          .toList(growable: false);
      final savedCategoryQuotes = _filterQuotesByCategories(
        quotes: savedQuotes,
        selectedCategories: selectedCategories,
      );
      final effectiveSavedQuotes = savedCategoryQuotes.isNotEmpty
          ? savedCategoryQuotes
          : savedQuotes;

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
      final firstDailyRemote =
          state.source == 'daily' && selectedCategories.isEmpty
          ? await repo.getDailyQuote(firstLocalDate)
          : null;

      for (var offset = 0; offset < _kScheduleWindowDays; offset++) {
        final schedule = firstTrigger.add(Duration(days: offset));
        final localDate = DateTime(schedule.year, schedule.month, schedule.day);

        final quote = await _pickQuoteForReminder(
          localDate: localDate,
          allQuotes: effectiveAllQuotes,
          savedQuotes: effectiveSavedQuotes,
          quoteService: quoteService,
          firstDailyRemote: offset == 0 ? firstDailyRemote : null,
        );
        final body = _compactBody(quote.quote, quote.author);

        await service.scheduleReminder(
          id: 7001 + offset,
          schedule: schedule,
          title: _titleForCategories(selectedCategories),
          body: body,
          subtitle: _smallSubtitleForCategories(selectedCategories),
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
    final clipped = cleanQuote.length > 94
        ? '${cleanQuote.substring(0, 91).trimRight()}...'
        : cleanQuote;
    return '"$clipped"\n- $author';
  }

  Set<String> _normalizeCategories(List<String> categories) {
    return categories
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty && item != 'all')
        .toSet();
  }

  List<QuoteModel> _filterQuotesByCategories({
    required List<QuoteModel> quotes,
    required Set<String> selectedCategories,
  }) {
    if (selectedCategories.isEmpty) return quotes;

    return quotes
        .where((quote) {
          return selectedCategories.any(
            (category) => _quoteMatchesCategory(quote, category),
          );
        })
        .toList(growable: false);
  }

  bool _quoteMatchesCategory(QuoteModel quote, String category) {
    final normalizedCategory = category.trim().toLowerCase();
    final tags = quote.revisedTags
        .map((tag) => tag.toLowerCase())
        .toList(growable: false);
    final text = '${quote.quote} ${quote.author}'.toLowerCase();
    final keywords = switch (normalizedCategory) {
      'motivational' => <String>[
        'motivational',
        'motivation',
        'motivated',
        'inspiration',
        'inspirational',
        'inspire',
        'goal',
        'success',
        'discipline',
      ],
      'love' => <String>[
        'love',
        'romantic',
        'romance',
        'heart',
        'relationship',
      ],
      'movies' => <String>['movie', 'movies', 'film', 'cinema'],
      'series' => <String>['series', 'tv', 'television', 'show', 'episode'],
      _ => <String>[normalizedCategory],
    };

    for (final keyword in keywords) {
      if (tags.any(
        (tag) =>
            tag == keyword || tag.contains(keyword) || keyword.contains(tag),
      )) {
        return true;
      }
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  List<QuoteModel> _mergeQuotes(
    List<QuoteModel> first,
    List<QuoteModel> second,
  ) {
    final seen = <String>{};
    final merged = <QuoteModel>[];

    for (final quote in [...first, ...second]) {
      final key = '${quote.quote}|${quote.author}'.toLowerCase();
      if (!seen.add(key)) continue;
      merged.add(quote);
    }

    return merged;
  }

  String _titleForCategories(Set<String> categories) {
    if (categories.isEmpty) return 'Today\'s Quote';
    if (categories.length == 1) {
      final category = categories.first;
      final label = switch (category) {
        'motivational' => 'Motivational',
        'love' => 'Love',
        'movies' => 'Movie',
        'series' => 'Series',
        _ => category,
      };
      return 'Today\'s $label Quote';
    }
    return 'Today\'s Quote Mix';
  }

  String _smallSubtitleForCategories(Set<String> categories) {
    if (categories.isEmpty) return 'Daily Scroll';
    if (categories.length == 1) {
      return 'Daily Scroll | ${_titleLabel(categories.first)}';
    }
    return 'Daily Scroll | ${categories.length} categories';
  }

  String _titleLabel(String category) {
    return switch (category) {
      'motivational' => 'Motivational',
      'movies' => 'Movies',
      'series' => 'Series',
      'love' => 'Love',
      _ => category,
    };
  }
}

final notificationSettingsProvider =
    StateNotifierProvider<
      NotificationSettingsNotifier,
      NotificationSettingsModel
    >((ref) {
      return NotificationSettingsNotifier(ref);
    });
