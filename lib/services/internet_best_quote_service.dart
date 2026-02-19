import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/quote_model.dart';

class InternetBestQuoteService {
  static final Uri _bulkUri = Uri.parse('https://zenquotes.io/api/quotes');
  static final Uri _randomUri = Uri.parse('https://zenquotes.io/api/random');

  static const List<String> _iconicAuthors = [
    'albert einstein',
    'mahatma gandhi',
    'oscar wilde',
    'confucius',
    'aristotle',
    'maya angelou',
    'mark twain',
    'nelson mandela',
    'winston churchill',
    'lao tzu',
    'martin luther king',
  ];

  static const List<String> _iconicQuoteFragments = [
    'be yourself',
    'change you wish',
    'to be yourself',
    'knowledge is power',
    'unexamined life',
    'what we think',
    'imagination is more important',
    'be the change',
  ];

  Future<QuoteModel?> fetchBestQuoteOfAllTime() async {
    try {
      final response = await http
          .get(_bulkUri)
          .timeout(const Duration(seconds: 12));
      final candidates = _parseCandidates(response.body);
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => _score(b).compareTo(_score(a)));
        return _toQuoteModel(candidates.first);
      }
    } catch (_) {
      // Fallbacks below.
    }

    try {
      final response = await http
          .get(_randomUri)
          .timeout(const Duration(seconds: 10));
      final candidates = _parseCandidates(response.body);
      if (candidates.isNotEmpty) {
        return _toQuoteModel(candidates.first);
      }
    } catch (_) {
      // Final static fallback.
    }

    return const QuoteModel(
      id: 'internet-fallback-oscar-wilde',
      quote: 'Be yourself; everyone else is already taken.',
      author: 'Oscar Wilde',
      revisedTags: ['famous', 'inspirational'],
    );
  }

  List<_InternetQuote> _parseCandidates(String body) {
    final decoded = jsonDecode(body);
    final rows = decoded is List ? decoded : [decoded];

    return rows
        .whereType<Map<String, dynamic>>()
        .map((row) {
          final quote = (row['q'] ?? row['quote'] ?? '').toString().trim();
          final author = (row['a'] ?? row['author'] ?? '').toString().trim();
          if (quote.isEmpty || author.isEmpty) return null;
          if (quote.toLowerCase().contains('unauthorized api request')) {
            return null;
          }
          return _InternetQuote(quote: quote, author: author);
        })
        .whereType<_InternetQuote>()
        .toList(growable: false);
  }

  int _score(_InternetQuote q) {
    final author = q.author.toLowerCase();
    final quote = q.quote.toLowerCase();

    var score = 0;
    if (_iconicAuthors.any((a) => author.contains(a))) {
      score += 25;
    }
    if (_iconicQuoteFragments.any((f) => quote.contains(f))) {
      score += 40;
    }

    final words = quote.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (words >= 6 && words <= 24) score += 8;
    if (words > 40) score -= 4;

    if (quote.contains('life')) score += 2;
    if (quote.contains('love')) score += 2;
    if (quote.contains('truth')) score += 2;

    return score;
  }

  QuoteModel _toQuoteModel(_InternetQuote q) {
    final normalized = '${q.quote}|${q.author}'.toLowerCase();
    final hash = normalized.codeUnits.fold<int>(
      0,
      (prev, c) => (prev * 31 + c) & 0x7fffffff,
    );

    return QuoteModel(
      id: 'internet-$hash',
      quote: q.quote,
      author: q.author,
      revisedTags: const ['famous', 'internet', 'all-time'],
    );
  }
}

class _InternetQuote {
  const _InternetQuote({required this.quote, required this.author});

  final String quote;
  final String author;
}
