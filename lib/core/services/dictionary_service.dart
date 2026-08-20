import 'dart:convert';

import 'package:http/http.dart' as http;

class WiktionaryResult {
  WiktionaryResult({required this.word, this.phonetic, required this.senses});

  factory WiktionaryResult.fromJson(Map<String, dynamic> json) =>
      WiktionaryResult(
        word: json['word'] as String,
        phonetic: json['phonetic'] as String?,
        senses: (json['senses'] as List)
            .map((s) => WiktionarySense.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  static WiktionaryResult? tryParse(String json) {
    try {
      return WiktionaryResult.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'phonetic': phonetic,
    'senses': senses.map((s) => s.toJson()).toList(),
  };

  final String word;
  final String? phonetic;
  final List<WiktionarySense> senses;
}

class WiktionarySense {
  WiktionarySense({
    required this.partOfSpeech,
    required this.definition,
    this.examples = const [],
  });

  factory WiktionarySense.fromJson(Map<String, dynamic> json) =>
      WiktionarySense(
        partOfSpeech: json['partOfSpeech'] as String,
        definition: json['definition'] as String,
        examples: (json['examples'] as List).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
    'partOfSpeech': partOfSpeech,
    'definition': definition,
    'examples': examples,
  };

  final String partOfSpeech;
  final String definition;
  final List<String> examples;
}

class WiktionaryLanguage {
  const WiktionaryLanguage(this.code, this.label);

  final String code;
  final String label;
}

const List<WiktionaryLanguage> supportedLanguages = [
  WiktionaryLanguage('en', 'English'),
  WiktionaryLanguage('fr', 'French'),
  WiktionaryLanguage('de', 'German'),
  WiktionaryLanguage('es', 'Spanish'),
  WiktionaryLanguage('it', 'Italian'),
  WiktionaryLanguage('pt', 'Portuguese'),
  WiktionaryLanguage('nl', 'Dutch'),
  WiktionaryLanguage('ru', 'Russian'),
  WiktionaryLanguage('ja', 'Japanese'),
  WiktionaryLanguage('zh', 'Chinese'),
  WiktionaryLanguage('ko', 'Korean'),
  WiktionaryLanguage('ar', 'Arabic'),
  WiktionaryLanguage('tr', 'Turkish'),
  WiktionaryLanguage('pl', 'Polish'),
  WiktionaryLanguage('sv', 'Swedish'),
  WiktionaryLanguage('da', 'Danish'),
  WiktionaryLanguage('fi', 'Finnish'),
  WiktionaryLanguage('el', 'Greek'),
  WiktionaryLanguage('he', 'Hebrew'),
  WiktionaryLanguage('hi', 'Hindi'),
];

/// Default BCP-47 locale for each supported dictionary language code, used to
/// drive TTS pronunciation when looking a word up in that language.
final Map<String, String> dictionaryLanguageLocales = {
  'en': 'en-US',
  'fr': 'fr-FR',
  'de': 'de-DE',
  'es': 'es-ES',
  'it': 'it-IT',
  'pt': 'pt-PT',
  'nl': 'nl-NL',
  'ru': 'ru-RU',
  'ja': 'ja-JP',
  'zh': 'zh-CN',
  'ko': 'ko-KR',
  'ar': 'ar-SA',
  'tr': 'tr-TR',
  'pl': 'pl-PL',
  'sv': 'sv-SE',
  'da': 'da-DK',
  'fi': 'fi-FI',
  'el': 'el-GR',
  'he': 'he-IL',
  'hi': 'hi-IN',
};

/// Resolves [code] (a 2-letter dictionary language code) to a BCP-47 tag for
/// TTS, falling back to the bare code when unmapped.
String localeForLanguageCode(String code) =>
    dictionaryLanguageLocales[code] ?? code;

/// A selectable dictionary backend. Each source advertises the languages it
/// can look up, so the UI can present a source picker next to the language
/// picker and only offer valid combinations.
enum DictionarySource {
  wiktionary(
    id: 'wiktionary',
    label: 'Wiktionary',
    languages: supportedLanguages,
  ),
  urbanDictionary(
    id: 'urban_dictionary',
    label: 'Urban Dictionary',
    languages: [WiktionaryLanguage('en', 'English')],
  );

  const DictionarySource({
    required this.id,
    required this.label,
    required this.languages,
  });

  final String id;
  final String label;
  final List<WiktionaryLanguage> languages;

  static DictionarySource fromId(String id) {
    return DictionarySource.values.firstWhere(
      (s) => s.id == id,
      orElse: () => DictionarySource.wiktionary,
    );
  }
}

abstract interface class DictionaryService {
  Future<WiktionaryResult?> lookup(String word, String language);
}

class WiktionaryService implements DictionaryService {
  WiktionaryService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<WiktionaryResult?> lookup(String word, String language) async {
    final uri = Uri.parse(
      'https://api.wiktapi.dev/v1/en/word/${Uri.encodeComponent(word.toLowerCase())}?lang=$language',
    );
    final response = await _client
        .get(uri, headers: {'User-Agent': 'AtlasApp/1.0'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception(
        'Wiktionary API returned status ${response.statusCode} for "$word"',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final entries = body['entries'] as List?;
    if (entries == null || entries.isEmpty) return null;

    String? phonetic;
    final allSenses = <WiktionarySense>[];

    for (final entry in entries) {
      final e = entry as Map<String, dynamic>;
      final pos = e['pos'] as String? ?? 'unknown';

      if (phonetic == null && e['sounds'] is List) {
        for (final s in (e['sounds'] as List)) {
          final sound = s as Map<String, dynamic>;
          final ipa = sound['ipa'] as String?;
          if (ipa != null && ipa.isNotEmpty) {
            phonetic = ipa;
            break;
          }
        }
      }

      final senses = e['senses'] as List? ?? [];
      for (final s in senses) {
        final sense = s as Map<String, dynamic>;
        final glosses = sense['glosses'] as List? ?? [];
        final gloss = glosses.isNotEmpty ? glosses[0] as String : '';
        if (gloss.isEmpty) continue;

        final examples =
            (sense['examples'] as List?)
                ?.map((ex) => (ex as Map)['text'] as String? ?? '')
                .where((t) => t.isNotEmpty)
                .toList() ??
            [];

        allSenses.add(
          WiktionarySense(
            partOfSpeech: pos,
            definition: gloss.trim(),
            examples: examples.toList(),
          ),
        );
      }
    }

    if (allSenses.isEmpty) return null;
    return WiktionaryResult(word: word, phonetic: phonetic, senses: allSenses);
  }
}

class UrbanDictionaryService implements DictionaryService {
  UrbanDictionaryService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _maxResults = 5;

  @override
  Future<WiktionaryResult?> lookup(String word, String language) async {
    final uri = Uri.parse(
      'https://api.urbandictionary.com/v0/define'
      '?term=${Uri.encodeComponent(word.toLowerCase())}',
    );
    final response = await _client
        .get(uri, headers: {'User-Agent': 'AtlasApp/1.0'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception(
        'Urban Dictionary API returned status ${response.statusCode} for "$word"',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['list'] as List?;
    if (list == null || list.isEmpty) return null;

    final senses = <WiktionarySense>[];
    for (final item in list.take(_maxResults)) {
      final e = item as Map<String, dynamic>;
      final definition = (e['definition'] as String? ?? '').trim();
      if (definition.isEmpty) continue;
      final example = (e['example'] as String? ?? '').trim();
      senses.add(
        WiktionarySense(
          partOfSpeech: 'slang',
          definition: definition,
          examples: example.isEmpty ? const [] : [example],
        ),
      );
    }

    if (senses.isEmpty) return null;
    return WiktionaryResult(word: word, phonetic: null, senses: senses);
  }
}
