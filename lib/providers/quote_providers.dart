import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/quote_model.dart';
import '../repository/quote_repository.dart';
import '../services/quote_service.dart';
import 'storage_provider.dart';

final quoteRepositoryProvider = Provider<QuoteRepository>((ref) {
  return QuoteRepository();
});

final quoteServiceProvider = Provider<QuoteService>((ref) {
  return QuoteService();
});

final allQuotesProvider = FutureProvider<List<QuoteModel>>((ref) async {
  return ref.read(quoteRepositoryProvider).loadQuotes();
});

final dailyQuoteProvider = FutureProvider<QuoteModel>((ref) async {
  final quotes = await ref.watch(allQuotesProvider.future);
  final service = ref.read(quoteServiceProvider);
  final prefs = ref.read(sharedPreferencesProvider);

  return service.pickDailyQuote(quotes, prefs, DateTime.now());
});

final categoryCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final quotes = await ref.watch(allQuotesProvider.future);
  return ref.read(quoteServiceProvider).buildTagCounts(quotes);
});

final moodCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final quotes = await ref.watch(allQuotesProvider.future);
  return ref
      .read(quoteServiceProvider)
      .buildTagCounts(quotes, includeOnly: moodTags);
});

final quotesByTagProvider = FutureProvider.family<List<QuoteModel>, String>((
  ref,
  tag,
) async {
  final quotes = await ref.watch(allQuotesProvider.future);
  return ref.read(quoteServiceProvider).filterByTag(quotes, tag);
});
