import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_selection_menu.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_span_builder.dart';

void main() {
  group('ChapterSpanBuilder', () {
    const builder = ChapterSpanBuilder();

    test('findQuoteRanges detects straight and typographic curly double quotes', () {
      const text = 'He said, "Hello there!" and she replied, “General Kenobi!”';
      final ranges = builder.findQuoteRanges(text);

      expect(ranges.length, 2);
      expect(text.substring(ranges[0].$1, ranges[0].$2), '"Hello there!"');
      expect(text.substring(ranges[1].$1, ranges[1].$2), '“General Kenobi!”');
    });

    test('buildQuoteAwareSpans italicizes quotes and applies highlight color', () {
      const text = 'Normal text. "Quoted text." Highlighted.';
      const baseStyle = TextStyle(fontSize: 16, color: Colors.black);
      const highlight = HighlightEntry(
        chapterId: 'ch1',
        start: 28,
        end: 39,
        text: 'Highlighted',
        colorValue: 0xFFFFF176,
      );

      final spans = builder.buildQuoteAwareSpans(
        text,
        0,
        text.length,
        baseStyle,
        highlights: [highlight],
      );

      expect(spans, isNotEmpty);

      // Verify the quote span is italicized
      final quoteSpan = spans.firstWhere(
        (s) => s.text == '"Quoted text."',
        orElse: () => const TextSpan(),
      );
      expect(quoteSpan.style?.fontStyle, FontStyle.italic);

      // Verify normal text is not italicized
      final normalSpan = spans.firstWhere(
        (s) => s.text == 'Normal text. ',
        orElse: () => const TextSpan(),
      );
      expect(normalSpan.style?.fontStyle, isNot(FontStyle.italic));

      // Verify highlighted text has background color
      final highlightedSpan = spans.firstWhere(
        (s) => s.text == 'Highlighted',
        orElse: () => const TextSpan(),
      );
      expect(highlightedSpan.style?.backgroundColor, isNotNull);
    });
  });

  group('ChapterSelectionMenuBuilder', () {
    test('sentenceAround extracts enclosing sentence bounded by punctuation', () {
      const full = 'First sentence. The quick brown fox jumps! Third sentence?';
      // Select "brown fox"
      final sel = TextSelection(
        baseOffset: full.indexOf('brown'),
        extentOffset: full.indexOf('fox') + 3,
      );

      final sentence = ChapterSelectionMenuBuilder.sentenceAround(full, sel);
      expect(sentence, 'The quick brown fox jumps!');
    });

    test('contentOffsetFromRenderOffset maps segmented boundaries correctly', () {
      // In segmented mode: renderMap has (renderStart, renderEnd, contentStart)
      final renderMap = [
        (0, 10, 0), // prose 0..10 maps to content 0..10
        (11, 21, 25), // prose 11..21 maps to content 25..35 (after a card of length 15)
      ];

      // Offset inside first chunk
      expect(
        ChapterSelectionMenuBuilder.contentOffsetFromRenderOffset(5, renderMap),
        5,
      );

      // Offset inside second chunk
      expect(
        ChapterSelectionMenuBuilder.contentOffsetFromRenderOffset(15, renderMap),
        29, // 25 + (15 - 11) = 29
      );

      // Offset in card gap clamps to start of next prose chunk
      expect(
        ChapterSelectionMenuBuilder.contentOffsetFromRenderOffset(10, renderMap),
        10,
      );
    });
  });
}
