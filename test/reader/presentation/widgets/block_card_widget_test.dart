import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/reader/presentation/widgets/block_card_theme.dart';
import 'package:atlas_app/reader/presentation/widgets/block_card_widget.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';

ReadingColors _darkColors() => const ReadingColors(
  background: Color(0xFF101418),
  text: Color(0xFFE8ECEF),
  surface: Color(0xFF181D23),
  accent: Color(0xFF6C9EFF),
);

ReadingColors _lightColors() => const ReadingColors(
  background: Color(0xFFFAF6EE),
  text: Color(0xFF2A2620),
  surface: Color(0xFFF1EAD9),
  accent: Color(0xFF8A5A2B),
);

BlockCard _confidentCard() => const BlockCard(
  type: BlockCardType.system,
  title: 'Character status',
  confidence: 0.9,
  rawText: 'HP: 840/1000\nClass: Reaver',
  fields: [
    BlockCardField(
      label: 'HP',
      value: '840 / 1000',
      display: FieldDisplay.bar,
      current: 840,
      max: 1000,
    ),
    BlockCardField(label: 'Class', value: 'Reaver'),
  ],
  tags: ['Devour Essence Lv.1'],
  footnote: 'Sync complete.',
);

BlockCard _weakCard() => BlockCard.fallback(
  'The old man sighed and walked away into the morning mist.',
);

Widget _host(BlockCard card, ReadingColors colors) => MaterialApp(
  home: Scaffold(
    body: BlockCardWidget(card: card, colors: colors),
  ),
);

void main() {
  group('BlockCardWidget', () {
    testWidgets('renders themed presentation above the confidence threshold', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_confidentCard(), _darkColors()));

      expect(find.text('SYSTEM NOTIFICATION'), findsOneWidget);
      expect(find.text('Character status'), findsOneWidget);
      expect(find.text('Class'), findsOneWidget);
      expect(find.text('Reaver'), findsOneWidget);
      expect(find.text('Devour Essence Lv.1'), findsOneWidget);
      expect(find.text('Sync complete.'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // No dashed border on confident cards.
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.foregroundPainter is DashedBorderPainter,
        ),
        findsNothing,
      );
    });

    testWidgets(
      'renders fallback presentation below the confidence threshold',
      (tester) async {
        final weak = _weakCard();
        await tester.pumpWidget(_host(weak, _lightColors()));

        expect(find.text('UNPARSED STATUS TEXT'), findsOneWidget);
        expect(
          find.text(
            'The old man sighed and walked away into the morning mist.',
          ),
          findsOneWidget,
        );
        // Parsed fields are not shown for untrusted parses.
        expect(find.text('SYSTEM NOTIFICATION'), findsNothing);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is CustomPaint && w.foregroundPainter is DashedBorderPainter,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('bar fields fall back to accent color when label is unknown', (
      tester,
    ) async {
      const card = BlockCard(
        type: BlockCardType.system,
        confidence: 0.9,
        rawText: 'Qi: 61%',
        fields: [
          BlockCardField(
            label: 'Qi',
            value: '61%',
            display: FieldDisplay.bar,
            current: 61,
            max: 100,
          ),
        ],
      );
      await tester.pumpWidget(_host(card, _darkColors()));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('adaptive theming', () {
    test('theme colors derive from the active reader palette', () {
      final dark = resolveBlockCardTheme(_confidentCard(), _darkColors());
      final light = resolveBlockCardTheme(_confidentCard(), _lightColors());

      // Backgrounds stay close to the reader background luminance while
      // differing between palettes.
      expect(dark.background, isNot(light.background));
      expect(
        (dark.background.computeLuminance() -
                _darkColors().background.computeLuminance())
            .abs(),
        lessThan(0.12),
      );
      expect(
        (light.background.computeLuminance() -
                _lightColors().background.computeLuminance())
            .abs(),
        lessThan(0.12),
      );

      // Text roles follow the reader text color.
      expect(dark.valueColor, _darkColors().text.withValues(alpha: 0.95));
      expect(light.labelColor, _lightColors().text.withValues(alpha: 0.55));
    });

    test('genre hue survives adaptation per palette brightness', () {
      final darkTheme = systemThemeFor(_darkColors());
      final lightTheme = systemThemeFor(_lightColors());

      // Cyan family preserved on dark backgrounds.
      expect(darkTheme.glowOrAccent.b, greaterThan(darkTheme.glowOrAccent.r));
      // Light backgrounds darken the hue toward black for contrast.
      expect(
        lightTheme.glowOrAccent.computeLuminance(),
        lessThan(const Color(0xFF54E1FF).computeLuminance()),
      );
    });

    test('shadows only apply on dark reader palettes', () {
      expect(systemThemeFor(_darkColors()).shadows, isNotEmpty);
      expect(systemThemeFor(_lightColors()).shadows, isEmpty);
    });

    test(
      'low-confidence cards always resolve to the dashed fallback',
      () async {
        final darkFallback = resolveBlockCardTheme(_weakCard(), _darkColors());
        final lightFallback = resolveBlockCardTheme(
          _weakCard(),
          _lightColors(),
        );

        expect(darkFallback.dashedBorder, isTrue);
        expect(lightFallback.dashedBorder, isTrue);
        expect(darkFallback.label, 'UNPARSED STATUS TEXT');
      },
    );

    test('registered custom themes receive the active palette', () {
      // A plugin re-pointing "custom" at the cultivation builder proves
      // registered builders are palette-adaptive like built-ins.
      registerBlockCardTheme(BlockCardType.custom, cultivationThemeFor);
      addTearDown(
        () => registerBlockCardTheme(BlockCardType.custom, fallbackThemeFor),
      );

      final theme = resolveBlockCardTheme(
        const BlockCard(
          type: BlockCardType.custom,
          confidence: 0.9,
          rawText: 'x',
        ),
        _darkColors(),
      );
      expect(theme.label, 'BREAKTHROUGH');
      expect(theme.background, _cardBackgroundNear(_darkColors()));
    });
  });
}

Color _cardBackgroundNear(ReadingColors colors) =>
    Color.lerp(colors.background, const Color(0xFFB9974F), 0.07)!;
