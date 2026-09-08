import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/block_card/block_card_detector.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_narration_coordinator.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_selection_menu.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_span_builder.dart';
import 'package:atlas_app/reader/presentation/widgets/paged_page_view.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

Offset textOffsetToPosition(RenderParagraph paragraph, int offset) {
  const caret = Rect.fromLTWH(0.0, 0.0, 2.0, 20.0);
  final Offset localOffset = paragraph.getOffsetForCaret(TextPosition(offset: offset), caret);
  return paragraph.localToGlobal(localOffset);
}

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

    test('buildSegmentedSpans preserves inter-paragraph newlines and 1:1 offsets', () {
      const text = 'Paragraph one.\n\nParagraph two.\n\nParagraph three.';
      final spans = BlockCardDetector().processSync(text);
      expect(spans.length, 3);
      final (richSpans, renderMap) = const ChapterSpanBuilder().buildSegmentedSpans(
        spans: spans,
        content: text,
        textStyle: const TextStyle(),
        readingColors: ReadingViewTheme.paper.resolve(const ColorScheme.light()),
        fontSize: 16,
        lineHeight: 1.5,
        highlights: [],
      );
      final renderedText = richSpans.map((s) => s.toPlainText()).join();
      expect(renderedText, text);
      expect(renderMap.length, 3);
      // All offsets should map 1:1 because inter-paragraph newlines are preserved
      expect(renderMap[0], (0, 14, 0));
      expect(renderMap[1], (14, 30, 14));
      expect(renderMap[2], (30, 48, 30));
    });

    testWidgets('ChapterSelectionMenuBuilder extracts exact selection without paragraph bleeding', (tester) async {
      const paragraph1 = 'This is the first paragraph of text that we want to test in the reader.';
      const paragraph2 = 'This is the second paragraph. It contains multiple sentences for testing.';
      const fullText = '$paragraph1\n\n$paragraph2';

      final spans = BlockCardDetector().processSync(fullText);
      final textKey = GlobalKey();
      List<(int, int, int)>? capturedRenderMap;
      late SelectableRegionState capturedRegionState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              contextMenuBuilder: (context, selectableRegionState) {
                capturedRegionState = selectableRegionState;
                return const SizedBox();
              },
              child: Builder(
                builder: (context) {
                  final registrar = SelectionContainer.maybeOf(context);
                  final (richSpans, renderMap) = const ChapterSpanBuilder().buildSegmentedSpans(
                    spans: spans,
                    content: fullText,
                    textStyle: const TextStyle(fontSize: 16, height: 1.5),
                    readingColors: ReadingViewTheme.paper.resolve(const ColorScheme.light()),
                    fontSize: 16,
                    lineHeight: 1.5,
                    highlights: [],
                  );
                  capturedRenderMap = renderMap;
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      context.findAncestorStateOfType<SelectableRegionState>()?.clearSelection();
                    },
                    child: RichText(
                      key: textKey,
                      selectionRegistrar: registrar,
                      selectionColor: Colors.blue.withValues(alpha: 0.3),
                      text: TextSpan(children: richSpans),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      const target = 'contains multiple sentences';
      final renderTargetIndex = fullText.indexOf(target);
      final render = textKey.currentContext!.findRenderObject() as RenderParagraph;

      final startPos = textOffsetToPosition(render, renderTargetIndex);
      final endPos = textOffsetToPosition(render, renderTargetIndex + target.length);

      final dragGesture = await tester.startGesture(startPos);
      addTearDown(dragGesture.removePointer);
      await tester.pump(const Duration(milliseconds: 500));
      await dragGesture.moveTo(endPos);
      await tester.pump(const Duration(milliseconds: 50));
      await dragGesture.up();
      await tester.pumpAndSettle();

      expect(render.selections, isNotEmpty);
      expect(render.selections.first.isCollapsed, isFalse);

      final menuWidget = const ChapterSelectionMenuBuilder().buildContextMenu(
        context: textKey.currentContext!,
        selectableRegionState: capturedRegionState,
        content: fullText,
        bookId: 'b1',
        chapterId: 'c1',
        chapterTitle: 'Test Chapter',
        highlights: const [],
        renderContentMap: capturedRenderMap,
        renderParagraph: render,
      );
      expect(menuWidget, isNotNull);

      // Verify that the selection accurately captures the target phrase and does not bleed into the rest of the paragraph
      final sel = render.selections.first;
      final startRender = math.min(sel.baseOffset, sel.extentOffset);
      final endRender = math.max(sel.baseOffset, sel.extentOffset);
      final gStart = ChapterSelectionMenuBuilder.contentOffsetFromRenderOffset(startRender, capturedRenderMap);
      final gEnd = ChapterSelectionMenuBuilder.contentOffsetFromRenderOffset(endRender, capturedRenderMap);
      expect(gStart, isNotNull);
      expect(gEnd, isNotNull);
      final extracted = fullText.substring(gStart!, gEnd!).trim();
      expect(extracted, target);

      // Tap on unselected space inside SelectionArea:
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(render.selections.isEmpty || render.selections.first.isCollapsed, isTrue);
    });

    test('ChapterNarrationCoordinator renderOffsetFromContentOffset translates content offsets across cards', () {
      const coordinator = ChapterNarrationCoordinator();
      // Suppose map has 2 prose segments with a block card in between:
      // Prose 1: content [0..50) -> render [0..50)
      // Card: in content [50..150), replaced by 3 render chars [50..53)
      // Prose 2: content [150..250) -> render [53..153)
      final map = <(int, int, int)>[
        (0, 50, 0),
        (53, 153, 150),
      ];

      // Content offset 25 (inside prose 1) -> render offset 25
      expect(coordinator.renderOffsetFromContentOffset(25, map), 25);

      // Content offset 170 (20 chars into prose 2) -> render offset 53 + 20 = 73
      expect(coordinator.renderOffsetFromContentOffset(170, map), 73);

      // Content offset 100 (inside the card gap) -> maps to start of following segment (53)
      expect(coordinator.renderOffsetFromContentOffset(100, map), 53);

      // Content offset with empty map -> returns itself
      expect(coordinator.renderOffsetFromContentOffset(40, null), 40);
    });

    test('ChapterSpanBuilder buildSegmentedSpans does not treat leading newlines as drop cap', () {
      const builder = ChapterSpanBuilder();
      const content = '\n\nOnce upon a time in a faraway kingdom.';
      final spans = [
        const ContentSpan.prose('Once upon a time in a faraway kingdom.'),
      ];
      final (richSpans, _) = builder.buildSegmentedSpans(
        spans: spans,
        content: content,
        textStyle: const TextStyle(fontSize: 16),
        readingColors: const ReadingColors(
          text: Colors.black,
          background: Colors.white,
          accent: Colors.blue,
          surface: Colors.white,
        ),
        fontSize: 16,
        lineHeight: 1.5,
        highlights: const [],
        dropCapStyle: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
        applyDropCap: true,
      );

      // First span should be the drop-capped 'O', NOT '\n'
      final firstSpan = richSpans.first as TextSpan;
      expect(firstSpan.text, 'O');
      expect(firstSpan.style?.fontSize, 48);
    });

    testWidgets('PagedPageView triggers onTap when tapping on empty margins/space outside text', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 800,
              child: PagedPageView(
                content: 'Short page text.',
                chapterTitle: 'Chapter 1',
                chapterIndex: 0,
                isFirstPageOfChapter: false,
                isLastPageOfChapter: false,
                textStyle: const TextStyle(fontSize: 16),
                textAlignment: TextAlignment.left,
                marginPreset: MarginPreset.normal,
                vt: ReadingViewTheme.paper,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap at empty space (well below the short text which is at the top)
      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });
}
