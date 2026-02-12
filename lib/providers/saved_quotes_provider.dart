import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quote_providers.dart';
import 'supabase_provider.dart';

class SavedQuotesNotifier extends StateNotifier<Set<String>> {
  SavedQuotesNotifier(this._ref) : super(<String>{}) {
    _authSub = _ref
        .read(supabaseClientProvider)
        .auth
        .onAuthStateChange
        .listen((_) => _load());
    _load();
  }

  final Ref _ref;
  StreamSubscription<dynamic>? _authSub;

  String? get _userId => _ref.read(supabaseClientProvider).auth.currentUser?.id;

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null) {
      state = <String>{};
      return;
    }

    final saved = await _ref.read(quoteRepositoryProvider).getSavedQuoteIds(userId);
    state = saved;
  }

  Future<void> refresh() => _load();

  Future<void> toggle(String quoteId) async {
    final userId = _userId;
    if (userId == null) return;

    final next = {...state};
    final repo = _ref.read(quoteRepositoryProvider);

    if (next.contains(quoteId)) {
      await repo.unsaveQuote(userId: userId, quoteId: quoteId);
      next.remove(quoteId);
      state = next;
      return;
    }

    await repo.saveQuote(userId: userId, quoteId: quoteId);
    next.add(quoteId);
    state = next;
  }

  Future<void> remove(String quoteId) async {
    final userId = _userId;
    if (userId == null || !state.contains(quoteId)) return;

    await _ref.read(quoteRepositoryProvider).unsaveQuote(userId: userId, quoteId: quoteId);

    final next = {...state}..remove(quoteId);
    state = next;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final savedQuoteIdsProvider = StateNotifierProvider<SavedQuotesNotifier, Set<String>>(
  (ref) => SavedQuotesNotifier(ref),
);
