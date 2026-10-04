/// Represents a recognized relationship between two Story Memory entities.
class StoryRelationship {
  const StoryRelationship({
    required this.id,
    required this.bookId,
    this.readThroughId = 'default',
    required this.sourceEntityId,
    required this.targetEntityId,
    required this.relationType,
    required this.confidenceScore,
    required this.chapterEstablished,
    required this.createdAt,
  });

  factory StoryRelationship.fromJson(Map<String, dynamic> json) {
    return StoryRelationship(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      readThroughId: json['readThroughId'] as String? ?? 'default',
      sourceEntityId: json['sourceEntityId'] as String,
      targetEntityId: json['targetEntityId'] as String,
      relationType: json['relationType'] as String? ?? 'related',
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.5,
      chapterEstablished: (json['chapterEstablished'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final String id;
  final String bookId;
  final String readThroughId;
  final String sourceEntityId;
  final String targetEntityId;

  /// Relationship descriptor (e.g. "ally", "rival", "master", "disciple", "enemy").
  final String relationType;

  /// Confidence score, derived as min(source.confidence, target.confidence).
  final double confidenceScore;

  /// Earliest chapter where this relationship was recognized.
  final int chapterEstablished;

  final DateTime createdAt;

  StoryRelationship copyWith({
    String? id,
    String? bookId,
    String? readThroughId,
    String? sourceEntityId,
    String? targetEntityId,
    String? relationType,
    double? confidenceScore,
    int? chapterEstablished,
    DateTime? createdAt,
  }) {
    return StoryRelationship(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      readThroughId: readThroughId ?? this.readThroughId,
      sourceEntityId: sourceEntityId ?? this.sourceEntityId,
      targetEntityId: targetEntityId ?? this.targetEntityId,
      relationType: relationType ?? this.relationType,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      chapterEstablished: chapterEstablished ?? this.chapterEstablished,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'readThroughId': readThroughId,
    'sourceEntityId': sourceEntityId,
    'targetEntityId': targetEntityId,
    'relationType': relationType,
    'confidenceScore': confidenceScore,
    'chapterEstablished': chapterEstablished,
    'createdAt': createdAt.toIso8601String(),
  };
}

