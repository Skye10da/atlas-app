import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/reader/domain/entities/reading_preset.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

void main() {
  group('ReadingPreset', () {
    test('has all defined curated presets', () {
      expect(ReadingPreset.presets.length, equals(7));
      final ids = ReadingPreset.presets.map((p) => p.id).toList();
      expect(ids, contains(ReadingPresetId.classicPaper));
      expect(ids, contains(ReadingPresetId.antiqueBook));
      expect(ids, contains(ReadingPresetId.cedarWood));
      expect(ids, contains(ReadingPresetId.modernClean));
      expect(ids, contains(ReadingPresetId.midnightOled));
      expect(ids, contains(ReadingPresetId.warmAmber));
      expect(ids, contains(ReadingPresetId.focusMinimal));
    });

    test('matches correctly when attributes match within tolerance', () {
      final classic = ReadingPreset.presets.firstWhere(
        (p) => p.id == ReadingPresetId.classicPaper,
      );

      expect(
        classic.matches(
          currentTheme: ReadingViewTheme.paper,
          currentFontFamily: 'Playfair Display',
          currentFontSize: 18.0,
          currentLineHeight: 1.6,
        ),
        isTrue,
      );

      // Slightly different font size within 1.0 tolerance
      expect(
        classic.matches(
          currentTheme: ReadingViewTheme.paper,
          currentFontFamily: 'Playfair Display',
          currentFontSize: 18.5,
          currentLineHeight: 1.65,
        ),
        isTrue,
      );

      // Different theme should fail
      expect(
        classic.matches(
          currentTheme: ReadingViewTheme.amoled,
          currentFontFamily: 'Playfair Display',
          currentFontSize: 18.0,
          currentLineHeight: 1.6,
        ),
        isFalse,
      );

      // Different font family should fail
      expect(
        classic.matches(
          currentTheme: ReadingViewTheme.paper,
          currentFontFamily: 'Inter',
          currentFontSize: 18.0,
          currentLineHeight: 1.6,
        ),
        isFalse,
      );
    });
  });
}

