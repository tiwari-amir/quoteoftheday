import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../providers/storage_provider.dart';

const _kViewedHistory = 'v3.viewed_history';
const _kPersonalization = 'v3.personalization';
const _kStreak = 'v3.streak';

final settingsActionsProvider = Provider<SettingsActions>((ref) {
  return SettingsActions(ref);
});

class SettingsActions {
  SettingsActions(this._ref);

  final Ref _ref;

  Future<void> resetPersonalization() async {
    await _ref.read(sharedPreferencesProvider).remove(_kPersonalization);
  }

  Future<void> resetStreak() async {
    await _ref.read(sharedPreferencesProvider).remove(_kStreak);
  }

  Future<void> clearRecentHistory() async {
    await _ref.read(sharedPreferencesProvider).remove(_kViewedHistory);
  }

  Future<void> exportSavedQuotes({required bool isWeb}) async {
    final ids = _ref.read(savedQuoteIdsProvider);
    final quotes = await _ref.read(allQuotesProvider.future);
    final saved = quotes.where((q) => ids.contains(q.id)).toList(growable: false);

    final text = saved.map((q) => '${q.quote} - ${q.author}').join('\n\n');

    if (isWeb) {
      await Clipboard.setData(ClipboardData(text: text));
      return;
    }

    await Share.share(text, subject: 'Saved quotes export');
  }
}
