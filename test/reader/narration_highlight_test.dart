import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/presentation/widgets/chapter_narration_coordinator.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/paged_page_view.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

void main() {
  group('Narration Paragraph and Sentence Highlighting', () {
    const content =
        'Paragraph one sentence one. Paragraph one sentence two.\n\n'
        'Paragraph two sentence one. Paragraph two sentence two.\n\n'
        'Paragraph three sentence one.';

    const item = SpeechItem(
      bookId: 'b1',
      chapterId: 'c1',
      paragraphIndex: 1,
      sentenceIndex: 0,
      text: 'Paragraph two sentence one.',
      language: 'en',
    );

    test('ChapterNarrationCoordinator resolves paragraph range and sentence offset', () {
      const coordinator = ChapterNarrationCoordinator();

      final speechOffset = coordinator.resolveActiveSpeechOffset(
        item: item,
        content: content,
      );
      expect(speechOffset, equals(content.indexOf('Paragraph two sentence one.')));

      final paraRange = coordinator.resolveActiveParagraphRange(
        item: item,
        content: content,
      );
      expect(paraRange, isNotNull);
      expect(
        content.substring(paraRange!.start, paraRange.end),
        equals('Paragraph two sentence one. Paragraph two sentence two.'),
      );
    });

    testWidgets('ChapterView renders narration highlighted spans for paragraph and sentence', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChapterView(
                content: content,
                bookId: 'b1',
                chapterId: 'c1',
                activeSpeechItem: item,
                scrollable: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RichText), findsOneWidget);
      final richText = tester.widget<RichText>(find.byType(RichText));
      final rootSpan = richText.text as TextSpan;
      expect(rootSpan.children, isNotEmpty);
    });

    testWidgets('PagedPageView renders narration highlights on the active page', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PagedPageView(
                content: content,
                chapterTitle: 'Chapter 1',
                chapterIndex: 0,
                bookId: 'b1',
                chapterId: 'c1',
                pageStartOffset: 0,
                activeSpeechItem: item,
                fullChapterContent: content,
                isFirstPageOfChapter: true,
                isLastPageOfChapter: true,
                textStyle: TextStyle(fontSize: 16),
                textAlignment: TextAlignment.left,
                marginPreset: MarginPreset.normal,
                vt: ReadingViewTheme.paper,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SelectableText), findsOneWidget);
      final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));
      final rootSpan = selectableText.textSpan!;
      expect(rootSpan.children, isNotEmpty);
    });
  });
}

