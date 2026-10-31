import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/presentation/widgets/reader_bar_surface.dart';

/// Reader pill shell tests — the glass migration gate in
/// docs/plans/reader_glass_pills_plan.md phase 4.
///
/// The single most important invariant is the tap-through contract: taps on
/// empty pill space must fall through to the page underneath.
Widget _host({
  required ColorScheme colorScheme,
  required Widget pill,
  VoidCallback? onPageTap,
}) =>
    MaterialApp(
      home: Theme(
        data: ThemeData.from(colorScheme: colorScheme, useMaterial3: true),
        child: Scaffold(
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
              Positioned(left: 40, top: 40, child: pill),
            ],
          ),
        ),
      ),
    );

ColorScheme _scheme(Brightness brightness) => ColorScheme.fromSeed(
      seedColor: const Color(0xFF796B57),
      brightness: brightness,
    );

void main() {
  testWidgets('glass pill hugs its child over a busy page', (tester) async {
    final scheme = _scheme(Brightness.light);
    await tester.pumpWidget(_host(
      colorScheme: scheme,
      pill: ReaderPillSurface(
        colorScheme: scheme,
        child: const SizedBox(
          width: 120,
          height: 44,
          child: Center(child: Text('Ch. 4')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(ReaderPillSurface));
    expect(rect.width, 120);
    expect(rect.height, 44);
    // Glass paint path active: backdrop blur + painted layers in the tree.
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
  });

  testWidgets('glass pill: tap on empty pill area falls through',
      (tester) async {
    var pageTaps = 0;
    final scheme = _scheme(Brightness.light);
    await tester.pumpWidget(_host(
      colorScheme: scheme,
      onPageTap: () => pageTaps++,
      pill: ReaderPillSurface(
        colorScheme: scheme,
        child: const SizedBox(
          width: 120,
          height: 44,
          child: Center(child: Text('Ch. 4')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(ReaderPillSurface));
    await tester.tapAt(Offset(rect.left + 10, rect.center.dy));
    await tester.pump();
    expect(pageTaps, 1,
        reason: 'regression gate: empty pill space must fall through');
  });

  testWidgets('glass pill stays dark-mode legible (renders both schemes)',
      (tester) async {
    final scheme = _scheme(Brightness.dark);
    await tester.pumpWidget(_host(
      colorScheme: scheme,
      pill: ReaderPillSurface(
        colorScheme: scheme,
        child: const SizedBox(
          width: 120,
          height: 44,
          child: Center(child: Text('Ch. 4')),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('classic translucent shell keeps its legacy structure',
      (tester) async {
    final scheme = _scheme(Brightness.light);
    await tester.pumpWidget(_host(
      colorScheme: scheme,
      onPageTap: () {},
      pill: ReaderPillSurface(
        colorScheme: scheme,
        glass: false,
        child: const SizedBox(
          width: 120,
          height: 44,
          child: Center(child: Text('Ch. 4')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Legacy shell: shadow/fill decoration boxes + blur, hugging its child.
    expect(
      find.descendant(
        of: find.byType(ReaderPillSurface),
        matching: find.byType(DecoratedBox),
      ),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.descendant(
        of: find.byType(ReaderPillSurface),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
    final rect = tester.getRect(find.byType(ReaderPillSurface));
    // +2 px: the legacy 1px hairline border boxes both sides of the child.
    expect(rect.width, 122);
    expect(rect.height, 46);
  });
}
