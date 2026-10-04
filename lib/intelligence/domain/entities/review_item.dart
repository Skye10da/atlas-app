/// Category of item awaiting human review in the review queue.
enum ReviewType {
  newEntity('new_entity', 'New Entity Confirmation'),
  mergeCandidates('merge_candidates', 'Potential Alias Merge'),
  relationship('relationship', 'Relationship Verification');

  const ReviewType(this.id, this.label);
  final String id;
  final String label;

  static ReviewType fromId(String id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return ReviewType.newEntity;
  }
}

enum ReviewStatus {
  pending('pending'),
  resolved('resolved'),
  dismissed('dismissed');

  const ReviewStatus(this.id);
  final String id;

  static ReviewStatus fromId(String id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return ReviewStatus.pending;
  }
}

/// An entry in the user review queue with attached inspectable evidence.
class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.bookId,
    this.readThroughId = 'default',
    required this.type,
    required this.entityId,
    this.targetEntityId,
    required this.candidateName,
    this.targetName,
    required this.confidenceScore,
    this.similarityScore,
    this.cooccurrenceCount = 0,
    this.evidence = const [],
    this.status = ReviewStatus.pending,
    required this.chapterIndex,
    required this.createdAt,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    return ReviewItem(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      readThroughId: json['readThroughId'] as String? ?? 'default',
      type: ReviewType.fromId(json['type'] as String? ?? 'new_entity'),
      entityId: json['entityId'] as String,
      targetEntityId: json['targetEntityId'] as String?,
      candidateName: json['candidateName'] as String? ?? '',
      targetName: json['targetName'] as String?,
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.5,
      similarityScore: (json['similarityScore'] as num?)?.toDouble(),
      cooccurrenceCount: (json['cooccurrenceCount'] as num?)?.toInt() ?? 0,
      evidence: [
        for (final e in (json['evidence'] as List? ?? const []))
          if (e is String) e,
      ],
      status: ReviewStatus.fromId(json['status'] as String? ?? 'pending'),
      chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final String id;
  final String bookId;
  final String readThroughId;
  final ReviewType type;

  /// Primary entity under review.
  final String entityId;

  /// Target entity for merge reviews (if applicable).
  final String? targetEntityId;

  /// Proposed or extracted name.
  final String candidateName;

  /// Target canonical name (for merge reviews).
  final String? targetName;

  /// Extraction confidence or merge confidence.
  final double confidenceScore;

  /// Phonetic/string similarity score (0.0 to 1.0) if an alias merge candidate.
  final double? similarityScore;

  /// Co-occurrence frequency between candidate and target entity.
  final int cooccurrenceCount;

  /// Human-readable list of reasons/signals (e.g. "Matched dialogue tag: said Lin Dong", "Phonetic similarity: 0.91").
  final List<String> evidence;

  final ReviewStatus status;
  final int chapterIndex;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'readThroughId': readThroughId,
    'type': type.id,
    'entityId': entityId,
    'targetEntityId': targetEntityId,
    'candidateName': candidateName,
    'targetName': targetName,
    'confidenceScore': confidenceScore,
    'similarityScore': similarityScore,
    'cooccurrenceCount': cooccurrenceCount,
    'evidence': evidence,
    'status': status.id,
    'chapterIndex': chapterIndex,
    'createdAt': createdAt.toIso8601String(),
  };
}

