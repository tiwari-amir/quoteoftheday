import '../../models/quote_model.dart';

class SearchResult {
  const SearchResult({required this.quote, required this.score});

  final QuoteModel quote;
  final int score;
}

class _SearchIndexEntry {
  const _SearchIndexEntry({
    required this.quote,
    required this.quoteText,
    required this.author,
    required this.tags,
  });

  final QuoteModel quote;
  final String quoteText;
  final String author;
  final String tags;
}

class SearchService {
  SearchService(List<QuoteModel> quotes)
      : _entries = quotes
            .map(
              (q) => _SearchIndexEntry(
                quote: q,
                quoteText: q.quote.toLowerCase(),
                author: q.author.toLowerCase(),
                tags: q.revisedTags.join(' ').toLowerCase(),
              ),
            )
            .toList(growable: false);

  final List<_SearchIndexEntry> _entries;

  List<QuoteModel> searchQuotes(
    String query, {
    Set<String>? scopeQuoteIds,
    String? lengthFilter,
    String? tagFilter,
    int limit = 100,
  }) {
    final normalized = query.trim().toLowerCase();
    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList(growable: false);

    if (tokens.isEmpty && scopeQuoteIds == null && lengthFilter == null && tagFilter == null) {
      return _entries.take(limit).map((e) => e.quote).toList(growable: false);
    }

    final results = <SearchResult>[];

    for (final entry in _entries) {
      final quote = entry.quote;
      if (scopeQuoteIds != null && !scopeQuoteIds.contains(quote.id)) continue;

      if (lengthFilter != null && !_matchLength(quote.quote, lengthFilter)) continue;
      if (tagFilter != null && tagFilter.isNotEmpty && !quote.revisedTags.contains(tagFilter)) {
        continue;
      }

      var score = 0;
      for (final token in tokens) {
        score += _scoreToken(token, entry);
      }

      if (tokens.isNotEmpty && score == 0) continue;
      results.add(SearchResult(quote: quote, score: score));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(limit).map((r) => r.quote).toList(growable: false);
  }

  int _scoreToken(String token, _SearchIndexEntry entry) {
    var score = 0;

    if (entry.quoteText.contains(token)) score += 3;
    if (entry.author.contains(token)) score += 2;
    if (entry.tags.contains(token)) score += 2;

    if (entry.quoteText.startsWith(token)) score += 1;
    if (entry.author.startsWith(token)) score += 1;
    if (entry.tags.startsWith(token)) score += 1;

    return score;
  }

  bool _matchLength(String text, String filter) {
    final words = text
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .length;

    return switch (filter) {
      'short' => words <= 12,
      'medium' => words > 12 && words <= 24,
      'long' => words > 24,
      _ => true,
    };
  }
}
