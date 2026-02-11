import 'dart:math';

import 'package:intl/intl.dart';
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

    final today = DateFormat('yyyy-MM-dd').format(now);
    final savedDate = prefs.getString(prefDailyQuoteDate);
    final savedId = prefs.getInt(prefDailyQuoteId);

    if (savedDate == today && savedId != null) {
      final existing = quotes.where((quote) => quote.id == savedId).firstOrNull;
      if (existing != null) return existing;
    }

    final random = Random(now.year + now.month + now.day);
    final selected = quotes[random.nextInt(quotes.length)];

    prefs
      ..setString(prefDailyQuoteDate, today)
      ..setInt(prefDailyQuoteId, selected.id);

    return selected;
  }

  Map<String, int> buildTagCounts(
    List<QuoteModel> quotes, {
    Set<String>? includeOnly,
  }) {
    final counts = <String, int>{};

    for (final quote in quotes) {
      for (final tag in quote.revisedTags) {
        if (includeOnly != null && !includeOnly.contains(tag)) continue;
        counts.update(tag, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    final sortedEntries = counts.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        if (cmp != 0) return cmp;
        return a.key.compareTo(b.key);
      });

    return {for (final entry in sortedEntries) entry.key: entry.value};
  }

  List<QuoteModel> filterByTag(List<QuoteModel> quotes, String tag) {
    final normalized = tag.trim().toLowerCase();

    return quotes
        .where((quote) => quote.revisedTags.contains(normalized))
        .toList(growable: false);
  }

  int readingDurationInSeconds(String quoteText) {
    final words = quoteText
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
    return words.clamp(1, 180);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
