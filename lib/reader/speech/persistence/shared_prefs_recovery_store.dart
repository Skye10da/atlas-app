import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/reader/speech/persistence/recovery_store.dart';
import 'package:atlas_app/reader/speech/speech_session.dart';

/// [RecoveryStore] backed by shared_preferences. Checkpoints are stored as
/// a JSON blob per book, keyed `speech_checkpoint_<bookId>` - consistent
/// with how the rest of Atlas persists lightweight app state (see the
/// shared_prefs settings repository).
class SharedPrefsRecoveryStore implements RecoveryStore {
  static const _keyPrefix = 'speech_checkpoint_';

  @override
  Future<void> save(SpeechCheckpoint checkpoint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_keyPrefix${checkpoint.bookId}',
      jsonEncode(checkpoint.toJson()),
    );
  }

  @override
  Future<SpeechCheckpoint?> load(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$bookId');
    if (raw == null) return null;
    try {
      return SpeechCheckpoint.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clear(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$bookId');
  }
}
