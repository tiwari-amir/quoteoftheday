import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/quote_model.dart';
import '../../providers/quote_providers.dart';
import 'search_service.dart';

final searchServiceProvider = FutureProvider<SearchService>((ref) async {
  final quotes = await ref.watch(allQuotesProvider.future);
  return SearchService(quotes);
});

class SearchQueryState {
  const SearchQueryState({
    required this.query,
    this.lengthFilter,
    this.tagFilter,
  });

  final String query;
  final String? lengthFilter;
  final String? tagFilter;

  SearchQueryState copyWith({String? query, String? lengthFilter, String? tagFilter}) {
    return SearchQueryState(
      query: query ?? this.query,
      lengthFilter: lengthFilter == '__keep__' ? this.lengthFilter : lengthFilter,
      tagFilter: tagFilter == '__keep__' ? this.tagFilter : tagFilter,
    );
  }
}

class SearchQueryNotifier extends StateNotifier<SearchQueryState> {
  SearchQueryNotifier() : super(const SearchQueryState(query: ''));

  Timer? _debounce;

  void setQueryDebounced(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      state = state.copyWith(query: query);
    });
  }

  void setLengthFilter(String? value) {
    state = state.copyWith(lengthFilter: value);
  }

  void setTagFilter(String? value) {
    state = state.copyWith(tagFilter: value);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchQueryProvider =
    StateNotifierProvider<SearchQueryNotifier, SearchQueryState>((ref) {
  return SearchQueryNotifier();
});

final searchResultsProvider =
    FutureProvider.family<List<QuoteModel>, Set<String>?>((ref, scopeIds) async {
  final service = await ref.watch(searchServiceProvider.future);
  final query = ref.watch(searchQueryProvider);

  return service.searchQuotes(
    query.query,
    scopeQuoteIds: scopeIds,
    lengthFilter: query.lengthFilter,
    tagFilter: query.tagFilter,
    limit: 100,
  );
});
