import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_bottom_nav.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_viewer_models.dart';

void main() {
  testWidgets('PdfBottomNav renders page progress and handles action callbacks', (
    WidgetTester tester,
  ) async {
    var settingsTapped = false;
    var outlineTapped = false;
    var bookmarkTapped = false;
    var layoutModeToggled = false;
    var listenTapped = false;

    var annotationsTapped = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: PdfBottomNav(
              textColor: Colors.black,
              currentPage: 5,
              totalPages: 20,
              onPageSelected: (_) {},
              onSettingsTap: () => settingsTapped = true,
              onOutlineTap: () => outlineTapped = true,
              onBookmarkTap: () => bookmarkTapped = true,
              isBookmarked: false,
              layoutMode: PdfReaderLayoutMode.single,
              onToggleLayoutMode: () => layoutModeToggled = true,
              onListenTap: () => listenTapped = true,
              onAnnotationsTap: () => annotationsTapped = true,
            ),
          ),
        ),
      ),
    );

    // Verify labels are displayed
    expect(find.text('Tune'), findsOneWidget);
    expect(find.text('5 / 20'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Single'), findsOneWidget);
    expect(find.text('Listen'), findsOneWidget);

    // Tap Tune
    await tester.tap(find.text('Tune'));
    expect(settingsTapped, isTrue);

    // Tap Pages/Outline
    await tester.tap(find.text('5 / 20'));
    expect(outlineTapped, isTrue);

    // Tap Save
    await tester.tap(find.text('Save'));
    expect(bookmarkTapped, isTrue);

    // Tap Notes
    await tester.tap(find.text('Notes'));
    expect(annotationsTapped, isTrue);

    // Tap Single (layout mode)
    await tester.tap(find.text('Single'));
    expect(layoutModeToggled, isTrue);

    // Tap Listen
    await tester.tap(find.text('Listen'));
    expect(listenTapped, isTrue);
  });
}
