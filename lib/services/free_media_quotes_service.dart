import '../models/quote_model.dart';

class FreeMediaQuotesService {
  final Map<String, List<QuoteModel>> _cacheByCategorySet =
      <String, List<QuoteModel>>{};

  // Offline curated fallback so movies/series always has visible quotes.
  static const Map<String, List<QuoteModel>> _fallbackQuotesByCategory = {
    'movies': [
      QuoteModel(
        id: 'fallback-movie-1',
        quote: 'May the Force be with you.',
        author: 'Star Wars',
        revisedTags: <String>['movies'],
        categories: <String>['movies'],
      ),
      QuoteModel(
        id: 'fallback-movie-2',
        quote: "I'm going to make him an offer he can't refuse.",
        author: 'The Godfather',
        revisedTags: <String>['movies'],
        categories: <String>['movies'],
      ),
      QuoteModel(
        id: 'fallback-movie-3',
        quote: 'Why so serious?',
        author: 'The Dark Knight',
        revisedTags: <String>['movies'],
        categories: <String>['movies'],
      ),
      QuoteModel(
        id: 'fallback-movie-4',
        quote:
            'Life is like a box of chocolates. You never know what you are gonna get.',
        author: 'Forrest Gump',
        revisedTags: <String>['movies'],
        categories: <String>['movies'],
      ),
      QuoteModel(
        id: 'fallback-movie-5',
        quote: "I'll be back.",
        author: 'The Terminator',
        revisedTags: <String>['movies'],
        categories: <String>['movies'],
      ),
      QuoteModel(
        id: 'fallback-movie-6',
        quote: 'Do, or do not. There is no try.',
        author: 'Yoda - The Empire Strikes Back',
        revisedTags: <String>['movies'],
        categories: <String>['movies'],
      ),
    ],
    'series': [
      QuoteModel(
        id: 'fallback-series-1',
        quote: 'Winter is coming.',
        author: 'Game of Thrones',
        revisedTags: <String>['series'],
        categories: <String>['series'],
      ),
      QuoteModel(
        id: 'fallback-series-2',
        quote: 'I am the one who knocks.',
        author: 'Breaking Bad',
        revisedTags: <String>['series'],
        categories: <String>['series'],
      ),
      QuoteModel(
        id: 'fallback-series-3',
        quote: 'How you doin?',
        author: 'Joey Tribbiani - Friends',
        revisedTags: <String>['series'],
        categories: <String>['series'],
      ),
      QuoteModel(
        id: 'fallback-series-4',
        quote: 'Bears. Beets. Battlestar Galactica.',
        author: 'The Office',
        revisedTags: <String>['series'],
        categories: <String>['series'],
      ),
      QuoteModel(
        id: 'fallback-series-5',
        quote: 'The game is on.',
        author: 'Sherlock',
        revisedTags: <String>['series'],
        categories: <String>['series'],
      ),
      QuoteModel(
        id: 'fallback-series-6',
        quote: 'When you play the game of thrones, you win or you die.',
        author: 'Cersei Lannister - Game of Thrones',
        revisedTags: <String>['series'],
        categories: <String>['series'],
      ),
    ],
  };

  Future<List<QuoteModel>> fetchQuotesForCategories({
    required Set<String> categories,
    int maxPerCategory = 14,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final normalized = categories
        .map((category) => category.trim().toLowerCase())
        .toSet();
    final mediaCategories = normalized
        .where(_fallbackQuotesByCategory.containsKey)
        .toSet();
    if (mediaCategories.isEmpty) return const <QuoteModel>[];

    final key = _setKey(mediaCategories);
    final cached = _cacheByCategorySet[key];
    if (cached != null) return cached;

    final output = <QuoteModel>[];
    for (final category in mediaCategories) {
      final quotes =
          _fallbackQuotesByCategory[category] ?? const <QuoteModel>[];
      output.addAll(quotes.take(maxPerCategory));
    }

    final deduped = _dedupeQuotes(output);
    _cacheByCategorySet[key] = deduped;
    return deduped;
  }

  String _setKey(Iterable<String> values) {
    final sorted = values.toList(growable: false)..sort();
    return sorted.join('|');
  }

  List<QuoteModel> _dedupeQuotes(List<QuoteModel> input) {
    final seen = <String>{};
    final output = <QuoteModel>[];
    for (final quote in input) {
      final key = '${quote.quote}|${quote.author}'.toLowerCase();
      if (!seen.add(key)) continue;
      output.add(quote);
    }
    return output;
  }
}
