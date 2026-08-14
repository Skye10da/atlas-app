import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/library/presentation/widgets/import_progress_dialog.dart';

void main() {
  late BuildContext testContext;

  group('showImportCompleteDialog', () {
    testWidgets('"Go to novel" returns true', (widgetTester) async {
      await widgetTester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          testContext = context;
          return const SizedBox();
        }),
      ));
      final future = showImportCompleteDialog(
        testContext,
        category: ContentCategory.novel,
      );
      await widgetTester.pumpAndSettle();

      expect(find.text('Novel added'), findsOneWidget);
      expect(find.text('Stay'), findsOneWidget);
      expect(find.text('Go to novel'), findsOneWidget);

      await widgetTester.tap(find.text('Go to novel'));
      await widgetTester.pumpAndSettle();

      expect(await future, isTrue);
    });

    testWidgets('"Stay" returns false', (widgetTester) async {
      await widgetTester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          testContext = context;
          return const SizedBox();
        }),
      ));
      final future = showImportCompleteDialog(
        testContext,
        category: ContentCategory.novel,
      );
      await widgetTester.pumpAndSettle();

      await widgetTester.tap(find.text('Stay'));
      await widgetTester.pumpAndSettle();

      expect(await future, isFalse);
    });

    testWidgets('labels a book import as "Go to book"', (widgetTester) async {
      await widgetTester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          testContext = context;
          return const SizedBox();
        }),
      ));
      final future = showImportCompleteDialog(
        testContext,
        category: ContentCategory.book,
      );
      await widgetTester.pumpAndSettle();

      expect(find.text('Book added'), findsOneWidget);
      expect(find.text('Go to book'), findsOneWidget);
      expect(find.text('Go to novel'), findsNothing);

      await widgetTester.tap(find.text('Go to book'));
      await widgetTester.pumpAndSettle();

      expect(await future, isTrue);
    });
  });
}
