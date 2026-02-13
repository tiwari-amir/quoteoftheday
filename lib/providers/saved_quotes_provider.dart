import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quote_providers.dart';
import 'storage_provider.dart';
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
  static const _localSavedQuotesKey = 'v1.saved_quote_ids';

  String? get _userId => _ref.read(supabaseClientProvider).auth.currentUser?.id;

  Set<String> _loadLocalIds() {
    final prefs = _ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_localSavedQuotesKey);
    if (raw == null || raw.isEmpty) return <String>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _persistLocal(Set<String> ids) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setString(
      _localSavedQuotesKey,
      jsonEncode(ids.toList(growable: false)),
    );
  }

  Future<void> _load() async {
    final local = _loadLocalIds();
    final userId = _userId;
    if (userId == null) {
      state = local;
      return;
    }

    final saved = await _ref
        .read(quoteRepositoryProvider)
        .getSavedQuoteIds(userId);
    final merged = {...saved, ...local};
    state = merged;

    if (local.difference(saved).isNotEmpty) {
      final repo = _ref.read(quoteRepositoryProvider);
      for (final quoteId in local.difference(saved)) {
        await repo.saveQuote(userId: userId, quoteId: quoteId);
      }
    }

    await _persistLocal(merged);
  }

  Future<void> refresh() => _load();

  Future<void> toggle(String quoteId) async {
    final next = {...state};

    if (next.contains(quoteId)) {
      next.remove(quoteId);
      state = next;
      await _persistLocal(next);

      final userId = _userId;
      if (userId != null) {
        await _ref
            .read(quoteRepositoryProvider)
            .unsaveQuote(userId: userId, quoteId: quoteId);
      }
      return;
    }

    next.add(quoteId);
    state = next;
    await _persistLocal(next);

    final userId = _userId;
    if (userId != null) {
      await _ref
          .read(quoteRepositoryProvider)
          .saveQuote(userId: userId, quoteId: quoteId);
    }
  }

  Future<void> remove(String quoteId) async {
    if (!state.contains(quoteId)) return;

    final next = {...state}..remove(quoteId);
    state = next;
    await _persistLocal(next);

    final userId = _userId;
    if (userId != null) {
      await _ref
          .read(quoteRepositoryProvider)
          .unsaveQuote(userId: userId, quoteId: quoteId);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final savedQuoteIdsProvider =
    StateNotifierProvider<SavedQuotesNotifier, Set<String>>(
      (ref) => SavedQuotesNotifier(ref),
    );
