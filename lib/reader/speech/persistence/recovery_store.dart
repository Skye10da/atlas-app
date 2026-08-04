import 'package:atlas_app/reader/speech/speech_session.dart';

/// Persists/restores SpeechCheckpoints. Deliberately an abstract interface
/// here rather than a concrete implementation — Atlas's actual persistence
/// layer (Drift, based on the existing DriftReaderRepository pattern) has a
/// schema this file doesn't have visibility into. Implement this against
/// whatever table/DAO makes sense alongside the existing reading-progress
/// storage described in the CDA doc's Database section.
abstract class RecoveryStore {
  Future<void> save(SpeechCheckpoint checkpoint);
  Future<SpeechCheckpoint?> load(String bookId);
  Future<void> clear(String bookId);
}

/// In-memory implementation for tests and early development, so
/// SpeechEngine can be built/tested before the real store is wired up.
class InMemoryRecoveryStore implements RecoveryStore {
  final Map<String, SpeechCheckpoint> _store = {};

  @override
  Future<void> save(SpeechCheckpoint checkpoint) async {
    _store[checkpoint.bookId] = checkpoint;
  }

  @override
  Future<SpeechCheckpoint?> load(String bookId) async => _store[bookId];

  @override
  Future<void> clear(String bookId) async {
    _store.remove(bookId);
  }
}
