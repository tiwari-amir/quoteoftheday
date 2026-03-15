import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/quote_model.dart';
import '../models/quote_viewer_filter.dart';
import '../providers/storage_provider.dart';
import '../repository/quote_repository.dart';
import '../services/author_wiki_service.dart';
import '../services/free_media_quotes_service.dart';
import '../services/internet_best_quote_service.dart';
import '../services/quote_service.dart';
import '../features/v3_search/search_service.dart';
import 'supabase_provider.dart';

class MonthlyAuthorSpotlight {
  const MonthlyAuthorSpotlight({
    required this.authorKey,
    required this.authorName,
    required this.rankScore,
    required this.totalQuotes,
    required this.topQuotes,
  });

  final String authorKey;
  final String authorName;
  final double rankScore;
  final int totalQuotes;
  final List<QuoteModel> topQuotes;
}

class AuthorCatalogEntry {
  const AuthorCatalogEntry({
    required this.authorKey,
    required this.authorName,
    required this.quoteCount,
    required this.discoveryScore,
    required this.monthlyMomentumScore,
    required this.topQuotes,
  });

  final String authorKey;
  final String authorName;
  final int quoteCount;
  final double discoveryScore;
  final double monthlyMomentumScore;
  final List<QuoteModel> topQuotes;

  QuoteModel? get heroQuote => topQuotes.isEmpty ? null : topQuotes.first;
}

final quoteRepositoryProvider = Provider<QuoteRepository>((ref) {
  return QuoteRepository(client: ref.read(supabaseClientProvider));
});

final quoteServiceProvider = Provider<QuoteService>((ref) {
  return QuoteService();
});

final authorWikiServiceProvider = Provider<AuthorWikiService>((ref) {
  return AuthorWikiService();
});

final internetBestQuoteServiceProvider = Provider<InternetBestQuoteService>((
  ref,
) {
  return InternetBestQuoteService();
});

final freeMediaQuotesServiceProvider = Provider<FreeMediaQuotesService>((ref) {
  return FreeMediaQuotesService();
});

final currentUserIdProvider = Provider<String?>((ref) {
  final client = ref.read(supabaseClientProvider);
  return client.auth.currentUser?.id;
});

final allQuotesProvider = FutureProvider<List<QuoteModel>>((ref) async {
  final quotes = await ref.read(quoteRepositoryProvider).getAllQuotes();
  return quotes.where(_isLikelyEnglishQuote).toList(growable: false);
});

final mediaQuotesProvider = FutureProvider<List<QuoteModel>>((ref) async {
  try {
    final quotes = await ref
        .read(freeMediaQuotesServiceProvider)
        .fetchQuotesForCategories(
          categories: const {'movies', 'series'},
          timeout: const Duration(seconds: 2),
        );
    return quotes.where(_isLikelyEnglishQuote).toList(growable: false);
  } catch (_) {
    return const <QuoteModel>[];
  }
});

final allQuotesWithMediaProvider = FutureProvider<List<QuoteModel>>((
  ref,
) async {
  final localQuotes = await ref.watch(allQuotesProvider.future);
  final mediaQuotes = await ref.watch(mediaQuotesProvider.future);
  return _mergeUniqueQuotes(localQuotes, mediaQuotes);
});

final dailyQuoteProvider = FutureProvider<QuoteModel>((ref) async {
  final quotes = await ref.watch(allQuotesProvider.future);
  final prefs = ref.read(sharedPreferencesProvider);
  final quoteService = ref.read(quoteServiceProvider);
  return quoteService.pickDailyQuote(quotes, prefs, DateTime.now());
});

final categoryCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final localQuotes = await ref.watch(allQuotesProvider.future);
  final localCounts = _sortedTagCounts(localQuotes);

  List<QuoteModel> mediaQuotes = const <QuoteModel>[];
  try {
    mediaQuotes = await ref
        .read(mediaQuotesProvider.future)
        .timeout(
          const Duration(milliseconds: 900),
          onTimeout: () => const <QuoteModel>[],
        );
  } catch (_) {
    mediaQuotes = const <QuoteModel>[];
  }
  final mediaCounts = _sortedTagCounts(mediaQuotes);

  return _mergeTagCounts(localCounts, mediaCounts);
});

final authorCatalogProvider = FutureProvider<List<AuthorCatalogEntry>>((
  ref,
) async {
  final quotes = await ref.watch(allQuotesProvider.future);
  return _buildAuthorCatalog(quotes, now: DateTime.now());
});

final authorCatalogEntryProvider =
    FutureProvider.family<AuthorCatalogEntry?, String>((ref, authorKey) async {
      final catalog = await ref.watch(authorCatalogProvider.future);
      final target = normalizeAuthorKey(authorKey);
      for (final entry in catalog) {
        if (entry.authorKey == target) return entry;
      }
      return null;
    });

final moodTagsProvider = FutureProvider<List<String>>((ref) async {
  final allQuotes = await ref.watch(allQuotesProvider.future);
  return moodAllowlist
      .where((mood) => _quotesForMood(allQuotes, mood).isNotEmpty)
      .toList(growable: false);
});

final moodCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final allQuotes = await ref.watch(allQuotesProvider.future);
  final counts = <String, int>{};
  for (final mood in moodAllowlist) {
    final matched = _quotesForMood(allQuotes, mood);
    if (matched.isNotEmpty) {
      counts[mood] = matched.length;
    }
  }
  return counts;
});

final quotesByFilterProvider =
    FutureProvider.family<List<QuoteModel>, QuoteViewerFilter>((
      ref,
      filter,
    ) async {
      final tag = filter.tag.trim().toLowerCase();
      if (filter.isSearch) {
        final searchQuotes = await ref.watch(allQuotesProvider.future);
        return SearchService(searchQuotes).searchQuotes(tag, limit: 200);
      }
      final allQuotes = await ref.watch(allQuotesWithMediaProvider.future);
      if (tag.isEmpty || tag == 'all') {
        return allQuotes;
      }
      if (filter.isAuthor) {
        final filtered = allQuotes
            .where((quote) => _matchesAuthor(quote, tag))
            .toList(growable: false);
        final monthKey = _monthKey(DateTime.now());
        filtered.sort(
          (a, b) => _authorQuoteSignal(
            b,
            monthKey: monthKey,
          ).compareTo(_authorQuoteSignal(a, monthKey: monthKey)),
        );
        return filtered;
      }
      if (filter.isMood) {
        return _quotesForMood(allQuotes, tag);
      }
      if (tag == 'series' || tag == 'movies/series') {
        return allQuotes
            .where(
              (quote) =>
                  _matchesAnyTag(quote.revisedTags, {'movies', 'series'}),
            )
            .toList(growable: false);
      }
      return allQuotes
          .where((quote) => _matchesTag(quote.revisedTags, tag))
          .toList(growable: false);
    });

final topLikedQuotesProvider = FutureProvider<List<QuoteModel>>((ref) async {
  final repo = ref.read(quoteRepositoryProvider);
  final futures = await Future.wait([
    ref.watch(allQuotesProvider.future),
    repo.getMostLikedQuoteIds(limit: 12),
  ]);
  final allQuotes = futures[0] as List<QuoteModel>;
  final topIds = futures[1] as List<String>;
  final byId = {for (final q in allQuotes) q.id: q};

  final likedQuotes = topIds
      .map((id) => byId[id])
      .whereType<QuoteModel>()
      .toList(growable: false);
  if (likedQuotes.length >= 6) {
    return likedQuotes;
  }

  final fallback = _webInspiredPopularFallback(allQuotes);
  final merged = <QuoteModel>[
    ...likedQuotes,
    ...fallback.where((q) => !topIds.contains(q.id)),
  ];
  return merged.take(12).toList(growable: false);
});

final internetBestQuoteProvider = FutureProvider<QuoteModel>((ref) async {
  final internet = await ref
      .read(internetBestQuoteServiceProvider)
      .fetchBestQuoteOfAllTime();
  if (internet != null) return internet;

  final localQuotes = await ref.read(quoteRepositoryProvider).getAllQuotes();
  if (localQuotes.isEmpty) {
    throw StateError('No quotes available');
  }
  final fallback = _webInspiredPopularFallback(localQuotes);
  return fallback.isNotEmpty ? fallback.first : localQuotes.first;
});

final bestQuoteOfAllTimeProvider = FutureProvider<QuoteModel>((ref) async {
  return ref.watch(internetBestQuoteProvider.future);
});

final topAuthorsOfMonthProvider = FutureProvider<List<MonthlyAuthorSpotlight>>((
  ref,
) async {
  final catalog = await ref.watch(authorCatalogProvider.future);
  final ordered = [...catalog]
    ..sort((a, b) => b.monthlyMomentumScore.compareTo(a.monthlyMomentumScore));
  return ordered
      .take(5)
      .map(
        (entry) => MonthlyAuthorSpotlight(
          authorKey: entry.authorKey,
          authorName: entry.authorName,
          rankScore: entry.monthlyMomentumScore,
          totalQuotes: entry.quoteCount,
          topQuotes: entry.topQuotes.take(10).toList(growable: false),
        ),
      )
      .toList(growable: false);
});

List<QuoteModel> _webInspiredPopularFallback(List<QuoteModel> quotes) {
  const authorPriority = [
    'albert einstein',
    'maya angelou',
    'mark twain',
    'oscar wilde',
    'friedrich nietzsche',
    'aristotle',
    'mahatma gandhi',
    'confucius',
    'winston churchill',
    'lao tzu',
  ];

  final ranked = <QuoteModel>[];
  for (final author in authorPriority) {
    final match = quotes.firstWhere(
      (q) => q.author.toLowerCase().contains(author),
      orElse: () =>
          const QuoteModel(id: '', quote: '', author: '', revisedTags: []),
    );
    if (match.id.isNotEmpty) {
      ranked.add(match);
    }
  }

  if (ranked.length >= 12) return ranked;
  final extras = [...quotes]
    ..sort((a, b) => b.quote.length.compareTo(a.quote.length));
  for (final quote in extras) {
    if (ranked.any((q) => q.id == quote.id)) continue;
    ranked.add(quote);
    if (ranked.length >= 12) break;
  }

  return ranked;
}

Map<String, int> _sortedTagCounts(List<QuoteModel> quotes) {
  final counts = <String, int>{};
  for (final quote in quotes) {
    for (final tag in quote.revisedTags) {
      final normalized = tag.trim().toLowerCase();
      if (normalized.isEmpty || normalized == 'all') continue;
      counts.update(normalized, (v) => v + 1, ifAbsent: () => 1);
    }
  }

  final sorted = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });
  return {for (final entry in sorted) entry.key: entry.value};
}

Map<String, int> _mergeTagCounts(
  Map<String, int> localCounts,
  Map<String, int> mediaCounts,
) {
  final merged = <String, int>{...localCounts};
  for (final entry in mediaCounts.entries) {
    merged.update(
      entry.key,
      (v) => v + entry.value,
      ifAbsent: () => entry.value,
    );
  }

  for (final category in curatedCategoryTags) {
    merged.putIfAbsent(category, () => 0);
  }

  for (final required in const ['movies', 'series']) {
    merged.putIfAbsent(required, () => 1);
  }

  final sorted = merged.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });
  return {for (final entry in sorted) entry.key: entry.value};
}

List<AuthorCatalogEntry> _buildAuthorCatalog(
  List<QuoteModel> quotes, {
  DateTime? now,
}) {
  final monthKey = _monthKey(now ?? DateTime.now());
  final grouped = <String, List<QuoteModel>>{};

  for (final quote in quotes) {
    final key = normalizeAuthorKey(
      quote.canonicalAuthor.isNotEmpty ? quote.canonicalAuthor : quote.author,
    );
    if (key.isEmpty || key == 'unknown') continue;
    grouped.putIfAbsent(key, () => <QuoteModel>[]).add(quote);
  }

  final catalog = <AuthorCatalogEntry>[];
  for (final entry in grouped.entries) {
    final authorQuotes = [...entry.value]
      ..sort(
        (a, b) => _authorQuoteSignal(
          b,
          monthKey: monthKey,
        ).compareTo(_authorQuoteSignal(a, monthKey: monthKey)),
      );
    if (authorQuotes.isEmpty) continue;

    final topQuotes = authorQuotes.take(24).toList(growable: false);
    final displayAuthor = _displayAuthorForGroup(topQuotes);
    final topSignals = topQuotes
        .take(5)
        .map((quote) => _authorQuoteSignal(quote, monthKey: monthKey))
        .toList(growable: false);
    final topAverage = topSignals.isEmpty
        ? 0.0
        : topSignals.reduce((a, b) => a + b) / topSignals.length;
    final recentQuotes = authorQuotes
        .where((quote) => _monthlyRecencySignal(quote.createdAt, monthKey) > 0)
        .take(5)
        .toList(growable: false);
    final recentSignals = recentQuotes
        .map((quote) => _authorQuoteSignal(quote, monthKey: monthKey))
        .toList(growable: false);
    final recentAverage = recentSignals.isEmpty
        ? 0.0
        : recentSignals.reduce((a, b) => a + b) / recentSignals.length;
    final tagBreadth = topQuotes
        .expand((quote) => quote.revisedTags)
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .length;

    final quoteVolumeBoost = math.log(authorQuotes.length + 1) * 18.0;
    final breadthBoost = math.sqrt(tagBreadth.toDouble()) * 6.0;
    final leadSignal = _authorQuoteSignal(topQuotes.first, monthKey: monthKey);
    final discoveryScore =
        (leadSignal * 0.74) +
        (topAverage * 0.46) +
        quoteVolumeBoost +
        breadthBoost +
        ((Object.hash(entry.key, authorQuotes.length) & 0x0F) / 100.0);
    final monthlyMomentumScore =
        (leadSignal * 0.3) +
        (recentAverage * 0.92) +
        (recentQuotes.length * 18.0) +
        (math.log(recentQuotes.length + 1) * 12.0) +
        (authorQuotes.length.clamp(0, 32) * 0.95) +
        (tagBreadth * 0.9) +
        ((Object.hash(entry.key, monthKey) & 0x0F) / 100.0);

    catalog.add(
      AuthorCatalogEntry(
        authorKey: entry.key,
        authorName: displayAuthor,
        quoteCount: authorQuotes.length,
        discoveryScore: discoveryScore,
        monthlyMomentumScore: monthlyMomentumScore,
        topQuotes: topQuotes,
      ),
    );
  }

  catalog.sort((a, b) => b.discoveryScore.compareTo(a.discoveryScore));
  return catalog;
}

bool _matchesTag(List<String> quoteTags, String selectedTag) {
  final target = selectedTag.trim().toLowerCase();
  if (target.isEmpty || target == 'all') return true;
  for (final raw in quoteTags) {
    final tag = raw.trim().toLowerCase();
    if (tag == target || tag.contains(target) || target.contains(tag)) {
      return true;
    }
  }
  return false;
}

bool _matchesAuthor(QuoteModel quote, String selectedAuthor) {
  final target = normalizeAuthorKey(selectedAuthor);
  if (target.isEmpty || target == 'all') return true;
  final canonical = normalizeAuthorKey(quote.canonicalAuthor);
  final author = normalizeAuthorKey(quote.author);
  return canonical == target || author == target;
}

bool _matchesAnyTag(List<String> quoteTags, Set<String> selectedTags) {
  for (final selected in selectedTags) {
    if (_matchesTag(quoteTags, selected)) return true;
  }
  return false;
}

String normalizeAuthorKey(String raw) {
  return raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _monthKey(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  return '${value.year}-$month';
}

double _authorQuoteSignal(QuoteModel quote, {required String monthKey}) {
  final basePopularity = quote.popularityScore.toDouble();
  final socialSignal =
      (quote.likesCount * 6) +
      (quote.savesCount * 5) +
      (quote.sharesCount * 7) +
      (quote.viewsCount * 0.05);
  final prestigeSignal = (quote.authorScore * 18) + (quote.viralityScore * 12);
  final recencySignal = _monthlyRecencySignal(quote.createdAt, monthKey);
  return basePopularity + socialSignal + prestigeSignal + recencySignal;
}

double _monthlyRecencySignal(DateTime? createdAt, String monthKey) {
  if (createdAt == null) return 0;
  final local = createdAt.toLocal();
  final createdKey = _monthKey(local);
  if (createdKey == monthKey) {
    return 28;
  }
  return 0;
}

String _displayAuthorForGroup(List<QuoteModel> quotes) {
  if (quotes.isEmpty) return 'Unknown';
  final ranked = [...quotes]
    ..sort((a, b) {
      final quality = _displayAuthorQuality(
        b.author,
      ).compareTo(_displayAuthorQuality(a.author));
      if (quality != 0) return quality;
      return a.author.length.compareTo(b.author.length);
    });
  return ranked.first.author.trim().isEmpty ? 'Unknown' : ranked.first.author;
}

int _displayAuthorQuality(String author) {
  final trimmed = author.trim();
  if (trimmed.isEmpty) return -100;
  final normalized = normalizeAuthorKey(trimmed);
  if (normalized == 'unknown') return -100;
  final tokenCount = normalized
      .split(' ')
      .where((part) => part.isNotEmpty)
      .length;
  var score = 0;
  if (tokenCount >= 2 && tokenCount <= 4) score += 8;
  if (RegExp(r'[A-Z]').hasMatch(trimmed)) score += 3;
  score -= trimmed.length ~/ 18;
  return score;
}

List<QuoteModel> _mergeUniqueQuotes(
  List<QuoteModel> first,
  List<QuoteModel> second,
) {
  final seen = <String>{};
  final output = <QuoteModel>[];
  for (final quote in [...first, ...second]) {
    final key = '${quote.quote}|${quote.author}'.toLowerCase();
    if (!seen.add(key)) continue;
    output.add(quote);
  }
  return output;
}

const Map<String, List<String>> _moodKeywords = {
  'motivated': [
    'motivated',
    'motivational',
    'motivation',
    'inspire',
    'inspirational',
    'discipline',
    'success',
    'goal',
    'courage',
    'perseverance',
  ],
  'calm': [
    'calm',
    'peace',
    'peaceful',
    'serenity',
    'stillness',
    'quiet',
    'mindful',
    'mindfulness',
    'zen',
    'breathe',
  ],
  'confident': ['confident', 'confidence', 'courage', 'bold', 'brave'],
  'grateful': ['grateful', 'gratitude', 'thankful', 'blessing'],
  'hopeful': ['hope', 'hopeful', 'faith', 'optimistic'],
  'romantic': ['romance', 'romantic', 'love', 'heart'],
  'stressed': ['stress', 'overwhelm', 'anxious', 'pressure', 'tired'],
  'anxious': ['anxious', 'anxiety', 'worry', 'fear', 'panic'],
  'happy': ['happy', 'happiness', 'joy', 'smile', 'delight'],
  'sad': ['sad', 'grief', 'sorrow', 'hurt', 'tears'],
  'angry': ['angry', 'anger', 'rage', 'furious', 'temper'],
  'lonely': ['lonely', 'alone', 'solitude', 'isolation'],
};

List<QuoteModel> _quotesForMood(List<QuoteModel> quotes, String mood) {
  final normalizedMood = mood.trim().toLowerCase();
  final keywords = _moodKeywords[normalizedMood] ?? [normalizedMood];
  final scored = <({QuoteModel quote, int score})>[];

  for (final quote in quotes) {
    final tags = quote.revisedTags.map((t) => t.toLowerCase()).toList();
    final text = '${quote.quote} ${quote.author}'.toLowerCase();

    var score = 0;
    for (final tag in tags) {
      if (tag == normalizedMood) {
        score += 8;
      }
      for (final keyword in keywords) {
        if (tag == keyword) {
          score += 6;
        } else if (tag.contains(keyword) || keyword.contains(tag)) {
          score += 3;
        }
      }
    }

    for (final keyword in keywords) {
      if (text.contains(keyword)) score += 1;
    }

    if (normalizedMood == 'motivated' &&
        tags.any((t) => t.contains('inspir'))) {
      score += 3;
    }
    if (normalizedMood == 'calm' &&
        tags.any((t) => t.contains('spiritual') || t.contains('mind'))) {
      score += 2;
    }

    if (score > 0) {
      scored.add((quote: quote, score: score));
    }
  }

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.quote.id.compareTo(b.quote.id);
  });

  return scored.map((e) => e.quote).toList(growable: false);
}

bool _isLikelyEnglishQuote(QuoteModel quote) {
  final text = '${quote.quote} ${quote.author}'.trim();
  if (text.isEmpty) return false;

  var letters = 0;
  var latinLetters = 0;
  for (final rune in text.runes) {
    final isAsciiLetter =
        (rune >= 65 && rune <= 90) || (rune >= 97 && rune <= 122);
    final isExtendedLatin = rune >= 0x00C0 && rune <= 0x024F;
    final isAnyLetter =
        isAsciiLetter ||
        isExtendedLatin ||
        (rune >= 0x0370 && rune <= 0x03FF) ||
        (rune >= 0x0400 && rune <= 0x04FF) ||
        (rune >= 0x0590 && rune <= 0x05FF) ||
        (rune >= 0x0600 && rune <= 0x06FF) ||
        (rune >= 0x4E00 && rune <= 0x9FFF);

    if (!isAnyLetter) continue;
    letters += 1;
    if (isAsciiLetter || isExtendedLatin) {
      latinLetters += 1;
    }
  }

  if (letters == 0) return false;
  final ratio = latinLetters / letters;
  return ratio >= 0.78;
}
