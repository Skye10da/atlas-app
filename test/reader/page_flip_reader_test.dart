import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/layout_tab.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

void main() {
  group('Real Flip & Sensory Controls Integration', () {
    test('ReadingSettingsEntity defaults to realFlip animation and sensory flags', () {
      const settings = ReadingSettingsEntity();
      expect(settings.pageTurnAnimation, PageTurnAnimation.realFlip);
      expect(settings.enablePageFlipSound, false);
      expect(settings.enablePageFlipHaptics, true);
    });

    testWidgets('LayoutTab renders Real Flip card and Sensory Controls switches', (
      tester,
    ) async {
      bool soundToggled = false;
      bool hapticsToggled = false;
      PageTurnAnimation? selectedAnim;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LayoutTab(
                readingMode: ReadingMode.page,
                keepScreenAwake: false,
                brightness: 1.0,
                autoOptimizeBrightness: false,
                followSystemBrightness: true,
                pageTurnAnimation: PageTurnAnimation.realFlip,
                enablePageFlipSound: false,
                enablePageFlipHaptics: true,
                scrollAnimation: ScrollAnimation.smooth,
                chromeStyle: ReaderChromeStyle.translucent,
                desktopSheetPresentation: DesktopSheetPresentation.dialog,
                horizontalPadding: 16.0,
                useBookSpread: true,
                onReadingModeChanged: (_) {},
                onHorizontalPaddingChanged: (_) {},
                onUseBookSpreadChanged: (_) {},
                onPageTurnAnimationChanged: (a) => selectedAnim = a,
                onEnablePageFlipSoundChanged: (s) => soundToggled = s,
                onEnablePageFlipHapticsChanged: (h) => hapticsToggled = h,
                onScrollAnimationChanged: (_) {},
                onChromeStyleChanged: (_) {},
                onDesktopSheetPresentationChanged: (_) {},
                onKeepScreenAwakeChanged: (_) {},
                onBrightnessChanged: (_) {},
                onAutoOptimizeChanged: (_) {},
                onFollowSystemBrightnessChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Verify Page Flip card is present and visible
      expect(find.text('Page Flip'), findsOneWidget);
      expect(find.text('Sensory Controls'), findsOneWidget);
      expect(find.text('Page Turn Sound'), findsOneWidget);
      expect(find.text('Haptic Feedback'), findsOneWidget);

      // Tap an animation card (e.g., Slide or Real Flip)
      await tester.tap(find.text('Slide'));
      expect(selectedAnim, PageTurnAnimation.slide);

      // Toggle Sound switch
      final soundSwitch = find.ancestor(
        of: find.text('Page Turn Sound'),
        matching: find.byType(SwitchListTile),
      );
      expect(soundSwitch, findsOneWidget);
      await tester.tap(soundSwitch);
      expect(soundToggled, isTrue);

      // Toggle Haptics switch
      final hapticsSwitch = find.ancestor(
        of: find.text('Haptic Feedback'),
        matching: find.byType(SwitchListTile),
      );
      expect(hapticsSwitch, findsOneWidget);
      await tester.tap(hapticsSwitch);
      expect(hapticsToggled, isFalse);
    });

    test('ReadingMode.realFlip is defined with proper label and icon', () {
      expect(ReadingMode.realFlip.label, 'Real Page Flip');
      expect(ReadingMode.realFlip.icon, Icons.menu_book);
    });
  });
}
