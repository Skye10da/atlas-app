/// Identified intent of a user's story query.
enum QueryIntentType {
  whoIs,
  whatHappened,
  whereIs,
  relationship,
  recap,
  sceneSearch,
  unknown,
}

/// Structured extraction of user query intent and extracted entity/chapter slots.
class QueryIntentMatch {
  const QueryIntentMatch({
    required this.intent,
    required this.rawQuery,
    this.primarySlot,
    this.secondarySlot,
    this.chapterSlot,
    this.confidence = 1.0,
  });

  final QueryIntentType intent;
  final String rawQuery;

  /// Primary entity name extracted from the question (e.g. "Lin Dong" in "Who is Lin Dong?").
  final String? primarySlot;

  /// Secondary entity name extracted for relationship queries (e.g. "Mo" in "How are Lin Dong and Mo related?").
  final String? secondarySlot;

  /// Specific chapter referenced in the query, if any (e.g. 5 in "What happened in chapter 5?").
  final int? chapterSlot;

  /// Intent confidence score (0.0 to 1.0).
  final double confidence;
}

