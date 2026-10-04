import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';

/// Confidence tiers reflecting the extraction engine's certainty in an entity.
enum ConfidenceTier {
  low('low', 'Low / Provisional'),
  medium('medium', 'Medium / Provisional'),
  high('high', 'High / Confirmed');

  const ConfidenceTier(this.id, this.label);

  final String id;
  final String label;

  static ConfidenceTier fromId(String id) {
    for (final tier in values) {
      if (tier.id.toLowerCase() == id.toLowerCase()) {
        return tier;
      }
    }
    return ConfidenceTier.low;
  }
}

/// Tunable thresholds for determining confidence tiers and review triggers.
class ConfidenceThresholdConfig {
  const ConfidenceThresholdConfig({
    required this.type,
    required this.lowUpperBound,
    required this.mediumUpperBound,
    required this.autoAcceptMedium,
    required this.tieringEnabled,
  });

  final StoryEntityType type;
  final double lowUpperBound;
  final double mediumUpperBound;
  final bool autoAcceptMedium;
  final bool tieringEnabled;

  /// Resolves the tier given a raw posterior score (0.0 to 1.0).
  ConfidenceTier resolveTier(double score) {
    if (!tieringEnabled) {
      return score >= mediumUpperBound ? ConfidenceTier.high : ConfidenceTier.low;
    }
    if (score < lowUpperBound) {
      return ConfidenceTier.low;
    } else if (score < mediumUpperBound) {
      return ConfidenceTier.medium;
    } else {
      return ConfidenceTier.high;
    }
  }

  /// Whether an entity at [score] requires human review before creation.
  bool requiresReview(double score, {bool userConfirmed = false}) {
    if (userConfirmed) return false;
    final tier = resolveTier(score);
    return tier == ConfidenceTier.low;
  }

  /// Default configuration map for all entity types per the specification.
  static Map<StoryEntityType, ConfidenceThresholdConfig> get defaults => {
    StoryEntityType.character: const ConfidenceThresholdConfig(
      type: StoryEntityType.character,
      lowUpperBound: 0.35,
      mediumUpperBound: 0.70,
      autoAcceptMedium: false,
      tieringEnabled: true,
    ),
    StoryEntityType.faction: const ConfidenceThresholdConfig(
      type: StoryEntityType.faction,
      lowUpperBound: 0.35,
      mediumUpperBound: 0.60,
      autoAcceptMedium: true,
      tieringEnabled: true,
    ),
    StoryEntityType.location: const ConfidenceThresholdConfig(
      type: StoryEntityType.location,
      lowUpperBound: 0.35,
      mediumUpperBound: 0.60,
      autoAcceptMedium: true,
      tieringEnabled: true,
    ),
    StoryEntityType.item: const ConfidenceThresholdConfig(
      type: StoryEntityType.item,
      lowUpperBound: 0.50,
      mediumUpperBound: 0.50,
      autoAcceptMedium: false,
      tieringEnabled: false,
    ),
  };
}
