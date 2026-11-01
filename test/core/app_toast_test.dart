// Glass toast pill tests: the in-app notification molecule.
//
// Covers: emoticon + geometry (hugs content, top-anchored), spring landing
// (fluid entry), explicit dismiss, replacement semantics, action callback,
// tap-to-dismiss, auto-dismiss, and reduced-motion instant landing/dismiss.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/design_system/molecules/app_toast.dart';
import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';

final _pillFinder = find.byType(GlassCapsule);

// AnimatedBuilder is the direct ancestor that applies the spring transforms.
final _toastTransformFinder = find
    .ancestor(of: find.byType(GlassCapsule), matching: find.byType(AnimatedBuilder))
    .first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Each test prims its own viewport (setUp has no tester reference).
  void primeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget host({required GlobalKey<NavigatorState> navigatorKey}) => MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox.expand()),
      );

  testWidgets('shows a glass pill with the tone emoticon, hugging content',
      (tester) async {
    primeViewport(tester);
    final navigatorKey = GlobalKey<NavigatorState>();
    AppToast.bind(navigatorKey);

    await tester.pumpWidget(host(navigatorKey: navigatorKey));

    AppToast.showSuccess('Saved.');
    await tester.pump();

    // Pill visible mid-flight already (widget tree exists), emoticon present.
    expect(_pillFinder, findsOneWidget);
    expect(find.text('✅'), findsOneWidget);
    expect(find.text('Saved.'), findsOneWidget);

    // Pill hugs content but never explodes: bounded, near the top.
    // Measure once the spring has landed (start frame floats above).
    await tester.pumpAndSettle(const Duration(milliseconds: 800));
    final pill = tester.getRect(_pillFinder);
    expect(pill.top, inInclusiveRange(0, 150));
    expect(pill.left, greaterThan(0));
    expect(pill.width, lessThan(220)); // "Saved." hugs tight, no stretching

    // Replacement semantics: a rapid second show swaps the pill.
    AppToast.showError('Failed.');
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 800));
    expect(_pillFinder, findsOneWidget);
    expect(find.text('⛔'), findsOneWidget);
    expect(find.text('Failed.'), findsOneWidget);

    AppToast.dismiss();
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(_pillFinder, findsNothing);
  });

  testWidgets('lands with fluid spring: falls from above, then rests',
      (tester) async {
    primeViewport(tester);
    final navigatorKey = GlobalKey<NavigatorState>();
    AppToast.bind(navigatorKey);

    await tester.pumpWidget(host(navigatorKey: navigatorKey));

    AppToast.show('Falling in ✨', tone: AppToastTone.sparkle);
    await tester.pump(); // first frame: droplet still high above its rest
    final start = tester.getRect(_pillFinder);

    await tester.pump(const Duration(milliseconds: 80));
    final midFlight = tester.getRect(_pillFinder);
    expect(midFlight.top, lessThan(150)); // traveling toward its landing pad above

    await tester.pumpAndSettle(const Duration(milliseconds: 800));
    final landed = tester.getRect(_pillFinder);

    // Moves downward toward the landing spot ~12px below the safe-area top;
    // the spring overshoot dips slightly lower before settling.
    expect(start.top, lessThan(landed.top));
    expect(start.top, lessThan(0)); // starts above the screen
    expect(landed.top, inInclusiveRange(0, 150));
  });

  testWidgets('action fires once, then pill dismisses', (tester) async {
    primeViewport(tester);
    final navigatorKey = GlobalKey<NavigatorState>();
    AppToast.bind(navigatorKey);
    var pressed = 0;

    await tester.pumpWidget(host(navigatorKey: navigatorKey));

    AppToast.show(
      'New chapters found',
      tone: AppToastTone.download,
      action: AppToastAction('Open', () => pressed += 1),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(pressed, 1);
    expect(_pillFinder, findsNothing);
  });

  testWidgets('tap the pill dismisses it', (tester) async {
    primeViewport(tester);
    final navigatorKey = GlobalKey<NavigatorState>();
    AppToast.bind(navigatorKey);

    await tester.pumpWidget(host(navigatorKey: navigatorKey));

    AppToast.show('Tap me away 🔖', tone: AppToastTone.bookmark);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.tap(find.text('Tap me away 🔖'), warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(_pillFinder, findsNothing);
  });

  testWidgets('auto-dismisses after its duration', (tester) async {
    primeViewport(tester);
    final navigatorKey = GlobalKey<NavigatorState>();
    AppToast.bind(navigatorKey);

    await tester.pumpWidget(host(navigatorKey: navigatorKey));

    AppToast.show('brief', duration: const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // spring landed
    expect(_pillFinder, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1700)); // 2.1s: timer fires
    await tester.pump(const Duration(milliseconds: 400)); // exit completes
    expect(_pillFinder, findsNothing);
  });

  testWidgets('reduced motion: lands and leaves instantly', (tester) async {
    primeViewport(tester);
    final navigatorKey = GlobalKey<NavigatorState>();
    AppToast.bind(navigatorKey);

    await tester.pumpWidget(host(navigatorKey: navigatorKey));

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(() {
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });

    AppToast.show('no-animation tone', tone: AppToastTone.search);
    await tester.pump();

    // Instantly at rest: position stable on the very next pump.
    final rest = tester.getTopLeft(_toastTransformFinder);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.getTopLeft(_toastTransformFinder), equals(rest));

    // And leaves instantly once its duration elapses (180ms exit is skipped).
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(_pillFinder, findsNothing);
  });
}
