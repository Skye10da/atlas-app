/// Represents an extracted key plot event in the novel's timeline.
class StoryEvent {
  const StoryEvent({
    required this.id,
    required this.bookId,
    this.readThroughId = 'default',
    required this.chapter,
    required this.summary,
    this.involvedEntityIds = const [],
    required this.confidenceScore,
    required this.createdAt,
  });

  factory StoryEvent.fromJson(Map<String, dynamic> json) {
    return StoryEvent(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      readThroughId: json['readThroughId'] as String? ?? 'default',
      chapter: (json['chapter'] as num?)?.toInt() ?? 1,
      summary: json['summary'] as String? ?? '',
      involvedEntityIds: [
        for (final e in (json['involvedEntityIds'] as List? ?? const []))
          if (e is String) e,
      ],
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.5,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final String id;
  final String bookId;
  final String readThroughId;

  /// Chapter index where the event occurred.
  final int chapter;

  /// Compressed, factual description of what happened.
  final String summary;

  /// Entity IDs of characters, factions, locations, or items involved in this event.
  final List<String> involvedEntityIds;

  /// Inherited confidence score = min(involved entities' confidence).
  final double confidenceScore;

  final DateTime createdAt;

  StoryEvent copyWith({
    String? id,
    String? bookId,
    String? readThroughId,
    int? chapter,
    String? summary,
    List<String>? involvedEntityIds,
    double? confidenceScore,
    DateTime? createdAt,
  }) {
    return StoryEvent(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      readThroughId: readThroughId ?? this.readThroughId,
      chapter: chapter ?? this.chapter,
      summary: summary ?? this.summary,
      involvedEntityIds: involvedEntityIds ?? this.involvedEntityIds,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'readThroughId': readThroughId,
    'chapter': chapter,
    'summary': summary,
    'involvedEntityIds': involvedEntityIds,
    'confidenceScore': confidenceScore,
    'createdAt': createdAt.toIso8601String(),
  };
}

