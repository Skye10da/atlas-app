enum NotificationGroupingMode {
  bundled,
  individual,
  both;

  String get label => switch (this) {
    NotificationGroupingMode.bundled => 'Grouped summary only',
    NotificationGroupingMode.individual => 'Separate cards only',
    NotificationGroupingMode.both => 'Grouped with individual cards',
  };
}

/// User preferences for ongoing-novel update checking and notifications.
class UpdateCheckSettings {
  const UpdateCheckSettings({
    required this.enabled,
    required this.intervalHours,
    required this.notificationsEnabled,
    this.wifiOnly = false,
    this.quietHoursEnabled = false,
    this.quietHoursStart = 22,
    this.quietHoursEnd = 7,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.autoDownloadChapters = false,
    this.groupingMode = NotificationGroupingMode.both,
  });

  const UpdateCheckSettings.defaults()
    : enabled = true,
      intervalHours = 24,
      notificationsEnabled = true,
      wifiOnly = false,
      quietHoursEnabled = false,
      quietHoursStart = 22,
      quietHoursEnd = 7,
      soundEnabled = true,
      vibrationEnabled = true,
      autoDownloadChapters = false,
      groupingMode = NotificationGroupingMode.both;

  /// Master toggle for periodic chapter-list checks.
  final bool enabled;

  /// How often checks run. One of 1, 3, 6, 12, or 24 (hours).
  final int intervalHours;

  /// Whether finding new chapters raises an OS notification.
  final bool notificationsEnabled;

  /// Only run background update checks on Wi-Fi (unmetered) networks.
  final bool wifiOnly;

  /// Whether to suppress OS notifications during quiet hours.
  final bool quietHoursEnabled;

  /// Start hour of quiet hours (0-23).
  final int quietHoursStart;

  /// End hour of quiet hours (0-23).
  final int quietHoursEnd;

  /// Whether notifications play sound.
  final bool soundEnabled;

  /// Whether notifications vibrate.
  final bool vibrationEnabled;

  /// Whether newly found chapters should be automatically fetched into offline cache.
  final bool autoDownloadChapters;

  /// How notifications are displayed in the OS drawer.
  final NotificationGroupingMode groupingMode;

  UpdateCheckSettings copyWith({
    bool? enabled,
    int? intervalHours,
    bool? notificationsEnabled,
    bool? wifiOnly,
    bool? quietHoursEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? autoDownloadChapters,
    NotificationGroupingMode? groupingMode,
  }) {
    return UpdateCheckSettings(
      enabled: enabled ?? this.enabled,
      intervalHours: intervalHours ?? this.intervalHours,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      autoDownloadChapters: autoDownloadChapters ?? this.autoDownloadChapters,
      groupingMode: groupingMode ?? this.groupingMode,
    );
  }
}
