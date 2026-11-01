import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/design_system/nav_chrome_providers.dart';
import 'package:atlas_app/core/design_system/organisms/atlas_glass_nav_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _items = [
  AtlasNavItem(
    icon: Icons.auto_stories_outlined,
    activeIcon: Icons.auto_stories_rounded,
    label: 'Library',
  ),
  AtlasNavItem(
    icon: Icons.explore_outlined,
    activeIcon: Icons.explore_rounded,
    label: 'Find new',
  ),
  AtlasNavItem(
    icon: Icons.bookmarks_outlined,
    activeIcon: Icons.bookmarks_rounded,
    label: 'Saved',
  ),
  AtlasNavItem(
    icon: Icons.tune_outlined,
    activeIcon: Icons.tune_rounded,
    label: 'Settings',
  ),
];

Widget _bar(int selected, ValueChanged<int> onChanged,
        {VoidCallback? onAdd}) =>
    MaterialApp(
      home: Center(
        child: AtlasGlassNavBar(
          items: _items,
          currentIndex: selected,
          onChanged: onChanged,
          action: onAdd == null
              ? null
              : AtlasNavAction(icon: Icons.add_rounded, onTap: onAdd),
        ),
      ),
      theme: ThemeData.light(useMaterial3: true),
    );

void main() {
  testWidgets('tap on a destination selects it via onChanged', (tester) async {
    final changes = <int>[];
    final selected = <int>[];
    await tester.pumpWidget(_bar(0, (i) {
      selected.add(i);
      changes.add(i);
    }, onAdd: () {}));
    await tester.pumpAndSettle();

    // Dest 1 lives in slot 1 (center x = pad + 1.5*slotW). Bar: 5 slots over
    // 400px window minus side padding -> measured from the rendered widget.
    final rect = tester.getRect(find.byType(AtlasGlassNavBar));
    final slotW = (rect.width - 40 - 12) / 5; // outer 20px pads + 2*6 inner pad
    await tester.tapAt(Offset(
      rect.left + 20 + 6 + 1.5 * slotW,
      rect.top + rect.height / 2,
    ));
    await tester.pumpAndSettle();

    expect(changes, [1]);
  });

  testWidgets('tap on the centre action slot fires the action, not onChanged',
      (tester) async {
    var addTaps = 0;
    final changes = <int>[];
    await tester.pumpWidget(_bar(0, changes.add, onAdd: () => addTaps++));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(AtlasGlassNavBar));
    final slotW = (rect.width - 40 - 12) / 5;
    // Action slot = middle of 5 slots (index 2).
    await tester.tapAt(Offset(
      rect.left + 20 + 6 + 2.5 * slotW,
      rect.top + rect.height / 2,
    ));
    await tester.pumpAndSettle();

    expect(addTaps, 1);
    expect(changes, isEmpty);
  });

  testWidgets('tap on a destination slot right of the action resolves '
      'to the right destination index', (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(_bar(0, changes.add, onAdd: () {}));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(AtlasGlassNavBar));
    final slotW = (rect.width - 40 - 12) / 5;
    // Slot 3 = destination 2 ("Saved").
    await tester.tapAt(Offset(
      rect.left + 20 + 6 + 3.5 * slotW,
      rect.top + rect.height / 2,
    ));
    await tester.pumpAndSettle();

    expect(changes, [2]);
  });

  testWidgets('horizontal drag across tabs snaps to the nearest destination',
      (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(_bar(0, changes.add, onAdd: () {}));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(AtlasGlassNavBar));
    final slotW = (rect.width - 40 - 12) / 5;
    final y = rect.top + rect.height / 2;
    final gesture = await tester.startGesture(Offset(
      rect.left + 20 + 6 + 0.5 * slotW,
      y,
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(Offset(3 * slotW, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    // Landed ~slot 3.5 → destination 2.
    expect(changes, [2]);
  });

  testWidgets('AtlasGlassRail selects top and bottom destinations vertically',
      (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          height: 420,
          child: AtlasGlassRail(
            items: _items,
            currentIndex: 1,
            onChanged: changes.add,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final rail = find.byType(AtlasGlassRail);
    final rect = tester.getRect(rail);
    // Rail: 4 slots over (4 bottom pad + 12 top pad + 12 inner pads).
    final slotW = (rect.height - 16 - 12) / 4;
    final x = rect.left + rect.width / 2;
    await tester.tapAt(Offset(x, rect.top + 12 + 6 + 0.5 * slotW));
    await tester.pumpAndSettle();
    expect(changes, [0]);

    await tester.tapAt(Offset(x, rect.top + 12 + 6 + 3.5 * slotW));
    await tester.pumpAndSettle();
    expect(changes, [0, 3]);
  });

  testWidgets('rail laid out in a Stack via Positioned(left/top/bottom) '
      'does not hit unbounded width', (tester) async {
    // Regression: Stack gives positioned children an unconstrained width
    // when only left/top/bottom are provided, which used to propagate
    // Infinity into the vertical slot Column and crash layout.
    final changes = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: Colors.blue),
            ),
            Positioned(
              left: 8,
              top: 8,
              bottom: 8,
              child: AtlasGlassRail(
                items: _items,
                currentIndex: 0,
                onChanged: changes.add,
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final rail = tester.getRect(find.byType(AtlasGlassRail));
    expect(rail.width, closeTo(76 + 24, 1)); // capsule + outer pads

    final x = rail.left + rail.width / 2;
    // 4 bottom + 12 top internal pads + 12 inner pads.
    final slotH = (rail.height - 16 - 12) / 4;
    await tester.tapAt(Offset(x, rail.top + 12 + 6 + 2.5 * slotH));
    await tester.pumpAndSettle();
    expect(changes, [2]);
  });

  testWidgets('AtlasGlassNavBar stays anchored at the bottom instead of '
      'filling the whole bottomNavigationBar slot', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: AtlasGlassNavBar(
          items: _items,
          currentIndex: 0,
          onChanged: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final rect = tester.getRect(find.byType(AtlasGlassNavBar));
    // Bar hugs the bottom and stays small — never fills the window.
    expect(rect.bottom, 844);
    expect(rect.height, lessThan(120));
  });

  testWidgets('NavChromeNotifier persists the chosen style', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(navChromeProvider), NavChromeStyle.glass);

    await container.read(navChromeProvider.notifier).set(NavChromeStyle.classic);
    expect(container.read(navChromeProvider), NavChromeStyle.classic);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('nav_chrome_style'), 'classic');

    // A fresh container loads the persisted value.
    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    // build() starts at the default; _load() flips it asynchronously.
    expect(container2.read(navChromeProvider), NavChromeStyle.glass);
    await container2.pump();
    expect(container2.read(navChromeProvider), NavChromeStyle.classic);
  });
}
