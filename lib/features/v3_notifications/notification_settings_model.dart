class NotificationSettingsModel {
  const NotificationSettingsModel({
    required this.dailyEnabled,
    required this.dailyHour,
    required this.dailyMinute,
    required this.extraEnabled,
    required this.extraHour,
    required this.extraMinute,
    required this.extraSource,
    required this.extraSelectedTags,
    required this.streakEnabled,
  });

  final bool dailyEnabled;
  final int dailyHour;
  final int dailyMinute;
  final bool extraEnabled;
  final int extraHour;
  final int extraMinute;
  final String extraSource;
  final List<String> extraSelectedTags;
  final bool streakEnabled;

  static const defaults = NotificationSettingsModel(
    dailyEnabled: true,
    dailyHour: 8,
    dailyMinute: 0,
    extraEnabled: false,
    extraHour: 20,
    extraMinute: 0,
    extraSource: 'saved',
    extraSelectedTags: <String>[],
    streakEnabled: true,
  );

  NotificationSettingsModel copyWith({
    bool? dailyEnabled,
    int? dailyHour,
    int? dailyMinute,
    bool? extraEnabled,
    int? extraHour,
    int? extraMinute,
    String? extraSource,
    List<String>? extraSelectedTags,
    bool? streakEnabled,
  }) {
    return NotificationSettingsModel(
      dailyEnabled: dailyEnabled ?? this.dailyEnabled,
      dailyHour: dailyHour ?? this.dailyHour,
      dailyMinute: dailyMinute ?? this.dailyMinute,
      extraEnabled: extraEnabled ?? this.extraEnabled,
      extraHour: extraHour ?? this.extraHour,
      extraMinute: extraMinute ?? this.extraMinute,
      extraSource: extraSource ?? this.extraSource,
      extraSelectedTags: extraSelectedTags ?? this.extraSelectedTags,
      streakEnabled: streakEnabled ?? this.streakEnabled,
    );
  }
}
