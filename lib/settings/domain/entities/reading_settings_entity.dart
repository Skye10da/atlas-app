import 'package:flutter/material.dart';

import 'package:atlas_app/core/theme/app_brand.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';

class ReadingSettingsEntity {
  const ReadingSettingsEntity({
    this.systemFontFamily,
    this.brand = AppBrand.violet,
    this.fontSize = 18.0,
    this.fontFamily,
    this.lineHeight = 1.8,
    this.letterSpacing = 0.0,
    this.keepScreenAwake = false,
    this.brightness = 1.0,
    this.autoOptimizeBrightness = false,
    this.theme = ReadingViewTheme.light,
    this.readingMode = ReadingMode.page,
    this.textAlignment = TextAlignment.left,
    this.marginPreset = MarginPreset.normal,
    this.pageTurnAnimation = PageTurnAnimation.slide,
    this.scrollAnimation = ScrollAnimation.smooth,
    this.themeMode = ThemeMode.system,
  });

  final String? systemFontFamily;
  final AppBrand brand;
  final double fontSize;
  final String? fontFamily;
  final double lineHeight;
  final double letterSpacing;
  final bool keepScreenAwake;
  final double brightness;
  final bool autoOptimizeBrightness;
  final ReadingViewTheme theme;
  final ReadingMode readingMode;
  final TextAlignment textAlignment;
  final MarginPreset marginPreset;
  final PageTurnAnimation pageTurnAnimation;
  final ScrollAnimation scrollAnimation;
  final ThemeMode themeMode;

  ReadingSettingsEntity copyWith({
    String? systemFontFamily,
    AppBrand? brand,
    double? fontSize,
    String? fontFamily,
    double? lineHeight,
    double? letterSpacing,
    bool? keepScreenAwake,
    double? brightness,
    bool? autoOptimizeBrightness,
    ReadingViewTheme? theme,
    ReadingMode? readingMode,
    TextAlignment? textAlignment,
    MarginPreset? marginPreset,
    PageTurnAnimation? pageTurnAnimation,
    ScrollAnimation? scrollAnimation,
    ThemeMode? themeMode,
  }) {
    return ReadingSettingsEntity(
      systemFontFamily: systemFontFamily ?? this.systemFontFamily,
      brand: brand ?? this.brand,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      brightness: brightness ?? this.brightness,
      autoOptimizeBrightness: autoOptimizeBrightness ?? this.autoOptimizeBrightness,
      theme: theme ?? this.theme,
      readingMode: readingMode ?? this.readingMode,
      textAlignment: textAlignment ?? this.textAlignment,
      marginPreset: marginPreset ?? this.marginPreset,
      pageTurnAnimation: pageTurnAnimation ?? this.pageTurnAnimation,
      scrollAnimation: scrollAnimation ?? this.scrollAnimation,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}
