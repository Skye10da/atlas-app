import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/screens/library_screen.dart';
import 'package:atlas_app/library/presentation/widgets/book_card.dart';
import 'package:atlas_app/library/presentation/widgets/bookshelf_grid.dart';

BookEntity _book(String id, String title) => BookEntity(
      id: id,
      title: title,
      author: 'Author $id',
      format: 'epub',
      totalChapters: 50,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      // Exercises the progress overlay on the cover.
      progress: 0.42,
      lastOpenedAt: DateTime(2026, 1, 2),
    );

BooksCompanion _dbBook({required String id, required String title}) =>
    BooksCompanion(
      id: Value(id),
      title: Value(title),
      author: const Value('Author'),
      format: const Value('epub'),
      itemType: Value(ContentCategory.novel.name),
      filePath: const Value('/fake/path'),
      totalChapters: const Value(10),
      createdAt: Value(DateTime(2026, 1, 1)),
      updatedAt: Value(DateTime(2026, 1, 1)),
      lastOpenedAt: Value(DateTime(2026, 1, 2)),
    );

/// Collects every exception raised so far, so one overflow does not hide
/// another (a single [WidgetTester.takeException] only returns the first).
List<Object> _drainExceptions(WidgetTester tester) {
  final errors = <Object>[];
  while (true) {
    final error = tester.takeException();
    if (error == null) return errors;
    errors.add(error);
  }
}

void main() {
  testWidgets(
    'grid tiles leave room for cover and info at narrow desktop width',
    (tester) async {
      // 439px: the width the grid gets on desktop while the 400px
      // book detail panel is open.
      tester.view.physicalSize = const Size(439, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookshelfGrid(
              books: [
                _book('n1', "Villain's Path: Transmigrated with an SSS+ Luck Stat"),
                _book('n2', 'A Second Novel With A Rather Long Title'),
              ],
              isDesktop: true,
              isTablet: false,
              onBookTap: (_) {},
              onBookLongPress: (_, _) {},
              onDeleteBook: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_drainExceptions(tester), isEmpty);
    },
  );

  testWidgets('grid tiles fit at mobile width', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookshelfGrid(
            books: [
              _book('n1', "Villain's Path: Transmigrated with an SSS+ Luck Stat"),
              _book('n2', 'A Second Novel With A Rather Long Title'),
              _book('n3', 'Third Book'),
            ],
            isDesktop: false,
            isTablet: false,
            onBookTap: (_) {},
            onBookLongPress: (_, _) {},
            onDeleteBook: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_drainExceptions(tester), isEmpty);
  });

  testWidgets(
    'library screen lays out without overflow on a narrow window',
    (tester) async {
      tester.view.physicalSize = const Size(240, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = AppDatabase.memory();
      addTearDown(db.close);
      await db.into(db.books).insert(_dbBook(id: 'n1', title: 'Solo Leveling'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: LibraryScreen(),
          ),
        ),
      );
      // Bounded pumps on purpose: the first frame already lays out and paints
      // the whole screen, which is what surfaces render overflows. pumpAndSettle
      // never converges here because the screen keeps a periodic timer alive.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The Library home now leads with the personalised header + continue
      // hero; the shelf heading sits further down the scroll and may not be
      // built at this tiny window size. Assert the home content instead.
      expect(find.text('CONTINUE'), findsOneWidget);
      expect(_drainExceptions(tester), isEmpty);

      // Unmount so the screen's periodic timers are cancelled.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'grid tiles fit with Windows-style non-linear font scaling',
    (tester) async {
      // Windows delivers a non-linear text scaler: scale(1) is ~0.625 at
      // common display scales, but body-size fonts (the 12px info text)
      // render unscaled. Estimating the tile's info-height budget from
      // scale(1) therefore underestimates and overflows the tile Column;
      // this reproduces that environment exactly.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: _WindowsLikeScaler()),
            child: Scaffold(
              body: BookshelfGrid(
                books: [
                  _book(
                    'n1',
                    "Villain's Path: Transmigrated with an SSS+ Luck Stat",
                  ),
                  _book('n2', 'A Second Novel With A Rather Long Title'),
                  _book('n3', 'A Man Like None Other'),
                ],
                isDesktop: false,
                isTablet: false,
                onBookTap: (_) {},
                onBookLongPress: (_, _) {},
                onDeleteBook: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_drainExceptions(tester), isEmpty);
    },
  );

  testWidgets('grid survives a window resize between frames', (tester) async {
    tester.view.physicalSize = const Size(439, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookshelfGrid(
            books: [
              _book('n1', "Villain's Path: Transmigrated with an SSS+ Luck Stat"),
              _book('n2', 'A Second Novel With A Rather Long Title'),
              _book('n3', 'Third Book'),
            ],
            isDesktop: true,
            isTablet: false,
            onBookTap: (_) {},
            onBookLongPress: (_, _) {},
            onDeleteBook: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_drainExceptions(tester), isEmpty);

    // Shrink the window the way the startup window-manager resize and split
    // pane do, and lay the same tiles out at the narrower width.
    tester.view.physicalSize = const Size(340, 800);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_drainExceptions(tester), isEmpty);
  });

  testWidgets('columns capped by book count still produce fitting tiles', (
    tester,
  ) async {
    // 900px wide: plenty of room for 6+ columns, only 2 books offered.
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookshelfGrid(
            books: [
              _book('n1', 'A Man Like None Other'),
              _book('n2', 'A Second Novel With A Rather Long Title'),
            ],
            isDesktop: true,
            isTablet: false,
            onBookTap: (_) {},
            onBookLongPress: (_, _) {},
            onDeleteBook: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // With the tile width derived from the capped column count, each tile
    // spans about half the row and still fits its planned mainAxisExtent.
    final tiles = tester.widgetList<BookGridCard>(find.byType(BookGridCard));
    for (final tile in tiles) {
      expect(tile.coverWidth, greaterThan(150.0 * 2.5));
      expect(
        tile.coverHeight,
        closeTo(tile.coverWidth! * (225.0 / 150.0), 0.1),
      );
    }

    expect(_drainExceptions(tester), isEmpty);
  });
}

/// Non-linear text scaler mimicking Windows' font scaling curve: sub-2px
/// fonts are scaled down while body-size fonts pass through unscaled, so
/// `scale(1) != scale(12) / 12`.
class _WindowsLikeScaler extends TextScaler {
  const _WindowsLikeScaler();

  @override
  double scale(double fontSize) => fontSize <= 1.0 ? 0.625 : fontSize;

  @override
  double get maxScalingFactor => 1.0;

  @override
  double get minScalingFactor => 0.625;

  @override
  @Deprecated('Use scale instead.')
  double get textScaleFactor => 0.625;

  @override
  bool operator ==(Object other) => other is _WindowsLikeScaler;

  @override
  int get hashCode => 0.625.hashCode;
}