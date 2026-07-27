class DictionaryWordEntity {
  final String id;
  final String word;
  final String language;
  final String languageLabel;
  final String? phonetic;
  final String partOfSpeech;
  final String definition;
  final String fullJson;
  final DateTime savedAt;

  const DictionaryWordEntity({
    required this.id,
    required this.word,
    required this.language,
    required this.languageLabel,
    this.phonetic,
    required this.partOfSpeech,
    required this.definition,
    required this.fullJson,
    required this.savedAt,
  });
}
