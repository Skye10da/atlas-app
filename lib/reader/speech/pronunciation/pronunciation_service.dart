import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Service: stateless wrapper over `SharedPreferences` for pronunciation rules.
/// Returns raw JSON / API models.
class PronunciationService {
  const PronunciationService();

  static const _key = 'pronunciation_rules_v1';

  Future<List<Map<String, dynamic>>?> fetchRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<void> persistRaw(List<Map<String, dynamic>> raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(raw));
  }

  Future<void> clearRaw() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
