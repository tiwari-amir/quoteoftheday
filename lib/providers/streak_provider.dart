import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import 'storage_provider.dart';

class StreakNotifier extends StateNotifier<int> {
  StreakNotifier(this._ref) : super(0) {
    _refresh();
  }

  final Ref _ref;

  Future<void> _refresh() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final savedCount = prefs.getInt(prefStreakCount) ?? 0;
    final rawLast = prefs.getString(prefStreakLastDate);
    final last = rawLast == null ? null : DateTime.tryParse(rawLast);
    final lastDay = last == null
        ? null
        : DateTime(last.year, last.month, last.day);

    int next;
    if (lastDay == null) {
      next = 1;
    } else {
      final diffDays = today.difference(lastDay).inDays;
      if (diffDays <= 0) {
        next = savedCount <= 0 ? 1 : savedCount;
      } else if (diffDays == 1) {
        next = (savedCount <= 0 ? 1 : savedCount) + 1;
      } else {
        next = 1;
      }
    }

    await prefs.setInt(prefStreakCount, next);
    await prefs.setString(prefStreakLastDate, today.toIso8601String());
    state = next;
  }
}

final streakProvider = StateNotifierProvider<StreakNotifier, int>((ref) {
  return StreakNotifier(ref);
});
