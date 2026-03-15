import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../models/quote_model.dart';
import '../services/quote_selection_service.dart';
import 'local_quote_cache.dart';

class QuoteRepository {
  QuoteRepository({required SupabaseClient client, LocalQuoteCache? localCache})
    : _client = client,
      _localCache = localCache ?? LocalQuoteCache.instance {
    _scheduleStartupWarmup();
  }

  final SupabaseClient _client;
  final LocalQuoteCache _localCache;
  final QuoteSelectionService _selectionService = const QuoteSelectionService();
  static const int _networkPageSize = 40;
  static const int _recentlyShownLimit = 200;
  static const int _candidateMultiplier = 3;
  static const Duration _minSyncInterval = Duration(hours: 6);
  List<QuoteModel>? _quotesCache;
  Future<List<QuoteModel>>? _quotesInFlight;
  Future<void>? _backgroundSyncInFlight;
  final Map<String, List<QuoteModel>> _prefetchedExplorePages =
      <String, List<QuoteModel>>{};
  final Map<String, List<QuoteModel>> _prefetchedMoodPages =
      <String, List<QuoteModel>>{};
  final Map<String, QuoteModel> _dailyQuoteMemory = <String, QuoteModel>{};
  Future<void>? _startupWarmupInFlight;

  Future<List<QuoteModel>> getAllQuotes() async {
    if (_quotesCache != null) {
      unawaited(_refreshFromNetworkIfStale());
      return _quotesCache!;
    }
    if (_quotesInFlight != null) return _quotesInFlight!;

    _quotesInFlight = _loadQuotesCacheFirst();
    try {
      final resolved = await _quotesInFlight!;
      _quotesCache = resolved;
      _warmExplorePrefetch(resolved);
      return resolved;
    } finally {
      _quotesInFlight = null;
    }
  }

  Future<List<QuoteModel>> _loadQuotesCacheFirst() async {
    try {
      final cached = await _localCache.getAllQuotes();
      if (cached.isNotEmpty) {
        unawaited(_refreshFromNetworkIfStale());
        return _rankAllQuotes(cached);
      }
    } catch (error, stack) {
      debugPrint('Local quote cache read failed: $error');
      debugPrint('$stack');
    }

    final network = await _fetchAllQuotesFromSupabase();
    if (network.isNotEmpty) {
      final ranked = await _rankAllQuotes(network);
      await _localCache.replaceAllQuotes(ranked);
      await _localCache.setLastSyncAt(DateTime.now().toUtc());
      return ranked;
    }

    final fallback = await _loadLocalQuotesFallback();
    if (fallback.isNotEmpty) {
      final ranked = await _rankAllQuotes(fallback);
      await _localCache.replaceAllQuotes(ranked);
      return ranked;
    }
    return fallback;
  }

  Future<void> _refreshFromNetworkIfStale({bool force = false}) async {
    if (_backgroundSyncInFlight != null) return;

    if (!force) {
      final lastSync = await _localCache.getLastSyncAt();
      if (lastSync != null &&
          DateTime.now().toUtc().difference(lastSync) < _minSyncInterval) {
        return;
      }
    }

    final future = _runBackgroundSync();
    _backgroundSyncInFlight = future;
    unawaited(
      future.whenComplete(() {
        _backgroundSyncInFlight = null;
      }),
    );
  }

  Future<void> _runBackgroundSync() async {
    final refreshed = await _fetchAllQuotesFromSupabase();
    if (refreshed.isEmpty) return;

    final ranked = await _rankAllQuotes(refreshed);
    _quotesCache = ranked;
    _warmExplorePrefetch(ranked);
    await _prefetchStartupCollections(ranked);
    await _localCache.replaceAllQuotes(ranked);
    await _localCache.setLastSyncAt(DateTime.now().toUtc());
  }

  Future<void> refreshNow() async {
    if (_backgroundSyncInFlight != null) {
      await _backgroundSyncInFlight;
      return;
    }

    final future = _runBackgroundSync();
    _backgroundSyncInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_backgroundSyncInFlight, future)) {
        _backgroundSyncInFlight = null;
      }
    }
  }

  void _scheduleStartupWarmup() {
    if (_startupWarmupInFlight != null) return;
    final future = _runStartupWarmup();
    _startupWarmupInFlight = future;
    unawaited(
      future.whenComplete(() {
        _startupWarmupInFlight = null;
      }),
    );
  }

  Future<void> _runStartupWarmup() async {
    try {
      final day = _yyyyMmDd(DateTime.now());
      final cachedDailyQuoteId = await _localCache.getDailyQuoteId(day);
      if (cachedDailyQuoteId != null) {
        final cachedDailyQuote = await _localCache.getQuoteById(
          cachedDailyQuoteId,
        );
        if (cachedDailyQuote != null) {
          _dailyQuoteMemory[day] = cachedDailyQuote;
        }
      }

      var cachedQuotes = await _localCache.getAllQuotes();
      if (cachedQuotes.isNotEmpty) {
        cachedQuotes = await _rankAllQuotes(cachedQuotes);
        _quotesCache ??= cachedQuotes;
        _warmExplorePrefetch(cachedQuotes);
        await _prefetchStartupCollections(cachedQuotes);
      }

      if (cachedQuotes.isEmpty) {
        final remoteQuotes = await _fetchAllQuotesFromSupabase();
        if (remoteQuotes.isEmpty) return;
        final rankedRemoteQuotes = await _rankAllQuotes(remoteQuotes);
        _quotesCache = rankedRemoteQuotes;
        _warmExplorePrefetch(rankedRemoteQuotes);
        await _prefetchStartupCollections(rankedRemoteQuotes);
        await _localCache.replaceAllQuotes(rankedRemoteQuotes);
        await _localCache.setLastSyncAt(DateTime.now().toUtc());
        cachedQuotes = rankedRemoteQuotes;
      }

      if (cachedQuotes.isNotEmpty) {
        unawaited(_refreshFromNetworkIfStale());
      }
    } catch (error, stack) {
      debugPrint('QuoteRepository startup warmup failed: $error');
      debugPrint('$stack');
    }
  }

  Future<List<QuoteModel>> _fetchAllQuotesFromSupabase() async {
    try {
      final quotes = <QuoteModel>[];
      var from = 0;

      while (true) {
        final rows = await _fetchQuotesPage(
          from: from,
          limit: _networkPageSize,
        );

        quotes.addAll(rows);

        if (rows.length < _networkPageSize) {
          break;
        }
        from += _networkPageSize;
      }

      if (quotes.isEmpty) {
        return const <QuoteModel>[];
      }
      return quotes;
    } catch (error, stack) {
      debugPrint('Supabase fetch quotes failed: $error');
      debugPrint('$stack');
      return const <QuoteModel>[];
    }
  }

  Future<List<QuoteModel>> _fetchQuotesPage({
    required int from,
    required int limit,
  }) async {
    final to = from + limit - 1;
    final modernFields =
        'id,text,author,canonical_author,source_url,license,categories,moods,views_count,shares_count,saves_count,likes_count,popularity_score,author_score,virality_score,length_tier,created_at,hash,quote_hash,quote_tags(tags(slug,type))';

    try {
      final rows = await _client
          .from('quotes')
          .select(modernFields)
          .order('virality_score', ascending: false)
          .order('popularity_score', ascending: false)
          .order('author_score', ascending: false)
          .order('created_at', ascending: false)
          .range(from, to);
      return _mapQuoteRows(rows);
    } catch (_) {
      // Compatibility fallback when migration has not been applied yet.
      final rows = await _client
          .from('quotes')
          .select('id,text,author,created_at,hash,quote_tags(tags(slug,type))')
          .order('created_at', ascending: false)
          .range(from, to);
      return _mapQuoteRows(rows);
    }
  }

  List<QuoteModel> _mapQuoteRows(dynamic rows) {
    if (rows is! List) return const <QuoteModel>[];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(QuoteModel.fromJson)
        .where((q) => q.id.isNotEmpty && q.quote.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<QuoteModel>> getQuotesPage({
    required int offset,
    int limit = _networkPageSize,
  }) async {
    final recentIds = await _localCache.getRecentlyShownQuoteIds(
      limit: _recentlyShownLimit,
    );
    final candidateLimit = math.max(limit * _candidateMultiplier, limit);
    final cached = await _localCache.getTopQuotes(
      limit: candidateLimit,
      offset: offset,
    );
    if (cached.isNotEmpty) {
      final ranked = _selectionService.rankExploreFeed(
        cached,
        contextKey: 'all:$offset',
        recentQuoteIds: recentIds,
        limit: limit,
      );
      unawaited(_localCache.markQuotesShown(ranked.map((quote) => quote.id)));
      unawaited(_refreshFromNetworkIfStale());
      return ranked;
    }

    final all = await getAllQuotes();
    if (offset >= all.length) {
      return const <QuoteModel>[];
    }
    final end = math.min(offset + candidateLimit, all.length);
    final slice = all.sublist(offset, end);
    final ranked = _selectionService.rankExploreFeed(
      slice,
      contextKey: 'all:$offset',
      recentQuoteIds: recentIds,
      limit: limit,
    );
    unawaited(_localCache.markQuotesShown(ranked.map((quote) => quote.id)));
    return ranked;
  }

  Future<QuoteModel?> getDailyQuote(DateTime date) async {
    final day = _yyyyMmDd(date);
    final memoryQuote = _dailyQuoteMemory[day];
    if (memoryQuote != null) {
      return memoryQuote;
    }
    final cachedId = await _localCache.getDailyQuoteId(day);
    if (cachedId != null) {
      final cachedQuote = await _localCache.getQuoteById(cachedId);
      if (cachedQuote != null) {
        _dailyQuoteMemory[day] = cachedQuote;
        unawaited(_refreshFromNetworkIfStale());
        return cachedQuote;
      }
    }

    try {
      final rows = await _client
          .from('daily_quotes')
          .select('quote_id')
          .eq('date', day)
          .limit(1);

      if (rows.isNotEmpty) {
        final row = rows.first;
        final quoteId = (row['quote_id'] ?? '').toString().trim();
        if (quoteId.isNotEmpty) {
          final model = await _fetchQuoteByIdFromSupabase(quoteId);
          if (model == null) {
            throw StateError('daily quote not found for id=$quoteId');
          }
          _dailyQuoteMemory[day] = model;
          await _localCache.upsertQuotes(<QuoteModel>[model]);
          await _localCache.cacheDailyQuote(day: day, quoteId: model.id);
          await _localCache.markQuotesShown(<String>[model.id]);
          return model;
        }
      }
    } catch (error) {
      debugPrint('Supabase getDailyQuote failed: $error');
    }

    final fallback = await _selectDailyQuoteFallback(date);
    if (fallback == null) {
      return null;
    }
    _dailyQuoteMemory[day] = fallback;
    await _localCache.upsertQuotes(<QuoteModel>[fallback]);
    await _localCache.cacheDailyQuote(day: day, quoteId: fallback.id);
    await _localCache.markQuotesShown(<String>[fallback.id]);
    return fallback;
  }

  Future<Map<String, int>> getTagsWithCounts() async {
    final cachedCounts = await _localCache.getCategoryCounts();
    if (cachedCounts.isNotEmpty) {
      return cachedCounts;
    }

    final quotes = await getAllQuotes();
    final counts = <String, int>{};

    for (final quote in quotes) {
      for (final tag in quote.revisedTags) {
        counts.update(tag, (v) => v + 1, ifAbsent: () => 1);
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

  Future<List<QuoteModel>> getQuotesByTag(
    String tag, {
    int offset = 0,
    int limit = _networkPageSize,
  }) async {
    final normalized = tag.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'all') {
      return getQuotesPage(offset: offset, limit: limit);
    }
    final prefetched = _prefetchedExplorePages[normalized];
    if (prefetched != null && prefetched.isNotEmpty) {
      final recentIds = await _localCache.getRecentlyShownQuoteIds(
        limit: _recentlyShownLimit,
      );
      final ranked = _selectionService.rankExploreFeed(
        prefetched,
        contextKey: 'tag:$normalized:$offset',
        recentQuoteIds: recentIds,
        preferredCategory: moodAllowlist.contains(normalized)
            ? null
            : normalized,
        preferredMood: moodAllowlist.contains(normalized) ? normalized : null,
        limit: limit,
      );
      unawaited(_localCache.markQuotesShown(ranked.map((quote) => quote.id)));
      return ranked;
    }

    final recentIds = await _localCache.getRecentlyShownQuoteIds(
      limit: _recentlyShownLimit,
    );
    final candidateLimit = math.max(limit * _candidateMultiplier, limit);
    final cached = moodAllowlist.contains(normalized)
        ? await _localCache.getQuotesForMood(
            mood: normalized,
            limit: candidateLimit,
            offset: offset,
          )
        : await _localCache.getQuotesForCategory(
            category: normalized,
            limit: candidateLimit,
            offset: offset,
          );
    if (cached.isNotEmpty) {
      final ranked = _selectionService.rankExploreFeed(
        cached,
        contextKey: 'tag:$normalized:$offset',
        recentQuoteIds: recentIds,
        preferredCategory: moodAllowlist.contains(normalized)
            ? null
            : normalized,
        preferredMood: moodAllowlist.contains(normalized) ? normalized : null,
        limit: limit,
      );
      unawaited(_localCache.markQuotesShown(ranked.map((quote) => quote.id)));
      unawaited(_refreshFromNetworkIfStale());
      return ranked;
    }

    final remote = await _fetchQuotesByTagFromSupabase(
      tag: normalized,
      limit: candidateLimit,
      offset: offset,
    );
    if (remote.isNotEmpty) {
      await _localCache.upsertQuotes(remote);
      final ranked = _selectionService.rankExploreFeed(
        remote,
        contextKey: 'tag:$normalized:$offset',
        recentQuoteIds: recentIds,
        preferredCategory: moodAllowlist.contains(normalized)
            ? null
            : normalized,
        preferredMood: moodAllowlist.contains(normalized) ? normalized : null,
        limit: limit,
      );
      await _localCache.markQuotesShown(ranked.map((quote) => quote.id));
      return ranked;
    }

    final quotes = await getAllQuotes();
    final filtered = quotes
        .where((quote) => quote.revisedTags.contains(normalized))
        .toList(growable: false);
    return _selectionService.rankExploreFeed(
      filtered,
      contextKey: 'tag:$normalized:$offset',
      recentQuoteIds: recentIds,
      preferredCategory: moodAllowlist.contains(normalized) ? null : normalized,
      preferredMood: moodAllowlist.contains(normalized) ? normalized : null,
      limit: limit,
    );
  }

  Future<List<String>> getMoodTagsAvailable(List<String> allowlist) async {
    final tags = await getTagsWithCounts();
    final allowedSet = allowlist.map((m) => m.toLowerCase()).toSet();

    return tags.keys.where(allowedSet.contains).toList(growable: false);
  }

  Future<List<QuoteModel>> getForYouQuotesPage({
    required Set<String> preferredCategories,
    int offset = 0,
    int limit = _networkPageSize,
  }) async {
    final normalizedCategories = preferredCategories
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    if (normalizedCategories.isEmpty) {
      return getQuotesPage(offset: offset, limit: limit);
    }

    final recentIds = await _localCache.getRecentlyShownQuoteIds(
      limit: _recentlyShownLimit,
    );
    final candidateLimit = math.max(limit, 20);
    final candidates = <QuoteModel>[];
    final seenIds = <String>{};

    for (final category in normalizedCategories.take(4)) {
      final cached = await _localCache.getQuotesForCategory(
        category: category,
        limit: candidateLimit,
        offset: 0,
      );
      for (final quote in cached) {
        if (seenIds.add(quote.id)) {
          candidates.add(quote);
        }
      }
    }

    if (candidates.isEmpty) {
      final remote = await _fetchQuotesForPreferredCategoriesFromSupabase(
        categories: normalizedCategories,
        limitPerCategory: candidateLimit,
      );
      if (remote.isNotEmpty) {
        await _localCache.upsertQuotes(remote);
        for (final quote in remote) {
          if (seenIds.add(quote.id)) {
            candidates.add(quote);
          }
        }
      }
    }

    if (candidates.isEmpty) {
      final fallback = await _localCache.getTopQuotes(
        limit: math.max(limit * _candidateMultiplier, limit),
        offset: offset,
      );
      candidates.addAll(fallback);
    }

    final ranked = _selectionService.rankForYouFeed(
      candidates,
      preferredCategories: normalizedCategories,
      recentQuoteIds: recentIds,
      limit: limit,
      contextKey: 'for-you:$offset',
    );
    unawaited(_localCache.markQuotesShown(ranked.map((quote) => quote.id)));
    return ranked;
  }

  Future<QuoteModel?> getNotificationQuote({
    Set<String> preferredCategories = const <String>{},
    Set<String> preferredMoods = const <String>{},
  }) async {
    final categories = preferredCategories
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    final moods = preferredMoods
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    final recentIds = await _localCache.getRecentlyShownQuoteIds(
      limit: _recentlyShownLimit,
      within: const Duration(days: 7),
    );

    final candidates = <QuoteModel>[];
    final seenIds = <String>{};
    for (final category in categories.take(3)) {
      final matches = await _localCache.getQuotesForCategory(
        category: category,
        limit: 20,
      );
      for (final quote in matches) {
        if (seenIds.add(quote.id)) {
          candidates.add(quote);
        }
      }
    }

    for (final mood in moods.take(2)) {
      final matches = await _localCache.getQuotesForMood(mood: mood, limit: 20);
      for (final quote in matches) {
        if (seenIds.add(quote.id)) {
          candidates.add(quote);
        }
      }
    }

    if (candidates.isEmpty) {
      final fallback = await _localCache.getTopQuotes(limit: 60);
      candidates.addAll(fallback);
    }

    final picked = _selectionService.pickNotificationQuote(
      candidates,
      recentQuoteIds: recentIds,
      preferredCategories: categories,
      preferredMoods: moods,
    );
    if (picked != null) {
      await _localCache.markQuotesShown(<String>[picked.id]);
    }
    return picked;
  }

  Future<Set<String>> getSavedQuoteIds(String userId) async {
    try {
      final rows = await _client
          .from('user_saved_quotes')
          .select('quote_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((row) => (row['quote_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (error) {
      debugPrint('Supabase getSavedQuoteIds failed: $error');
      return <String>{};
    }
  }

  Future<bool> saveQuote({
    required String userId,
    required String quoteId,
  }) async {
    try {
      await _client.from('user_saved_quotes').upsert({
        'user_id': userId,
        'quote_id': quoteId,
      }, onConflict: 'user_id,quote_id');
      await _localCache.incrementSavesCount(quoteId: quoteId, delta: 1);
      return true;
    } catch (error) {
      debugPrint('Supabase saveQuote failed: $error');
      return false;
    }
  }

  Future<bool> unsaveQuote({
    required String userId,
    required String quoteId,
  }) async {
    try {
      await _client
          .from('user_saved_quotes')
          .delete()
          .eq('user_id', userId)
          .eq('quote_id', quoteId);
      await _localCache.incrementSavesCount(quoteId: quoteId, delta: -1);
      return true;
    } catch (error) {
      debugPrint('Supabase unsaveQuote failed: $error');
      return false;
    }
  }

  Future<Set<String>> getLikedQuoteIds(String userId) async {
    try {
      final rows = await _client
          .from('user_liked_quotes')
          .select('quote_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((row) => (row['quote_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (error) {
      debugPrint('Supabase getLikedQuoteIds failed: $error');
      return <String>{};
    }
  }

  Future<bool> likeQuote({
    required String userId,
    required String quoteId,
  }) async {
    try {
      await _client.from('user_liked_quotes').upsert({
        'user_id': userId,
        'quote_id': quoteId,
      }, onConflict: 'user_id,quote_id');
      await _localCache.incrementLikesCount(quoteId: quoteId, delta: 1);
      return true;
    } catch (error) {
      debugPrint('Supabase likeQuote failed: $error');
      return false;
    }
  }

  Future<bool> unlikeQuote({
    required String userId,
    required String quoteId,
  }) async {
    try {
      await _client
          .from('user_liked_quotes')
          .delete()
          .eq('user_id', userId)
          .eq('quote_id', quoteId);
      await _localCache.incrementLikesCount(quoteId: quoteId, delta: -1);
      return true;
    } catch (error) {
      debugPrint('Supabase unlikeQuote failed: $error');
      return false;
    }
  }

  Future<List<String>> getMostLikedQuoteIds({int limit = 12}) async {
    final recentIds = await _localCache.getRecentlyShownQuoteIds(
      limit: _recentlyShownLimit,
    );

    try {
      final quoteRows = await _client
          .from('quotes')
          .select(
            'id,text,author,canonical_author,categories,moods,views_count,shares_count,saves_count,likes_count,popularity_score,author_score,virality_score,length_tier,created_at,hash,quote_hash',
          )
          .order('virality_score', ascending: false)
          .order('popularity_score', ascending: false)
          .order('author_score', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit * _candidateMultiplier);

      final candidates = _mapQuoteRows(quoteRows);
      final ranked = _selectionService.rankExploreFeed(
        candidates,
        contextKey: 'most-liked',
        recentQuoteIds: recentIds,
        limit: limit,
      );
      final ids = ranked.map((quote) => quote.id).toList(growable: false);

      if (ids.isNotEmpty) {
        unawaited(_localCache.markQuotesShown(ids));
        return ids;
      }
    } catch (error) {
      debugPrint('Supabase likes_count query failed, fallback to RPC: $error');
    }

    try {
      final rows = await _client.rpc(
        'get_top_liked_quotes',
        params: {'limit_count': limit},
      );

      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((row) => (row['quote_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      debugPrint('Supabase getMostLikedQuoteIds failed: $error');
      final fallback = await _localCache.getTopQuotes(
        limit: limit * _candidateMultiplier,
      );
      final ranked = _selectionService.rankExploreFeed(
        fallback,
        contextKey: 'most-liked-local',
        recentQuoteIds: recentIds,
        limit: limit,
      );
      return ranked.map((quote) => quote.id).toList(growable: false);
    }
  }

  Future<void> logQuoteEvent({
    required String quoteId,
    required String eventType,
    String? userId,
    String? tagContext,
    String? feedType,
  }) async {
    try {
      await _client.from('quote_events').insert({
        'user_id': userId,
        'quote_id': quoteId,
        'event_type': eventType,
        'tag_context': tagContext,
        'feed_type': feedType,
        'client_ts': DateTime.now().toUtc().toIso8601String(),
      });
      final normalizedEventType = eventType.trim().toLowerCase();
      if (normalizedEventType == 'view') {
        await _localCache.incrementViewsCount(quoteId: quoteId);
      } else if (normalizedEventType == 'share') {
        await _localCache.incrementSharesCount(quoteId: quoteId);
      }
    } catch (error) {
      debugPrint('Supabase logQuoteEvent failed: $error');
    }
  }

  Future<List<QuoteModel>> _rankAllQuotes(List<QuoteModel> quotes) async {
    if (quotes.isEmpty) {
      return const <QuoteModel>[];
    }
    final recentIds = await _localCache.getRecentlyShownQuoteIds(
      limit: _recentlyShownLimit,
    );
    return _selectionService.orderGlobalFeed(
      quotes,
      contextKey: 'global',
      recentQuoteIds: recentIds,
      pageSize: _networkPageSize,
      featuredWindow: _networkPageSize * 5,
    );
  }

  Future<QuoteModel?> _selectDailyQuoteFallback(DateTime date) async {
    final quotes = await _localCache.getTopQuotes(
      limit: _networkPageSize * _candidateMultiplier,
    );
    final candidates = quotes.isNotEmpty ? quotes : await getAllQuotes();
    final window = candidates.take(_networkPageSize * _candidateMultiplier);
    if (candidates.isEmpty) {
      return null;
    }

    final recentIds = await _localCache.getRecentlyShownQuoteIds(
      limit: _recentlyShownLimit,
      within: const Duration(days: 14),
    );
    return _selectionService.pickDailyQuote(
      quotes: window.toList(growable: false),
      recentlyShownIds: recentIds,
      date: date,
    );
  }

  Future<List<QuoteModel>> _fetchQuotesByTagFromSupabase({
    required String tag,
    required int limit,
    required int offset,
  }) async {
    final to = offset + limit - 1;
    final fields = _modernQuoteFields;

    try {
      final filtered = moodAllowlist.contains(tag)
          ? _client.from('quotes').select(fields).contains('moods', <String>[
              tag,
            ])
          : _client.from('quotes').select(fields).contains(
              'categories',
              <String>[tag],
            );

      final rows = await filtered
          .order('virality_score', ascending: false)
          .order('popularity_score', ascending: false)
          .order('author_score', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, to);
      return _mapQuoteRows(rows);
    } catch (error) {
      debugPrint('Supabase getQuotesByTag failed for "$tag": $error');
      return const <QuoteModel>[];
    }
  }

  Future<List<QuoteModel>> _fetchQuotesForPreferredCategoriesFromSupabase({
    required Set<String> categories,
    required int limitPerCategory,
  }) async {
    final results = <QuoteModel>[];
    final seenIds = <String>{};

    for (final category in categories.take(4)) {
      final rows = await _fetchQuotesByTagFromSupabase(
        tag: category,
        limit: limitPerCategory,
        offset: 0,
      );
      for (final quote in rows) {
        if (seenIds.add(quote.id)) {
          results.add(quote);
        }
      }
    }

    return results;
  }

  Future<List<QuoteModel>> _loadLocalQuotesFallback() async {
    final rawJson = await rootBundle.loadString(quotesAssetPath);
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(QuoteModel.fromJson)
        .where((q) => q.id.isNotEmpty && q.quote.isNotEmpty)
        .toList(growable: false);
  }

  String get _modernQuoteFields =>
      'id,text,author,canonical_author,source_url,license,categories,moods,views_count,shares_count,saves_count,likes_count,popularity_score,author_score,virality_score,length_tier,created_at,hash,quote_hash,quote_tags(tags(slug,type))';

  Future<QuoteModel?> _fetchQuoteByIdFromSupabase(String quoteId) async {
    final normalizedId = quoteId.trim();
    if (normalizedId.isEmpty) {
      return null;
    }

    try {
      final rows = await _client
          .from('quotes')
          .select(_modernQuoteFields)
          .eq('id', normalizedId)
          .limit(1);
      final models = _mapQuoteRows(rows);
      if (models.isNotEmpty) {
        return models.first;
      }
    } catch (error) {
      debugPrint('Supabase fetchQuoteById failed for "$normalizedId": $error');
    }
    return null;
  }

  String _yyyyMmDd(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  void _warmExplorePrefetch(List<QuoteModel> quotes) {
    _prefetchedExplorePages.clear();
    final counts = <String, int>{};
    for (final quote in quotes) {
      for (final tag in quote.revisedTags) {
        final normalized = tag.trim().toLowerCase();
        if (normalized.isEmpty) continue;
        counts.update(normalized, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    final topTags = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    for (final entry in topTags.take(12)) {
      final tag = entry.key;
      final page = quotes
          .where((quote) => quote.revisedTags.contains(tag))
          .take(_networkPageSize)
          .toList(growable: false);
      if (page.isNotEmpty) {
        _prefetchedExplorePages[tag] = page;
      }
    }
  }

  Future<void> _prefetchStartupCollections(List<QuoteModel> quotes) async {
    if (quotes.isEmpty) return;

    final topCategories = _topCategoryTags(
      quotes,
    ).take(2).toList(growable: false);
    final selectedQuotes = <QuoteModel>[];

    for (final category in topCategories) {
      final page = quotes
          .where((quote) => _quoteCategoryTags(quote).contains(category))
          .take(_networkPageSize)
          .toList(growable: false);
      if (page.isEmpty) continue;
      _prefetchedExplorePages[category] = page;
      selectedQuotes.addAll(page);
    }

    final mood = _pickWarmupMoodTag(quotes);
    if (mood != null) {
      final page = quotes
          .where((quote) => _quoteMoodTags(quote).contains(mood))
          .take(_networkPageSize)
          .toList(growable: false);
      if (page.isNotEmpty) {
        _prefetchedMoodPages[mood] = page;
        selectedQuotes.addAll(page);
      }
    }

    if (selectedQuotes.isNotEmpty) {
      await _localCache.upsertQuotes(selectedQuotes);
    }
  }

  List<String> _topCategoryTags(List<QuoteModel> quotes) {
    final counts = <String, int>{};
    for (final quote in quotes) {
      for (final tag in _quoteCategoryTags(quote)) {
        counts.update(tag, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    return sorted.map((entry) => entry.key).toList(growable: false);
  }

  String? _pickWarmupMoodTag(List<QuoteModel> quotes) {
    final counts = <String, int>{};
    for (final quote in quotes) {
      for (final mood in _quoteMoodTags(quote)) {
        counts.update(mood, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    final ordered = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    return ordered.isEmpty ? null : ordered.first.key;
  }

  List<String> _quoteCategoryTags(QuoteModel quote) {
    final source = quote.categories.isNotEmpty
        ? quote.categories
        : quote.revisedTags;
    return source
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty && !moodAllowlist.contains(item))
        .toSet()
        .toList(growable: false);
  }

  List<String> _quoteMoodTags(QuoteModel quote) {
    final source = quote.moods.isNotEmpty
        ? quote.moods
        : quote.revisedTags.where(
            (item) => moodAllowlist.contains(item.trim().toLowerCase()),
          );
    return source
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}
