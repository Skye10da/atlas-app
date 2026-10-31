import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_shimmer.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';

/// ReaderStatusPill tests (reader glass pills plan phase 4): the glass shell
/// renders, hugs its content, and never blocks taps on the page underneath.
const _colors = ReadingColors(
  background: Color(0xFFFFFBF2),
  text: Color(0xFF1E1A16),
  surface: Color(0xFFF5EEE0),
  accent: Color(0xFF8B5E34),
);

Widget _host(ChapterLoadPhase phase, {VoidCallback? onPageTap}) => MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onPageTap,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal, Colors.indigo],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 40,
              top: 40,
              child: ReaderStatusPill(phase: phase, colors: _colors),
            ),
          ],
        ),
      ),
    );

void main() {
  testWidgets('renders the phase label on the glass shell and hugs its content',
      (tester) async {
    await tester.pumpWidget(_host(ChapterLoadPhase.processing));
    // The bouncing dots never settle: pulse a few frames instead.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Processing text'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);

    final rect = tester.getRect(find.byType(ReaderStatusPill));
    expect(rect.height, lessThan(60),
        reason: 'status pill must hug its content, not stretch');
  });

  testWidgets('status pill does not block taps on the page underneath',
      (tester) async {
    var pageTaps = 0;
    await tester.pumpWidget(
      _host(ChapterLoadPhase.gettingText, onPageTap: () => pageTaps++),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final rect = tester.getRect(find.byType(ReaderStatusPill));
    // Empty glass corner — the phase label (like any Text) absorbs taps at
    // its own glyphs, but the pill body must fall through.
    await tester.tapAt(Offset(rect.left + 6, rect.center.dy));
    await tester.pump();
    expect(pageTaps, 1);

    // And again from the right side while the dots animate.
    await tester.tapAt(Offset(rect.right - 6, rect.center.dy));
    await tester.pump();
    expect(pageTaps, 2);
  });
}
