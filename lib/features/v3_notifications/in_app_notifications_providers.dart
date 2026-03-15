import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/quote_providers.dart';
import '../../providers/storage_provider.dart';
import '../../providers/supabase_provider.dart';
import 'in_app_notification_model.dart';
import 'in_app_notifications_repository.dart';
import 'notification_providers.dart';

const _kInAppNotificationsMuted = 'in_app_notifications.muted';
const _kInAppNotificationsLastSeenId = 'in_app_notifications.last_seen_id';
const _kInAppNotificationsLastAlertedId =
    'in_app_notifications.last_alerted_id';
const _kMaxStartupAlertAge = Duration(hours: 36);
const _kNotificationsPollInterval = Duration(seconds: 6);

class InAppNotificationPreferences {
  const InAppNotificationPreferences({
    required this.muted,
    required this.lastSeenId,
    required this.lastAlertedId,
  });

  final bool muted;
  final int lastSeenId;
  final int lastAlertedId;

  static const defaults = InAppNotificationPreferences(
    muted: false,
    lastSeenId: 0,
    lastAlertedId: 0,
  );

  InAppNotificationPreferences copyWith({
    bool? muted,
    int? lastSeenId,
    int? lastAlertedId,
  }) {
    return InAppNotificationPreferences(
      muted: muted ?? this.muted,
      lastSeenId: lastSeenId ?? this.lastSeenId,
      lastAlertedId: lastAlertedId ?? this.lastAlertedId,
    );
  }
}

class InAppNotificationPreferencesNotifier
    extends StateNotifier<InAppNotificationPreferences> {
  InAppNotificationPreferencesNotifier(this._ref)
    : super(InAppNotificationPreferences.defaults) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    state = InAppNotificationPreferences(
      muted: prefs.getBool(_kInAppNotificationsMuted) ?? false,
      lastSeenId: prefs.getInt(_kInAppNotificationsLastSeenId) ?? 0,
      lastAlertedId: prefs.getInt(_kInAppNotificationsLastAlertedId) ?? 0,
    );
  }

  Future<void> setMuted(bool value) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    state = state.copyWith(muted: value);
    await prefs.setBool(_kInAppNotificationsMuted, value);
  }

  Future<void> markSeenUpTo(int notificationId) async {
    final nextId = notificationId <= state.lastSeenId
        ? state.lastSeenId
        : notificationId;
    if (nextId == state.lastSeenId) return;
    final prefs = _ref.read(sharedPreferencesProvider);
    state = state.copyWith(lastSeenId: nextId);
    await prefs.setInt(_kInAppNotificationsLastSeenId, nextId);
  }

  Future<void> markAlertedUpTo(int notificationId) async {
    final nextId = notificationId <= state.lastAlertedId
        ? state.lastAlertedId
        : notificationId;
    if (nextId == state.lastAlertedId) return;
    final prefs = _ref.read(sharedPreferencesProvider);
    state = state.copyWith(lastAlertedId: nextId);
    await prefs.setInt(_kInAppNotificationsLastAlertedId, nextId);
  }
}

final inAppNotificationsRepositoryProvider =
    Provider<InAppNotificationsRepository>((ref) {
      return InAppNotificationsRepository(
        client: ref.read(supabaseClientProvider),
      );
    });

final inAppNotificationPreferencesProvider =
    StateNotifierProvider<
      InAppNotificationPreferencesNotifier,
      InAppNotificationPreferences
    >((ref) => InAppNotificationPreferencesNotifier(ref));

final inAppNotificationsProvider = FutureProvider<List<InAppNotificationModel>>(
  (ref) async {
    return ref.read(inAppNotificationsRepositoryProvider).fetchRecent();
  },
);

final latestInAppNotificationProvider = Provider<InAppNotificationModel?>((
  ref,
) {
  return ref
      .watch(inAppNotificationsProvider)
      .maybeWhen(
        data: (items) => items.isEmpty ? null : items.first,
        orElse: () => null,
      );
});

final hasUnreadInAppNotificationsProvider = Provider<bool>((ref) {
  final prefs = ref.watch(inAppNotificationPreferencesProvider);
  final latest = ref.watch(latestInAppNotificationProvider);
  return latest != null && latest.id > prefs.lastSeenId;
});

final inAppNotificationsBootstrapProvider =
    Provider<InAppNotificationsRealtimeBridge>((ref) {
      final bridge = InAppNotificationsRealtimeBridge(ref);
      unawaited(bridge.start());
      ref.onDispose(() {
        unawaited(bridge.dispose());
      });
      return bridge;
    });

class InAppNotificationsRealtimeBridge {
  InAppNotificationsRealtimeBridge(this._ref);

  final Ref _ref;
  RealtimeChannel? _channel;
  Timer? _pollTimer;
  bool _started = false;
  int _latestObservedId = 0;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    await syncNow();

    final repo = _ref.read(inAppNotificationsRepositoryProvider);
    _channel = repo.subscribeToInserts((notification) {
      unawaited(_consumeNotification(notification));
    });
    _pollTimer = Timer.periodic(_kNotificationsPollInterval, (_) {
      unawaited(syncNow());
    });
  }

  Future<void> syncNow() async {
    final latest = await _ref
        .read(inAppNotificationsRepositoryProvider)
        .fetchLatest();
    if (latest == null) return;
    await _consumeNotification(latest);
  }

  Future<void> _consumeNotification(InAppNotificationModel notification) async {
    if (notification.id <= _latestObservedId) return;
    _latestObservedId = notification.id;
    _ref.invalidate(inAppNotificationsProvider);
    await _refreshQuotesForNotification(notification);
    await _handleIncoming(notification);
  }

  Future<void> _refreshQuotesForNotification(
    InAppNotificationModel notification,
  ) async {
    if (notification.quotesAdded <= 0 && notification.prunedQuotes <= 0) {
      return;
    }

    try {
      await _ref.read(quoteRepositoryProvider).refreshNow();
      _ref.invalidate(allQuotesProvider);
      _ref.invalidate(allQuotesWithMediaProvider);
      _ref.invalidate(categoryCountsProvider);
      _ref.invalidate(moodCountsProvider);
      _ref.invalidate(topLikedQuotesProvider);
      _ref.invalidate(dailyQuoteProvider);
    } catch (_) {
      // Notification delivery should continue even if the quote cache refresh fails.
    }
  }

  Future<void> _handleIncoming(InAppNotificationModel notification) async {
    final prefs = _ref.read(inAppNotificationPreferencesProvider);
    if (notification.id <= prefs.lastAlertedId) return;

    final age = DateTime.now().difference(notification.createdAt.toLocal());
    if (age > _kMaxStartupAlertAge) {
      await _ref
          .read(inAppNotificationPreferencesProvider.notifier)
          .markAlertedUpTo(notification.id);
      return;
    }

    if (!prefs.muted) {
      await _ref
          .read(notificationsServiceProvider)
          .showNow(
            id: 100000 + notification.id,
            title: notification.title,
            body: notification.body,
            payload: notification.actionRoute,
            useUpdatesChannel: true,
          );
    }

    await _ref
        .read(inAppNotificationPreferencesProvider.notifier)
        .markAlertedUpTo(notification.id);
  }

  Future<void> dispose() async {
    _pollTimer?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel == null) return;
    await _ref.read(inAppNotificationsRepositoryProvider).unsubscribe(channel);
  }
}
