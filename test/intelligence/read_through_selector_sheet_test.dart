import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/intelligence/presentation/read_through/read_through_selector_sheet.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  testWidgets('ReadThroughSelectorSheet renders and displays sessions', (tester) async {
    const bookId = 'book_ui_test_1';

    await tester.pumpWidget(
      buildTestableWidget(
        const ReadThroughSelectorSheet(bookId: bookId),
      ),
    );

    // Initial pump and wait for future to settle
    await tester.pumpAndSettle();

    // Verify session explanation banner
    expect(find.textContaining('isolated story memory graph'), findsOneWidget);

    // Verify default session is listed as ACTIVE
    expect(find.text('Primary Read'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('Start New Read-Through'), findsOneWidget);

    // Tap "Start New Read-Through"
    await tester.tap(find.text('Start New Read-Through'));
    await tester.pumpAndSettle();

    // Verify create dialog is shown
    expect(find.text('New Reading Session'), findsOneWidget);
    expect(find.text('Clone Canon Codex'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
  });
}
