import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/quote_model.dart';
import '../models/quote_viewer_filter.dart';
import '../repository/quote_repository.dart';
import '../services/quote_service.dart';
import 'supabase_provider.dart';

final quoteRepositoryProvider = Provider<QuoteRepository>((ref) {
  return QuoteRepository(client: ref.read(supabaseClientProvider));
});

final quoteServiceProvider = Provider<QuoteService>((ref) {
  return QuoteService();
});

final currentUserIdProvider = Provider<String?>((ref) {
  final client = ref.read(supabaseClientProvider);
  return client.auth.currentUser?.id;
});

final allQuotesProvider = FutureProvider<List<QuoteModel>>((ref) async {
  return ref.read(quoteRepositoryProvider).getAllQuotes();
});

final dailyQuoteProvider = FutureProvider<QuoteModel>((ref) async {
  final repo = ref.read(quoteRepositoryProvider);

  final remote = await repo.getDailyQuote(DateTime.now());
  if (remote != null) return remote;

  final allQuotes = await ref.watch(allQuotesProvider.future);
  final service = ref.read(quoteServiceProvider);
  return service.pickQuoteForDate(allQuotes, DateTime.now());
});

final categoryCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  return ref.read(quoteRepositoryProvider).getTagsWithCounts();
});

final moodTagsProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(quoteRepositoryProvider).getMoodTagsAvailable(moodAllowlist);
});

final moodCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final tagsWithCounts = await ref.watch(categoryCountsProvider.future);
  final moods = await ref.watch(moodTagsProvider.future);

  return {
    for (final mood in moods)
      if (tagsWithCounts.containsKey(mood)) mood: tagsWithCounts[mood]!,
  };
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
      return ref.read(quoteRepositoryProvider).getQuotesByTag(filter.tag);
    });
