import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/quote_model.dart';
import '../models/quote_viewer_filter.dart';
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

class AttributionSourceEntry {
  const AttributionSourceEntry({
    required this.sourceKey,
    required this.sourceName,
    required this.quoteCount,
    required this.discoveryScore,
    required this.kindLabel,
    required this.topQuotes,
  });

  final String sourceKey;
  final String sourceName;
  final int quoteCount;
  final double discoveryScore;
  final String kindLabel;
  final List<QuoteModel> topQuotes;

  QuoteModel? get heroQuote => topQuotes.isEmpty ? null : topQuotes.first;
}

class CrawlRunQuoteBatch {
  const CrawlRunQuoteBatch({
    required this.runId,
    required this.completedAt,
    required this.quotesAdded,
    required this.quotes,
  });

  final int runId;
  final DateTime? completedAt;
  final int quotesAdded;
  final List<QuoteModel> quotes;
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

final exploreDiscoveryQuotesProvider = FutureProvider<List<QuoteModel>>((
  ref,
) async {
  final quotes = await ref
      .read(quoteRepositoryProvider)
      .getQuotesPage(offset: 0, limit: 180);
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
  final quote = await ref
      .read(quoteRepositoryProvider)
      .getDailyQuote(DateTime.now());
  if (quote == null) {
    throw StateError('No daily quote available.');
  }
  return quote;
});

final categoryCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final localCounts = await ref
      .read(quoteRepositoryProvider)
      .getTagsWithCounts();
  return _mergeTagCounts(localCounts, const <String, int>{});
});

final authorCatalogProvider = FutureProvider<List<AuthorCatalogEntry>>((
  ref,
) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final rows = await client
        .from('authors')
        .select(
          'name,canonical_name,total_quotes,avg_popularity_score,total_likes,author_score',
        )
        .order('author_score', ascending: false)
        .order('avg_popularity_score', ascending: false)
        .order('total_quotes', ascending: false)
        .limit(600);
    return _buildAuthorCatalogFromAuthorRows(rows);
  } catch (_) {
    final quotes = await ref.watch(allQuotesProvider.future);
    return _buildAuthorCatalog(quotes, now: DateTime.now());
  }
});

final attributionSourceCatalogProvider =
    FutureProvider<List<AttributionSourceEntry>>((ref) async {
      final client = ref.read(supabaseClientProvider);
      try {
        final rows = await client
            .from('authors')
            .select(
              'name,canonical_name,total_quotes,avg_popularity_score,total_likes,author_score',
            )
            .order('author_score', ascending: false)
            .order('avg_popularity_score', ascending: false)
            .order('total_quotes', ascending: false)
            .limit(600);
        return _buildAttributionSourceCatalogFromAuthorRows(rows);
      } catch (_) {
        final quotes = await ref.watch(allQuotesProvider.future);
        return _buildAttributionSourceCatalog(quotes, now: DateTime.now());
      }
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

final attributionSourceEntryProvider =
    FutureProvider.family<AttributionSourceEntry?, String>((
      ref,
      sourceKey,
    ) async {
      final catalog = await ref.watch(attributionSourceCatalogProvider.future);
      final target = normalizeAuthorKey(sourceKey);
      for (final entry in catalog) {
        if (entry.sourceKey == target) return entry;
      }
      return null;
    });

final moodTagsProvider = FutureProvider<List<String>>((ref) async {
  final counts = await ref.watch(moodCountsProvider.future);
  return moodAllowlist
      .where((mood) => (counts[mood] ?? 0) > 0)
      .toList(growable: false);
});

final moodCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final counts = await ref.read(quoteRepositoryProvider).getMoodCounts();
  return {
    for (final mood in moodAllowlist)
      if ((counts[mood] ?? 0) > 0) mood: counts[mood]!,
  };
});

final crawlRunQuotesProvider = FutureProvider.family<CrawlRunQuoteBatch?, int>((
  ref,
  runId,
) async {
  if (runId <= 0) return null;

  final client = ref.read(supabaseClientProvider);
  try {
    final rows = await client
        .from('ingestion_runs')
        .select('id,quotes_inserted,completed_at,metadata')
        .eq('id', runId)
        .limit(1);
    if (rows.isEmpty) {
      return null;
    }

    final row = _asDynamicMap(rows.first);
    if (row.isEmpty) {
      return null;
    }

    final metadata = _asDynamicMap(row['metadata']);
    final insertedIds = _stringList(metadata['inserted_quote_ids']);
    final quotes = await ref
        .read(quoteRepositoryProvider)
        .getQuotesByIds(insertedIds);
    final completedAt = DateTime.tryParse(
      (row['completed_at'] ?? '').toString().trim(),
    );

    return CrawlRunQuoteBatch(
      runId: runId,
      completedAt: completedAt,
      quotesAdded: _asInt(row['quotes_inserted']),
      quotes: quotes,
    );
  } catch (_) {
    return null;
  }
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
      if (filter.isCrawl) {
        final runId = int.tryParse(tag) ?? 0;
        final batch = await ref.watch(crawlRunQuotesProvider(runId).future);
        return batch?.quotes ?? const <QuoteModel>[];
      }
      if (tag.isEmpty || tag == 'all') {
        return ref.watch(allQuotesProvider.future);
      }
      if (filter.isAuthor) {
        final filtered = await ref
            .read(quoteRepositoryProvider)
            .getQuotesByAuthor(tag, offset: 0, limit: 600);
        final monthKey = _monthKey(DateTime.now());
        filtered.sort(
          (a, b) => _authorQuoteSignal(
            b,
            monthKey: monthKey,
          ).compareTo(_authorQuoteSignal(a, monthKey: monthKey)),
        );
        return filtered;
      }
      if (filter.isSource) {
        final filtered = await ref
            .read(quoteRepositoryProvider)
            .getQuotesByAuthor(tag, offset: 0, limit: 600);
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
        return ref
            .read(quoteRepositoryProvider)
            .getQuotesByTag(tag, offset: 0, limit: 600);
      }
      if (tag == 'series' || tag == 'movies/series') {
        final allQuotes = await ref.watch(allQuotesWithMediaProvider.future);
        return allQuotes
            .where(
              (quote) =>
                  _matchesAnyTag(quote.revisedTags, {'movies', 'series'}),
            )
            .toList(growable: false);
      }
      return ref
          .read(quoteRepositoryProvider)
          .getQuotesByTag(tag, offset: 0, limit: 600);
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

final topAttributionSourcesProvider =
    FutureProvider<List<AttributionSourceEntry>>((ref) async {
      final catalog = await ref.watch(attributionSourceCatalogProvider.future);
      final ordered = [...catalog]
        ..sort((a, b) => b.discoveryScore.compareTo(a.discoveryScore));
      return ordered.take(8).toList(growable: false);
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
    if (key.isEmpty || key == 'unknown' || isSourceStyleAttribution(key)) {
      continue;
    }
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

List<AuthorCatalogEntry> _buildAuthorCatalogFromAuthorRows(dynamic rows) {
  if (rows is! List) return const <AuthorCatalogEntry>[];
  final catalog = <AuthorCatalogEntry>[];
  for (final raw in rows.whereType<Map<String, dynamic>>()) {
    final authorName = (raw['name'] ?? '').toString().trim();
    final authorKey = normalizeAuthorKey(
      (raw['canonical_name'] ?? raw['name'] ?? '').toString(),
    );
    if (authorName.isEmpty ||
        authorKey.isEmpty ||
        authorKey == 'unknown' ||
        isSourceStyleAttribution(authorKey)) {
      continue;
    }
    final quoteCount = _asInt(raw['total_quotes']);
    final authorScore = _asDouble(raw['author_score']);
    final avgPopularity = _asDouble(raw['avg_popularity_score']);
    final totalLikes = _asInt(raw['total_likes']);
    final discoveryScore =
        (authorScore * 28) +
        avgPopularity +
        (math.log(quoteCount + 1) * 14) +
        (totalLikes * 0.015);
    final monthlyMomentumScore =
        (authorScore * 30) +
        (avgPopularity * 0.9) +
        (math.log(quoteCount + 1) * 10) +
        (totalLikes * 0.012);
    catalog.add(
      AuthorCatalogEntry(
        authorKey: authorKey,
        authorName: authorName,
        quoteCount: quoteCount,
        discoveryScore: discoveryScore,
        monthlyMomentumScore: monthlyMomentumScore,
        topQuotes: const <QuoteModel>[],
      ),
    );
  }
  catalog.sort((a, b) => b.discoveryScore.compareTo(a.discoveryScore));
  return catalog;
}

List<AttributionSourceEntry> _buildAttributionSourceCatalog(
  List<QuoteModel> quotes, {
  DateTime? now,
}) {
  final monthKey = _monthKey(now ?? DateTime.now());
  final grouped = <String, List<QuoteModel>>{};

  for (final quote in quotes) {
    final key = normalizeAuthorKey(
      quote.canonicalAuthor.isNotEmpty ? quote.canonicalAuthor : quote.author,
    );
    if (key.isEmpty || key == 'unknown' || !isSourceStyleAttribution(key)) {
      continue;
    }
    grouped.putIfAbsent(key, () => <QuoteModel>[]).add(quote);
  }

  final catalog = <AttributionSourceEntry>[];
  for (final entry in grouped.entries) {
    final sourceQuotes = [...entry.value]
      ..sort(
        (a, b) => _authorQuoteSignal(
          b,
          monthKey: monthKey,
        ).compareTo(_authorQuoteSignal(a, monthKey: monthKey)),
      );
    if (sourceQuotes.isEmpty) continue;

    final topQuotes = sourceQuotes.take(24).toList(growable: false);
    final displayName = _displayAuthorForGroup(topQuotes);
    final tagBreadth = topQuotes
        .expand((quote) => quote.revisedTags)
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .length;
    final leadSignal = _authorQuoteSignal(topQuotes.first, monthKey: monthKey);
    final score =
        (leadSignal * 0.72) +
        (math.log(sourceQuotes.length + 1) * 14.0) +
        (math.sqrt(tagBreadth.toDouble()) * 4.0) +
        ((Object.hash(entry.key, sourceQuotes.length) & 0x0F) / 100.0);

    catalog.add(
      AttributionSourceEntry(
        sourceKey: entry.key,
        sourceName: displayName,
        quoteCount: sourceQuotes.length,
        discoveryScore: score,
        kindLabel: sourceStyleKindLabel(displayName),
        topQuotes: topQuotes,
      ),
    );
  }

  catalog.sort((a, b) => b.discoveryScore.compareTo(a.discoveryScore));
  return catalog;
}

List<AttributionSourceEntry> _buildAttributionSourceCatalogFromAuthorRows(
  dynamic rows,
) {
  if (rows is! List) return const <AttributionSourceEntry>[];
  final catalog = <AttributionSourceEntry>[];
  for (final raw in rows.whereType<Map<String, dynamic>>()) {
    final sourceName = (raw['name'] ?? '').toString().trim();
    final sourceKey = normalizeAuthorKey(
      (raw['canonical_name'] ?? raw['name'] ?? '').toString(),
    );
    if (sourceName.isEmpty ||
        sourceKey.isEmpty ||
        sourceKey == 'unknown' ||
        !isSourceStyleAttribution(sourceKey)) {
      continue;
    }
    final quoteCount = _asInt(raw['total_quotes']);
    final authorScore = _asDouble(raw['author_score']);
    final avgPopularity = _asDouble(raw['avg_popularity_score']);
    final totalLikes = _asInt(raw['total_likes']);
    final discoveryScore =
        (authorScore * 26) +
        avgPopularity +
        (math.log(quoteCount + 1) * 12) +
        (totalLikes * 0.012);
    catalog.add(
      AttributionSourceEntry(
        sourceKey: sourceKey,
        sourceName: sourceName,
        quoteCount: quoteCount,
        discoveryScore: discoveryScore,
        kindLabel: sourceStyleKindLabel(sourceName),
        topQuotes: const <QuoteModel>[],
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

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic> _asDynamicMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return const <String, dynamic>{};
}

List<String> _stringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
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

const Set<String> _sourceStyleSingletons = {
  'anonymous',
  'proverb',
  'maxim',
  'slogan',
  'aphorism',
};

const Set<String> _sourceStyleModifiers = {
  'african',
  'american',
  'ancient',
  'arab',
  'biblical',
  'british',
  'buddhist',
  'chinese',
  'folk',
  'french',
  'greek',
  'indian',
  'irish',
  'italian',
  'japanese',
  'jewish',
  'latin',
  'maori',
  'medieval',
  'old',
  'persian',
  'russian',
  'scottish',
  'spanish',
  'traditional',
  'turkish',
  'victorian',
  'wartime',
  'zen',
};

const Set<String> _sourceStyleBases = {
  'adage',
  'aphorism',
  'dictum',
  'maxim',
  'motto',
  'proverb',
  'saying',
  'slogan',
  'wisdom',
};

bool isSourceStyleAttribution(String raw) {
  final normalized = normalizeAuthorKey(raw);
  if (normalized.isEmpty || normalized == 'unknown') return false;
  if (_sourceStyleSingletons.contains(normalized)) return true;
  final words = normalized
      .split(' ')
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return false;
  if (!_sourceStyleBases.contains(words.last)) return false;
  return words.take(words.length - 1).every(_sourceStyleModifiers.contains);
}

String sourceStyleKindLabel(String raw) {
  final normalized = normalizeAuthorKey(raw);
  if (normalized.contains('slogan')) return 'SLOGAN';
  if (normalized.contains('saying')) return 'SAYING';
  if (normalized.contains('maxim')) return 'MAXIM';
  if (normalized.contains('wisdom')) return 'WISDOM';
  if (normalized == 'anonymous') return 'ANONYMOUS';
  return 'PROVERB';
}

String sourceStyleDescriptor(String raw) {
  final normalized = normalizeAuthorKey(raw);
  if (normalized.contains('slogan')) {
    return 'Collective line carried through public memory';
  }
  if (normalized == 'anonymous') {
    return 'Widely repeated without a single credited author';
  }
  if (normalized.contains('saying')) {
    return 'Folk saying passed between generations';
  }
  if (normalized.contains('wisdom')) {
    return 'Traditional wisdom gathered from shared experience';
  }
  return 'Traditional proverb carried through shared culture';
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
