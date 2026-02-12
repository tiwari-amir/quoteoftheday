import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../models/quote_model.dart';

class QuoteRepository {
  QuoteRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;
  List<QuoteModel>? _quotesCache;

  Future<List<QuoteModel>> getAllQuotes() async {
    if (_quotesCache != null) return _quotesCache!;

    try {
      const pageSize = 1000;
      final quotes = <QuoteModel>[];
      var from = 0;

      while (true) {
        final rows = await _client
            .from('quotes')
            .select('id,text,author,quote_tags(tags(slug,type))')
            .order('created_at', ascending: true)
            .range(from, from + pageSize - 1);

        final page = (rows as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(QuoteModel.fromJson)
            .where((q) => q.id.isNotEmpty && q.quote.isNotEmpty)
            .toList(growable: false);

        quotes.addAll(page);

        if (page.length < pageSize) {
          break;
        }
        from += pageSize;
      }

      if (quotes.isEmpty) {
        _quotesCache = await _loadLocalQuotesFallback();
      } else {
        _quotesCache = quotes;
      }

      return _quotesCache!;
    } catch (error, stack) {
      debugPrint('Supabase getAllQuotes failed, using local fallback: $error');
      debugPrint('$stack');
      _quotesCache = await _loadLocalQuotesFallback();
      return _quotesCache!;
    }
  }

  Future<QuoteModel?> getDailyQuote(DateTime date) async {
    final day = _yyyyMmDd(date);

    try {
      final rows = await _client
          .from('daily_quotes')
          .select('date,quote:quotes!inner(id,text,author,quote_tags(tags(slug,type)))')
          .eq('date', day)
          .limit(1);

      if (rows.isNotEmpty) {
        final row = rows.first;
        final quote = row['quote'];
        if (quote is Map<String, dynamic>) {
          return QuoteModel.fromJson(quote);
        }
      }
    } catch (error) {
      debugPrint('Supabase getDailyQuote failed: $error');
    }

    return null;
  }

  Future<Map<String, int>> getTagsWithCounts() async {
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

  Future<List<QuoteModel>> getQuotesByTag(String tag) async {
    final normalized = tag.trim().toLowerCase();
    final quotes = await getAllQuotes();

    return quotes
        .where((q) => q.revisedTags.contains(normalized))
        .toList(growable: false);
  }

  Future<List<String>> getMoodTagsAvailable(List<String> allowlist) async {
    final tags = await getTagsWithCounts();
    final allowedSet = allowlist.map((m) => m.toLowerCase()).toSet();

    return tags.keys.where(allowedSet.contains).toList(growable: false);
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

  Future<void> saveQuote({required String userId, required String quoteId}) async {
    try {
      await _client.from('user_saved_quotes').insert({
        'user_id': userId,
        'quote_id': quoteId,
      });
    } catch (error) {
      debugPrint('Supabase saveQuote failed: $error');
    }
  }

  Future<void> unsaveQuote({required String userId, required String quoteId}) async {
    try {
      await _client
          .from('user_saved_quotes')
          .delete()
          .eq('user_id', userId)
          .eq('quote_id', quoteId);
    } catch (error) {
      debugPrint('Supabase unsaveQuote failed: $error');
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
    } catch (error) {
      debugPrint('Supabase logQuoteEvent failed: $error');
    }
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

  String _yyyyMmDd(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }
}
