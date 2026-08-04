import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/speech/parser/sentence_splitter.dart';

void main() {
  const splitter = SentenceSplitter();

  group('SentenceSplitter.splitChapter', () {
    test('splits paragraphs into sentences and sets indices', () {
      final items = splitter.splitChapter(
        bookId: 'b1',
        chapterId: 'c1',
        paragraphs: const ['Hello world. This is good.', 'A second paragraph. With two sentences.'],
        language: 'en-US',
      );

      expect(items.length, 4);
      expect(items[0].paragraphIndex, 0);
      expect(items[0].sentenceIndex, 0);
      expect(items[0].text, 'Hello world.');
      expect(items[1].paragraphIndex, 0);
      expect(items[1].sentenceIndex, 1);
      expect(items[1].text, 'This is good.');
      expect(items[2].paragraphIndex, 1);
      expect(items[2].sentenceIndex, 0);
      expect(items[2].text, 'A second paragraph.');
      expect(items[3].text, 'With two sentences.');
    });

    test('does not split on decimals or abbreviations', () {
      final items = splitter.splitChapter(
        bookId: 'b1',
        chapterId: 'c1',
        paragraphs: const ['The value is 3.14 and Dr. Smith arrived at 9.30 pm.'],
        language: 'en-US',
      );

      expect(items.length, 1);
      expect(items.first.text, 'The value is 3.14 and Dr. Smith arrived at 9.30 pm.');
    });

    test('splits on multiple terminators', () {
      final items = splitter.splitChapter(
        bookId: 'b1',
        chapterId: 'c1',
        paragraphs: const ['Go! Why? Because.', ''],
        language: 'en-US',
      );

      expect(items.map((i) => i.text).toList(), ['Go!', 'Why?', 'Because.']);
    });

    test('hard-splits sentences longer than the cap near a word boundary', () {
      final long = '${'word ' * 2000}x';
      final items = splitter.splitChapter(
        bookId: 'b1',
        chapterId: 'c1',
        paragraphs: [long],
        language: 'en-US',
      );

      expect(items.length, greaterThan(1));
      for (final item in items) {
        expect(item.text.length, lessThanOrEqualTo(SentenceSplitter.maxChunkChars));
      }
    });

    test('propagates language and voiceId to items', () {
      final items = splitter.splitChapter(
        bookId: 'b1',
        chapterId: 'c1',
        paragraphs: const ['Hi there.'],
        language: 'en-AU',
        voiceId: 'voice@en-AU',
      );

      expect(items.first.language, 'en-AU');
      expect(items.first.voiceId, 'voice@en-AU');
    });
  });

  group('SentenceSplitter.splitParagraphSpans', () {
    test('reports each sentence offset within the paragraph', () {
      final spans = splitter.splitParagraphSpans('Hello world. This is good.');
      expect(spans.map((s) => s.text).toList(), ['Hello world.', 'This is good.']);
      expect(spans[0].offset, 0);
      expect(spans[1].offset, 13); // "Hello world. " is 13 chars
    });

    test('offsets include leading space trimmed off each sentence', () {
      const paragraph = 'Go now. Then run!';
      final spans = splitter.splitParagraphSpans(paragraph);
      expect(spans[0].text, 'Go now.');
      expect(spans[0].offset, 0);
      expect(spans[1].text, 'Then run!');
      expect(spans[1].offset, 8); // "Go now. " is 8 chars
    });

    test('stays consistent with splitChapter indices after abbreviations', () {
      const paragraph = 'Dr. Smith went. He spoke to Jane.';
      final items = splitter.splitChapter(
        bookId: 'b1',
        chapterId: 'c1',
        paragraphs: const [paragraph],
        language: 'en-US',
      );
      final spans = splitter.splitParagraphSpans(paragraph);
      expect(items.length, 2);
      expect(items[0].text, spans[0].text);
      expect(items[1].text, spans[1].text);
      // The second item should start right after "Dr. Smith went. "
      expect(spans[1].offset, paragraph.indexOf(items[1].text));
    });

    test('resolves a repeated name to its own occurrence, not the first', () {
      const p0 = 'John went home.';
      const p1 = 'He met John again.';
      const p2 = 'John said hi.';
      const content = '$p0\n\n$p1\n\n$p2';

      // Mirror SpeechSessionBuilder paragraph split to pin offsets.
      final segments = <(int, String)>[];
      final breaks = RegExp(r'\n\s*\n');
      var segStart = 0;
      for (final m in breaks.allMatches(content)) {
        final seg = content.substring(segStart, m.start);
        if (seg.trim().isNotEmpty) segments.add((segStart, seg));
        segStart = m.end;
      }
      final tail = content.substring(segStart);
      if (tail.trim().isNotEmpty) segments.add((segStart, tail));

      // Third paragraph, first sentence -> must point at "John said hi.", not the opener.
      final (segOffset, segRaw) = segments[2];
      final para = segRaw.trim();
      final start = segOffset + segRaw.indexOf(para) +
          splitter.splitParagraphSpans(para).first.offset;
      expect(content.substring(start, start + p2.length), p2);
    });
  });
}