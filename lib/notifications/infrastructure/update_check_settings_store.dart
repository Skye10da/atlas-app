import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/notifications/domain/entities/update_check_settings.dart';

/// SharedPreferences-backed store for [UpdateCheckSettings].
///
/// Static [load] deliberately avoids any Riverpod dependency so the
/// workmanager background isolate can read preferences without booting the
/// app's provider graph.
class UpdateCheckSettingsStore {
  static const _keyEnabled = 'updates_enabled';
  static const _keyIntervalHours = 'updates_interval_hours';
  static const _keyNotifications = 'updates_notifications';
  static const _keyWifiOnly = 'updates_wifi_only';
  static const _keyQuietHoursEnabled = 'updates_quiet_hours_enabled';
  static const _keyQuietHoursStart = 'updates_quiet_hours_start';
  static const _keyQuietHoursEnd = 'updates_quiet_hours_end';
  static const _keySoundEnabled = 'updates_sound_enabled';
  static const _keyVibrationEnabled = 'updates_vibration_enabled';
  static const _keyAutoDownload = 'updates_auto_download_chapters';
  static const _keyGroupingMode = 'updates_notification_grouping_mode';

  static Future<UpdateCheckSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final interval = prefs.getInt(_keyIntervalHours) ?? 24;
    final groupingIndex =
        prefs.getInt(_keyGroupingMode) ?? NotificationGroupingMode.both.index;
    final groupingMode =
        groupingIndex >= 0 &&
            groupingIndex < NotificationGroupingMode.values.length
        ? NotificationGroupingMode.values[groupingIndex]
        : NotificationGroupingMode.both;

    return UpdateCheckSettings(
      enabled: prefs.getBool(_keyEnabled) ?? true,
      intervalHours: switch (interval) {
        1 => 1,
        3 => 3,
        6 => 6,
        12 => 12,
        _ => 24,
      },
      notificationsEnabled: prefs.getBool(_keyNotifications) ?? true,
      wifiOnly: prefs.getBool(_keyWifiOnly) ?? false,
      quietHoursEnabled: prefs.getBool(_keyQuietHoursEnabled) ?? false,
      quietHoursStart: prefs.getInt(_keyQuietHoursStart) ?? 22,
      quietHoursEnd: prefs.getInt(_keyQuietHoursEnd) ?? 7,
      soundEnabled: prefs.getBool(_keySoundEnabled) ?? true,
      vibrationEnabled: prefs.getBool(_keyVibrationEnabled) ?? true,
      autoDownloadChapters: prefs.getBool(_keyAutoDownload) ?? false,
      groupingMode: groupingMode,
    );
  }

  Future<void> save(UpdateCheckSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, settings.enabled);
    await prefs.setInt(_keyIntervalHours, settings.intervalHours);
    await prefs.setBool(_keyNotifications, settings.notificationsEnabled);
    await prefs.setBool(_keyWifiOnly, settings.wifiOnly);
    await prefs.setBool(_keyQuietHoursEnabled, settings.quietHoursEnabled);
    await prefs.setInt(_keyQuietHoursStart, settings.quietHoursStart);
    await prefs.setInt(_keyQuietHoursEnd, settings.quietHoursEnd);
    await prefs.setBool(_keySoundEnabled, settings.soundEnabled);
    await prefs.setBool(_keyVibrationEnabled, settings.vibrationEnabled);
    await prefs.setBool(_keyAutoDownload, settings.autoDownloadChapters);
    await prefs.setInt(_keyGroupingMode, settings.groupingMode.index);
  }

  /// Determines whether [time] falls inside the configured quiet hours window.
  /// Handles both standard windows (e.g., 14:00 to 18:00) and windows crossing
  /// midnight (e.g., 22:00 to 07:00).
  static bool isWithinQuietHours(DateTime time, UpdateCheckSettings settings) {
    if (!settings.quietHoursEnabled) return false;
    final hour = time.hour;
    final start = settings.quietHoursStart;
    final end = settings.quietHoursEnd;

    if (start == end) return true; // 24-hour quiet period
    if (start < end) {
      return hour >= start && hour < end;
    } else {
      // Crosses midnight, e.g., 22 to 7
      return hour >= start || hour < end;
    }
  }
}
