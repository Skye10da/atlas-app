import 'package:atlas_app/reader/domain/entities/atlas_glossary_entry.dart';

/// Persists the reader's per-novel user glossary.
///
/// Keyed by `bookId`, so every novel keeps its own term set and the glossary
/// travels with the book. Storage is local-only (SharedPreferences): these are
/// the user's own replacement choices, never synced to any server.
abstract interface class AtlasGlossaryRepository {
  /// The user's glossary entries for [bookId] in no particular order.
  Future<List<AtlasGlossaryEntry>> load(String bookId);

  /// Replaces [bookId]'s whole entry list with [entries].
  Future<void> save(String bookId, List<AtlasGlossaryEntry> entries);
}

/// In-memory default so pure-logic paths (unit tests, cold boot before the
/// app's real repository is wired) never touch platform storage.
class InMemoryAtlasGlossaryRepository implements AtlasGlossaryRepository {
  final Map<String, List<AtlasGlossaryEntry>> _store = {};

  @override
  Future<List<AtlasGlossaryEntry>> load(String bookId) async =>
      List.of(_store[bookId] ?? const []);

  @override
  Future<void> save(String bookId, List<AtlasGlossaryEntry> entries) async {
    _store[bookId] = List.of(entries);
  }
}
