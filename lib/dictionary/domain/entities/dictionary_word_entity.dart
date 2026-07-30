class DictionaryWordEntity {

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
    this.sourceSentence,
    this.sourceTitle,
    this.reviewLevel = 0,
    this.reviewCount = 0,
    this.lastReviewedAt,
    this.nextReviewAt,
  });
  final String id;
  final String word;
  final String language;
  final String languageLabel;
  final String? phonetic;
  final String partOfSpeech;
  final String definition;
  final String fullJson;
  final DateTime savedAt;
  final String? sourceSentence;
  final String? sourceTitle;
  final int reviewLevel;
  final int reviewCount;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;

  DictionaryWordEntity copyWith({
    String? id,
    String? word,
    String? language,
    String? languageLabel,
    String? phonetic,
    String? partOfSpeech,
    String? definition,
    String? fullJson,
    DateTime? savedAt,
    String? sourceSentence,
    String? sourceTitle,
    int? reviewLevel,
    int? reviewCount,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
    bool clearSourceSentence = false,
    bool clearSourceTitle = false,
    bool clearLastReviewedAt = false,
    bool clearNextReviewAt = false,
  }) {
    return DictionaryWordEntity(
      id: id ?? this.id,
      word: word ?? this.word,
      language: language ?? this.language,
      languageLabel: languageLabel ?? this.languageLabel,
      phonetic: phonetic ?? this.phonetic,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      definition: definition ?? this.definition,
      fullJson: fullJson ?? this.fullJson,
      savedAt: savedAt ?? this.savedAt,
      sourceSentence: clearSourceSentence ? null : (sourceSentence ?? this.sourceSentence),
      sourceTitle: clearSourceTitle ? null : (sourceTitle ?? this.sourceTitle),
      reviewLevel: reviewLevel ?? this.reviewLevel,
      reviewCount: reviewCount ?? this.reviewCount,
      lastReviewedAt: clearLastReviewedAt ? null : (lastReviewedAt ?? this.lastReviewedAt),
      nextReviewAt: clearNextReviewAt ? null : (nextReviewAt ?? this.nextReviewAt),
    );
  }
}
