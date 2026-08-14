import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/wtr/domain/entities/wtr_session_record.dart';
import 'package:atlas_app/wtr/domain/repository_interfaces/wtr_session_repository.dart';

/// `SharedPreferences`-backed [WtrSessionRepository].
///
/// Stores only the *metadata* of the connection (the boolean fact that a WTR
/// session exists and when it was captured). The session itself lives in the
/// platform WebView cookie store / browser-session repository. **No cookies,
/// tokens, or passwords are written here.**
class SharedPrefsWtrSessionRepository implements WtrSessionRepository {
  const SharedPrefsWtrSessionRepository();

  static const _key = 'wtr_lab_session_record';

  @override
  Future<WtrSessionRecord?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return WtrSessionRecord.fromJson(Map<String, Object?>.from(decoded));
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(WtrSessionRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(record.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}