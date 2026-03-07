import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/quote_model.dart';
import 'quote_selection_service.dart';

const _kRecentDailyQuoteHistory = 'recent_daily_quote_history_v1';
const _kRecentDailyQuoteHistoryLimit = 30;

class QuoteService {
  QuoteService({QuoteSelectionService? selectionService})
    : _selectionService = selectionService ?? const QuoteSelectionService();

  final QuoteSelectionService _selectionService;

  QuoteModel pickDailyQuote(
    List<QuoteModel> quotes,
    SharedPreferences prefs,
    DateTime now,
  ) {
    if (quotes.isEmpty) {
      throw StateError('No quotes available.');
    }

    final today = _formatDate(now);
    final savedDate = prefs.getString(prefDailyQuoteDate);
    final savedId = prefs.getString(prefDailyQuoteId);

    if (savedDate == today && savedId != null) {
      final existing = quotes.where((q) => q.id == savedId).firstOrNull;
      if (existing != null) return existing;
    }

    final recentIds = _recentDailyQuoteIds(prefs, now);
    final selected = _selectionService.pickDailyQuote(
      quotes: quotes,
      recentlyShownIds: recentIds,
      date: now,
    );

    prefs
      ..setString(prefDailyQuoteDate, today)
      ..setString(prefDailyQuoteId, selected.id)
      ..setStringList(
        _kRecentDailyQuoteHistory,
        _recordRecentDailyQuote(prefs, selected.id, now),
      );

    return selected;
  }

  int readingDurationInSeconds(String quoteText) {
    final words = quoteText
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
    return words <= 0 ? 1 : words;
  }

  QuoteModel pickQuoteForDate(List<QuoteModel> quotes, DateTime date) {
    if (quotes.isEmpty) {
      throw StateError('No quotes available.');
    }
    final dayIndex = _dayNumber(date);
    final quoteIndex = dayIndex % quotes.length;
    return quotes[quoteIndex];
  }

  String toTitleCase(String value) {
    final clean = value.trim().toLowerCase();
    if (clean.isEmpty) return clean;

    return clean
        .split(RegExp(r'[-_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _formatDate(DateTime now) {
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  int _dayNumber(DateTime date) {
    final localDay = DateTime(date.year, date.month, date.day);
    return localDay.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  Set<String> _recentDailyQuoteIds(SharedPreferences prefs, DateTime now) {
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 14));
    final entries =
        prefs.getStringList(_kRecentDailyQuoteHistory) ?? const <String>[];
    final ids = <String>{};

    for (final entry in entries) {
      final parts = entry.split('|');
      if (parts.length != 2) {
        continue;
      }
      final shownAt = DateTime.tryParse(parts[0]);
      final quoteId = parts[1].trim();
      if (shownAt == null || quoteId.isEmpty) {
        continue;
      }
      if (shownAt.isBefore(cutoff)) {
        continue;
      }
      ids.add(quoteId);
    }

    return ids;
  }

  List<String> _recordRecentDailyQuote(
    SharedPreferences prefs,
    String quoteId,
    DateTime now,
  ) {
    final entries = <String>[
      '${DateTime(now.year, now.month, now.day).toIso8601String()}|${quoteId.trim()}',
      ...(prefs.getStringList(_kRecentDailyQuoteHistory) ?? const <String>[]),
    ];
    final deduped = <String>[];
    final seen = <String>{};

    for (final entry in entries) {
      final parts = entry.split('|');
      if (parts.length != 2) {
        continue;
      }
      final id = parts[1].trim();
      if (id.isEmpty || !seen.add(id)) {
        continue;
      }
      deduped.add(entry);
      if (deduped.length >= _kRecentDailyQuoteHistoryLimit) {
        break;
      }
    }

    return deduped;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
