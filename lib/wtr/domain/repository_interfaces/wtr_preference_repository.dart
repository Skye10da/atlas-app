import 'package:atlas_app/wtr/domain/entities/wtr_translation_service.dart';

/// Persists the user's preferred translation service for a WTR-Lab novel.
///
/// Keyed by the novel's WTR `raw_id` (stored as the book's `sourceId`), so the
/// preference follows the novel wherever it is imported from.
abstract interface class WtrPreferenceRepository {
  /// Returns the saved service for [rawId], or null when none was chosen yet
  /// (the caller then applies the site's account-dependent default).
  Future<WtrTranslationService?> loadService(int rawId);

  Future<void> saveService(int rawId, WtrTranslationService service);
}

/// In-memory default so pure-logic paths (unit tests, cold boot before the
/// app's real repository is wired) never touch platform storage.
class InMemoryWtrPreferenceRepository implements WtrPreferenceRepository {
  final Map<int, WtrTranslationService> _store = {};

  @override
  Future<WtrTranslationService?> loadService(int rawId) async => _store[rawId];

  @override
  Future<void> saveService(int rawId, WtrTranslationService service) async {
    _store[rawId] = service;
  }
}
