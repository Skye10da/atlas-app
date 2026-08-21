import 'package:flutter/material.dart';

import 'package:atlas_app/core/theme/app_brand.dart';
import 'package:atlas_app/core/theme/app_theme_tokens.dart';
import 'package:atlas_app/core/theme/local_fonts.dart';

abstract final class AppTheme {
  static const _displayFont = 'Playfair Display';
  static const _uiFont = 'Inter';
  static const _bodyFont = 'Open Sans';

  static ThemeData light(AppBrand brand, [String? systemFontFamily]) {
    final uiFont = systemFontFamily ?? _uiFont;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brand.seed,
      brightness: Brightness.light,
    );
    return _build(brand, colorScheme, uiFont, Brightness.light);
  }

  static ThemeData dark(AppBrand brand, [String? systemFontFamily]) {
    final uiFont = systemFontFamily ?? _uiFont;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brand.seed,
      brightness: Brightness.dark,
    );
    return _build(brand, colorScheme, uiFont, Brightness.dark);
  }

  static ThemeData _build(
    AppBrand brand,
    ColorScheme colorScheme,
    String uiFont,
    Brightness brightness,
  ) {
    final textTheme = _buildTextTheme(uiFont);
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 2,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
      extensions: [
        AppThemeTokens(
          brandPrimary: brand.seed,
          brandSecondary: colorScheme.secondary,
          radiusXs: 4,
          radiusSm: 8,
          radiusMd: 12,
          radiusLg: 16,
          elevation0: 0,
          elevation1: 1,
          elevation2: 2,
          elevation3: 4,
          opacityDisabled: 0.38,
          opacityHover: 0.08,
          opacityPress: 0.12,
          shadowSm: Shadow(
            blurRadius: 4,
            offset: const Offset(0, 1),
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
          ),
          shadowMd: Shadow(
            blurRadius: 8,
            offset: const Offset(0, 2),
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
          ),
          shadowLg: Shadow(
            blurRadius: 16,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
          ),
        ),
      ],
    );
  }

  static TextTheme _buildTextTheme(String uiFont) {
    const base = TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w300,
        letterSpacing: -0.25,
      ),
      displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400),
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w400),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );

    return TextTheme(
      displayLarge: LocalFonts.getFont(_displayFont, textStyle: base.displayLarge),
      displayMedium: LocalFonts.getFont(
        _displayFont,
        textStyle: base.displayMedium,
      ),
      displaySmall: LocalFonts.getFont(
        _displayFont,
        textStyle: base.displaySmall,
      ),
      headlineLarge: LocalFonts.getFont(uiFont, textStyle: base.headlineLarge),
      headlineMedium: LocalFonts.getFont(
        uiFont,
        textStyle: base.headlineMedium,
      ),
      headlineSmall: LocalFonts.getFont(uiFont, textStyle: base.headlineSmall),
      titleLarge: LocalFonts.getFont(uiFont, textStyle: base.titleLarge),
      titleMedium: LocalFonts.getFont(uiFont, textStyle: base.titleMedium),
      titleSmall: LocalFonts.getFont(uiFont, textStyle: base.titleSmall),
      bodyLarge: LocalFonts.getFont(_bodyFont, textStyle: base.bodyLarge),
      bodyMedium: LocalFonts.getFont(_bodyFont, textStyle: base.bodyMedium),
      bodySmall: LocalFonts.getFont(_bodyFont, textStyle: base.bodySmall),
      labelLarge: LocalFonts.getFont(uiFont, textStyle: base.labelLarge),
      labelMedium: LocalFonts.getFont(uiFont, textStyle: base.labelMedium),
      labelSmall: LocalFonts.getFont(uiFont, textStyle: base.labelSmall),
    );
  }
}
