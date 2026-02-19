import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/quote_model.dart';
import '../models/quote_viewer_filter.dart';
import '../providers/storage_provider.dart';
import '../repository/quote_repository.dart';
import '../services/author_wiki_service.dart';
import '../services/internet_best_quote_service.dart';
import '../services/quote_service.dart';
import 'supabase_provider.dart';

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

final currentUserIdProvider = Provider<String?>((ref) {
  final client = ref.read(supabaseClientProvider);
  return client.auth.currentUser?.id;
});

final allQuotesProvider = FutureProvider<List<QuoteModel>>((ref) async {
  return ref.read(quoteRepositoryProvider).getAllQuotes();
});

final dailyQuoteProvider = FutureProvider<QuoteModel>((ref) async {
  final quotes = await ref.watch(allQuotesProvider.future);
  final prefs = ref.read(sharedPreferencesProvider);
  final quoteService = ref.read(quoteServiceProvider);
  return quoteService.pickDailyQuote(quotes, prefs, DateTime.now());
});

final categoryCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  return ref.read(quoteRepositoryProvider).getTagsWithCounts();
});

final moodTagsProvider = FutureProvider<List<String>>((ref) async {
  final allQuotes = await ref.watch(allQuotesProvider.future);
  return moodAllowlist
      .where((mood) => _quotesForMood(allQuotes, mood).isNotEmpty)
      .toList(growable: false);
});

final moodCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final allQuotes = await ref.watch(allQuotesProvider.future);
  final counts = <String, int>{};
  for (final mood in moodAllowlist) {
    final matched = _quotesForMood(allQuotes, mood);
    if (matched.isNotEmpty) {
      counts[mood] = matched.length;
    }
  }
  return counts;
});

final quotesByFilterProvider =
    FutureProvider.family<List<QuoteModel>, QuoteViewerFilter>((
      ref,
      filter,
    ) async {
      final tag = filter.tag.trim().toLowerCase();
      if (tag.isEmpty || tag == 'all') {
        return ref.read(quoteRepositoryProvider).getAllQuotes();
      }
      if (filter.isMood) {
        final allQuotes = await ref
            .read(quoteRepositoryProvider)
            .getAllQuotes();
        return _quotesForMood(allQuotes, tag);
      }
      return ref.read(quoteRepositoryProvider).getQuotesByTag(filter.tag);
    });

final topLikedQuotesProvider = FutureProvider<List<QuoteModel>>((ref) async {
  final repo = ref.read(quoteRepositoryProvider);
  final allQuotes = await repo.getAllQuotes();
  final topIds = await repo.getMostLikedQuoteIds(limit: 12);
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

const Map<String, List<String>> _moodKeywords = {
  'motivated': [
    'motivated',
    'motivational',
    'motivation',
    'inspire',
    'inspirational',
    'discipline',
    'success',
    'goal',
    'courage',
    'perseverance',
  ],
  'calm': [
    'calm',
    'peace',
    'peaceful',
    'serenity',
    'stillness',
    'quiet',
    'mindful',
    'mindfulness',
    'zen',
    'breathe',
  ],
  'confident': ['confident', 'confidence', 'courage', 'bold', 'brave'],
  'grateful': ['grateful', 'gratitude', 'thankful', 'blessing'],
  'hopeful': ['hope', 'hopeful', 'faith', 'optimistic'],
  'romantic': ['romance', 'romantic', 'love', 'heart'],
  'stressed': ['stress', 'overwhelm', 'anxious', 'pressure', 'tired'],
  'anxious': ['anxious', 'anxiety', 'worry', 'fear', 'panic'],
  'happy': ['happy', 'happiness', 'joy', 'smile', 'delight'],
  'sad': ['sad', 'grief', 'sorrow', 'hurt', 'tears'],
  'angry': ['angry', 'anger', 'rage', 'furious', 'temper'],
  'lonely': ['lonely', 'alone', 'solitude', 'isolation'],
};

List<QuoteModel> _quotesForMood(List<QuoteModel> quotes, String mood) {
  final normalizedMood = mood.trim().toLowerCase();
  final keywords = _moodKeywords[normalizedMood] ?? [normalizedMood];
  final scored = <({QuoteModel quote, int score})>[];

  for (final quote in quotes) {
    final tags = quote.revisedTags.map((t) => t.toLowerCase()).toList();
    final text = '${quote.quote} ${quote.author}'.toLowerCase();

    var score = 0;
    for (final tag in tags) {
      if (tag == normalizedMood) {
        score += 8;
      }
      for (final keyword in keywords) {
        if (tag == keyword) {
          score += 6;
        } else if (tag.contains(keyword) || keyword.contains(tag)) {
          score += 3;
        }
      }
    }

    for (final keyword in keywords) {
      if (text.contains(keyword)) score += 1;
    }

    if (normalizedMood == 'motivated' &&
        tags.any((t) => t.contains('inspir'))) {
      score += 3;
    }
    if (normalizedMood == 'calm' &&
        tags.any((t) => t.contains('spiritual') || t.contains('mind'))) {
      score += 2;
    }

    if (score > 0) {
      scored.add((quote: quote, score: score));
    }
  }

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.quote.id.compareTo(b.quote.id);
  });

  return scored.map((e) => e.quote).toList(growable: false);
}
