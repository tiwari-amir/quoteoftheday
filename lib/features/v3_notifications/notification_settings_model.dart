class NotificationSettingsModel {
  const NotificationSettingsModel({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.source,
    required this.categories,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final String source;
  final List<String> categories;

  static const defaults = NotificationSettingsModel(
    enabled: false,
    hour: 9,
    minute: 0,
    source: 'daily',
    categories: <String>[],
  );

  NotificationSettingsModel copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    String? source,
    List<String>? categories,
  }) {
    return NotificationSettingsModel(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      source: source ?? this.source,
      categories: categories ?? this.categories,
    );
  }
}
