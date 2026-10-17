import 'package:atlas_app/core/theme/app_brand.dart';
import 'package:atlas_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppBrand.atlas', () {
    test('is the first (default) brand and uses the deep-green seed', () {
      expect(AppBrand.values.first, AppBrand.atlas);
      expect(AppBrand.atlas.seed, const Color(0xFF2F5D50));
      expect(AppBrand.atlas.label, 'Atlas');
      expect(AppBrand.atlas.usesWarmSurfaces, isTrue);
    });

    test('other brands keep neutral surfaces', () {
      expect(AppBrand.violet.usesWarmSurfaces, isFalse);
    });
  });

  group('AppTheme typography', () {
    test('display roles use Fraunces, UI roles use DM Sans (all brands)', () {
      for (final brand in AppBrand.values) {
        final theme = AppTheme.light(brand);
        expect(
          theme.textTheme.displayLarge?.fontFamily,
          'Fraunces',
          reason: 'brand $brand',
        );
        expect(theme.textTheme.headlineSmall?.fontFamily, 'Fraunces');
        expect(theme.textTheme.titleLarge?.fontFamily, 'DM Sans');
        expect(theme.textTheme.bodyMedium?.fontFamily, 'DM Sans');
      }
    });
  });

  group('Atlas warm surfaces', () {
    test('light scheme uses the parchment canvas + warm card tint', () {
      final scheme = AppTheme.light(AppBrand.atlas).colorScheme;
      expect(scheme.surface, const Color(0xFFF5F0E6));
      expect(scheme.surfaceContainerLow, const Color(0xFFFBF8F1));
      expect(scheme.outlineVariant, const Color(0xFFE4DCCB));
    });

    test('non-atlas brands keep fromSeed surfaces', () {
      final atlas = AppTheme.light(AppBrand.atlas).colorScheme.surface;
      final violet = AppTheme.light(AppBrand.violet).colorScheme.surface;
      expect(violet, isNot(atlas));
    });

    test('dark mode does not force the parchment canvas', () {
      final scheme = AppTheme.dark(AppBrand.atlas).colorScheme;
      expect(scheme.surface, isNot(const Color(0xFFF5F0E6)));
    });
  });
}
