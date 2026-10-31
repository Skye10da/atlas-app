import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_speed_control.dart';

/// Narration rate dial tests (reader glass pills plan phase 4): the selected
/// rate carries the GlassLens droplet, and tapping a chip reports its preset.
Widget _host(Widget child) => MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  const accent = Color(0xFF8B5E34);

  testWidgets('droplet highlights the selected rate chip', (tester) async {
    await tester.pumpWidget(_host(
      NarrationSpeedControl(
        accent: accent,
        color: Colors.black,
        rateOverride: 1.5,
        onRateChanged: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    final droplet = tester.getRect(find.byType(GlassLens));
    final chip = tester.getRect(find.text('1.5×'));
    expect(droplet.left <= chip.center.dx, isTrue,
        reason: 'droplet must cover the selected chip');
    expect(chip.center.dx <= droplet.right, isTrue);
    expect(droplet.left <= chip.left && chip.right <= droplet.right, isTrue);
  });

  testWidgets('unknown rates highlight the neutral 1× chip', (tester) async {
    await tester.pumpWidget(_host(
      NarrationSpeedControl(
        accent: accent,
        color: Colors.black,
        rateOverride: 1.1,
        onRateChanged: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    final droplet = tester.getRect(find.byType(GlassLens));
    final neutral = tester.getRect(find.text('1×'));
    expect(droplet.left <= neutral.center.dx, isTrue);
    expect(neutral.center.dx <= droplet.right, isTrue);
  });

  testWidgets('tapping a chip reports that preset', (tester) async {
    final rates = <double>[];
    await tester.pumpWidget(_host(
      NarrationSpeedControl(
        accent: accent,
        color: Colors.black,
        rateOverride: 0.75,
        onRateChanged: rates.add,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2×'));
    await tester.pumpAndSettle();
    expect(rates, [2.0]);
  });

  testWidgets('renders all six preset chips', (tester) async {
    await tester.pumpWidget(_host(
      NarrationSpeedControl(
        accent: accent,
        color: Colors.black,
        rateOverride: 1.0,
        onRateChanged: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    for (final label in ['0.5×', '0.75×', '1×', '1.25×', '1.5×', '2×']) {
      expect(find.text(label), findsOneWidget, reason: 'missing chip $label');
    }
  });
}
