import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/reader/presentation/widgets/quote_share_card_sheet.dart';

void main() {
  testWidgets('QuoteShareCardSheet renders quote card and switches themes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: QuoteShareCardSheet(
              quoteText:
                  'All we have to decide is what to do with the time that is given us.',
              bookTitle: 'The Fellowship of the Ring',
              author: 'J.R.R. Tolkien',
              chapterTitle: 'The Shadow of the Past',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and quote text
    expect(find.text('Quote Share Card'), findsOneWidget);
    expect(
      find.text(
        '“All we have to decide is what to do with the time that is given us.”',
      ),
      findsOneWidget,
    );
    expect(find.text('The Fellowship of the Ring'), findsOneWidget);
    expect(find.text('J.R.R. Tolkien'), findsOneWidget);
    expect(find.text('The Shadow of the Past'), findsOneWidget);

    // Switch theme to Midnight (Design tab is default visible)
    await tester.tap(find.text('Midnight'));
    await tester.pump();

    // Switch theme to Sunset
    await tester.tap(find.text('Sunset'));
    await tester.pump();

    // Verify tab groups render
    expect(find.text('Design'), findsOneWidget);
    expect(find.text('Typography'), findsOneWidget);

    // Go to Layout tab and switch ratio to Story 9:16
    await tester.tap(find.text('Layout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Story 9:16'));
    await tester.pump();

    // Verify copy, save, and share buttons exist
    expect(find.text('Copy Text'), findsOneWidget);
    expect(find.text('Save Image'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);

    // Go to Typography tab and toggle the quote format to Bold
    await tester.tap(find.text('Typography'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bold'));
    await tester.pump();
  });

  testWidgets('font dropdown handles a bundled reader font without crashing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'reader_font_family': 'Playfair Display',
    });
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: QuoteShareCardSheet(
              quoteText: 'A short quote.',
              bookTitle: 'A Book',
              author: 'An Author',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Previously this built with DropdownButton value pointing at the bundled
    // reader font with no matching item, throwing an assertion.
    await tester.pumpAndSettle();

    // The Typography tab contains the font dropdown (hidden by default).
    await tester.tap(find.text('Typography'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Playfair Display'), findsOneWidget);
  });
}
