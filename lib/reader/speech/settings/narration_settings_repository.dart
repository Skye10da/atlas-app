import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/reader/speech/settings/narration_settings.dart';

/// Persists [NarrationSettings] as a single JSON blob in shared_preferences,
/// mirroring how visual reading preferences are stored (see the
/// SharedPrefsSettingsRepository pattern).
class NarrationSettingsRepository {
  static const _key = 'narration_settings';

  Future<NarrationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const NarrationSettings();
    try {
      return NarrationSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const NarrationSettings();
    }
  }

  Future<void> save(NarrationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
