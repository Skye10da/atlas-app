import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder get sheetSurface =>
    find.byWidgetPredicate((w) => w is Material && w.elevation == 16);

Finder get sheetHandle =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SheetHandle');

void main() {
  late bool originalBlur;

  setUp(() {
    originalBlur = AppSheet.enableBackdropBlur;
    // Blur relies on BackdropFilter, which is a no-op in the test canvas.
    AppSheet.enableBackdropBlur = false;
    AppSheet.rememberedHeights.clear();
    AppSheet.rememberedDockStates.clear();
  });

  tearDown(() => AppSheet.enableBackdropBlur = originalBlur);

  /// Pumps the host app at a real [size] (dpr 1.0) so both the layout
  /// constraints and MediaQuery-based logic see identical dimensions.
  Future<void> pumpHost(
    WidgetTester tester, {
    Size size = const Size(800, 600),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => AppSheet.show<void>(
                  context: context,
                  id: 'test_sheet',
                  initialHeight: 0.5,
                  snapPoints: const [0.4, 0.8],
                  title: 'Test sheet',
                  child: const SizedBox.expand(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens as a bottom sheet below the desktop breakpoint', (
    tester,
  ) async {
    await pumpHost(tester);
    await openSheet(tester);

    expect(find.text('Test sheet'), findsOneWidget);
    final rect = tester.getRect(sheetSurface);
    expect(rect.bottom, closeTo(600, 0.5));
  });

  testWidgets('opens as a floating centered dialog at desktop width', (
    tester,
  ) async {
    await pumpHost(tester, size: const Size(1200, 800));
    await openSheet(tester);

    final rect = tester.getRect(sheetSurface);
    // Capped to maxSheetWidth and horizontally + vertically centered.
    expect(rect.width, AppSheet.maxSheetWidth);
    expect(rect.center.dx, closeTo(600, 0.5));
    expect(rect.center.dy, closeTo(400, 0.5));
    // Rounded on all corners (dialog), not just the top.
    final material = tester.widget<Material>(sheetSurface);
    final shape = material.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(28));
    expect(sheetHandle, findsOneWidget);
  });

  testWidgets('desktop dialog can be docked at bottom and floated back', (
    tester,
  ) async {
    await pumpHost(tester, size: const Size(1200, 800));
    await openSheet(tester);

    // Initial state: centered
    var rect = tester.getRect(sheetSurface);
    expect(rect.center.dy, closeTo(400, 0.5));

    // Tap dock button to dock at bottom
    await tester.tap(find.byTooltip('Dock at bottom'));
    await tester.pumpAndSettle();

    rect = tester.getRect(sheetSurface);
    expect(rect.bottom, closeTo(800, 0.5));

    // Tap float button to restore to center
    await tester.tap(find.byTooltip('Float to center'));
    await tester.pumpAndSettle();

    rect = tester.getRect(sheetSurface);
    expect(rect.center.dy, closeTo(400, 0.5));
  });

  testWidgets('remembers dock position across reopening', (tester) async {
    await pumpHost(tester, size: const Size(1200, 800));
    await openSheet(tester);

    // Dock at bottom
    await tester.tap(find.byTooltip('Dock at bottom'));
    await tester.pumpAndSettle();

    // Dismiss sheet
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Test sheet'), findsNothing);

    // Reopen sheet — should open docked at bottom directly
    await openSheet(tester);
    final rect = tester.getRect(sheetSurface);
    expect(rect.bottom, closeTo(800, 0.5));
  });

  testWidgets('caps width on wide phones and tablets', (tester) async {
    await pumpHost(tester, size: const Size(700, 900));
    await openSheet(tester);

    final rect = tester.getRect(sheetSurface);
    expect(rect.width, AppSheet.maxSheetWidth);
    // Still bottom-anchored.
    expect(rect.bottom, closeTo(900, 0.5));
  });

  testWidgets('header close button dismisses the sheet', (tester) async {
    await pumpHost(tester);
    await openSheet(tester);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Test sheet'), findsNothing);
  });

  testWidgets('tapping the scrim dismisses the sheet', (tester) async {
    await pumpHost(tester);
    await openSheet(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Test sheet'), findsNothing);
  });

  testWidgets('dragging down past the dismissal threshold closes', (
    tester,
  ) async {
    await pumpHost(tester);
    await openSheet(tester);

    // Hard downward fling on the handle projects below half of the lowest
    // snap (240px), which dismisses outright.
    final handle = tester.getCenter(sheetHandle);
    await tester.flingFrom(handle, const Offset(0, 500), 2500);
    await tester.pumpAndSettle();

    expect(find.text('Test sheet'), findsNothing);
  });

  testWidgets('remembered height persists per sheet id across opens', (
    tester,
  ) async {
    await pumpHost(tester);
    await openSheet(tester);

    // Fling up hard enough that the projected position lands at the upper
    // snap (480px), then let the spring settle there.
    final handle = tester.getCenter(sheetHandle);
    await tester.flingFrom(handle, const Offset(0, -400), 2000);
    await tester.pumpAndSettle();

    final grown = tester.getRect(sheetSurface).height;
    expect(grown, greaterThan(400));

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await openSheet(tester);

    final reopened = tester.getRect(sheetSurface).height;
    expect(reopened, closeTo(grown, 2));
  });

  group('content-aware opening height', () {
    Future<void> pumpAutoSheet(
      WidgetTester tester, {
      required Widget child,
      String id = 'auto_sheet',
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => AppSheet.show<void>(
                    context: context,
                    id: id,
                    initialHeight: 0.5,
                    snapPoints: const [0.4, 0.8],
                    title: 'Auto sheet',
                    child: child,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'compact content opens at its own height, not a screen fraction',
      (tester) async {
        await pumpAutoSheet(tester, child: const SizedBox(height: 180));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final rect = tester.getRect(sheetSurface);
        // 180px content + handle/header — nowhere near the 300px (0.5 × 600)
        // fraction the sheet used to open at.
        expect(rect.height, lessThan(300));
        expect(rect.height, greaterThan(180));
      },
    );

    testWidgets('compact content opens compact on a large viewport too', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1000, 1400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpAutoSheet(
        tester,
        id: 'auto_large',
        child: const SizedBox(height: 200),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final rect = tester.getRect(sheetSurface);
      // On a 1400px-tall device the old 0.5 fraction was 700px of mostly
      // empty sheet; content-aware sizing stays near the content height.
      expect(rect.height, lessThan(320));
    });

    testWidgets('long scrollable content still opens at the fraction height', (
      tester,
    ) async {
      await pumpAutoSheet(
        tester,
        id: 'auto_scroll',
        child: ListView.builder(
          itemCount: 100,
          itemBuilder: (_, i) => ListTile(title: Text('row $i')),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final rect = tester.getRect(sheetSurface);
      // Fills the measure cap → falls back to the fraction logic, which
      // opens at the nearest configured snap (0.4 × 600 = 240px), exactly
      // as sheets sized before content-awareness.
      expect(rect.height, closeTo(240, 6));
    });

    testWidgets('a user drag still pins a remembered height over measurement', (
      tester,
    ) async {
      await pumpAutoSheet(
        tester,
        id: 'auto_drag',
        child: ListView.builder(
          itemCount: 100,
          itemBuilder: (_, i) => ListTile(title: Text('row $i')),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final handle = tester.getCenter(sheetHandle);
      await tester.flingFrom(handle, const Offset(0, -400), 2000);
      await tester.pumpAndSettle();
      final grown = tester.getRect(sheetSurface).height;
      expect(grown, greaterThan(400));

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.getRect(sheetSurface).height, closeTo(grown, 2));
    });
  });

  testWidgets('fitToContent auto-sizes to compact child content', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => AppSheet.show<void>(
                  context: context,
                  id: 'fit_sheet',
                  fitToContent: true,
                  title: 'Compact Note',
                  child: const SizedBox(height: 150),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(sheetSurface);
    // Height should be ~150 plus handle and header, well below 300px
    expect(rect.height, lessThan(300));
    expect(rect.height, greaterThan(150));
  });

  testWidgets('AppSheetMode.sideSheet positions sheet on the right edge', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => AppSheet.show<void>(
                  context: context,
                  id: 'side_sheet',
                  mode: AppSheetMode.sideSheet,
                  title: 'Side Panel',
                  child: const SizedBox.expand(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(sheetSurface);
    expect(rect.right, closeTo(1200, 0.5));
    expect(rect.height, closeTo(800, 0.5));
  });

  testWidgets('SheetNavigator pushes and pops sub-views in sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SheetNavigator(
            initialPage: Builder(
              builder: (context) => TextButton(
                onPressed: () => SheetNavigator.of(
                  context,
                ).push(const Text('Sub Page Content')),
                child: const Text('Go to Sub Page'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Go to Sub Page'), findsOneWidget);
    await tester.tap(find.text('Go to Sub Page'));
    await tester.pumpAndSettle();

    expect(find.text('Sub Page Content'), findsOneWidget);
  });
}
