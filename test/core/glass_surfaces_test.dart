import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';

/// Busy backdrop so the capsule has real content to blur; also the tap
/// target for the fall-through contract tests.
Widget _host(Widget chrome, {VoidCallback? onPageTap}) => MaterialApp(
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
                    gradient: LinearGradient(colors: [Colors.teal, Colors.indigo]),
                  ),
                ),
              ),
            ),
            Positioned(left: 40, top: 40, child: chrome),
          ],
        ),
      ),
    );

void main() {
  testWidgets('pill capsule hugs its child instead of stretching fullscreen',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const GlassCapsule(
          pill: true,
          interactive: false,
          child: SizedBox(
            width: 120,
            height: 44,
            child: Center(child: Text('title')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(GlassCapsule));
    expect(rect.width, 120, reason: 'glass capsule must hug the child width');
    expect(rect.height, 44, reason: 'glass capsule must hug the child height');
    // Positioned bounds sanity: not anchored fullscreen to the window.
    expect(rect.top, 40);
    expect(rect.left, 40);
  });

  testWidgets('interactive:false glass falls through to the page underneath',
      (tester) async {
    var pageTaps = 0;
    await tester.pumpWidget(
      _host(
        const GlassCapsule(
          pill: true,
          interactive: false,
          child: SizedBox(
            width: 120,
            height: 44,
            child: Center(child: Text('title')),
          ),
        ),
        onPageTap: () => pageTaps++,
      ),
    );
    await tester.pumpAndSettle();

    // Tap empty glass inside the pill (avoiding the centred Text label,
    // which absorbs hits for selection like any Text node, then and now).
    final rect = tester.getRect(find.byType(GlassCapsule));
    await tester.tapAt(Offset(rect.left + 10, rect.center.dy));
    await tester.pump();

    expect(pageTaps, 1,
        reason: "the reader's empty-glass tap-falls-through contract "
            'must hold for capsules built with interactive:false');
  });

  testWidgets(
      'interactive:false keeps the child interactive while empty glass '
      'falls through', (tester) async {
    var pageTaps = 0;
    var buttonTaps = 0;
    await tester.pumpWidget(
      _host(
        GlassCapsule(
          pill: true,
          interactive: false,
          child: SizedBox(
            width: 160,
            height: 60,
            child: Center(
              child: SizedBox(
                width: 44,
                height: 44,
                child: Material(
                  color: Colors.red,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => buttonTaps++,
                    child: const Icon(Icons.add),
                  ),
                ),
              ),
            ),
          ),
        ),
        onPageTap: () => pageTaps++,
      ),
    );
    await tester.pumpAndSettle();

    final capsule = tester.getRect(find.byType(GlassCapsule));
    // Dead centre: the child button.
    await tester.tapAt(capsule.center);
    await tester.pumpAndSettle();
    // Far corner of the capsule: empty glass.
    await tester.tapAt(Offset(capsule.left + 8, capsule.top + 8));
    await tester.pump();

    expect(buttonTaps, 1, reason: 'child buttons must stay live');
    expect(pageTaps, 1, reason: 'empty glass must fall through');
  });

  testWidgets('interactive capsule renders and exists under a real child',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const GlassCapsule(
          borderRadius: 24,
          blur: 24,
          child: SizedBox(
            width: 200,
            height: 60,
            child: Center(child: Text('nav-ish')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The glass paint path is active: backdrop filter in the tree, and the
    // specular rim/shadow painters present as CustomPaints.
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
  });

  testWidgets('GlassLens renders pure decoration sized to its parent',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 60,
          height: 40,
          child: GlassLens(
            accent: Colors.blue,
            isDark: false,
            radius: 20,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(GlassLens)), const Size(60, 40));
  });
}
