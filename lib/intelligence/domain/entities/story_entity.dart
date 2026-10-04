import 'package:atlas_app/intelligence/domain/entities/confidence.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';

/// Core domain entity representing an extracted Story Memory entity
/// (Character, Location, Faction, or Item).
class StoryEntity {
  const StoryEntity({
    required this.id,
    required this.bookId,
    this.readThroughId = 'default',
    required this.type,
    required this.canonicalName,
    this.aliases = const [],
    required this.confidenceScore,
    required this.tier,
    this.userConfirmed = false,
    this.attributes = const {},
    required this.firstSeenChapter,
    required this.lastSeenChapter,
    this.mentionCount = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StoryEntity.fromJson(Map<String, dynamic> json) {
    return StoryEntity(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      readThroughId: json['readThroughId'] as String? ?? 'default',
      type: StoryEntityType.fromId(json['type'] as String? ?? 'character'),
      canonicalName: json['canonicalName'] as String,
      aliases: [
        for (final a in (json['aliases'] as List? ?? const []))
          if (a is String) a,
      ],
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.5,
      tier: ConfidenceTier.fromId(json['tier'] as String? ?? 'low'),
      userConfirmed: json['userConfirmed'] as bool? ?? false,
      attributes: json['attributes'] is Map
          ? Map<String, dynamic>.from(json['attributes'] as Map)
          : {},
      firstSeenChapter: (json['firstSeenChapter'] as num?)?.toInt() ?? 1,
      lastSeenChapter: (json['lastSeenChapter'] as num?)?.toInt() ?? 1,
      mentionCount: (json['mentionCount'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Stable UUID across corrections and merges.
  final String id;

  /// Identifier of the book/novel this entity belongs to.
  final String bookId;

  /// Identifier of the read-through memory scope (defaults to 'default').
  final String readThroughId;

  /// Entity classification (character, location, faction, item).
  final StoryEntityType type;

  /// Primary name used when presenting this entity.
  final String canonicalName;

  /// Alternative names, titles, romanizations, and honorific forms.
  final List<String> aliases;

  /// Running posterior confidence score between 0.0 and 1.0.
  final double confidenceScore;

  /// Derived tier based on [confidenceScore] and entity-type thresholds.
  final ConfidenceTier tier;

  /// True once a human has confirmed or manually edited this entity.
  final bool userConfirmed;

  /// Free-form type-specific attributes (e.g. role, sect, element, realm).
  final Map<String, dynamic> attributes;

  /// Lowest chapter index where this entity appeared.
  final int firstSeenChapter;

  /// Highest chapter index where this entity appeared.
  final int lastSeenChapter;

  /// Total count of recognized mentions across all processed chapters.
  final int mentionCount;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCharacter => type == StoryEntityType.character;
  bool get isLocation => type == StoryEntityType.location;
  bool get isFaction => type == StoryEntityType.faction;
  bool get isItem => type == StoryEntityType.item;

  StoryEntity copyWith({
    String? id,
    String? bookId,
    String? readThroughId,
    StoryEntityType? type,
    String? canonicalName,
    List<String>? aliases,
    double? confidenceScore,
    ConfidenceTier? tier,
    bool? userConfirmed,
    Map<String, dynamic>? attributes,
    int? firstSeenChapter,
    int? lastSeenChapter,
    int? mentionCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoryEntity(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      readThroughId: readThroughId ?? this.readThroughId,
      type: type ?? this.type,
      canonicalName: canonicalName ?? this.canonicalName,
      aliases: aliases ?? this.aliases,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      tier: tier ?? this.tier,
      userConfirmed: userConfirmed ?? this.userConfirmed,
      attributes: attributes ?? this.attributes,
      firstSeenChapter: firstSeenChapter ?? this.firstSeenChapter,
      lastSeenChapter: lastSeenChapter ?? this.lastSeenChapter,
      mentionCount: mentionCount ?? this.mentionCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'readThroughId': readThroughId,
    'type': type.id,
    'canonicalName': canonicalName,
    'aliases': aliases,
    'confidenceScore': confidenceScore,
    'tier': tier.id,
    'userConfirmed': userConfirmed,
    'attributes': attributes,
    'firstSeenChapter': firstSeenChapter,
    'lastSeenChapter': lastSeenChapter,
    'mentionCount': mentionCount,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

