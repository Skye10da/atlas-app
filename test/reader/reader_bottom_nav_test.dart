import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/reader/presentation/providers/dock_prefs_provider.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bottom_nav.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_dock_customize_sheet.dart';
import 'package:atlas_app/reader/speech/drivers/noop_driver.dart';

List<Override> _dockOverrides() => [
  liveBatteryLevelProvider.overrideWith((ref) => Stream<double>.value(0.87)),
  liveChargingProvider.overrideWith((ref) => Stream<bool>.value(false)),
  speechDriverProvider.overrideWith((ref) => NoopDriver()),
  narrationStatusProvider.overrideWith(
    (ref) => Stream<NarrationStatus>.value(NarrationStatus.idle),
  ),
  readerDockPrefsProvider.overrideWith(
    (ref) => ReaderDockPrefsNotifier(ReaderDockPrefsRepository()),
  ),
];

ProviderContainer _container() => ProviderContainer(overrides: _dockOverrides());

Widget _dockHarness(
  ProviderContainer container, {
  VoidCallback? onCustomize,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ReaderBottomNav(
            textColor: Colors.black,
            onSettingsTap: () {},
            onChapterIndexTap: () {},
            onBookmarkTap: () {},
            currentChapterTitle: 'The Long Walk',
            currentChapterNumber: 2,
            totalChapters: 10,
            onAnnotationsTap: () {},
            onSearchTap: () {},
            onIntelligenceTap: () {},
            onCustomize: onCustomize,
          ),
        ),
      ),
    ),
  );
}

final _clockPattern = RegExp(r'^\d{1,2}:\d{2} (AM|PM)$');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('dock boots as the tucked spine and expands on tap',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(_dockHarness(container));
    await tester.pumpAndSettle();

    // Spine shows the reading row; the capsule is not rendered yet.
    expect(find.textContaining('Ch. 3 of 10'), findsOneWidget);
    expect(find.byTooltip('Contents'), findsNothing);
    expect(find.byTooltip('More'), findsNothing);

    // Tapping the spine expands into the capsule.
    await tester.tap(find.textContaining('Ch. 3 of 10'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Contents'), findsOneWidget);
    expect(find.byTooltip('More'), findsOneWidget);
  });

  testWidgets('expanded capsule keeps mobile-sized buttons with 4px gaps',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(_dockHarness(container));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ch. 3 of 10'));
    await tester.pumpAndSettle();

    // Mobile geometry floor: standard dock buttons are 44x44 with 22px
    // glyphs (Material touch-target guidance) — locked so they can't
    // silently shrink again.
    final more = tester.getSize(find.byTooltip('More'));
    expect(more.width, 44);
    expect(more.height, 44);

    // Every standard 44x44 button sits exactly 4px from its neighbor.
    // (The More popup button reports its child tooltip twice through two
    // element paths — identical offsets — so dedupe by position.)
    final positions = <int, List<double>>{};
    for (final element in tester.elementList(find.byType(Tooltip))) {
      final size = element.size;
      if (size?.width != 44 || size?.height != 44) continue;
      final origin =
          (element.findRenderObject()! as RenderBox).localToGlobal(Offset.zero);
      final bucket = positions[(origin.dy).round()] ??= [];
      if (!bucket.contains(origin.dx)) bucket.add(origin.dx);
    }
    final rows = [
      for (final entry in positions.entries)
        if (entry.value.length > 1) entry.value..sort(),
    ];
    // The capsule packs at least More + Contents; enough to pin spacing.
    expect(rows, isNotEmpty);
    for (final row in rows) {
      for (int i = 1; i < row.length; i++) {
        expect(row[i] - row[i - 1], closeTo(48, 0.5)); // 44 + 4 gap
      }
    }
  });

  testWidgets('tapping outside the dock collapses the capsule back to the spine',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const SizedBox(height: 60),
                TextButton(
                  onPressed: () {},
                  child: const Text('Page tap'),
                ),
                const Spacer(),
                ReaderBottomNav(
                  textColor: Colors.black,
                  onSettingsTap: () {},
                  onChapterIndexTap: () {},
                  onBookmarkTap: () {},
                  currentChapterNumber: 2,
                  totalChapters: 10,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Ch. 3 of 10'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('More'), findsOneWidget);

    // A tap outside the dock re-tucks it into the spine.
    await tester.tap(find.text('Page tap'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Contents'), findsNothing);
    expect(find.byTooltip('More'), findsNothing);
    expect(find.textContaining('Ch. 3 of 10'), findsOneWidget);
  });

  testWidgets('fixed chapter edge buttons fire and hide at the bounds',
      (tester) async {
    var prev = 0;
    var next = 0;
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(_dockHarness(container));
    await tester.pumpAndSettle();

    // Without wiring: no edges at all.
    expect(find.byTooltip('Previous chapter'), findsNothing);
    expect(find.byTooltip('Next chapter'), findsNothing);

    // Wired (harness is mid-book): tap the spine, then the edges.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ReaderBottomNav(
                textColor: Colors.black,
                onSettingsTap: () {},
                onChapterIndexTap: () {},
                onBookmarkTap: () {},
                currentChapterNumber: 2,
                totalChapters: 10,
                onPrevChapter: () => prev++,
                onNextChapter: () => next++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ch. 3 of 10'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Previous chapter'), findsOneWidget);
    expect(find.byTooltip('Next chapter'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous chapter'));
    await tester.pumpAndSettle();
    expect(prev, 1);

    await tester.tap(find.byTooltip('Next chapter'));
    await tester.pumpAndSettle();
    expect(next, 1);
  });

  testWidgets('default order renders Contents, Notes, Listen, Aa, then More',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(_dockHarness(container));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ch. 3 of 10'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Contents'), findsOneWidget);
    expect(find.byTooltip('Notes'), findsOneWidget);
    expect(find.byTooltip('Listen'), findsOneWidget);
    expect(find.byTooltip('Aa'), findsOneWidget);
    expect(find.byTooltip('More'), findsOneWidget);
    // Promotable actions stay in the More overflow until the user adds them:
    expect(find.byTooltip('Search'), findsNothing);
    expect(find.byTooltip('Atlas'), findsNothing);
  });

  testWidgets('hiding a default action and promoting Search are respected',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    final notifier = container.read(readerDockPrefsProvider.notifier);
    notifier.spliceAction(ReaderDockAction.annotations, include: false);
    notifier.spliceAction(ReaderDockAction.search, include: true);

    await tester.pumpWidget(_dockHarness(container));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ch. 3 of 10'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Notes'), findsNothing);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('More'), findsOneWidget);
  });

  testWidgets('spine toggles drop the clock and battery chips',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    // Clock + battery render with the prefs on:
    await tester.pumpWidget(_dockHarness(container));
    await tester.pumpAndSettle();
    expect(find.text('87%'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Text && _clockPattern.hasMatch(w.data ?? '')), findsOneWidget);

    // Turn them off; chapter label stays:
    final notifier = container.read(readerDockPrefsProvider.notifier);
    notifier.setSpine(
      const ReaderSpineVisibility(clock: false, battery: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('87%'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is Text && _clockPattern.hasMatch(w.data ?? '')), findsNothing);
    expect(find.textContaining('Ch. 3 of 10'), findsOneWidget);
  });

  testWidgets('clock-only battery-off combination also renders',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    final notifier = container.read(readerDockPrefsProvider.notifier);
    notifier.setSpine(const ReaderSpineVisibility(battery: false));

    await tester.pumpWidget(_dockHarness(container));
    await tester.pumpAndSettle();

    expect(find.text('87%'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is Text && _clockPattern.hasMatch(w.data ?? '')), findsOneWidget);
  });

  testWidgets('auto-scroll strip renders when active and taps through',
      (tester) async {
    var toggles = 0;
    var pauses = 0;
    var speeds = 0.0;
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ReaderBottomNav(
                textColor: Colors.black,
                onSettingsTap: () {},
                onChapterIndexTap: () {},
                onBookmarkTap: () {},
                autoScrollActive: true,
                onAutoScrollToggle: () => toggles++,
                autoScrollPaused: false,
                onAutoScrollPauseToggle: () => pauses++,
                autoScrollSpeed: 2.0,
                onAutoScrollSpeedChanged: (s) => speeds = s,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('px/s'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pumpAndSettle();
    expect(pauses, 1);

    await tester.tap(find.byTooltip('Slower'));
    await tester.pumpAndSettle();
    expect(speeds, closeTo(1.5, 0.001));

    await tester.tap(find.byTooltip('Stop auto-scroll'));
    await tester.pumpAndSettle();
    expect(toggles, 1);
  });

  testWidgets('customize sheet toggles actions, spine, speed, and resets',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    final notifier = container.read(readerDockPrefsProvider.notifier);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 520,
                child: ReaderDockCustomizeSheet(
                  availablePromotable: [
                    ReaderDockAction.contents,
                    ReaderDockAction.annotations,
                    ReaderDockAction.listen,
                    ReaderDockAction.aa,
                    ReaderDockAction.flow,
                    ReaderDockAction.search,
                    ReaderDockAction.atlas,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(notifier.state.actions, contains(ReaderDockAction.search));

    await tester.ensureVisible(find.text('Clock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clock'));
    await tester.pumpAndSettle();
    expect(notifier.state.spine.clock, isFalse);

    await tester.ensureVisible(find.text('45 px/s'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('45 px/s'));
    await tester.pumpAndSettle();
    expect(notifier.state.autoScrollSpeed, closeTo(2.25, 0.001));

    await tester.ensureVisible(find.text('Reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(notifier.state.actions, ReaderDockPrefs.defaultActions);
    expect(notifier.state.spine.allOn, isTrue);
    expect(notifier.state.autoScrollSpeed, 2.0);
  });

  testWidgets('long-press on the chapter strip wires the customize callback',
      (tester) async {
    var customizeCount = 0;
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _dockHarness(container, onCustomize: () => customizeCount++),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('Ch. 3 of 10'));
    await tester.pumpAndSettle();
    expect(customizeCount, 1);
  });

  testWidgets('long-press without the callback override still opens the sheet',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(_dockHarness(container));
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('Ch. 3'));
    await tester.pumpAndSettle();

    expect(find.text('Customize dock'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}

