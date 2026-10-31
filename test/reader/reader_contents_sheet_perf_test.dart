import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_index_sheet.dart';

List<ChapterEntity> _chapters(int n) => [
  for (var i = 0; i < n; i++)
    ChapterEntity(
      id: 'ch-$i',
      bookId: 'perf-book',
      index: i,
      title: 'Chapter ${i + 1}',
      contentPath: 'ch-$i.md',
      totalChapters: n,
    ),
];

/// Regression guard for the chapter-list first-frame cost.
///
/// The open of the sheet once laid out every row from index 0 up to the
/// initial scroll offset because [ChapterIndexSheet]'s ListView had no
/// `itemExtent` (~2.3 ms/row in debug ⇒ ~5 s at 2000 chapters, 12 s at 5000).
/// With the fixed 57 px extent the whole open stays under a quarter second
/// regardless of book length. The bound below is generous (~30× baseline)
/// but still trips if the extent is ever dropped again.
void main() {
  testWidgets('chapter sheet first frame stays cheap on a huge book', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;

    const count = 4000;
    final chapters = _chapters(count);
    const current = count ~/ 2;

    final sw = Stopwatch()..start();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChapterIndexSheet(
            chapters: chapters,
            currentChapterIndex: current,
            onChapterTap: (_) {},
          ),
        ),
      ),
    );
    final openMs = sw.elapsedMilliseconds;
    // ignore: avoid_print
    print('chapter sheet first frame: $openMs ms at $count chapters');

    // Only catches the no-itemExtent regression (~10 s in debug), never a
    // healthy build (~0.3 s with ~28x headroom).
    expect(openMs, lessThan(8000));

    // The current chapter's row is the one materialized on screen.
    expect(find.text('Chapter ${current + 1}'), findsOneWidget);
  });
}
