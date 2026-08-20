/// A target language a chapter can be translated into.
///
/// Populated at runtime from Google Translate's supported languages API,
/// with a curated [defaults] list for offline/fallback use.
class SupportedLanguage {
  const SupportedLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });

  /// ISO-639-1 code accepted by the translation endpoints.
  final String code;

  /// English name, shown in compact contexts.
  final String name;

  /// The language's own name, shown in the picker.
  final String nativeName;

  /// Flag emoji for this language.
  final String flag;

  /// Resolves an ISO-639-1 code back to a [SupportedLanguage].
  ///
  /// Searches [languages] first (the full fetched list), then falls back to
  /// [defaults] so that codes saved before the API was called still resolve.
  static SupportedLanguage? fromCode(
    String? code, {
    List<SupportedLanguage>? languages,
  }) {
    if (code == null || code.isEmpty) return null;
    if (languages != null) {
      for (final language in languages) {
        if (language.code == code) return language;
      }
    }
    for (final language in defaults) {
      if (language.code == code) return language;
    }
    return null;
  }

  /// Curated fallback list used when the API is unreachable.
  ///
  /// Kept in alphabetical order by English name.
  static const defaults = [
    SupportedLanguage(
      code: 'ar',
      name: 'Arabic',
      nativeName: 'العربية',
      flag: '🇸🇦',
    ),
    SupportedLanguage(
      code: 'zh',
      name: 'Chinese',
      nativeName: '中文',
      flag: '🇨🇳',
    ),
    SupportedLanguage(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flag: '🇺🇸',
    ),
    SupportedLanguage(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      flag: '🇫🇷',
    ),
    SupportedLanguage(
      code: 'de',
      name: 'German',
      nativeName: 'Deutsch',
      flag: '🇩🇪',
    ),
    SupportedLanguage(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
      flag: '🇮🇳',
    ),
    SupportedLanguage(
      code: 'id',
      name: 'Indonesian',
      nativeName: 'Bahasa Indonesia',
      flag: '🇮🇩',
    ),
    SupportedLanguage(
      code: 'it',
      name: 'Italian',
      nativeName: 'Italiano',
      flag: '🇮🇹',
    ),
    SupportedLanguage(
      code: 'ja',
      name: 'Japanese',
      nativeName: '日本語',
      flag: '🇯🇵',
    ),
    SupportedLanguage(
      code: 'ko',
      name: 'Korean',
      nativeName: '한국어',
      flag: '🇰🇷',
    ),
    SupportedLanguage(
      code: 'pt',
      name: 'Portuguese',
      nativeName: 'Português',
      flag: '🇧🇷',
    ),
    SupportedLanguage(
      code: 'ru',
      name: 'Russian',
      nativeName: 'Русский',
      flag: '🇷🇺',
    ),
    SupportedLanguage(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      flag: '🇪🇸',
    ),
    SupportedLanguage(
      code: 'th',
      name: 'Thai',
      nativeName: 'ไทย',
      flag: '🇹🇭',
    ),
    SupportedLanguage(
      code: 'vi',
      name: 'Vietnamese',
      nativeName: 'Tiếng Việt',
      flag: '🇻🇳',
    ),
  ];
}
