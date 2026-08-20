import 'package:atlas_app/wtr/domain/entities/supported_language.dart';

/// Persists the reader's translation preference for a book.
///
/// Keyed by the book's id (`translation_lang_<bookId>`,
/// `translation_enabled_<bookId>`), so each novel remembers its own target
/// language and whether on-device translation is active. Local-only
/// (SharedPreferences), never synced.
abstract interface class TranslationRepository {
  /// The saved target language for [bookId], or null when never chosen.
  ///
  /// [languages] is the full fetched list; when provided, codes outside
  /// [SupportedLanguage.defaults] can still be resolved.
  Future<SupportedLanguage?> loadTargetLanguage(
    String bookId, {
    List<SupportedLanguage>? languages,
  });

  Future<void> saveTargetLanguage(String bookId, SupportedLanguage language);

  /// Whether on-device translation is enabled for [bookId].
  Future<bool> loadEnabled(String bookId);

  Future<void> saveEnabled(String bookId, bool enabled);
}

/// In-memory default so pure-logic paths (unit tests, cold boot) never touch
/// platform storage.
class InMemoryTranslationRepository implements TranslationRepository {
  final Map<String, String> _languageCodes = {};
  final Map<String, bool> _enabled = {};

  @override
  Future<SupportedLanguage?> loadTargetLanguage(
    String bookId, {
    List<SupportedLanguage>? languages,
  }) async {
    final code = _languageCodes[bookId];
    if (code == null) return null;
    return SupportedLanguage.fromCode(code, languages: languages);
  }

  @override
  Future<void> saveTargetLanguage(
    String bookId,
    SupportedLanguage language,
  ) async {
    _languageCodes[bookId] = language.code;
  }

  @override
  Future<bool> loadEnabled(String bookId) async => _enabled[bookId] ?? false;

  @override
  Future<void> saveEnabled(String bookId, bool enabled) async {
    _enabled[bookId] = enabled;
  }
}
