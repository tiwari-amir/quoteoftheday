import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/quote_model.dart';

class LocalQuoteCache {
  LocalQuoteCache._();

  static final LocalQuoteCache instance = LocalQuoteCache._();

  static const _dbName = 'quoteflow_quotes_cache_v1.db';
  static const _dbVersion = 4;
  static const _metaLastSyncAt = 'last_sync_at';

  Database? _db;
  Future<Database>? _openFuture;

  // Web fallback keeps behavior intact where sqflite is unavailable.
  List<QuoteModel> _memoryQuotes = const <QuoteModel>[];
  final Map<String, String> _memoryDailyQuoteByDay = <String, String>{};
  final Map<String, DateTime> _memoryRecentlyShown = <String, DateTime>{};
  DateTime? _memoryLastSyncAt;

  Future<Database?> _database() async {
    if (kIsWeb) {
      return null;
    }
    if (_db != null) {
      return _db;
    }
    if (_openFuture != null) {
      return _openFuture;
    }

    _openFuture = _openDatabase();
    try {
      _db = await _openFuture!;
      return _db;
    } finally {
      _openFuture = null;
    }
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = '$databasesPath/$_dbName';
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _upgradeSchema(
          db,
          oldVersion: oldVersion,
          newVersion: newVersion,
        );
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      create table if not exists quotes_cache (
        id text primary key,
        text text not null,
        author text not null,
        canonical_author text not null default '',
        source_url text,
        license text,
        categories_json text not null,
        moods_json text not null,
        tags_json text not null,
        views_count integer not null default 0,
        shares_count integer not null default 0,
        saves_count integer not null default 0,
        likes_count integer not null default 0,
        popularity_score integer not null default 0,
        author_score real not null default 0,
        virality_score real not null default 0,
        length_tier text not null default 'medium',
        created_at text not null,
        hash text not null unique,
        search_text text not null
      )
    ''');

    await db.execute('''
      create table if not exists quote_categories_cache (
        quote_id text not null,
        category text not null,
        primary key (quote_id, category)
      )
    ''');

    await db.execute('''
      create table if not exists quote_moods_cache (
        quote_id text not null,
        mood text not null,
        primary key (quote_id, mood)
      )
    ''');

    await db.execute('''
      create table if not exists quote_search_cache (
        quote_id text primary key,
        search_blob text not null
      )
    ''');

    await db.execute('''
      create table if not exists daily_quote_cache (
        day text primary key,
        quote_id text not null,
        cached_at text not null
      )
    ''');

    await db.execute('''
      create table if not exists recently_shown_quotes (
        quote_id text primary key,
        shown_at text not null
      )
    ''');

    await db.execute('''
      create table if not exists cache_meta (
        key text primary key,
        value text not null
      )
    ''');

    await _ensureIndexes(db);
  }

  Future<void> _upgradeSchema(
    Database db, {
    required int oldVersion,
    required int newVersion,
  }) async {
    if (oldVersion < 2) {
      await db.execute(
        "alter table quotes_cache add column canonical_author text not null default ''",
      );
      await db.execute(
        "alter table quotes_cache add column popularity_score integer not null default 0",
      );
      await db.execute(
        "alter table quotes_cache add column length_tier text not null default 'medium'",
      );
      await db.execute('''
        create table if not exists recently_shown_quotes (
          quote_id text primary key,
          shown_at text not null
        )
      ''');
    }

    await _ensureIndexes(db);
    if (oldVersion < 2 && newVersion >= 2) {
      await db.rawUpdate('''
        update quotes_cache
        set canonical_author = trim(lower(author))
        where canonical_author = ''
        ''');
      await db.rawUpdate('''
        update quotes_cache
        set popularity_score = likes_count
        where popularity_score = 0
        ''');
    }

    if (oldVersion < 3) {
      await db.execute(
        "alter table quotes_cache add column author_score real not null default 0",
      );
    }

    if (oldVersion < 4) {
      await db.execute(
        "alter table quotes_cache add column views_count integer not null default 0",
      );
      await db.execute(
        "alter table quotes_cache add column shares_count integer not null default 0",
      );
      await db.execute(
        "alter table quotes_cache add column saves_count integer not null default 0",
      );
      await db.execute(
        "alter table quotes_cache add column virality_score real not null default 0",
      );
    }

    await _ensureIndexes(db);
  }

  Future<void> _ensureIndexes(Database db) async {
    await db.execute(
      'create index if not exists idx_quotes_cache_created_at on quotes_cache(created_at desc)',
    );
    await db.execute(
      'create index if not exists idx_quotes_cache_likes_count on quotes_cache(likes_count desc)',
    );
    await db.execute(
      'create index if not exists idx_quotes_cache_popularity_score on quotes_cache(popularity_score desc, likes_count desc, created_at desc)',
    );
    await db.execute(
      'create index if not exists idx_quotes_cache_virality_score on quotes_cache(virality_score desc)',
    );
    await db.execute(
      'create index if not exists idx_quotes_cache_author_score on quotes_cache(author_score desc)',
    );
    await db.execute(
      'create index if not exists idx_quotes_cache_author on quotes_cache(author)',
    );
    await db.execute(
      'create index if not exists idx_quotes_cache_canonical_author on quotes_cache(canonical_author)',
    );
    await db.execute(
      'create index if not exists idx_quotes_cache_length_tier on quotes_cache(length_tier)',
    );
    await db.execute(
      'create index if not exists idx_quotes_cache_hash on quotes_cache(hash)',
    );
    await db.execute(
      'create index if not exists idx_quotes_cache_search_text on quotes_cache(search_text)',
    );
    await db.execute(
      'create index if not exists idx_quote_categories_cache_category on quote_categories_cache(category)',
    );
    await db.execute(
      'create index if not exists idx_quote_moods_cache_mood on quote_moods_cache(mood)',
    );
    await db.execute(
      'create index if not exists idx_quote_search_cache_search_blob on quote_search_cache(search_blob)',
    );
    await db.execute(
      'create index if not exists idx_recently_shown_quotes_shown_at on recently_shown_quotes(shown_at desc)',
    );
  }

  Future<List<QuoteModel>> getAllQuotes() async {
    final db = await _database();
    if (db == null) {
      final memoryQuotes = List<QuoteModel>.from(
        _memoryQuotes,
        growable: false,
      );
      return _sortQuotes(memoryQuotes);
    }

    final rows = await db.query('quotes_cache', orderBy: _rankOrderBy);
    return rows.map(_quoteFromCacheRow).toList(growable: false);
  }

  Future<List<QuoteModel>> getTopQuotes({
    int limit = 40,
    int offset = 0,
  }) async {
    final db = await _database();
    if (db == null) {
      final sorted = _sortQuotes(_memoryQuotes);
      if (offset >= sorted.length) {
        return const <QuoteModel>[];
      }
      final end = math.min(offset + limit, sorted.length);
      return sorted.sublist(offset, end);
    }

    final rows = await db.query(
      'quotes_cache',
      orderBy: _rankOrderBy,
      limit: limit,
      offset: offset,
    );
    return rows.map(_quoteFromCacheRow).toList(growable: false);
  }

  Future<List<QuoteModel>> getQuotesForCategory({
    required String category,
    int limit = 120,
    int offset = 0,
  }) async {
    final normalized = category.trim().toLowerCase();
    if (normalized.isEmpty) {
      return getTopQuotes(limit: limit, offset: offset);
    }

    final db = await _database();
    if (db == null) {
      final quotes = _memoryQuotes
          .where((quote) => _normalizedCategories(quote).contains(normalized))
          .toList(growable: false);
      final sorted = _sortQuotes(quotes);
      if (offset >= sorted.length) {
        return const <QuoteModel>[];
      }
      final end = math.min(offset + limit, sorted.length);
      return sorted.sublist(offset, end);
    }

    final rows = await db.rawQuery(
      '''
      select qc.*
      from quotes_cache qc
      inner join quote_categories_cache cc on cc.quote_id = qc.id
      where cc.category = ?
      order by ${_rankOrderByWithAlias('qc')}
      limit ? offset ?
      ''',
      <Object>[normalized, limit, offset],
    );
    return rows.map(_quoteFromCacheRow).toList(growable: false);
  }

  Future<List<QuoteModel>> getQuotesForMood({
    required String mood,
    int limit = 120,
    int offset = 0,
  }) async {
    final normalized = mood.trim().toLowerCase();
    if (normalized.isEmpty) {
      return getTopQuotes(limit: limit, offset: offset);
    }

    final db = await _database();
    if (db == null) {
      final quotes = _memoryQuotes
          .where((quote) => _normalizedMoods(quote).contains(normalized))
          .toList(growable: false);
      final sorted = _sortQuotes(quotes);
      if (offset >= sorted.length) {
        return const <QuoteModel>[];
      }
      final end = math.min(offset + limit, sorted.length);
      return sorted.sublist(offset, end);
    }

    final rows = await db.rawQuery(
      '''
      select qc.*
      from quotes_cache qc
      inner join quote_moods_cache qm on qm.quote_id = qc.id
      where qm.mood = ?
      order by ${_rankOrderByWithAlias('qc')}
      limit ? offset ?
      ''',
      <Object>[normalized, limit, offset],
    );
    return rows.map(_quoteFromCacheRow).toList(growable: false);
  }

  Future<void> replaceAllQuotes(List<QuoteModel> quotes) async {
    final unique = _dedupeById(quotes);
    final db = await _database();
    if (db == null) {
      _memoryQuotes = _sortQuotes(unique);
      _memoryLastSyncAt = DateTime.now().toUtc();
      return;
    }

    await db.transaction((txn) async {
      await txn.delete('quote_categories_cache');
      await txn.delete('quote_moods_cache');
      await txn.delete('quote_search_cache');
      await txn.delete('quotes_cache');

      final batch = txn.batch();
      for (final quote in unique) {
        _appendQuoteInsert(batch, quote);
      }
      await batch.commit(noResult: true);
    });

    await setLastSyncAt(DateTime.now().toUtc());
  }

  Future<void> upsertQuotes(List<QuoteModel> quotes) async {
    final unique = _dedupeById(quotes);
    if (unique.isEmpty) {
      return;
    }

    final db = await _database();
    if (db == null) {
      final merged = <String, QuoteModel>{
        for (final quote in _memoryQuotes) quote.id: quote,
      };
      for (final quote in unique) {
        merged[quote.id] = quote;
      }
      _memoryQuotes = _sortQuotes(merged.values.toList(growable: false));
      return;
    }

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final quote in unique) {
        batch.delete(
          'quote_categories_cache',
          where: 'quote_id = ?',
          whereArgs: <Object>[quote.id],
        );
        batch.delete(
          'quote_moods_cache',
          where: 'quote_id = ?',
          whereArgs: <Object>[quote.id],
        );
        batch.delete(
          'quote_search_cache',
          where: 'quote_id = ?',
          whereArgs: <Object>[quote.id],
        );
        _appendQuoteInsert(batch, quote);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<QuoteModel?> getQuoteById(String quoteId) async {
    final normalized = quoteId.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final db = await _database();
    if (db == null) {
      for (final quote in _memoryQuotes) {
        if (quote.id == normalized) {
          return quote;
        }
      }
      return null;
    }

    final rows = await db.query(
      'quotes_cache',
      where: 'id = ?',
      whereArgs: <Object>[normalized],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _quoteFromCacheRow(rows.first);
  }

  Future<Map<String, int>> getCategoryCounts() async {
    final db = await _database();
    if (db == null) {
      return _countsFromMemoryQuotes();
    }

    final rows = await db.rawQuery('''
      select category, count(*) as count
      from quote_categories_cache
      group by category
      order by count desc, category asc
    ''');
    final counts = <String, int>{};
    for (final row in rows) {
      final category = (row['category'] ?? '').toString().trim().toLowerCase();
      if (category.isEmpty) {
        continue;
      }
      final value = (row['count'] as int?) ?? 0;
      counts[category] = value;
    }
    if (counts.isNotEmpty) {
      return counts;
    }
    return _countsFromMemoryQuotes();
  }

  Future<void> cacheDailyQuote({
    required String day,
    required String quoteId,
  }) async {
    final dayKey = day.trim();
    final id = quoteId.trim();
    if (dayKey.isEmpty || id.isEmpty) {
      return;
    }

    final db = await _database();
    if (db == null) {
      _memoryDailyQuoteByDay[dayKey] = id;
      return;
    }

    await db.insert('daily_quote_cache', <String, Object>{
      'day': dayKey,
      'quote_id': id,
      'cached_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getDailyQuoteId(String day) async {
    final dayKey = day.trim();
    if (dayKey.isEmpty) {
      return null;
    }

    final db = await _database();
    if (db == null) {
      return _memoryDailyQuoteByDay[dayKey];
    }

    final rows = await db.query(
      'daily_quote_cache',
      columns: <String>['quote_id'],
      where: 'day = ?',
      whereArgs: <Object>[dayKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final quoteId = (rows.first['quote_id'] ?? '').toString().trim();
    return quoteId.isEmpty ? null : quoteId;
  }

  Future<Set<String>> getRecentlyShownQuoteIds({
    int limit = 200,
    Duration? within,
  }) async {
    final cutoff = within == null
        ? null
        : DateTime.now().toUtc().subtract(within);
    final db = await _database();
    if (db == null) {
      final entries = _memoryRecentlyShown.entries.toList(growable: false)
        ..sort((a, b) => b.value.compareTo(a.value));
      final ids = <String>{};
      for (final entry in entries) {
        if (cutoff != null && entry.value.isBefore(cutoff)) {
          continue;
        }
        ids.add(entry.key);
        if (ids.length >= limit) {
          break;
        }
      }
      return ids;
    }

    final rows = await db.query(
      'recently_shown_quotes',
      columns: <String>['quote_id', 'shown_at'],
      where: cutoff == null ? null : 'shown_at >= ?',
      whereArgs: cutoff == null ? null : <Object>[cutoff.toIso8601String()],
      orderBy: 'shown_at desc',
      limit: limit,
    );
    return rows
        .map((row) => (row['quote_id'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> markQuotesShown(
    Iterable<String> quoteIds, {
    DateTime? shownAt,
    int keep = 200,
  }) async {
    final ids = quoteIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) {
      return;
    }

    final timestamp = (shownAt ?? DateTime.now()).toUtc();
    final db = await _database();
    if (db == null) {
      for (final id in ids) {
        _memoryRecentlyShown[id] = timestamp;
      }
      _pruneMemoryRecentlyShown(keep);
      return;
    }

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in ids) {
        batch.insert('recently_shown_quotes', <String, Object>{
          'quote_id': id,
          'shown_at': timestamp.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      await txn.rawDelete(
        '''
        delete from recently_shown_quotes
        where quote_id not in (
          select quote_id
          from recently_shown_quotes
          order by shown_at desc
          limit ?
        )
        ''',
        <Object>[keep],
      );
    });
  }

  Future<void> incrementLikesCount({
    required String quoteId,
    required int delta,
  }) async {
    await _updateEngagementCounts(quoteId: quoteId, likesDelta: delta);
  }

  Future<void> incrementSavesCount({
    required String quoteId,
    required int delta,
  }) async {
    await _updateEngagementCounts(quoteId: quoteId, savesDelta: delta);
  }

  Future<void> incrementViewsCount({
    required String quoteId,
    int delta = 1,
  }) async {
    await _updateEngagementCounts(quoteId: quoteId, viewsDelta: delta);
  }

  Future<void> incrementSharesCount({
    required String quoteId,
    int delta = 1,
  }) async {
    await _updateEngagementCounts(quoteId: quoteId, sharesDelta: delta);
  }

  Future<void> _updateEngagementCounts({
    required String quoteId,
    int likesDelta = 0,
    int savesDelta = 0,
    int viewsDelta = 0,
    int sharesDelta = 0,
  }) async {
    if (likesDelta == 0 &&
        savesDelta == 0 &&
        viewsDelta == 0 &&
        sharesDelta == 0) {
      return;
    }
    final id = quoteId.trim();
    if (id.isEmpty) {
      return;
    }

    final db = await _database();
    if (db == null) {
      _memoryQuotes = _sortQuotes(
        _memoryQuotes
            .map((quote) {
              if (quote.id != id) {
                return quote;
              }
              return _nextInteractionState(
                quote,
                likesDelta: likesDelta,
                savesDelta: savesDelta,
                viewsDelta: viewsDelta,
                sharesDelta: sharesDelta,
              );
            })
            .toList(growable: false),
      );
      return;
    }

    final rows = await db.query(
      'quotes_cache',
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return;
    }

    final current = _quoteFromCacheRow(rows.first);
    final next = _nextInteractionState(
      current,
      likesDelta: likesDelta,
      savesDelta: savesDelta,
      viewsDelta: viewsDelta,
      sharesDelta: sharesDelta,
    );

    await db.update(
      'quotes_cache',
      <String, Object?>{
        'views_count': next.viewsCount,
        'shares_count': next.sharesCount,
        'saves_count': next.savesCount,
        'likes_count': next.likesCount,
        'popularity_score': next.popularityScore,
        'virality_score': next.viralityScore,
      },
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
  }

  Future<DateTime?> getLastSyncAt() async {
    final db = await _database();
    if (db == null) {
      return _memoryLastSyncAt;
    }

    final rows = await db.query(
      'cache_meta',
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object>[_metaLastSyncAt],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return DateTime.tryParse((rows.first['value'] ?? '').toString());
  }

  Future<void> setLastSyncAt(DateTime timestamp) async {
    final iso = timestamp.toUtc().toIso8601String();
    final db = await _database();
    if (db == null) {
      _memoryLastSyncAt = timestamp.toUtc();
      return;
    }

    await db.insert('cache_meta', <String, Object>{
      'key': _metaLastSyncAt,
      'value': iso,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  QuoteModel _quoteFromCacheRow(Map<String, Object?> row) {
    final categories = _decodeStringList(row['categories_json']);
    final moods = _decodeStringList(row['moods_json']);
    final tags = _decodeStringList(row['tags_json']);

    return QuoteModel.fromJson(<String, Object?>{
      'id': (row['id'] ?? '').toString(),
      'text': (row['text'] ?? '').toString(),
      'author': (row['author'] ?? 'Unknown').toString(),
      'canonical_author': row['canonical_author'],
      'categories': categories,
      'moods': moods,
      'revised_tags': tags,
      'source_url': row['source_url'],
      'license': row['license'],
      'views_count': row['views_count'],
      'shares_count': row['shares_count'],
      'saves_count': row['saves_count'],
      'likes_count': row['likes_count'],
      'popularity_score': row['popularity_score'],
      'author_score': row['author_score'],
      'virality_score': row['virality_score'],
      'length_tier': row['length_tier'],
      'created_at': row['created_at'],
      'hash': row['hash'],
    });
  }

  List<QuoteModel> _dedupeById(List<QuoteModel> quotes) {
    final seen = <String>{};
    final output = <QuoteModel>[];
    for (final quote in quotes) {
      if (quote.id.isEmpty || quote.quote.isEmpty) {
        continue;
      }
      if (!seen.add(quote.id)) {
        continue;
      }
      output.add(quote);
    }
    return output;
  }

  List<String> _normalizedCategories(QuoteModel quote) {
    if (quote.categories.isNotEmpty) {
      return quote.categories;
    }
    return quote.revisedTags;
  }

  List<String> _normalizedMoods(QuoteModel quote) {
    return quote.moods;
  }

  List<String> _normalizedTags(QuoteModel quote) {
    final tags = <String>[
      ..._normalizedCategories(quote),
      ..._normalizedMoods(quote),
      ...quote.revisedTags,
    ];
    return tags
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  String _searchBlob(
    QuoteModel quote,
    List<String> categories,
    List<String> moods,
  ) {
    return <String>[
      quote.quote.toLowerCase(),
      quote.author.toLowerCase(),
      _effectiveCanonicalAuthor(quote),
      categories.join(' '),
      moods.join(' '),
    ].where((part) => part.trim().isNotEmpty).join(' ');
  }

  List<String> _decodeStringList(Object? raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }
    final source = (raw ?? '').toString().trim();
    if (source.isEmpty) {
      return const <String>[];
    }

    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) {
        return const <String>[];
      }
      return decoded
          .map((item) => item.toString().trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  String _effectiveHash(QuoteModel quote) {
    final normalized = quote.hash.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    final payload = '${quote.quote}|${quote.author}'.toLowerCase();
    final folded = payload.codeUnits.fold<int>(
      0,
      (previous, codeUnit) => (previous * 31 + codeUnit) & 0x7fffffff,
    );
    return 'local-$folded';
  }

  String _effectiveCanonicalAuthor(QuoteModel quote) {
    final normalized = quote.canonicalAuthor.trim().toLowerCase();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return quote.author
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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

  int _effectivePopularityScore(QuoteModel quote) {
    if (quote.popularityScore > 0) {
      return quote.popularityScore;
    }
    final lengthTier = _effectiveLengthTier(quote);
    final lengthBonus = switch (lengthTier) {
      'medium' => 5,
      'short' => 3,
      'long' => 2,
      _ => 3,
    };
    return quote.likesCount + lengthBonus;
  }

  double _effectiveViralityScore(QuoteModel quote) {
    final score = quote.viralityScore;
    if (score.isFinite && !score.isNaN && score > 0) {
      return score;
    }
    return _computeViralityScore(
      viewsCount: quote.viewsCount,
      likesCount: quote.likesCount,
      savesCount: quote.savesCount,
      sharesCount: quote.sharesCount,
    );
  }

  double _effectiveAuthorScore(QuoteModel quote) {
    final score = quote.authorScore;
    if (!score.isFinite || score.isNaN || score < 0) {
      return 0;
    }
    return score;
  }

  void _appendQuoteInsert(Batch batch, QuoteModel quote) {
    final categories = _normalizedCategories(quote);
    final moods = _normalizedMoods(quote);
    final tags = _normalizedTags(quote);
    final createdAt =
        quote.createdAt?.toUtc().toIso8601String() ??
        DateTime.now().toUtc().toIso8601String();

    batch.insert('quotes_cache', <String, Object?>{
      'id': quote.id,
      'text': quote.quote,
      'author': quote.author,
      'canonical_author': _effectiveCanonicalAuthor(quote),
      'source_url': quote.sourceUrl,
      'license': quote.license,
      'categories_json': jsonEncode(categories),
      'moods_json': jsonEncode(moods),
      'tags_json': jsonEncode(tags),
      'views_count': quote.viewsCount,
      'shares_count': quote.sharesCount,
      'saves_count': quote.savesCount,
      'likes_count': quote.likesCount,
      'popularity_score': _effectivePopularityScore(quote),
      'author_score': _effectiveAuthorScore(quote),
      'virality_score': _effectiveViralityScore(quote),
      'length_tier': _effectiveLengthTier(quote),
      'created_at': createdAt,
      'hash': _effectiveHash(quote),
      'search_text': _searchBlob(quote, categories, moods),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    for (final category in categories) {
      batch.insert('quote_categories_cache', <String, Object>{
        'quote_id': quote.id,
        'category': category,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final mood in moods) {
      batch.insert('quote_moods_cache', <String, Object>{
        'quote_id': quote.id,
        'mood': mood,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    batch.insert('quote_search_cache', <String, Object>{
      'quote_id': quote.id,
      'search_blob': _searchBlob(quote, categories, moods),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Map<String, int> _countsFromMemoryQuotes() {
    final counts = <String, int>{};
    for (final quote in _memoryQuotes) {
      final categories = quote.categories.isEmpty
          ? quote.revisedTags
          : quote.categories;
      for (final category in categories) {
        final normalized = category.trim().toLowerCase();
        if (normalized.isEmpty) {
          continue;
        }
        counts.update(normalized, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) {
          return byCount;
        }
        return a.key.compareTo(b.key);
      });
    return <String, int>{for (final entry in sorted) entry.key: entry.value};
  }

  List<QuoteModel> _sortQuotes(List<QuoteModel> quotes) {
    final sorted = List<QuoteModel>.from(quotes, growable: false)
      ..sort((a, b) {
        final byVirality = _effectiveViralityScore(
          b,
        ).compareTo(_effectiveViralityScore(a));
        if (byVirality != 0) {
          return byVirality;
        }
        final byPopularity = _effectivePopularityScore(
          b,
        ).compareTo(_effectivePopularityScore(a));
        if (byPopularity != 0) {
          return byPopularity;
        }
        final byAuthorScore = _effectiveAuthorScore(
          b,
        ).compareTo(_effectiveAuthorScore(a));
        if (byAuthorScore != 0) {
          return byAuthorScore;
        }
        final byLikes = b.likesCount.compareTo(a.likesCount);
        if (byLikes != 0) {
          return byLikes;
        }
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        final byCreatedAt = bTime.compareTo(aTime);
        if (byCreatedAt != 0) {
          return byCreatedAt;
        }
        return a.id.compareTo(b.id);
      });
    return sorted;
  }

  void _pruneMemoryRecentlyShown(int keep) {
    final entries = _memoryRecentlyShown.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    _memoryRecentlyShown
      ..clear()
      ..addEntries(entries.take(keep));
  }

  static const String _rankOrderBy =
      'virality_score desc, popularity_score desc, author_score desc, created_at desc, id asc';

  String _rankOrderByWithAlias(String alias) {
    return '$alias.virality_score desc, '
        '$alias.popularity_score desc, '
        '$alias.author_score desc, '
        '$alias.created_at desc, '
        '$alias.id asc';
  }

  QuoteModel _nextInteractionState(
    QuoteModel quote, {
    int likesDelta = 0,
    int savesDelta = 0,
    int viewsDelta = 0,
    int sharesDelta = 0,
  }) {
    final nextLikes = math.max(0, quote.likesCount + likesDelta);
    final nextSaves = math.max(0, quote.savesCount + savesDelta);
    final nextViews = math.max(0, quote.viewsCount + viewsDelta);
    final nextShares = math.max(0, quote.sharesCount + sharesDelta);
    final nextPopularity = math.max(
      0,
      _effectivePopularityScore(quote) + likesDelta,
    );
    final nextVirality = _computeViralityScore(
      viewsCount: nextViews,
      likesCount: nextLikes,
      savesCount: nextSaves,
      sharesCount: nextShares,
    );

    return quote.copyWith(
      viewsCount: nextViews,
      sharesCount: nextShares,
      savesCount: nextSaves,
      likesCount: nextLikes,
      popularityScore: nextPopularity,
      viralityScore: nextVirality,
    );
  }

  double _computeViralityScore({
    required int viewsCount,
    required int likesCount,
    required int savesCount,
    required int sharesCount,
  }) {
    return (viewsCount * 0.1) +
        (likesCount * 1.5) +
        (savesCount * 2.0) +
        (sharesCount * 3.0);
  }
}
