import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/presentation/widgets/quote_share_card_sheet.dart';

void main() {
  testWidgets('QuoteShareCardSheet renders quote card and switches themes',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuoteShareCardSheet(
            quoteText: 'All we have to decide is what to do with the time that is given us.',
            bookTitle: 'The Fellowship of the Ring',
            author: 'J.R.R. Tolkien',
            chapterTitle: 'The Shadow of the Past',
          ),
        ),
      ),
    );

    // Verify title and quote text
    expect(find.text('Quote Share Card'), findsOneWidget);
    expect(
      find.text('“All we have to decide is what to do with the time that is given us.”'),
      findsOneWidget,
    );
    expect(find.text('The Fellowship of the Ring'), findsOneWidget);
    expect(find.text('J.R.R. Tolkien'), findsOneWidget);
    expect(find.text('The Shadow of the Past'), findsOneWidget);

    // Switch theme to Midnight
    await tester.tap(find.text('Midnight'));
    await tester.pump();

    // Switch theme to Sunset
    await tester.tap(find.text('Sunset'));
    await tester.pump();

    // Switch ratio to Story 9:16
    await tester.tap(find.text('Story 9:16'));
    await tester.pump();

    // Verify copy button exists
    expect(find.text('Copy Text'), findsOneWidget);
    expect(find.text('Save Image'), findsOneWidget);
  });
}

