import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/presentation/widgets/reader_chrome_bar.dart';

void _noop() {}

Future<void> _pumpBar(
  WidgetTester tester, {
  bool withBack = true,
  bool isChecked = false,
  VoidCallback? onBack = _noop,
  VoidCallback? onTitleTap,
  VoidCallback? onBookmarkTap = _noop,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: MediaQuery(
                data: const MediaQueryData(),
                child: ReaderChromeBar(
                  title: 'Chapter One',
                  textColor: const Color(0xFF222222),
                  onSettingsTap: () {},
                  slim: true,
                  onBack: withBack ? onBack : null,
                  onTitleTap: onTitleTap,
                  onBookmarkTap: onBookmarkTap,
                  isBookmarked: isChecked,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('slim icon pills keep mobile-sized touch targets',
      (tester) async {
    await _pumpBar(tester);

    // Mobile geometry floor: the icon tap area is the locked 44px
    // Material touch target (the pill's padding+border wrap it outside
    // the tooltip widget's box).
    final back = tester.getSize(find.byTooltip('Back to Library'));
    expect(back.width, 44);
    expect(back.height, 44);

    final bookmark = tester.getSize(find.byTooltip('Add bookmark'));
    expect(bookmark.width, 44);
    expect(bookmark.height, 44);
  });

  testWidgets('slim bar renders three separate pills: back, title, bookmark',
      (tester) async {
    await _pumpBar(tester);

    // Back pill hugs the top-left (16px screen pad + 1px pill border + 4px pill pad).
    final back = find.byTooltip('Back to Library');
    expect(back, findsOneWidget);
    expect(tester.getTopLeft(back).dx, 21);

    // Bookmark pill hugs the top-right.
    final bookmark = find.byTooltip('Add bookmark');
    expect(bookmark, findsOneWidget);
    final windowWidth = tester.getSize(find.byType(MaterialApp)).width;
    expect(tester.getTopRight(bookmark).dx, windowWidth - 21);

    // Title pill floats centered between the two.
    final title = find.text('Chapter One');
    expect(title, findsOneWidget);
    expect(
      tester.getCenter(title).dx,
      closeTo(windowWidth / 2, 60),
    );
  });

  testWidgets('back pill calls onBack', (tester) async {
    var backTapped = false;
    await _pumpBar(tester, onBack: () => backTapped = true);

    expect(backTapped, isFalse);
    await tester.tap(find.byTooltip('Back to Library'));
    expect(backTapped, isTrue);
  });

  testWidgets('title tap + bookmark toggle fire', (tester) async {
    var titleTapped = false;
    var bookmarkTapped = false;
    await _pumpBar(
      tester,
      onTitleTap: () => titleTapped = true,
      onBookmarkTap: () => bookmarkTapped = true,
    );

    await tester.tap(find.text('Chapter One'));
    expect(titleTapped, isTrue);

    await tester.tap(find.byTooltip('Add bookmark'));
    expect(bookmarkTapped, isTrue);
    expect(find.byTooltip('Remove bookmark'), findsNothing);
  });

  testWidgets('checked bookmark offers the remove label', (tester) async {
    await _pumpBar(tester, isChecked: true);
    expect(find.byTooltip('Remove bookmark'), findsOneWidget);
    expect(find.byTooltip('Add bookmark'), findsNothing);
  });

  testWidgets('without onBack no left pill is rendered', (tester) async {
    await _pumpBar(tester, withBack: false);
    expect(find.byTooltip('Back to Library'), findsNothing);
  });
}
