import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/presentation/utils/chapter_position_resolver.dart';

void main() {
  const resolver = ChapterPositionResolver();

  const sample = 'Hello world. This is good.\n\n'
      'A second paragraph.\n'
      'With two sentences. And more here?';

  group('sentenceStartOffsets', () {
    test('returns one offset per sentence across all paragraphs', () {
      final offsets = resolver.sentenceStartOffsets(sample);
      expect(offsets.length, 5);
    });

    test('first sentence starts at the very beginning', () {
      expect(resolver.sentenceStartOffsets(sample).first, 0);
    });

    test('skips empty paragraphs', () {
      const content = 'Alpha. Beta.\n\n\n\nGamma.';
      expect(resolver.sentenceStartOffsets(content).length, 3);
    });

    test('returns empty for empty content', () {
      expect(resolver.sentenceStartOffsets(''), isEmpty);
    });
  });

  group('totalSentences', () {
    test('counts the flat sentence sequence', () {
      expect(resolver.totalSentences(sample), 5);
      expect(resolver.totalSentences(''), 0);
    });
  });

  group('charOffsetForSentenceIndex', () {
    test('maps flat index back to the exact sentence start', () {
      expect(
        resolver.charOffsetForSentenceIndex(sample, 0),
        sample.indexOf('Hello world.'),
      );
      expect(
        resolver.charOffsetForSentenceIndex(sample, 1),
        sample.indexOf('This is good.'),
      );
      expect(
        resolver.charOffsetForSentenceIndex(sample, 2),
        sample.indexOf('A second paragraph.'),
      );
    });

    test('handles a paragraph starting mid-content', () {
      const content = 'Intro.\n\n  Second paragraph start. Body.';
      final offset = resolver.charOffsetForSentenceIndex(content, 1);
      expect(content.substring(offset!), startsWith('Second paragraph'));
    });

    test('does not split on abbreviations or decimals', () {
      const content = 'Dr. Smith ran 3.14 km. He stopped.';
      expect(resolver.totalSentences(content), 2);
      expect(
        resolver.charOffsetForSentenceIndex(content, 0),
        content.indexOf('Dr. Smith ran 3.14 km.'),
      );
      expect(
        resolver.charOffsetForSentenceIndex(content, 1),
        content.indexOf('He stopped.'),
      );
    });

    test('returns null for negative or out-of-range indices', () {
      expect(resolver.charOffsetForSentenceIndex(sample, -1), isNull);
      expect(resolver.charOffsetForSentenceIndex(sample, 99), isNull);
      expect(resolver.charOffsetForSentenceIndex('', 0), isNull);
    });
  });

  group('sentenceIndexForOffset', () {
    test('resolves offsets inside each sentence to that sentence', () {
      final hello = sample.indexOf('Hello world.');
      final midSentence = sample.indexOf('world.');
      expect(resolver.sentenceIndexForOffset(sample, hello), 0);
      expect(resolver.sentenceIndexForOffset(sample, midSentence), 0);
    });

    test('resolves the first character of a sentence to that sentence', () {
      final thisIsGood = sample.indexOf('This is good.');
      expect(resolver.sentenceIndexForOffset(sample, thisIsGood), 1);
    });

    test('clamps past-the-end offsets to the last sentence', () {
      expect(resolver.sentenceIndexForOffset(sample, sample.length), 4);
    });

    test('returns 0 for offsets before the first sentence start', () {
      expect(resolver.sentenceIndexForOffset(sample, 0), 0);
    });

    test('returns null for empty content', () {
      expect(resolver.sentenceIndexForOffset('', 0), isNull);
    });
  });

  group('round-trip', () {
    test('sentenceIndexForOffset(charOffsetForSentenceIndex(i)) == i', () {
      final total = resolver.totalSentences(sample);
      for (var i = 0; i < total; i++) {
        final offset = resolver.charOffsetForSentenceIndex(sample, i)!;
        expect(resolver.sentenceIndexForOffset(sample, offset), i,
            reason: 'round-trip failed at index $i');
      }
    });
  });
}
