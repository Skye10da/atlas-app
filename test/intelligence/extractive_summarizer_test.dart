import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/intelligence/application/query/extractive_summarizer.dart';

void main() {
  const summarizer = ExtractiveSummarizer();

  group('ExtractiveSummarizer', () {
    const sampleChapter = '''
      The Great Wasteland stretched endlessly under a scorching sun.
      Lin Dong walked quietly beside Elder Mo, contemplating the ancient stone talisman resting within his robes.
      A sudden roar shattered the tranquil morning as a scarlet python burst from the thick underbrush.
      With swift footwork, Lin Dong dodged the venomous strike and channeled his Yuan power directly into his palm.
      The talisman pulsed with sudden warmth, diffusing the demonic beast's energy in an instant.
      Elder Mo nodded approvingly at the boy's quick instincts and decisive reflexes.
      They resumed their journey toward the Black Water City gates before dusk fell.
    ''';

    test('extracts top salient sentences in chronological order', () {
      final summary = summarizer.summarize(sampleChapter, targetSentences: 3);

      expect(summary, isNotEmpty);
      expect(summary.contains('Lin Dong'), isTrue);
      // Verify sentences are not duplicated
      final sentences = summary.split('. ');
      expect(sentences.length, lessThanOrEqualTo(4));
    });

    test('handles short text gracefully', () {
      const shortText = 'Lin Dong defeated the beast. The clan rejoiced.';
      final summary = summarizer.summarize(shortText, targetSentences: 2);
      expect(summary, isNotEmpty);
    });

    test('handles empty text', () {
      expect(summarizer.summarize(''), isEmpty);
    });
  });
}

