import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import 'storage_provider.dart';

class SavedQuotesNotifier extends StateNotifier<Set<int>> {
  SavedQuotesNotifier(this._ref) : super(_loadInitial(_ref));

  final Ref _ref;

  static Set<int> _loadInitial(Ref ref) {
    final raw = ref
        .read(sharedPreferencesProvider)
        .getStringList(prefSavedQuoteIds);
    if (raw == null || raw.isEmpty) return <int>{};

    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> toggle(int quoteId) async {
    final next = {...state};
    if (!next.add(quoteId)) {
      next.remove(quoteId);
    }
    state = next;
    await _persist();
  }

  Future<void> remove(int quoteId) async {
    if (!state.contains(quoteId)) return;
    final next = {...state}..remove(quoteId);
    state = next;
    await _persist();
  }

  Future<void> _persist() {
    final sorted = state.toList()..sort();
    return _ref
        .read(sharedPreferencesProvider)
        .setStringList(prefSavedQuoteIds, sorted.map((id) => '$id').toList());
  }
}

final savedQuoteIdsProvider =
    StateNotifierProvider<SavedQuotesNotifier, Set<int>>(
      (ref) => SavedQuotesNotifier(ref),
    );
