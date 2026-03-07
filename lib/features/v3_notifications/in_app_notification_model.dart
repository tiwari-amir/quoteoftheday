class InAppNotificationModel {
  const InAppNotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.actionRoute,
    required this.createdAt,
    required this.metadata,
    required this.quotesAdded,
    required this.totalQuotes,
    required this.prunedQuotes,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final String actionRoute;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;
  final int quotesAdded;
  final int totalQuotes;
  final int prunedQuotes;

  factory InAppNotificationModel.fromJson(Map<String, dynamic> json) {
    final metadata = _asMap(json['metadata']);
    return InAppNotificationModel(
      id: _toInt(json['id']),
      type: (json['notification_type'] ?? '').toString().trim(),
      title: (json['title'] ?? '').toString().trim(),
      body: (json['body'] ?? '').toString().trim(),
      actionRoute:
          (json['action_route'] ?? '/updates').toString().trim().isEmpty
          ? '/updates'
          : (json['action_route'] ?? '/updates').toString().trim(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString().trim()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      metadata: metadata,
      quotesAdded: _toInt(metadata['quotes_added']),
      totalQuotes: _toInt(metadata['total_quotes']),
      prunedQuotes: _toInt(metadata['pruned_quotes']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return const <String, dynamic>{};
  }
}
