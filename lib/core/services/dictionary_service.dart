import 'dart:convert';

import 'package:http/http.dart' as http;

class WiktionaryResult {

  WiktionaryResult({
    required this.word,
    this.phonetic,
    required this.senses,
  });
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

abstract interface class DictionaryService {
  Future<WiktionaryResult?> lookup(String word, String language);
}

class WiktionaryService implements DictionaryService {

  WiktionaryService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  @override
  Future<WiktionaryResult?> lookup(String word, String language) async {
    final uri = Uri.parse(
      'https://$language.wiktionary.org/api/rest/v1/page/definition/${Uri.encodeComponent(word.toLowerCase())}',
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final langData = body[language] as List?;
    if (langData == null || langData.isEmpty) return null;

    String? phonetic;
    final allSenses = <WiktionarySense>[];

    for (final entry in langData) {
      final e = entry as Map<String, dynamic>;
      final pos = e['partOfSpeech'] as String? ?? 'unknown';

      if (phonetic == null && e['sounds'] is List) {
        for (final s in (e['sounds'] as List)) {
          final sound = s as Map<String, dynamic>;
          final ipa = sound['ipa'] as String?;
          if (ipa != null) {
            phonetic = ipa;
            break;
          }
        }
      }

      final defs = e['definitions'] as List? ?? [];
      for (final d in defs) {
        final def = d as Map<String, dynamic>;
        final defText = def['definition'] as String?;
        if (defText == null) continue;

        final examples = (def['examples'] as List?)
                ?.map((e) => e is String ? e : (e as Map)['text'] as String? ?? '')
                .where((e) => e.isNotEmpty)
                .toList() ??
            [];

        allSenses.add(WiktionarySense(
          partOfSpeech: pos,
          definition: _stripHtml(defText),
          examples: examples.cast<String>(),
        ));
      }
    }

    if (allSenses.isEmpty) return null;
    return WiktionaryResult(word: word, phonetic: phonetic, senses: allSenses);
  }

  String _stripHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
}
