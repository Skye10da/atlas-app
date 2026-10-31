import 'package:atlas_app/core/design_system/organisms/app_scaffold.dart';
import 'package:atlas_app/core/design_system/organisms/atlas_glass_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    required int currentIndex,
    bool collapsed = false,
    required ValueChanged<int> onChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Container(
            width: collapsed ? 72 : 260,
            height: 600,
            decoration: BoxDecoration(color: Colors.grey.shade200),
            child: AtlasSidebarGlassNavList(
              currentIndex: currentIndex,
              collapsed: collapsed,
              onDestinationSelected: onChanged,
              onAdd: () {},
              accent: Colors.indigo,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('glass sidebar renders all four destination icons', (tester) async {
    await tester.pumpWidget(host(currentIndex: 0, onChanged: (_) {}));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Debug probe: dump tree.
    tester.allWidgets
        .whereType<Stack>()
        .forEach((s) => debugPrint('STACK children=${s.children.length}'));
    tester.allWidgets
        .whereType<Material>()
        .forEach((m) => debugPrint('MAT ${m.color} border=${m.shape}'));
    tester.allWidgets
        .whereType<Icon>()
        .forEach((i) => debugPrint('ICON ${i.icon} color=${i.color}'));
    tester.allWidgets
        .whereType<Text>()
        .forEach((t) => debugPrint('TXT "${t.data}"'));
    await tester.pumpAndSettle();
    // Note: Library is SELECTED at currentIndex 0 → shows the rounded icon.
    expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
    expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bookmarks_outlined), findsOneWidget);
    expect(find.byIcon(Icons.tune_outlined), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);

    // The droplet lens sits behind the selected slot.
    expect(find.byType(GlassLens), findsOneWidget);
  });

  testWidgets('selecting a destination reports the branch index',
      (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(
      host(currentIndex: 0, onChanged: changes.add),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(changes, [2]);
    expect(tester.takeException(), isNull, reason: 'no layout exceptions');
  });

  testWidgets('collapsed mode still renders and toggles metrics',
      (tester) async {
    await tester.pumpWidget(
      host(currentIndex: 0, collapsed: true, onChanged: (_) {}),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.tune_outlined), findsOneWidget);
  });
}
