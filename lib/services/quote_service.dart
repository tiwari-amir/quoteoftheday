import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/quote_model.dart';

class QuoteService {
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

    final random = Random(now.year + now.month + now.day);
    final selected = quotes[random.nextInt(quotes.length)];

    prefs
      ..setString(prefDailyQuoteDate, today)
      ..setString(prefDailyQuoteId, selected.id);

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
    final random = Random(date.year + date.month + date.day);
    return quotes[random.nextInt(quotes.length)];
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
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
