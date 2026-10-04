import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/intelligence/application/extraction/confidence_scorer.dart';

void main() {
  late ConfidenceScorer scorer;

  setUp(() {
    scorer = const ConfidenceScorer(baseRate: 0.35);
  });

  group('ConfidenceScorer', () {
    test('initial score scales with signal type and secondary signals', () {
      final dialogueOnly = scorer.initialScore(
        primarySignal: ExtractionSignalType.dialogueTag,
      );
      expect(dialogueOnly, 0.45);

      final dialoguePlusHonorific = scorer.initialScore(
        primarySignal: ExtractionSignalType.dialogueTag,
        hasSecondarySignal: true,
      );
      expect(dialoguePlusHonorific, 0.65);
    });

    test('positive updates increase score with diminishing learning rate', () {
      // Early mention (mentionCount = 1)
      final afterFirst = scorer.updateConfidence(
        currentScore: 0.45,
        signalType: ExtractionSignalType.dialogueTag,
        signalConfirms: true,
        mentionCount: 1,
      );
      // delta = 0.45 * 1.0 * (0.35 / (1 + ln(1))) = 0.45 * 0.35 = 0.1575 => 0.45 + 0.158 = 0.608
      expect(afterFirst, greaterThan(0.45));
      expect(afterFirst, closeTo(0.608, 0.01));

      // Late mention (mentionCount = 50)
      final afterFiftieth = scorer.updateConfidence(
        currentScore: 0.80,
        signalType: ExtractionSignalType.dialogueTag,
        signalConfirms: true,
        mentionCount: 50,
      );
      // delta at 50 mentions is much smaller than at 1 mention
      final earlyDelta = afterFirst - 0.45;
      final lateDelta = afterFiftieth - 0.80;
      expect(lateDelta, lessThan(earlyDelta));
    });

    test('active contradictions decrease score', () {
      final penalised = scorer.updateConfidence(
        currentScore: 0.70,
        signalType: ExtractionSignalType.activeContradiction,
        signalConfirms: false,
        mentionCount: 5,
      );
      expect(penalised, lessThan(0.70));
    });

    test('clamps score between 0.0 and 1.0', () {
      final clampedMax = scorer.updateConfidence(
        currentScore: 0.95,
        signalType: ExtractionSignalType.dialogueTag,
        signalConfirms: true,
        mentionCount: 1,
      );
      expect(clampedMax, lessThanOrEqualTo(1.0));

      final clampedMin = scorer.updateConfidence(
        currentScore: 0.05,
        signalType: ExtractionSignalType.activeContradiction,
        signalConfirms: false,
        mentionCount: 1,
      );
      expect(clampedMin, greaterThanOrEqualTo(0.0));
    });
  });
}

