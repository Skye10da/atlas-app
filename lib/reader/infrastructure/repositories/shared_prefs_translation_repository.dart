import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/reader/domain/repository_interfaces/translation_repository.dart';
import 'package:atlas_app/wtr/domain/entities/supported_language.dart';

/// `SharedPreferences`-backed [TranslationRepository].
class SharedPrefsTranslationRepository implements TranslationRepository {
  const SharedPrefsTranslationRepository();

  static String _langKey(String bookId) => 'translation_lang_$bookId';
  static String _enabledKey(String bookId) => 'translation_enabled_$bookId';

  @override
  Future<SupportedLanguage?> loadTargetLanguage(
    String bookId, {
    List<SupportedLanguage>? languages,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return SupportedLanguage.fromCode(
      prefs.getString(_langKey(bookId)),
      languages: languages,
    );
  }

  @override
  Future<void> saveTargetLanguage(
    String bookId,
    SupportedLanguage language,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey(bookId), language.code);
  }

  @override
  Future<bool> loadEnabled(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey(bookId)) ?? false;
  }

  @override
  Future<void> saveEnabled(String bookId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey(bookId), enabled);
  }
}
