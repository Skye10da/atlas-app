import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/design_system/molecules/icon_controls.dart';

Widget _harness(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('IconStepper', () {
    testWidgets('steps up and down within bounds and reports new values', (
      tester,
    ) async {
      double value = 16;
      final changes = <double>[];

      await tester.pumpWidget(
        _harness(
          StatefulBuilder(
            builder: (context, setState) => IconStepper(
              value: value,
              min: 12,
              max: 32,
              step: 1,
              onChanged: (v) {
                changes.add(v);
                setState(() => value = v);
              },
              semanticLabel: 'Text size',
              preview: Text('Aa', style: TextStyle(fontSize: value * 0.9)),
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Text size increase'));
      await tester.pump();
      expect(changes, [17]);

      await tester.tap(find.byTooltip('Text size decrease'));
      await tester.pump();
      expect(changes, [17, 16]);

      // Back at the start value: decrease once more, then keep decreasing —
      // the bead disables at the min and stops reporting changes.
      await tester.tap(find.byTooltip('Text size decrease'));
      await tester.pump();
      await tester.tap(find.byTooltip('Text size decrease'));
      await tester.pump();
      await tester.tap(find.byTooltip('Text size decrease'));
      await tester.pump();
      await tester.tap(find.byTooltip('Text size decrease'));
      await tester.pump();
      expect(value, 12);
      final atMin = changes.last;
      await tester.tap(find.byTooltip('Text size decrease'));
      expect(changes.last, atMin);
    });

    testWidgets('disables the increase bead at the max', (tester) async {
      double value = 32;

      await tester.pumpWidget(
        _harness(
          StatefulBuilder(
            builder: (context, setState) => IconStepper(
              value: value,
              min: 12,
              max: 32,
              step: 1,
              onChanged: (v) => setState(() => value = v),
              semanticLabel: 'Text size',
              preview: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Text size increase'));
      await tester.pump();
      expect(value, 32);
      await tester.tap(find.byTooltip('Text size decrease'));
      await tester.pump();
      expect(value, 31);
    });

    testWidgets('shows the current-value caption when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          IconStepper(
            value: 16,
            min: 12,
            max: 32,
            step: 1,
            onChanged: (_) {},
            semanticLabel: 'Text size',
            valueLabel: '16 pt',
            preview: const Text('Aa'),
          ),
        ),
      );

      expect(find.text('16 pt'), findsOneWidget);
      expect(find.text('Aa'), findsOneWidget);
    });

    testWidgets('omits the caption row when no value label is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          IconStepper(
            value: 16,
            min: 12,
            max: 32,
            step: 1,
            onChanged: (_) {},
            semanticLabel: 'Text size',
            preview: const Text('Aa'),
          ),
        ),
      );

      expect(find.text('16 pt'), findsNothing);
      expect(find.text('Aa'), findsOneWidget);
    });
  });

  group('IconSegment', () {
    testWidgets('reports the tapped option value and marks selection', (
      tester,
    ) async {
      final selected = <String>[];

      await tester.pumpWidget(
        _harness(
          IconSegment<String>(
            options: const [
              IconSegmentOption('a', label: 'Tight', icon: Icons.audiotrack),
              IconSegmentOption('b', label: 'Normal', icon: Icons.bookmark),
              IconSegmentOption('c', label: 'Roomy', icon: Icons.build),
            ],
            selected: 'a',
            onSelected: selected.add,
          ),
        ),
      );

      expect(find.text('Tight'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Roomy'), findsOneWidget);

      await tester.tap(find.text('Roomy'));
      expect(selected, ['c']);
    });

    testWidgets('supports custom glyphs instead of icons', (tester) async {
      await tester.pumpWidget(
        _harness(
          IconSegment<double>(
            options: const [
              IconSegmentOption(
                1.3,
                label: 'Tight',
                glyph: SpacedLinesGlyph(gap: 2, color: Colors.grey),
              ),
              IconSegmentOption(
                1.6,
                label: 'Normal',
                glyph: SpacedLinesGlyph(gap: 4, color: Colors.grey),
              ),
            ],
            selected: 1.3,
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.byType(SpacedLinesGlyph), findsNWidgets(2));
      expect(find.byIcon(Icons.audiotrack), findsNothing);
    });
  });

  group('IconToggleBead', () {
    testWidgets('toggles and reports the opposite state', (tester) async {
      final toggles = <bool>[];

      await tester.pumpWidget(
        _harness(
          IconToggleBead(
            active: false,
            label: 'Keep screen awake',
            onChanged: toggles.add,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Keep screen awake'));
      expect(toggles, [true]);
    });
  });

  group('AdvancedDisclosure', () {
    testWidgets('keeps children out of the tree until expanded', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const AdvancedDisclosure(
            label: 'Advanced typography',
            children: [Text('Typeface'), Text('Font Weight')],
          ),
        ),
      );

      expect(find.text('Advanced typography'), findsOneWidget);
      expect(find.text('Typeface'), findsNothing);
      expect(find.text('Font Weight'), findsNothing);

      await tester.tap(find.text('Advanced typography'));
      await tester.pumpAndSettle();

      expect(find.text('Typeface'), findsOneWidget);
      expect(find.text('Font Weight'), findsOneWidget);

      // Collapsing again removes the children from the tree.
      await tester.tap(find.text('Advanced typography'));
      await tester.pumpAndSettle();
      expect(find.text('Typeface'), findsNothing);
    });

    testWidgets('respects initiallyExpanded and shows the hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const AdvancedDisclosure(
            label: 'Advanced typography',
            hint: 'Serif',
            initiallyExpanded: true,
            children: [Text('Typeface')],
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Typeface'), findsOneWidget);
      expect(find.text('Serif'), findsOneWidget);
    });
  });

  group('SpacedLinesGlyph', () {
    testWidgets('draws three lines', (tester) async {
      await tester.pumpWidget(
        _harness(const SpacedLinesGlyph(gap: 4, color: Colors.grey)),
      );

      expect(find.byType(Container), findsNWidgets(3));
    });
  });
}
