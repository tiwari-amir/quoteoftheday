import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quote_providers.dart';
import 'storage_provider.dart';
import 'supabase_provider.dart';

class LikedQuotesNotifier extends StateNotifier<Set<String>> {
  LikedQuotesNotifier(this._ref) : super(<String>{}) {
    _authSub = _ref
        .read(supabaseClientProvider)
        .auth
        .onAuthStateChange
        .listen((_) => _load());
    _load();
  }

  final Ref _ref;
  StreamSubscription<dynamic>? _authSub;
  static const _localLikedQuotesKey = 'v1.liked_quote_ids';

  String? get _userId => _ref.read(supabaseClientProvider).auth.currentUser?.id;

  Set<String> _loadLocalIds() {
    final prefs = _ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_localLikedQuotesKey);
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
      _localLikedQuotesKey,
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

    final liked = await _ref
        .read(quoteRepositoryProvider)
        .getLikedQuoteIds(userId);
    final merged = {...liked, ...local};
    state = merged;

    if (local.difference(liked).isNotEmpty) {
      final repo = _ref.read(quoteRepositoryProvider);
      for (final quoteId in local.difference(liked)) {
        await repo.likeQuote(userId: userId, quoteId: quoteId);
      }
    }

    await _persistLocal(merged);
  }

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
            .unlikeQuote(userId: userId, quoteId: quoteId);
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
          .likeQuote(userId: userId, quoteId: quoteId);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final likedQuoteIdsProvider =
    StateNotifierProvider<LikedQuotesNotifier, Set<String>>(
      (ref) => LikedQuotesNotifier(ref),
    );
