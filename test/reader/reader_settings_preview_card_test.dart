import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/reader_settings_preview_card.dart';

void main() {
  group('ReaderSettingsPreviewCard', () {
    testWidgets('renders preview header, sample text, and footer badges', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReaderSettingsPreviewCard(
              theme: ReadingViewTheme.sepia,
              fontSize: 18.0,
              fontFamily: 'Playfair Display',
              fontWeight: 400,
              lineHeight: 1.6,
              letterSpacing: 0.0,
              textAlignment: TextAlignment.left,
              marginPreset: MarginPreset.normal,
            ),
          ),
        ),
      );

      expect(find.text('LIVE READING PREVIEW'), findsOneWidget);
      expect(find.text('Chapter Four: The Silent River'), findsOneWidget);
      expect(
        find.textContaining('The evening air was crisp and tranquil'),
        findsOneWidget,
      );
      expect(find.text('Playfair Display • 18 pt'), findsOneWidget);
      expect(find.text('Sepia • 1.6x'), findsOneWidget);
    });

    testWidgets('updates dynamically when theme and size change', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReaderSettingsPreviewCard(
              theme: ReadingViewTheme.amoled,
              fontSize: 22.0,
              fontFamily: 'Inter',
              fontWeight: 600,
              lineHeight: 1.8,
              letterSpacing: 0.5,
              textAlignment: TextAlignment.justify,
              marginPreset: MarginPreset.wide,
            ),
          ),
        ),
      );

      expect(find.text('Inter • 22 pt'), findsOneWidget);
      expect(find.text('AMOLED • 1.8x'), findsOneWidget);
    });
  });
}

