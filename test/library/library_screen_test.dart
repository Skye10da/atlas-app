import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/library/presentation/screens/library_screen.dart';

BooksCompanion _book({
  required String id,
  required String title,
  String? author,
  ContentCategory itemType = ContentCategory.novel,
  int totalChapters = 10,
}) => BooksCompanion(
  id: Value(id),
  title: Value(title),
  author: author != null ? Value(author) : const Value.absent(),
  format: const Value('epub'),
  itemType: Value(itemType.name),
  filePath: const Value('/fake/path'),
  totalChapters: Value(totalChapters),
  createdAt: Value(DateTime(2026, 1, 1)),
  updatedAt: Value(DateTime(2026, 1, 1)),
);

void main() {
  group('LibraryScreen mobile/tablet UI', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.memory();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('shows category selector and search on mobile screen width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await db.into(db.books).insert(
        _book(
          id: 'n1',
          title: 'Solo Leveling',
          itemType: ContentCategory.novel,
        ),
      );
      await db.into(db.books).insert(
        _book(
          id: 'b1',
          title: 'Clean Code',
          itemType: ContentCategory.book,
        ),
      );

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

      await tester.pumpAndSettle();

      // Verify category selector (Novels / Books) is visible on mobile
      expect(find.text('Novels'), findsOneWidget);
      expect(find.text('Books'), findsOneWidget);

      // Default category is novels, so Solo Leveling should be visible
      expect(find.text('Solo Leveling'), findsWidgets);
      expect(find.text('Clean Code'), findsNothing);

      // Switch category to Books
      await tester.tap(find.text('Books'));
      await tester.pumpAndSettle();

      expect(find.text('Clean Code'), findsWidgets);
      expect(find.text('Solo Leveling'), findsNothing);

      // Tap search icon to toggle search bar
      final searchIcon = find.byTooltip('Search library');
      expect(searchIcon, findsOneWidget);
      await tester.tap(searchIcon);
      await tester.pumpAndSettle();

      // Search bar should now appear
      expect(find.byType(TextField), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Clean');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Clean Code'), findsWidgets);

      // Enter non-matching query
      await tester.enterText(find.byType(TextField), 'NonExistent');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('No results found'), findsOneWidget);
      expect(find.text('Clear search'), findsOneWidget);

      // Tap Clear search
      await tester.tap(find.text('Clear search'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Clean Code'), findsWidgets);

      // Close search bar
      await tester.tap(find.byTooltip('Close search'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);

      // Cleanly unmount and settle timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    });

    testWidgets('shows category selector and search on tablet screen width', (
      tester,
    ) async {
      // Tablet width (600 <= width < 900)
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await db.into(db.books).insert(
        _book(
          id: 'n1',
          title: 'Omniscient Reader',
          itemType: ContentCategory.novel,
        ),
      );
      await db.into(db.books).insert(
        _book(
          id: 'b1',
          title: 'Design Patterns',
          itemType: ContentCategory.book,
        ),
      );

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

      await tester.pumpAndSettle();

      // Verify category selector (Novels / Books) is visible on tablet
      expect(find.text('Novels'), findsOneWidget);
      expect(find.text('Books'), findsOneWidget);

      expect(find.text('Omniscient Reader'), findsWidgets);
      expect(find.text('Design Patterns'), findsNothing);

      // Switch to Books
      await tester.tap(find.text('Books'));
      await tester.pumpAndSettle();

      expect(find.text('Design Patterns'), findsWidgets);
      expect(find.text('Omniscient Reader'), findsNothing);

      // Cleanly unmount and settle timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    });
  });
}

