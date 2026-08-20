import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_settings_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/theme_preview_screen.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';
import 'package:atlas_app/settings/presentation/screens/reading_settings_screen.dart';

void main() {
  group('PdfSettingsSheet', () {
    testWidgets('shows theme picker and keep-awake switch', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: PdfSettingsSheet())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reading Settings'), findsOneWidget);
      expect(find.text('Color Theme'), findsOneWidget);
      expect(find.text('Keep screen awake'), findsOneWidget);
      expect(find.text('More in Reading settings'), findsOneWidget);
      expect(find.byType(ReadingSettingsScreen), findsNothing);
    });

    testWidgets('tapping a theme opens preview and apply updates provider', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: PdfSettingsSheet())),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(PdfSettingsSheet)));

      // Before: default paper theme.
      expect(
        container.read(readingSettingsProvider).valueOrNull?.theme,
        ReadingViewTheme.paper,
      );

      // Tap the Dracula swatch — opens the preview screen.
      await tester.tap(find.text('Dracula'));
      await tester.pumpAndSettle();

      // Verify preview screen is open.
      expect(find.byType(ThemePreviewScreen), findsOneWidget);

      // Tap Apply on the preview screen.
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(
        container.read(readingSettingsProvider).valueOrNull?.theme,
        ReadingViewTheme.dracula,
      );
    });

    testWidgets('keep-awake switch persists via the notifier', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: PdfSettingsSheet())),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(PdfSettingsSheet)));
      expect(
        container.read(readingSettingsProvider).valueOrNull!.keepScreenAwake,
        isFalse,
      );

      await tester.tap(find.text('Keep screen awake'));
      await tester.pumpAndSettle();

      expect(
        container.read(readingSettingsProvider).valueOrNull!.keepScreenAwake,
        isTrue,
      );
    });
  });
}