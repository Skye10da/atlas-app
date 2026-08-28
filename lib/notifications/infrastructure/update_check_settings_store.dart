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

  static Future<UpdateCheckSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final interval = prefs.getInt(_keyIntervalHours) ?? 24;
    return UpdateCheckSettings(
      enabled: prefs.getBool(_keyEnabled) ?? true,
      intervalHours: switch (interval) {
        6 => 6,
        12 => 12,
        _ => 24,
      },
      notificationsEnabled: prefs.getBool(_keyNotifications) ?? true,
    );
  }

  Future<void> save(UpdateCheckSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, settings.enabled);
    await prefs.setInt(_keyIntervalHours, settings.intervalHours);
    await prefs.setBool(_keyNotifications, settings.notificationsEnabled);
  }
}
