import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/updater/domain/entities/app_release.dart';

/// SharedPreferences-backed persistence for app self-update preferences and
/// state. Mirrors UpdateCheckSettingsStore (notifications feature) but for the
/// app-binary updater — deliberately kept separate so the two features can
/// evolve their key sets independently.
class UpdatePrefsStore {
  UpdatePrefsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _keyAutoCheck = 'app_update_auto_check';
  static const _keyLastCheckedAt = 'app_update_last_checked_at';
  static const _keyChannelIndex = 'app_update_channel';
  static const _keySkippedTag = 'app_update_skipped_tag';
  static const _keyDownloadedTag = 'app_update_downloaded_tag';
  static const _keyDownloadedPath = 'app_update_downloaded_path';

  /// Whether a silent startup check should run (user-facing toggle).
  bool get autoCheck => _prefs.getBool(_keyAutoCheck) ?? true;
  set autoCheck(bool value) => _prefs.setBool(_keyAutoCheck, value);

  /// Timestamp of the last completed check; null before the first one.
  DateTime? get lastCheckedAt {
    final iso = _prefs.getString(_keyLastCheckedAt);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  set lastCheckedAt(DateTime? value) {
    if (value == null) {
      _prefs.remove(_keyLastCheckedAt);
    } else {
      _prefs.setString(_keyLastCheckedAt, value.toIso8601String());
    }
  }

  /// Which channel the updater polls. Persisted through the enum index so new
  /// values can be appended without corrupting old installs.
  UpdateChannel get channel =>
      UpdateChannel.values.asNameMap()[_prefs.getString(_keyChannelIndex)] ??
      UpdateChannel.stable;
  set channel(UpdateChannel value) =>
      _prefs.setString(_keyChannelIndex, value.name);

  /// Release tag the user chose "skip this version" for; cleared manually or
  /// superseded whenever a newer versionCode lands.
  String? get skippedTag => _prefs.getString(_keySkippedTag);
  set skippedTag(String? value) => value == null
      ? _prefs.remove(_keySkippedTag)
      : _prefs.setString(_keySkippedTag, value);

  /// Tag of the last fully downloaded (but not yet installed) update, so a
  /// completed install survives process restarts.
  String? get downloadedTag => _prefs.getString(_keyDownloadedTag);
  set downloadedTag(String? value) => value == null
      ? _prefs.remove(_keyDownloadedTag)
      : _prefs.setString(_keyDownloadedTag, value);

  /// Absolute path of the downloaded install file matching [downloadedTag].
  String? get downloadedPath => _prefs.getString(_keyDownloadedPath);
  set downloadedPath(String? value) => value == null
      ? _prefs.remove(_keyDownloadedPath)
      : _prefs.setString(_keyDownloadedPath, value);
}
