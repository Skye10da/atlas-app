import 'package:flutter/material.dart';

import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

class ReadingColors {
  const ReadingColors({
    required this.background,
    required this.text,
    required this.surface,
    required this.accent,
  });

  final Color background;
  final Color text;
  final Color surface;
  final Color accent;
}

extension ReadingViewThemeColorsX on ReadingViewTheme {
  ReadingColors resolve(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    return switch (this) {
      ReadingViewTheme.paper => ReadingColors(
        background: isDark ? const Color(0xFF121416) : const Color(0xFFFFFBF2),
        text: isDark ? const Color(0xFFE8E2D9) : const Color(0xFF1E1A16),
        surface: isDark ? const Color(0xFF1C1E20) : const Color(0xFFF5EEE0),
        accent: isDark ? const Color(0xFFD4A373) : const Color(0xFF8B5E34),
      ),
      ReadingViewTheme.parchment => ReadingColors(
        background: isDark ? const Color(0xFF1C160B) : const Color(0xFFFFF8E1),
        text: isDark ? const Color(0xFFEFDFB8) : const Color(0xFF3E2723),
        surface: isDark ? const Color(0xFF2A1F0F) : const Color(0xFFFFECC1),
        accent: isDark ? const Color(0xFFE6B86A) : const Color(0xFF6D4C41),
      ),
      ReadingViewTheme.ivory => ReadingColors(
        background: isDark ? const Color(0xFF191815) : const Color(0xFFFFFEF7),
        text: isDark ? const Color(0xFFEEE8D5) : const Color(0xFF2B2A26),
        surface: isDark ? const Color(0xFF25231E) : const Color(0xFFF8F4E8),
        accent: isDark ? const Color(0xFFB8A890) : const Color(0xFF5D4037),
      ),
      ReadingViewTheme.sepia => ReadingColors(
        background: isDark ? const Color(0xFF1E170A) : const Color(0xFFF5E6CC),
        text: isDark ? const Color(0xFFF0D9A8) : const Color(0xFF433422),
        surface: isDark ? const Color(0xFF2E2410) : const Color(0xFFE8D5B5),
        accent: isDark ? const Color(0xFFE2A950) : const Color(0xFF7A4A2E),
      ),
      ReadingViewTheme.wood => ReadingColors(
        background: isDark ? const Color(0xFF24160E) : const Color(0xFFE2D1C3),
        text: isDark ? const Color(0xFFEAD6C5) : const Color(0xFF2C190F),
        surface: isDark ? const Color(0xFF332015) : const Color(0xFFD6C1AF),
        accent: isDark ? const Color(0xFFE08D50) : const Color(0xFF9E4E20),
      ),
      ReadingViewTheme.book => ReadingColors(
        background: isDark ? const Color(0xFF1F1C18) : const Color(0xFFF7F0DF),
        text: isDark ? const Color(0xFFEBE0CD) : const Color(0xFF23201B),
        surface: isDark ? const Color(0xFF2D2822) : const Color(0xFFEDE2CB),
        accent: isDark ? const Color(0xFFE5B558) : const Color(0xFFAC3D20),
      ),
      ReadingViewTheme.blueLight => ReadingColors(
        background: isDark ? const Color(0xFF0E1B2E) : const Color(0xFFEAF6FF),
        text: isDark ? const Color(0xFFD0E6F6) : const Color(0xFF0F2A44),
        surface: isDark ? const Color(0xFF162A45) : const Color(0xFFD6ECFF),
        accent: isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0),
      ),
      ReadingViewTheme.warmGray => ReadingColors(
        background: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F0EB),
        text: isDark ? const Color(0xFFE8E8E6) : const Color(0xFF2B2B2B),
        surface: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E6E1),
        accent: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF616161),
      ),
      ReadingViewTheme.mint => ReadingColors(
        background: isDark ? const Color(0xFF0F1E17) : const Color(0xFFE6F4EA),
        text: isDark ? const Color(0xFFC8E6C9) : const Color(0xFF1B3329),
        surface: isDark ? const Color(0xFF1A2E23) : const Color(0xFFD0E8D9),
        accent: isDark ? const Color(0xFF66BB8A) : const Color(0xFF2E7D52),
      ),
      ReadingViewTheme.forest => ReadingColors(
        background: isDark ? const Color(0xFF0F1A12) : const Color(0xFFEFF6EF),
        text: isDark ? const Color(0xFFD0E2D0) : const Color(0xFF1A2E1A),
        surface: isDark ? const Color(0xFF1C2E1C) : const Color(0xFFD8E8D8),
        accent: isDark ? const Color(0xFF81C784) : const Color(0xFF2E6B31),
      ),
      ReadingViewTheme.ocean => ReadingColors(
        background: isDark ? const Color(0xFF071829) : const Color(0xFFE3F2FD),
        text: isDark ? const Color(0xFFB3D4F0) : const Color(0xFF0D2A4A),
        surface: isDark ? const Color(0xFF0F2A45) : const Color(0xFFBBDEFB),
        accent: isDark ? const Color(0xFF4FC3F7) : const Color(0xFF0277BD),
      ),
      ReadingViewTheme.midnight => ReadingColors(
        background: isDark ? const Color(0xFF070D1E) : const Color(0xFFE8EEF8),
        text: isDark ? const Color(0xFFC9D4F0) : const Color(0xFF0F1B33),
        surface: isDark ? const Color(0xFF0F1B33) : const Color(0xFFD0D9F0),
        accent: isDark ? const Color(0xFF7C9DFF) : const Color(0xFF1A3A8A),
      ),
      ReadingViewTheme.charcoal => ReadingColors(
        background: isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F5),
        text: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A),
        surface: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0),
        accent: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF424242),
      ),
      ReadingViewTheme.nord => ReadingColors(
        background: isDark ? const Color(0xFF2E3440) : const Color(0xFFECEFF4),
        text: isDark ? const Color(0xFFECEFF4) : const Color(0xFF2E3440),
        surface: isDark ? const Color(0xFF3B4252) : const Color(0xFFD8DEE9),
        accent: isDark ? const Color(0xFF88C0D0) : const Color(0xFF4C6A8A),
      ),
      ReadingViewTheme.dracula => ReadingColors(
        background: isDark ? const Color(0xFF1E1F29) : const Color(0xFFF5E6FF),
        text: isDark ? const Color(0xFFF8F8F2) : const Color(0xFF2D0A4A),
        surface: isDark ? const Color(0xFF282A36) : const Color(0xFFE9D5FF),
        accent: isDark ? const Color(0xFFBD93F9) : const Color(0xFF6B21A8),
      ),
      ReadingViewTheme.amoled => ReadingColors(
        background: isDark ? const Color(0xFF000000) : const Color(0xFFFFFBFF),
        text: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF1A1C1E),
        surface: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF0F0F3),
        accent: isDark ? const Color(0xFF9C27B0) : scheme.primary,
      ),
    };
  }

  // Kept for potential future theme blending; suppressed unused warning.
  // ignore: unused_element
  static Color _tint(
    Color c, {
    double hueShift = 0,
    double satBoost = 0,
    double lightShift = 0,
  }) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withHue((hsl.hue + hueShift) % 360)
        .withSaturation((hsl.saturation + satBoost).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + lightShift).clamp(0.0, 1.0))
        .toColor();
  }

  // ignore: unused_element
  static Color _desaturate(
    Color c, {
    double amount = 0.1,
    double lightShift = 0,
  }) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation((hsl.saturation - amount).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + lightShift).clamp(0.0, 1.0))
        .toColor();
  }
}
