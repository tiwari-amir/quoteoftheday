import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import 'storage_provider.dart';

const _kStreakTodayProgressDate = 'streak.today_progress_date';
const _kStreakTodayProgressCount = 'streak.today_progress_count';
const _kStreakDailyReadRequirement = 3;

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

  // Helper used by notifications: true if user read at least N quotes today.
  bool hasMetTodayRequirement() {
    final prefs = _ref.read(sharedPreferencesProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rawDate = prefs.getString(_kStreakTodayProgressDate);
    final savedDate = rawDate == null ? null : DateTime.tryParse(rawDate);
    final savedDay = savedDate == null
        ? null
        : DateTime(savedDate.year, savedDate.month, savedDate.day);
    final count = prefs.getInt(_kStreakTodayProgressCount) ?? 0;

    if (savedDay == null || savedDay != today) {
      return false;
    }
    return count >= _kStreakDailyReadRequirement;
  }

  // Optional helper for future hooks when a quote is consumed.
  Future<void> recordQuoteRead() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rawDate = prefs.getString(_kStreakTodayProgressDate);
    final savedDate = rawDate == null ? null : DateTime.tryParse(rawDate);
    final savedDay = savedDate == null
        ? null
        : DateTime(savedDate.year, savedDate.month, savedDate.day);
    final currentCount = savedDay == today
        ? (prefs.getInt(_kStreakTodayProgressCount) ?? 0)
        : 0;
    final next = currentCount + 1;

    await prefs.setString(_kStreakTodayProgressDate, today.toIso8601String());
    await prefs.setInt(_kStreakTodayProgressCount, next);
  }
}

final streakProvider = StateNotifierProvider<StreakNotifier, int>((ref) {
  return StreakNotifier(ref);
});
