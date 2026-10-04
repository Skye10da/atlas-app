import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';

/// User decision type recorded in the active learning loop.
enum CorrectionDecision {
  confirm('confirm'),
  merge('merge'),
  split('split'),
  reject('reject'),
  rename('rename');

  const CorrectionDecision(this.id);
  final String id;

  static CorrectionDecision fromId(String id) {
    for (final d in values) {
      if (d.id == id) return d;
    }
    return CorrectionDecision.confirm;
  }
}

/// Record of a user correction from the review queue used to tune extraction priors.
class CorrectionRecord {
  const CorrectionRecord({
    required this.id,
    required this.pattern,
    required this.decision,
    required this.entityType,
    required this.bookId,
    this.readThroughId = 'default',
    required this.createdAt,
  });

  factory CorrectionRecord.fromJson(Map<String, dynamic> json) {
    return CorrectionRecord(
      id: json['id'] as String,
      pattern: json['pattern'] as String,
      decision: CorrectionDecision.fromId(json['decision'] as String? ?? 'confirm'),
      entityType: StoryEntityType.fromId(json['entityType'] as String? ?? 'character'),
      bookId: json['bookId'] as String,
      readThroughId: json['readThroughId'] as String? ?? 'default',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final String id;

  /// String pattern or token sequence matched (e.g. "[honorific]+[surname]" or specific alias pair).
  final String pattern;

  final CorrectionDecision decision;
  final StoryEntityType entityType;
  final String bookId;
  final String readThroughId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'pattern': pattern,
    'decision': decision.id,
    'entityType': entityType.id,
    'bookId': bookId,
    'readThroughId': readThroughId,
    'createdAt': createdAt.toIso8601String(),
  };
}

