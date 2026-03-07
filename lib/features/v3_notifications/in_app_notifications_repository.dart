import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'in_app_notification_model.dart';

class InAppNotificationsRepository {
  InAppNotificationsRepository({required SupabaseClient client})
    : _client = client;

  static const int retentionLimit = 10;
  final SupabaseClient _client;

  Future<List<InAppNotificationModel>> fetchRecent({int limit = retentionLimit}) async {
    final safeLimit = limit.clamp(1, retentionLimit);
    try {
      final rows = await _client
          .from('app_notifications')
          .select(
            'id,notification_type,title,body,action_route,metadata,created_at',
          )
          .order('created_at', ascending: false)
          .limit(safeLimit);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(InAppNotificationModel.fromJson)
          .where((item) => item.id > 0 && item.title.isNotEmpty)
          .toList(growable: false);
    } catch (error, stackTrace) {
      debugPrint('Supabase fetch app notifications failed: $error');
      debugPrint('$stackTrace');
      return const <InAppNotificationModel>[];
    }
  }

  Future<InAppNotificationModel?> fetchLatest() async {
    final items = await fetchRecent(limit: 1);
    return items.isEmpty ? null : items.first;
  }

  RealtimeChannel subscribeToInserts(
    void Function(InAppNotificationModel notification) onInsert,
  ) {
    return _client
        .channel('public:app_notifications:feed')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'app_notifications',
          callback: (payload) {
            try {
              final row = Map<String, dynamic>.from(payload.newRecord);
              final notification = InAppNotificationModel.fromJson(row);
              if (notification.id <= 0 || notification.title.isEmpty) return;
              onInsert(notification);
            } catch (error, stackTrace) {
              debugPrint('Realtime app notification parse failed: $error');
              debugPrint('$stackTrace');
            }
          },
        )
        .subscribe();
  }

  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }
}
