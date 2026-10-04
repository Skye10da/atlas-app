import 'dart:math' as math;

enum ExtractionSignalType {
  dialogueTag(0.45),
  honorificMention(0.35),
  structuredPattern(0.55),
  exactNameRepeat(0.25),
  pronounBinding(0.15),
  activeContradiction(0.40),
  userCorrectionRule(0.40);

  const ExtractionSignalType(this.defaultWeight);
  final double defaultWeight;
}

/// Bayesian-style running posterior confidence updater.
///
/// Implements:
/// newScore = clamp(oldScore + signalWeight * (signalConfirms ? +1 : -1) * learningRate, 0.0, 1.0)
/// where learningRate = baseRate / (1 + ln(mentionCount))
class ConfidenceScorer {
  const ConfidenceScorer({this.baseRate = 0.35});

  final double baseRate;

  /// Calculates the updated confidence score after observing a new signal.
  double updateConfidence({
    required double currentScore,
    required ExtractionSignalType signalType,
    required bool signalConfirms,
    required int mentionCount,
    double? customWeight,
  }) {
    final weight = customWeight ?? signalType.defaultWeight;

    // Diminishing returns curve: early mentions shift confidence more than late ones
    final safeMention = math.max(1, mentionCount);
    final learningRate = baseRate / (1.0 + math.log(safeMention));

    final direction = signalConfirms ? 1.0 : -1.0;
    final delta = weight * direction * learningRate;

    final updated = (currentScore + delta).clamp(0.0, 1.0);
    // Round to 3 decimal places to prevent floating point noise
    return double.parse(updated.toStringAsFixed(3));
  }

  /// Initial confidence score for a freshly discovered candidate entity.
  double initialScore({
    required ExtractionSignalType primarySignal,
    bool hasSecondarySignal = false,
  }) {
    var score = primarySignal.defaultWeight;
    if (hasSecondarySignal) {
      score += 0.20;
    }
    return score.clamp(0.10, 0.95);
  }
}
