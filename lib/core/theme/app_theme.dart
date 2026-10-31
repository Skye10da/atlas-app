import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/colors.dart';
import 'package:atlas_app/core/theme/app_brand.dart';
import 'package:atlas_app/core/theme/app_theme_tokens.dart';
import 'package:atlas_app/core/theme/local_fonts.dart';

abstract final class AppTheme {
  static const _displayFont = 'Fraunces';
  static const _uiFont = 'DM Sans';
  static const _bodyFont = 'DM Sans';

  static ThemeData light(AppBrand brand, [String? systemFontFamily]) {
    final uiFont = systemFontFamily ?? _uiFont;
    var colorScheme = ColorScheme.fromSeed(
      seedColor: brand.seed,
      brightness: Brightness.light,
    );
    if (brand.usesWarmSurfaces) {
      colorScheme = colorScheme.copyWith(
        surface: AppColors.parchment,
        surfaceContainerLowest: AppColors.parchment,
        surfaceContainerLow: AppColors.surfaceCard,
        surfaceContainer: AppColors.surfaceCard,
        surfaceContainerHigh: AppColors.surfaceCard,
        surfaceContainerHighest: AppColors.surfaceCard,
        outlineVariant: AppColors.hairline,
      );
    }
    return _build(brand, colorScheme, uiFont, Brightness.light);
  }

  static ThemeData dark(AppBrand brand, [String? systemFontFamily]) {
    final uiFont = systemFontFamily ?? _uiFont;
    // Dark surfaces derive from the seed automatically; the warm parchment
    // canvas is a light-mode treatment only.
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

      // Shared "Atlas" look: serif page titles, 22dp bordered cards, pill
      // buttons / chips / segmented controls, 28dp sheets and dialogs.
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.secondaryContainer,
        indicatorShape: const StadiumBorder(),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          side: WidgetStatePropertyAll(
            BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: colorScheme.outlineVariant.withValues(alpha: 0.6),
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: colorScheme.onSurface,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: BorderSide(color: colorScheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: const StadiumBorder()),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: false,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
      displayLarge: LocalFonts.getFont(
        _displayFont,
        textStyle: base.displayLarge,
      ),
      displayMedium: LocalFonts.getFont(
        _displayFont,
        textStyle: base.displayMedium,
      ),
      displaySmall: LocalFonts.getFont(
        _displayFont,
        textStyle: base.displaySmall,
      ),
      headlineLarge: LocalFonts.getFont(
        _displayFont,
        textStyle: base.headlineLarge,
      ),
      headlineMedium: LocalFonts.getFont(
        _displayFont,
        textStyle: base.headlineMedium,
      ),
      headlineSmall: LocalFonts.getFont(
        _displayFont,
        textStyle: base.headlineSmall,
      ),
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
