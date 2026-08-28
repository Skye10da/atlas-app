/// User preferences for ongoing-novel update checking.
class UpdateCheckSettings {
  const UpdateCheckSettings({
    required this.enabled,
    required this.intervalHours,
    required this.notificationsEnabled,
  });

  const UpdateCheckSettings.defaults()
    : enabled = true,
      intervalHours = 24,
      notificationsEnabled = true;

  /// Master toggle for periodic chapter-list checks.
  final bool enabled;

  /// How often checks run. One of 6, 12 or 24 (hours).
  final int intervalHours;

  /// Whether finding new chapters raises an OS notification.
  final bool notificationsEnabled;

  UpdateCheckSettings copyWith({
    bool? enabled,
    int? intervalHours,
    bool? notificationsEnabled,
  }) {
    return UpdateCheckSettings(
      enabled: enabled ?? this.enabled,
      intervalHours: intervalHours ?? this.intervalHours,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
