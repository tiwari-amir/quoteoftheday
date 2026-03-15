import '../../core/constants.dart';
import '../../models/quote_model.dart';
import '../../providers/quote_providers.dart';

List<String> searchMoodMatches(
  String query,
  List<QuoteModel> quoteResults, {
  int limit = 10,
}) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return const <String>[];

  final scores = <String, int>{};
  for (final mood in moodAllowlist) {
    if (mood.contains(normalized)) {
      scores[mood] = 100;
    }
  }

  for (var index = 0; index < quoteResults.length; index++) {
    final quote = quoteResults[index];
    final weight = (quoteResults.length - index).clamp(1, 12);
    for (final tag in quote.revisedTags) {
      final mood = tag.trim().toLowerCase();
      if (!moodAllowlist.contains(mood)) continue;
      scores.update(mood, (value) => value + weight, ifAbsent: () => weight);
    }
  }

  final ranked = scores.entries.toList(growable: false)
    ..sort((a, b) {
      final scoreCompare = b.value.compareTo(a.value);
      if (scoreCompare != 0) return scoreCompare;
      return moodAllowlist
          .indexOf(a.key)
          .compareTo(moodAllowlist.indexOf(b.key));
    });
  return ranked.take(limit).map((entry) => entry.key).toList(growable: false);
}

List<AuthorCatalogEntry> searchAuthorMatches(
  String query,
  List<QuoteModel> quoteResults,
  List<AuthorCatalogEntry> catalog, {
  int limit = 24,
}) {
  final normalized = query.trim().toLowerCase();
  final tokens = normalized
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  if (tokens.isEmpty) return const <AuthorCatalogEntry>[];

  final scoreByKey = <String, int>{};
  final catalogByKey = {for (final entry in catalog) entry.authorKey: entry};
  final catalogByAuthor = {
    for (final entry in catalog)
      normalizeAuthorKey(entry.authorName): entry.authorKey,
  };

  for (final entry in catalog) {
    var score = 0;
    final authorName = entry.authorName.toLowerCase();
    for (final token in tokens) {
      if (authorName.contains(token)) score += 24;
      if (authorName.startsWith(token)) score += 8;
    }
    if (score > 0) {
      scoreByKey[entry.authorKey] = score;
    }
  }

  for (var index = 0; index < quoteResults.length; index++) {
    final quote = quoteResults[index];
    final authorKey =
        catalogByAuthor[normalizeAuthorKey(quote.canonicalAuthor)] ??
        catalogByAuthor[normalizeAuthorKey(quote.author)];
    if (authorKey == null) continue;
    final weight = (quoteResults.length - index).clamp(1, 18);
    scoreByKey.update(
      authorKey,
      (value) => value + weight,
      ifAbsent: () => weight,
    );
  }

  final ranked =
      scoreByKey.entries
          .map((entry) => (catalogByKey[entry.key], entry.value))
          .where((entry) => entry.$1 != null)
          .map((entry) => (entry.$1!, entry.$2))
          .toList(growable: false)
        ..sort((a, b) {
          final scoreCompare = b.$2.compareTo(a.$2);
          if (scoreCompare != 0) return scoreCompare;
          final countCompare = b.$1.quoteCount.compareTo(a.$1.quoteCount);
          if (countCompare != 0) return countCompare;
          return a.$1.authorName.compareTo(b.$1.authorName);
        });

  return ranked.take(limit).map((entry) => entry.$1).toList(growable: false);
}
