import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/wtr/domain/entities/language_flag_map.dart';
import 'package:atlas_app/wtr/domain/entities/supported_language.dart';

/// Fetches the list of languages supported by Google Translate at runtime.
///
/// Uses the public `translate.googleapis.com/translate_a/l` endpoint which
/// returns `{"sl": {code: name}, "tl": {code: name}, ...}` (an older build of
/// the same endpoint returned a flat `[[code, name], ...]` list) without
/// requiring an API key. Native names and flags are merged from static maps
/// in code; languages without a known flag fall back to a neutral globe.
class GoogleTranslateLanguagesService {
  const GoogleTranslateLanguagesService();

  static const _endpoint =
      'https://translate.googleapis.com/translate_a/l?client=gtx&tl=en';

  /// Known native names for the most common languages.
  ///
  /// Languages not listed here fall back to their English name.
  static const _nativeNames = <String, String>{
    'ar': 'العربية',
    'bg': 'Български',
    'bn': 'বাংলা',
    'cs': 'Čeština',
    'da': 'Dansk',
    'de': 'Deutsch',
    'el': 'Ελληνικά',
    'en': 'English',
    'es': 'Español',
    'et': 'Eesti',
    'fi': 'Suomi',
    'fr': 'Français',
    'gu': 'ગુજરાતી',
    'he': 'עברית',
    'hi': 'हिन्दी',
    'hr': 'Hrvatski',
    'hu': 'Magyar',
    'id': 'Bahasa Indonesia',
    'it': 'Italiano',
    'ja': '日本語',
    'kn': 'ಕನ್ನಡ',
    'ko': '한국어',
    'lt': 'Lietuvių',
    'lv': 'Latviešu',
    'mk': 'Македонски',
    'ml': 'മലയാളം',
    'mr': 'मराठी',
    'ms': 'Bahasa Melayu',
    'nl': 'Nederlands',
    'no': 'Norsk',
    'pa': 'ਪੰਜਾਬੀ',
    'pl': 'Polski',
    'pt': 'Português',
    'ro': 'Română',
    'ru': 'Русский',
    'sk': 'Slovenčina',
    'sl': 'Slovenščina',
    'so': 'Soomaali',
    'sq': 'Shqip',
    'sr': 'Српски',
    'sv': 'Svenska',
    'sw': 'Kiswahili',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
    'th': 'ไทย',
    'tl': 'Filipino',
    'tr': 'Türkçe',
    'uk': 'Українська',
    'ur': 'اردو',
    'vi': 'Tiếng Việt',
    'zh': '中文',
    'zu': 'isiZulu',
  };

  /// Fetches all languages supported by Google Translate, sorted alphabetically
  /// by English name. Falls back to [SupportedLanguage.defaults] on failure.
  Future<List<SupportedLanguage>> fetchSupportedLanguages(
    Transport transport,
  ) async {
    try {
      final value = await transport.fetchJson(Uri.parse(_endpoint));
      final entries = _extractEntries(value);
      if (entries.isEmpty) return SupportedLanguage.defaults;

      final languages = <SupportedLanguage>[];
      for (final entry in entries) {
        final code = entry.$1;
        final englishName = entry.$2;
        final nativeName = _nativeNames[code] ?? englishName;
        final flag = kLanguageFlags[code] ?? '🌐';
        languages.add(
          SupportedLanguage(
            code: code,
            name: englishName,
            nativeName: nativeName,
            flag: flag,
          ),
        );
      }

      languages.sort((a, b) => a.name.compareTo(b.name));
      return languages;
    } on Object {
      return SupportedLanguage.defaults;
    }
  }

  /// Normalizes the endpoint response into `(code, englishName)` pairs.
  ///
  /// The current build returns `{"sl": {...}, "tl": {...}, ...}`; target
  /// languages live under `tl`. Older builds returned a flat list of
  /// `[code, name]` pairs, which is still parsed for backward compatibility.
  List<(String, String)> _extractEntries(Object? value) {
    if (value is List) {
      final entries = <(String, String)>[];
      for (final entry in value) {
        if (entry is! List || entry.length < 2) continue;
        entries.add((entry[0].toString(), entry[1].toString()));
      }
      return entries;
    }
    if (value is Map) {
      for (final key in const ['tl', 'sl']) {
        final map = value[key];
        if (map is Map) {
          return map.entries
              .map((e) => (e.key.toString(), e.value.toString()))
              .toList();
        }
      }
    }
    return const [];
  }
}
