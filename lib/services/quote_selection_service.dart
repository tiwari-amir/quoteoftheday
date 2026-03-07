import 'dart:math' as math;

import '../core/constants.dart';
import '../models/quote_model.dart';

class QuoteSelectionService {
  const QuoteSelectionService();

  static const int _maxCandidateWindow = 120;

  QuoteModel pickDailyQuote({
    required List<QuoteModel> quotes,
    required Set<String> recentlyShownIds,
    required DateTime date,
  }) {
    final dailyCandidates =
        _dedupeQuotes(quotes).take(_maxCandidateWindow).toList(growable: false)
          ..sort((a, b) {
            final byVirality = _viralitySignal(b).compareTo(_viralitySignal(a));
            if (byVirality != 0) {
              return byVirality;
            }
            final byPopularity = _popularitySignal(
              b,
            ).compareTo(_popularitySignal(a));
            if (byPopularity != 0) {
              return byPopularity;
            }
            final byAuthorScore = _authorScoreSignal(
              b,
            ).compareTo(_authorScoreSignal(a));
            if (byAuthorScore != 0) {
              return byAuthorScore;
            }
            return a.id.compareTo(b.id);
          });
    final ranked = _rankCandidates(
      dailyCandidates,
      recentQuoteIds: recentlyShownIds,
      preferMedium: true,
    );
    if (ranked.isEmpty) {
      throw StateError('No quotes available.');
    }

    final topCount = math.max(1, (ranked.length * 0.3).ceil());
    final topPool = ranked.take(topCount).toList(growable: false);
    final unseenPool = topPool
        .where((item) => !recentlyShownIds.contains(item.quote.id))
        .toList(growable: false);
    final eligible = unseenPool.isNotEmpty ? unseenPool : topPool;
    final mediumPool = eligible
        .where((item) => _effectiveLengthTier(item.quote) == 'medium')
        .toList(growable: false);
    final focused = mediumPool.isNotEmpty ? mediumPool : eligible;
    final windowSize = math.min(
      math.max(1, math.min(focused.length, 12)),
      focused.length,
    );
    final window = focused.take(windowSize).toList(growable: false)
      ..sort(
        (a, b) => _shuffleValue(
          '${_dayKey(date)}|daily',
          a.quote,
        ).compareTo(_shuffleValue('${_dayKey(date)}|daily', b.quote)),
      );
    return window.first.quote;
  }

  List<QuoteModel> orderGlobalFeed(
    List<QuoteModel> quotes, {
    required String contextKey,
    Set<String> recentQuoteIds = const <String>{},
    int pageSize = 40,
    int featuredWindow = 200,
  }) {
    final deduped = _dedupeQuotes(quotes);
    final ranked = _rankCandidates(
      deduped
          .take(math.min(featuredWindow, _maxCandidateWindow))
          .toList(growable: false),
      recentQuoteIds: recentQuoteIds,
    );
    if (ranked.isEmpty) {
      return const <QuoteModel>[];
    }

    final featuredPool = List<_RankedQuote>.from(ranked, growable: true);
    final selected = <QuoteModel>[];
    var pageIndex = 0;

    while (featuredPool.isNotEmpty) {
      final nextCount = math.min(pageSize, ranked.length - selected.length);
      if (nextCount <= 0) {
        break;
      }

      final page = _buildDiversePage(
        featuredPool,
        contextKey: '$contextKey:$pageIndex',
        limit: nextCount,
      );
      if (page.isEmpty) {
        break;
      }

      selected.addAll(page.map((item) => item.quote));
      final selectedIds = page.map((item) => item.quote.id).toSet();
      featuredPool.removeWhere((item) => selectedIds.contains(item.quote.id));
      pageIndex += 1;
    }

    if (featuredPool.isNotEmpty) {
      selected.addAll(featuredPool.map((item) => item.quote));
    }

    final selectedIds = selected.map((quote) => quote.id).toSet();
    final remainder = deduped.where((quote) => !selectedIds.contains(quote.id));
    return <QuoteModel>[...selected, ...remainder];
  }

  List<QuoteModel> rankExploreFeed(
    List<QuoteModel> quotes, {
    required String contextKey,
    Set<String> recentQuoteIds = const <String>{},
    String? preferredCategory,
    String? preferredMood,
    int limit = 40,
    int maxPerAuthor = 2,
  }) {
    final ranked = _rankCandidates(
      _trimCandidateWindow(quotes, limit: limit),
      recentQuoteIds: recentQuoteIds,
    );
    if (ranked.isEmpty) {
      return const <QuoteModel>[];
    }

    return _buildDiversePage(
      ranked,
      contextKey: contextKey,
      limit: limit,
      maxPerAuthor: maxPerAuthor,
    ).map((item) => item.quote).toList(growable: false);
  }

  List<QuoteModel> rankForYouFeed(
    List<QuoteModel> quotes, {
    required Set<String> preferredCategories,
    Set<String> recentQuoteIds = const <String>{},
    int limit = 40,
    int maxPerAuthor = 2,
    String contextKey = 'for-you',
  }) {
    final normalizedCategories = _normalizeValues(preferredCategories);
    if (normalizedCategories.isEmpty) {
      return rankExploreFeed(
        quotes,
        contextKey: contextKey,
        recentQuoteIds: recentQuoteIds,
        limit: limit,
        maxPerAuthor: maxPerAuthor,
      );
    }

    final candidates = _trimCandidateWindow(quotes, limit: limit);
    final maxVirality = _maxViralitySignal(candidates);
    final maxPopularity = _maxPopularitySignal(candidates);
    final maxAuthorScore = _maxAuthorSignal(candidates);
    final ranked =
        candidates
            .map(
              (quote) => _RankedQuote(
                quote: quote,
                score: _forYouScore(
                  quote,
                  recentQuoteIds: recentQuoteIds,
                  maxVirality: maxVirality,
                  maxPopularity: maxPopularity,
                  maxAuthorScore: maxAuthorScore,
                ),
                authorKey: _authorKey(quote),
                categoryKey: _primaryCategory(quote),
              ),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final byScore = b.score.compareTo(a.score);
            if (byScore != 0) {
              return byScore;
            }
            return _shuffleValue(
              contextKey,
              a.quote,
            ).compareTo(_shuffleValue(contextKey, b.quote));
          });

    return _buildDiversePage(
      ranked,
      contextKey: contextKey,
      limit: limit,
      maxPerAuthor: maxPerAuthor,
    ).map((item) => item.quote).toList(growable: false);
  }

  QuoteModel? pickNotificationQuote(
    List<QuoteModel> quotes, {
    Set<String> recentQuoteIds = const <String>{},
    Set<String> preferredCategories = const <String>{},
    Set<String> preferredMoods = const <String>{},
    String contextKey = 'notification',
  }) {
    final ranked = _rankCandidates(
      _trimCandidateWindow(quotes, limit: 16),
      recentQuoteIds: recentQuoteIds,
      preferShortOrMedium: true,
    );
    final pool = ranked
        .where((item) {
          final tier = _effectiveLengthTier(item.quote);
          return tier == 'short' || tier == 'medium';
        })
        .toList(growable: false);

    final effectivePool = pool.isNotEmpty ? pool : ranked;
    if (effectivePool.isEmpty) {
      return null;
    }

    final candidates =
        effectivePool
            .take(math.min(effectivePool.length, 16))
            .toList(growable: false)
          ..sort(
            (a, b) => _shuffleValue(
              contextKey,
              a.quote,
            ).compareTo(_shuffleValue(contextKey, b.quote)),
          );
    return candidates.first.quote;
  }

  List<_RankedQuote> _rankCandidates(
    List<QuoteModel> quotes, {
    Set<String> recentQuoteIds = const <String>{},
    bool preferMedium = false,
    bool preferShortOrMedium = false,
  }) {
    final candidates = _trimCandidateWindow(quotes, limit: quotes.length);
    final maxVirality = _maxViralitySignal(candidates);
    final maxPopularity = _maxPopularitySignal(candidates);
    final maxAuthorScore = _maxAuthorSignal(candidates);

    final ranked =
        candidates
            .map((quote) {
              var score = _feedScore(
                quote: quote,
                maxVirality: maxVirality,
                maxPopularity: maxPopularity,
                maxAuthorScore: maxAuthorScore,
                freshnessScore: _freshnessScore(quote, recentQuoteIds),
              );

              final tier = _effectiveLengthTier(quote);
              if (preferMedium) {
                if (tier == 'medium') {
                  score += 8;
                } else if (tier == 'short') {
                  score += 2;
                } else {
                  score -= 3;
                }
              } else if (preferShortOrMedium) {
                if (tier == 'short' || tier == 'medium') {
                  score += 6;
                } else {
                  score -= 5;
                }
              }

              return _RankedQuote(
                quote: quote,
                score: score,
                authorKey: _authorKey(quote),
                categoryKey: _primaryCategory(quote),
              );
            })
            .toList(growable: false)
          ..sort((a, b) {
            final byScore = b.score.compareTo(a.score);
            if (byScore != 0) {
              return byScore;
            }
            return a.quote.id.compareTo(b.quote.id);
          });

    return ranked;
  }

  List<_RankedQuote> _buildDiversePage(
    List<_RankedQuote> ranked, {
    required String contextKey,
    required int limit,
    int maxPerAuthor = 2,
  }) {
    if (limit <= 0 || ranked.isEmpty) {
      return const <_RankedQuote>[];
    }

    final candidateWindow = math.min(
      ranked.length,
      math.min(_maxCandidateWindow, math.max(limit * 3, limit)),
    );
    final candidates = <_RankedQuote>[
      ..._shuffleTopRange(
        ranked.take(candidateWindow).toList(growable: false),
        contextKey: contextKey,
      ),
      ...ranked.skip(candidateWindow),
    ];

    final selected = <_RankedQuote>[];
    final deferred = <_RankedQuote>[];
    final authorCounts = <String, int>{};
    final categoryCounts = <String, int>{};
    final maxPerCategory = math.max(4, (limit / 3).ceil());

    for (final candidate in candidates) {
      if (selected.length >= limit) {
        break;
      }

      final authorCount = authorCounts[candidate.authorKey] ?? 0;
      final categoryCount = categoryCounts[candidate.categoryKey] ?? 0;
      if (authorCount >= maxPerAuthor ||
          (candidate.categoryKey.isNotEmpty &&
              categoryCount >= maxPerCategory)) {
        deferred.add(candidate);
        continue;
      }

      selected.add(candidate);
      authorCounts[candidate.authorKey] = authorCount + 1;
      if (candidate.categoryKey.isNotEmpty) {
        categoryCounts[candidate.categoryKey] = categoryCount + 1;
      }
    }

    for (final candidate in deferred) {
      if (selected.length >= limit) {
        break;
      }
      final authorCount = authorCounts[candidate.authorKey] ?? 0;
      if (authorCount >= maxPerAuthor) {
        continue;
      }
      selected.add(candidate);
      authorCounts[candidate.authorKey] = authorCount + 1;
    }

    if (selected.length < limit) {
      final selectedIds = selected.map((item) => item.quote.id).toSet();
      for (final candidate in candidates) {
        if (selected.length >= limit) {
          break;
        }
        if (selectedIds.contains(candidate.quote.id)) {
          continue;
        }
        selected.add(candidate);
      }
    }

    return selected;
  }

  List<_RankedQuote> _shuffleTopRange(
    List<_RankedQuote> ranked, {
    required String contextKey,
  }) {
    final shuffled = <_RankedQuote>[];
    for (var start = 0; start < ranked.length; start += 8) {
      final end = math.min(start + 8, ranked.length);
      final bucket = ranked.sublist(start, end).toList(growable: false)
        ..sort(
          (a, b) => _shuffleValue(
            '$contextKey:${start ~/ 8}',
            a.quote,
          ).compareTo(_shuffleValue('$contextKey:${start ~/ 8}', b.quote)),
        );
      shuffled.addAll(bucket);
    }
    return shuffled;
  }

  double _forYouScore(
    QuoteModel quote, {
    required Set<String> recentQuoteIds,
    required double maxVirality,
    required double maxPopularity,
    required double maxAuthorScore,
  }) {
    final virality = _normalizedScore(_viralitySignal(quote), maxVirality);
    final popularity = _normalizedScore(
      _popularitySignal(quote),
      maxPopularity,
    );
    final authorScore = _normalizedScore(
      _authorScoreSignal(quote),
      maxAuthorScore,
    );
    final freshnessBonus = _freshnessScore(quote, recentQuoteIds);
    return (virality * 0.4) +
        (popularity * 0.3) +
        (authorScore * 0.2) +
        (freshnessBonus * 0.1);
  }

  double _feedScore({
    required QuoteModel quote,
    required double maxVirality,
    required double maxPopularity,
    required double maxAuthorScore,
    required double freshnessScore,
  }) {
    final virality = _normalizedScore(_viralitySignal(quote), maxVirality);
    final popularity = _normalizedScore(
      _popularitySignal(quote),
      maxPopularity,
    );
    final author = _normalizedScore(_authorScoreSignal(quote), maxAuthorScore);
    return (virality * 0.4) +
        (popularity * 0.3) +
        (author * 0.2) +
        (freshnessScore * 0.1);
  }

  double _freshnessScore(QuoteModel quote, Set<String> recentQuoteIds) {
    return recentQuoteIds.contains(quote.id) ? 0 : 100;
  }

  double _popularitySignal(QuoteModel quote) {
    final base = quote.popularityScore > 0
        ? quote.popularityScore
        : ((quote.likesCount * 2) +
              _lengthTierBonus(_effectiveLengthTier(quote)));
    final length = quote.quote.trim().length;
    var score = base;
    if (length >= 40 && length <= 220) {
      score += 2;
    }
    if (_authorKey(quote) == 'unknown') {
      score -= 4;
    }
    return score.toDouble();
  }

  double _viralitySignal(QuoteModel quote) {
    final score = quote.viralityScore;
    if (score.isFinite && !score.isNaN && score > 0) {
      return score;
    }
    return (quote.viewsCount * 0.1) +
        (quote.likesCount * 1.5) +
        (quote.savesCount * 2.0) +
        (quote.sharesCount * 3.0);
  }

  double _authorScoreSignal(QuoteModel quote) {
    final score = quote.authorScore;
    if (!score.isFinite || score.isNaN || score <= 0) {
      return 0;
    }
    return score;
  }

  int _lengthTierBonus(String tier) {
    switch (tier) {
      case 'medium':
        return 5;
      case 'short':
        return 3;
      case 'long':
        return 2;
      default:
        return 3;
    }
  }

  String _effectiveLengthTier(QuoteModel quote) {
    final normalized = quote.lengthTier.trim().toLowerCase();
    if (normalized == 'short' ||
        normalized == 'medium' ||
        normalized == 'long') {
      return normalized;
    }

    final length = quote.quote.trim().length;
    if (length < 80) {
      return 'short';
    }
    if (length <= 160) {
      return 'medium';
    }
    return 'long';
  }

  Set<String> _quoteCategories(QuoteModel quote) {
    final source = quote.categories.isNotEmpty
        ? quote.categories
        : quote.revisedTags;
    return source
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty && !moodAllowlist.contains(item))
        .toSet();
  }

  String _primaryCategory(QuoteModel quote) {
    final categories = _quoteCategories(quote).toList(growable: false)..sort();
    return categories.isEmpty ? '' : categories.first;
  }

  String _authorKey(QuoteModel quote) {
    final canonical = quote.canonicalAuthor.trim().toLowerCase();
    if (canonical.isNotEmpty) {
      return canonical;
    }

    final normalized = quote.author
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized.isEmpty ? 'unknown' : normalized;
  }

  Set<String> _normalizeValues(Iterable<String> values) {
    return values
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  int _shuffleValue(String contextKey, QuoteModel quote) {
    final buffer = StringBuffer()
      ..write(contextKey)
      ..write('|')
      ..write(quote.id)
      ..write('|')
      ..write(quote.hash)
      ..write('|')
      ..write(_authorKey(quote));
    return _stableHash(buffer.toString());
  }

  int _stableHash(String value) {
    var hash = 2166136261;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }

  String _dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  List<QuoteModel> _trimCandidateWindow(
    List<QuoteModel> quotes, {
    required int limit,
  }) {
    final deduped = _dedupeQuotes(quotes);
    final windowSize = math.min(
      deduped.length,
      math.min(_maxCandidateWindow, math.max(limit * 3, limit)),
    );
    return deduped.take(windowSize).toList(growable: false);
  }

  List<QuoteModel> _dedupeQuotes(List<QuoteModel> quotes) {
    final deduped = <String, QuoteModel>{};
    for (final quote in quotes) {
      if (quote.id.trim().isEmpty || quote.quote.trim().isEmpty) {
        continue;
      }
      deduped.putIfAbsent(quote.id, () => quote);
    }
    return deduped.values.toList(growable: false);
  }

  double _maxPopularitySignal(List<QuoteModel> quotes) {
    var maxSignal = 1.0;
    for (final quote in quotes) {
      maxSignal = math.max(maxSignal, _popularitySignal(quote));
    }
    return maxSignal;
  }

  double _maxViralitySignal(List<QuoteModel> quotes) {
    var maxSignal = 1.0;
    for (final quote in quotes) {
      maxSignal = math.max(maxSignal, _viralitySignal(quote));
    }
    return maxSignal;
  }

  double _maxAuthorSignal(List<QuoteModel> quotes) {
    var maxSignal = 1.0;
    for (final quote in quotes) {
      maxSignal = math.max(maxSignal, _authorScoreSignal(quote));
    }
    return maxSignal;
  }

  double _normalizedScore(double value, double maxValue) {
    if (value <= 0 || maxValue <= 0) {
      return 0;
    }
    return ((value / maxValue) * 100).clamp(0, 100).toDouble();
  }
}

class _RankedQuote {
  const _RankedQuote({
    required this.quote,
    required this.score,
    required this.authorKey,
    required this.categoryKey,
  });

  final QuoteModel quote;
  final double score;
  final String authorKey;
  final String categoryKey;
}
