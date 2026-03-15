import '../../models/quote_model.dart';

const List<String> internetTopCategorySignals = <String>[
  'love',
  'life',
  'inspiration',
  'friendship',
  'success',
  'wisdom',
  'happiness',
];

String discoveryCategoryRouteTag(String raw) {
  final lower = raw.trim().toLowerCase();
  if (lower == 'series') return 'movies/series';
  return lower;
}

String discoveryCategoryLabel(String raw) {
  if (raw == 'series') return 'Movies / Series';
  return raw
      .split(RegExp(r'[_\s]+'))
      .map((part) {
        if (part.isEmpty) return part;
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}

String? pickRecentDiscoveryCategory(Iterable<QuoteModel> quotes) {
  final datedQuotes = quotes.where((quote) => quote.createdAt != null).toList();
  if (datedQuotes.isNotEmpty) {
    datedQuotes.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    final latest = datedQuotes.first.createdAt!;
    final latestDay = DateTime(latest.year, latest.month, latest.day);
    final sameDayQuotes = datedQuotes.where((quote) {
      final value = quote.createdAt!;
      final day = DateTime(value.year, value.month, value.day);
      return day == latestDay;
    });
    final recent = _pickMostFrequentCategory(sameDayQuotes);
    if (recent != null) return recent;
  }

  return _pickMostFrequentCategory(quotes);
}

List<String> selectTopCategoryKeys(
  Map<String, int> categoryCounts, {
  String? recentCategory,
  int limit = 7,
}) {
  final pool = categoryCounts.entries.toList(growable: true);
  final picks = <String>[];

  void addTag(String tag) {
    if (tag.trim().isEmpty) return;
    final index = pool.indexWhere((entry) => entry.key == tag);
    if (index < 0) return;
    picks.add(pool.removeAt(index).key);
  }

  if (recentCategory != null) {
    addTag(recentCategory);
  }

  for (final signal in internetTopCategorySignals) {
    final matchIndex = pool.indexWhere(
      (entry) => matchesTopCategorySignal(entry.key, signal),
    );
    if (matchIndex < 0) continue;
    picks.add(pool.removeAt(matchIndex).key);
    if (picks.length >= limit) {
      return picks.take(limit).toList(growable: false);
    }
  }

  pool.sort((a, b) => b.value.compareTo(a.value));
  for (final entry in pool) {
    if (picks.length >= limit) break;
    picks.add(entry.key);
  }

  return picks.take(limit).toList(growable: false);
}

bool matchesTopCategorySignal(String rawCategory, String signal) {
  final tag = rawCategory.trim().toLowerCase();
  switch (signal) {
    case 'love':
      return tag.contains('love') || tag.contains('romance');
    case 'life':
      return tag == 'life' || tag.contains('life');
    case 'inspiration':
      return tag.contains('inspiration') || tag.contains('motiv');
    case 'friendship':
      return tag.contains('friend');
    case 'success':
      return tag.contains('success') ||
          tag.contains('discipline') ||
          tag.contains('leadership');
    case 'wisdom':
      return tag.contains('wisdom') ||
          tag.contains('philosophy') ||
          tag.contains('knowledge');
    case 'happiness':
      return tag.contains('happiness') ||
          tag.contains('happy') ||
          tag.contains('joy');
  }
  return false;
}

String? _pickMostFrequentCategory(Iterable<QuoteModel> quotes) {
  final counts = <String, int>{};
  for (final quote in quotes) {
    for (final category in quote.categories) {
      final normalized = category.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      counts.update(normalized, (value) => value + 1, ifAbsent: () => 1);
    }
  }
  if (counts.isEmpty) return null;

  final ranked = counts.entries.toList(growable: false)
    ..sort((a, b) {
      final countCompare = b.value.compareTo(a.value);
      if (countCompare != 0) return countCompare;
      return discoveryCategoryLabel(
        a.key,
      ).compareTo(discoveryCategoryLabel(b.key));
    });
  return ranked.first.key;
}
