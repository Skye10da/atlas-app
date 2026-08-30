import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/providers/annotations_provider.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_annotations_sheet.dart';

void main() {
  testWidgets('ReaderAnnotationsSheet displays highlights and notes, filters query',
      (tester) async {
    final container = ProviderContainer();
    final controller = container.read(annotationsProvider('book-1').notifier);

    controller.addHighlight(
      chapterId: 'c1',
      start: 0,
      end: 20,
      text: 'Gandalfs secret weapon',
      colorValue: 0xFFFF5500,
      styleType: HighlightStyleType.wavy,
    );

    controller.addNote(
      chapterId: 'c1',
      text: 'Remember this prophecy',
      sentence: 'The stars shine on the hour of our meeting.',
      tags: ['Prophecy'],
    );

    final chapters = [
      const ChapterEntity(
        id: 'c1',
        bookId: 'book-1',
        title: 'Chapter 1',
        index: 0,
        contentPath: '/path/to/c1.txt',
      ),
    ];

    String? jumpedChapter;
    int? jumpedOffset;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ReaderAnnotationsSheet(
              bookId: 'book-1',
              chapters: chapters,
              currentChapterId: 'c1',
              bookTitle: 'The Fellowship',
              onJumpToChapter: (chId, offset) {
                jumpedChapter = chId;
                jumpedOffset = offset;
              },
            ),
          ),
        ),
      ),
    );

    // Verify both are listed under "All"
    expect(find.text('Remember this prophecy'), findsOneWidget);
    expect(find.text('“Gandalfs secret weapon”'), findsOneWidget);
    expect(find.text('#Prophecy'), findsOneWidget);

    // Test filter query
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'secret');
    await tester.pump();

    expect(find.text('“Gandalfs secret weapon”'), findsOneWidget);
    expect(find.text('Remember this prophecy'), findsNothing);

    // Tap on the highlight card to jump
    await tester.tap(find.text('“Gandalfs secret weapon”'));
    await tester.pumpAndSettle();

    expect(jumpedChapter, 'c1');
    expect(jumpedOffset, 0);
  });
}

