import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/updater/domain/entities/changelog_entry.dart';

/// SharedPreferences-backed cache of release-note history for the What's-new
/// screen. Entries are captured when the app first runs on a new build (and
/// refreshed from GitHub whenever the user opens the screen), so the changelog
/// stays readable offline and across installs. Mirrors [UpdatePrefsStore]'s
/// JSON-string persistence style.
class ChangelogStore {
  ChangelogStore(this._prefs);

  final SharedPreferences _prefs;

  static const _keyEntries = 'app_changelog_entries';
  static const _keyLastSeenBuild = 'app_changelog_last_seen_build';

  /// Cached entries (arbitrary order — callers sort by versionCode).
  List<ChangelogEntry> load() {
    final raw = _prefs.getString(_keyEntries);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ChangelogEntry.fromJson)
          .whereType<ChangelogEntry>()
          .toList(growable: false);
    } catch (_) {
      return const []; // corrupt cache beats crash
    }
  }

  Future<void> save(List<ChangelogEntry> entries) =>
      _prefs.setString(
        _keyEntries,
        json.encode([for (final entry in entries) entry.toJson()]),
      );

  /// Highest versionCode this device has celebrated/acknowledged. Null only
  /// on the very first run after install — silences the post-update banner
  /// for fresh installs (there was no update to celebrate).
  int? get lastSeenVersionCode => _prefs.getInt(_keyLastSeenBuild);

  set lastSeenVersionCode(int? value) {
    if (value == null) {
      _prefs.remove(_keyLastSeenBuild);
    } else {
      _prefs.setInt(_keyLastSeenBuild, value);
    }
  }
}
