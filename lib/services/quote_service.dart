import 'dart:math';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/quote_model.dart';

class QuoteService {
  static const Set<String> _noiseSuffixes = {
    '-quote',
    '-quotes',
    '-quotation',
    '-quotations',
  };

  static const Map<String, String> _tagAliases = {
    'inspiration': 'inspirational',
    'inspirational-quote': 'inspirational',
    'inspirational-quotes': 'inspirational',
    'motivated': 'motivational',
    'motivation': 'motivational',
    'motivational-quote': 'motivational',
    'motivational-quotes': 'motivational',
    'self-help': 'self-improvement',
    'selfhelp': 'self-improvement',
  };

  static const Map<String, Set<String>> _moodKeywords = {
    'happy': {'happy', 'joy', 'happiness', 'smile', 'cheerful', 'gratitude'},
    'sad': {'sad', 'sorrow', 'grief', 'heartbreak', 'loss'},
    'motivated': {
      'motivational',
      'inspirational',
      'success',
      'ambition',
      'discipline',
      'focus',
      'courage',
      'strength',
    },
    'angry': {'angry', 'anger', 'rage', 'frustration'},
    'calm': {'calm', 'peace', 'mindfulness', 'stillness', 'serenity'},
    'confident': {'confidence', 'confident', 'self-belief', 'bravery'},
    'lonely': {'lonely', 'loneliness', 'alone', 'isolation'},
    'hopeful': {'hope', 'optimism', 'faith', 'resilience'},
  };

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
    bool moodsOnly = false,
  }) {
    final counts = <String, int>{};

    for (final quote in quotes) {
      if (moodsOnly) {
        final moods = _extractMoodBuckets(quote);
        for (final mood in moods) {
          counts.update(mood, (value) => value + 1, ifAbsent: () => 1);
        }
      } else {
        final canonicalTags = quote.revisedTags.map(canonicalizeTag).toSet();
        for (final tag in canonicalTags) {
          counts.update(tag, (value) => value + 1, ifAbsent: () => 1);
        }
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

  List<QuoteModel> filterByTag(
    List<QuoteModel> quotes,
    String tag, {
    required bool isMood,
  }) {
    final normalized = canonicalizeTag(tag);

    return quotes
        .where((quote) {
          if (isMood) {
            return _extractMoodBuckets(quote).contains(normalized);
          }
          return quote.revisedTags.map(canonicalizeTag).contains(normalized);
        })
        .toList(growable: false);
  }

  int readingDurationInSeconds(String quoteText) {
    final words = quoteText
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
    return words.clamp(1, 180);
  }

  QuoteModel pickQuoteForDate(List<QuoteModel> quotes, DateTime date) {
    if (quotes.isEmpty) {
      throw StateError('No quotes available.');
    }
    final random = Random(date.year + date.month + date.day);
    return quotes[random.nextInt(quotes.length)];
  }

  String canonicalizeTag(String raw) {
    var tag = raw.trim().toLowerCase();
    tag = tag.replaceAll(RegExp(r'[_\s]+'), '-');
    tag = tag.replaceAll(RegExp(r'[^a-z0-9-]'), '');
    tag = tag.replaceAll(RegExp(r'-{2,}'), '-');
    tag = tag.replaceAll(RegExp(r'^-+|-+$'), '');

    for (final suffix in _noiseSuffixes) {
      if (tag.endsWith(suffix)) {
        tag = tag.substring(0, tag.length - suffix.length);
      }
    }

    if (tag.startsWith('inspir')) {
      return 'inspirational';
    }
    if (tag.startsWith('motiv')) {
      return 'motivational';
    }

    return _tagAliases[tag] ?? tag;
  }

  String displayTag(String canonicalTag) {
    return canonicalTag
        .split('-')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Set<String> _extractMoodBuckets(QuoteModel quote) {
    final moods = <String>{};
    final canonicalTags = quote.revisedTags.map(canonicalizeTag).toSet();

    for (final tag in canonicalTags) {
      for (final entry in _moodKeywords.entries) {
        final mood = entry.key;
        final keywords = entry.value;
        if (keywords.any(
          (keyword) => tag == keyword || tag.contains(keyword),
        )) {
          moods.add(mood);
        }
      }
    }

    return moods;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
