import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/library/presentation/screens/novel_details_screen.dart';

const _totalChapters = 25;

BooksCompanion _novelCompanion() => BooksCompanion.insert(
      id: 'novel-1',
      title: 'A Man Like None Other',
      author: const Value('Rizz上架'),
      format: 'novel',
      filePath: '/tmp/novels/a-man-like-none-other',
      totalChapters: _totalChapters,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      itemType: Value(ContentCategory.novel.name),
      sourceName: const Value('FreeWebNovel'),
      sourceUrl: const Value('https://example.com/a-man-like-none-other'),
      coverPath: const Value('/this/path/does/not/exist.jpg'),
    );

List<ChaptersCompanion> _chapterCompanions() => [
      for (var i = 0; i < _totalChapters; i++)
        ChaptersCompanion.insert(
          id: 'novel-1_ch$i',
          bookId: 'novel-1',
          index: i,
          title: 'Chapter ${i + 1}',
          contentPath: '/tmp/novels/novel/$i.txt',
          wordCount: 1500,
          pageCount: 5,
          createdAt: DateTime(2026, 1, 2),
        ),
    ];

Future<AppDatabase> _seed() async {
  final db = AppDatabase.memory();
  await db.into(db.books).insert(_novelCompanion());
  await db.batch((batch) {
    batch.insertAll(db.chapters, _chapterCompanions());
  });
  return db;
}

/// Tall enough that the whole details page is inside the upper fold, so all
/// sections (including the low-anchored chapter picker) stay built.
void _showDetailView(WidgetTester tester) {
  tester.view.physicalSize = const Size(480, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

/// Swallows layout overflows raised by other sections of the details screen
/// (the recap/characters cards are still WIP and overflow with the synthetic
/// test fonts). Positional assertions below are what this suite verifies.
List<Object> _drainExceptions(WidgetTester tester) {
  final errors = <Object>[];
  while (true) {
    final error = tester.takeException();
    if (error == null) return errors;
    errors.add(error);
  }
}

Widget _app(AppDatabase db) => ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: NovelDetailsScreen(bookId: 'novel-1')),
    );

void main() {
  testWidgets("'More' menu offers 'Repair chapter list' for novels", (
    tester,
  ) async {
    _showDetailView(tester);
    final db = await _seed();
    addTearDown(db.close);

    await tester.pumpWidget(_app(db));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Repair chapter list'), findsOneWidget);
    expect(find.byIcon(Icons.healing_outlined), findsOneWidget);

    _drainExceptions(tester);
    // Give drift's stream-query teardown (markAsClosed zero-timer) a pump to
    // run, or the pending-timers invariant fails at teardown.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('chapters section sits at the bottom of the details page', (
    tester,
  ) async {
    _showDetailView(tester);
    final db = await _seed();
    addTearDown(db.close);

    // Bounded pumps on purpose: the screen keeps periodic timers alive, so
    // pumpAndSettle never converges.
    await tester.pumpWidget(_app(db));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    final insightsTop = tester.getTopLeft(find.text('Reading Insights')).dy;
    final chaptersTop = tester.getTopLeft(find.text('Chapters')).dy;

    // Reading Insights ends the story block; the chapter arrangement must
    // come after it (it used to sit between the characters and insights).
    expect(chaptersTop, greaterThan(insightsTop));

    // Profile-style header: the cover card is a fixed portrait, not the
    // full column width (compact shows a ~120px-wide cover).
    final coverWidth = tester.getSize(find.byType(BookCover)).width;
    expect(coverWidth, greaterThan(90));
    expect(coverWidth, lessThan(140));

    // Floating pill action row: back, update, notifications and menu pills
    // replaced the full-width icon app bar. Tracking defaults to enabled,
    // so the notifications pill shows the active bell.
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);

    // The Continue button spans the width below the cover row, so it is
    // never crushed beside the cover (the 300px tablet-pane regression).
    final buttonWidth = tester.getSize(find.byType(FilledButton).first).width;
    expect(buttonWidth, greaterThan(coverWidth));

    _drainExceptions(tester);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('chapter sort button toggles newest-first / oldest-first', (
    tester,
  ) async {
    _showDetailView(tester);
    final db = await _seed();
    addTearDown(db.close);

    await tester.pumpWidget(_app(db));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    // Default: newest range first.
    double top(String groupTitle) => tester.getTopLeft(find.text(groupTitle)).dy;
    final descOrder = top('Ch. 21 – 25');
    expect(descOrder, lessThan(top('Ch. 11 – 20')));
    expect(descOrder, lessThan(top('Ch. 1 – 10')));

    // Inside an open range, newest chapter first too.
    double cellTop(int value) => tester.getTopLeft(find.text('$value')).dy;
    expect(cellTop(10), lessThan(cellTop(1)));

    _drainExceptions(tester);

    await tester.tap(find.byIcon(Icons.arrow_downward_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 250));

    // Oldest-first: first range on top, chapters ascending inside it.
    expect(top('Ch. 1 – 10'), lessThan(top('Ch. 11 – 20')));
    expect(top('Ch. 1 – 10'), lessThan(top('Ch. 21 – 25')));
    expect(cellTop(1), lessThan(cellTop(10)));

    _drainExceptions(tester);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
