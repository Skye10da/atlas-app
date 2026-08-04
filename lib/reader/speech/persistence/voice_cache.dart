import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/reader/speech/speech_models.dart';

/// Disk + in-memory cache of the platform's available voices (ASA §9).
///
/// The pipeline is: app start → `driver.listVoices()` → cache in memory and
/// persist to disk → the narration settings UI reads from here instead of
/// hitting the TTS engine on every open.
class VoiceCache {
  static const _key = 'speech_voice_cache';

  SharedPreferences? _prefs;
  List<VoiceDescriptor>? _memory;

  /// Voices currently cached in memory, if any have been loaded/persisted.
  List<VoiceDescriptor>? get cached => _memory;

  Future<SharedPreferences> _ensurePrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Restores the disk cache into memory. Safe to call repeatedly.
  Future<void> init() async {
    final prefs = await _ensurePrefs();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      _memory = list
          .whereType<Map>()
          .map((m) => VoiceDescriptor.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      _memory = null;
    }
  }

  /// Replaces the in-memory and disk cache.
  Future<void> persist(List<VoiceDescriptor> voices) async {
    final prefs = await _ensurePrefs();
    _memory = voices;
    await prefs.setString(
      _key,
      jsonEncode(voices.map((v) => v.toJson()).toList()),
    );
  }

  /// Clears both caches (e.g. after a language change).
  Future<void> clear() async {
    final prefs = await _ensurePrefs();
    _memory = null;
    await prefs.remove(_key);
  }
}
