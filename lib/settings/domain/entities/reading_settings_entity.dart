import 'package:flutter/material.dart';

import 'package:atlas_app/core/theme/app_brand.dart';
import 'package:atlas_app/settings/domain/value_objects/desktop_sheet_presentation.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

class ReadingSettingsEntity {
  const ReadingSettingsEntity({
    this.systemFontFamily,
    this.brand = AppBrand.violet,
    this.fontSize = 18.0,
    this.fontFamily,
    this.fontWeight,
    this.lineHeight = 1.8,
    this.letterSpacing = 0.0,
    this.keepScreenAwake = false,
    this.brightness = 1.0,
    this.autoOptimizeBrightness = false,
    this.followSystemBrightness = true,
    this.theme = ReadingViewTheme.paper,
    this.readingMode = ReadingMode.page,
    this.textAlignment = TextAlignment.left,
    this.marginPreset = MarginPreset.normal,
    this.horizontalPadding = 24.0,
    this.useBookSpread = true,
    this.pageTurnAnimation = PageTurnAnimation.realFlip,
    this.pageFlipGestureZone = PageFlipGestureZone.fullScreen,
    this.enablePageFlipSound = false,
    this.enablePageFlipHaptics = true,
    this.scrollAnimation = ScrollAnimation.smooth,
    this.chromeStyle = ReaderChromeStyle.translucent,
    this.themeMode = ThemeMode.system,
    this.desktopSheetPresentation = DesktopSheetPresentation.dialog,
  });

  final String? systemFontFamily;
  final AppBrand brand;
  final double fontSize;
  final String? fontFamily;

  /// Numeric weight for the reader body text (e.g. 400, 500, 700). `null`
  /// keeps the family's default Regular weight.
  final int? fontWeight;
  final double lineHeight;
  final double letterSpacing;
  final bool keepScreenAwake;
  final double brightness;
  final bool autoOptimizeBrightness;
  final bool followSystemBrightness;
  final ReadingViewTheme theme;
  final ReadingMode readingMode;
  final TextAlignment textAlignment;
  final MarginPreset marginPreset;

  /// Custom horizontal padding in dp applied to the reading content.
  /// Range: 0.0 – 80.0. Overrides the [MarginPreset] horizontal value when
  /// the user explicitly sets it.
  final double horizontalPadding;

  /// Whether to show a two-page book spread on wide desktop screens (≥ 1200dp)
  /// in page mode. When `false`, wide screens use a single centred column.
  final bool useBookSpread;

  final PageTurnAnimation pageTurnAnimation;

  /// Active drag gesture zone for page turn gestures (full screen vs edges only).
  final PageFlipGestureZone pageFlipGestureZone;

  /// Whether to play physical page-rustle sound effects during page flips.
  final bool enablePageFlipSound;

  /// Whether to trigger physical haptic feedback waveforms during page flips.
  final bool enablePageFlipHaptics;

  final ScrollAnimation scrollAnimation;
  final ReaderChromeStyle chromeStyle;
  final ThemeMode themeMode;

  /// How sheets are presented on desktop-sized windows: floating centered
  /// dialogs or docked into the reader's right side panel.
  final DesktopSheetPresentation desktopSheetPresentation;

  ReadingSettingsEntity copyWith({
    String? systemFontFamily,
    AppBrand? brand,
    double? fontSize,
    String? fontFamily,
    int? fontWeight,
    double? lineHeight,
    double? letterSpacing,
    bool? keepScreenAwake,
    double? brightness,
    bool? autoOptimizeBrightness,
    bool? followSystemBrightness,
    ReadingViewTheme? theme,
    ReadingMode? readingMode,
    TextAlignment? textAlignment,
    MarginPreset? marginPreset,
    double? horizontalPadding,
    bool? useBookSpread,
    PageTurnAnimation? pageTurnAnimation,
    PageFlipGestureZone? pageFlipGestureZone,
    bool? enablePageFlipSound,
    bool? enablePageFlipHaptics,
    ScrollAnimation? scrollAnimation,
    ReaderChromeStyle? chromeStyle,
    ThemeMode? themeMode,
    DesktopSheetPresentation? desktopSheetPresentation,
  }) {
    return ReadingSettingsEntity(
      systemFontFamily: systemFontFamily ?? this.systemFontFamily,
      brand: brand ?? this.brand,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      fontWeight: fontWeight ?? this.fontWeight,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      brightness: brightness ?? this.brightness,
      autoOptimizeBrightness:
          autoOptimizeBrightness ?? this.autoOptimizeBrightness,
      followSystemBrightness:
          followSystemBrightness ?? this.followSystemBrightness,
      theme: theme ?? this.theme,
      readingMode: readingMode ?? this.readingMode,
      textAlignment: textAlignment ?? this.textAlignment,
      marginPreset: marginPreset ?? this.marginPreset,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      useBookSpread: useBookSpread ?? this.useBookSpread,
      pageTurnAnimation: pageTurnAnimation ?? this.pageTurnAnimation,
      pageFlipGestureZone: pageFlipGestureZone ?? this.pageFlipGestureZone,
      enablePageFlipSound: enablePageFlipSound ?? this.enablePageFlipSound,
      enablePageFlipHaptics:
          enablePageFlipHaptics ?? this.enablePageFlipHaptics,
      scrollAnimation: scrollAnimation ?? this.scrollAnimation,
      chromeStyle: chromeStyle ?? this.chromeStyle,
      themeMode: themeMode ?? this.themeMode,
      desktopSheetPresentation:
          desktopSheetPresentation ?? this.desktopSheetPresentation,
    );
  }
}
