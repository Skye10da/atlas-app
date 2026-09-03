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
    final bg = isDark ? scheme.surface : scheme.surface;
    final txt = isDark ? scheme.onSurface : scheme.onSurface;
    final sf = isDark ? scheme.surfaceContainerLow : scheme.surfaceContainerLow;

    return switch (this) {
      ReadingViewTheme.paper => ReadingColors(
        background: bg,
        text: txt,
        surface: sf,
        accent: scheme.primary,
      ),
      ReadingViewTheme.parchment => ReadingColors(
        background: _tint(bg, hueShift: 30, satBoost: 0.08),
        text: _tint(txt, hueShift: 20, satBoost: 0.05),
        surface: _tint(sf, hueShift: 30, satBoost: 0.1),
        accent: scheme.primary,
      ),
      ReadingViewTheme.ivory => ReadingColors(
        background: _tint(bg, hueShift: 40, satBoost: 0.06),
        text: _tint(txt, hueShift: 30, satBoost: 0.04),
        surface: _tint(sf, hueShift: 40, satBoost: 0.08),
        accent: scheme.primary,
      ),
      ReadingViewTheme.sepia => ReadingColors(
        background: _tint(bg, hueShift: 35, satBoost: 0.15),
        text: _tint(txt, hueShift: 25, satBoost: 0.1),
        surface: _tint(sf, hueShift: 35, satBoost: 0.18),
        accent: scheme.primary,
      ),
      ReadingViewTheme.wood => ReadingColors(
        background: isDark
            ? const Color(0xFF24160E)
            : const Color(0xFFE2D1C3),
        text: isDark
            ? const Color(0xFFEAD6C5)
            : const Color(0xFF2C190F),
        surface: isDark
            ? const Color(0xFF332015)
            : const Color(0xFFD6C1AF),
        accent: isDark
            ? const Color(0xFFE08D50)
            : const Color(0xFF9E4E20),
      ),
      ReadingViewTheme.book => ReadingColors(
        background: isDark
            ? const Color(0xFF1F1C18)
            : const Color(0xFFF7F0DF),
        text: isDark
            ? const Color(0xFFEBE0CD)
            : const Color(0xFF23201B),
        surface: isDark
            ? const Color(0xFF2D2822)
            : const Color(0xFFEDE2CB),
        accent: isDark
            ? const Color(0xFFE5B558)
            : const Color(0xFFAC3D20),
      ),
      ReadingViewTheme.blueLight => ReadingColors(
        background: _tint(bg, hueShift: -30, satBoost: 0.1),
        text: _tint(txt, hueShift: -20, satBoost: 0.06),
        surface: _tint(sf, hueShift: -30, satBoost: 0.12),
        accent: scheme.primary,
      ),
      ReadingViewTheme.warmGray => ReadingColors(
        background: _desaturate(bg, amount: 0.15),
        text: _desaturate(txt, amount: 0.1),
        surface: _desaturate(sf, amount: 0.18),
        accent: scheme.primary,
      ),
      ReadingViewTheme.mint => ReadingColors(
        background: _tint(bg, hueShift: -60, satBoost: 0.12),
        text: _tint(txt, hueShift: -50, satBoost: 0.08),
        surface: _tint(sf, hueShift: -60, satBoost: 0.15),
        accent: scheme.primary,
      ),
      ReadingViewTheme.forest => ReadingColors(
        background: _tint(bg, hueShift: -70, satBoost: 0.1),
        text: _tint(txt, hueShift: -60, satBoost: 0.07),
        surface: _tint(sf, hueShift: -70, satBoost: 0.12),
        accent: scheme.primary,
      ),
      ReadingViewTheme.ocean => ReadingColors(
        background: _tint(bg, hueShift: -40, satBoost: 0.15),
        text: _tint(txt, hueShift: -30, satBoost: 0.1),
        surface: _tint(sf, hueShift: -40, satBoost: 0.18),
        accent: scheme.primary,
      ),
      ReadingViewTheme.midnight => ReadingColors(
        background: _tint(
          bg,
          hueShift: -50,
          satBoost: 0.12,
          lightShift: isDark ? -0.05 : 0,
        ),
        text: _tint(txt, hueShift: -40, satBoost: 0.08),
        surface: _tint(
          sf,
          hueShift: -50,
          satBoost: 0.15,
          lightShift: isDark ? -0.05 : 0,
        ),
        accent: scheme.primary,
      ),
      ReadingViewTheme.charcoal => ReadingColors(
        background: _desaturate(
          bg,
          amount: 0.25,
          lightShift: isDark ? 0.02 : -0.04,
        ),
        text: _desaturate(txt, amount: 0.2),
        surface: _desaturate(
          sf,
          amount: 0.28,
          lightShift: isDark ? 0.02 : -0.04,
        ),
        accent: scheme.primary,
      ),
      ReadingViewTheme.nord => ReadingColors(
        background: _tint(
          bg,
          hueShift: -45,
          satBoost: 0.08,
          lightShift: isDark ? 0.02 : -0.01,
        ),
        text: _tint(txt, hueShift: -35, satBoost: 0.05),
        surface: _tint(
          sf,
          hueShift: -45,
          satBoost: 0.1,
          lightShift: isDark ? 0.02 : -0.01,
        ),
        accent: scheme.primary,
      ),
      ReadingViewTheme.dracula => ReadingColors(
        background: _tint(
          bg,
          hueShift: 60,
          satBoost: 0.12,
          lightShift: isDark ? -0.02 : 0,
        ),
        text: _tint(txt, hueShift: 50, satBoost: 0.08),
        surface: _tint(
          sf,
          hueShift: 60,
          satBoost: 0.15,
          lightShift: isDark ? -0.02 : 0,
        ),
        accent: scheme.primary,
      ),
      ReadingViewTheme.amoled => ReadingColors(
        background: isDark ? const Color(0xFF000000) : bg,
        text: isDark ? const Color(0xFFFFFFFF) : txt,
        surface: isDark ? const Color(0xFF0A0A0A) : sf,
        accent: scheme.primary,
      ),
    };
  }

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
