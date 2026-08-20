import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/theme/app_brand.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/domain/repository_interfaces/settings_repository_interface.dart';

final class SharedPrefsSettingsRepository implements SettingsRepositoryInterface {
  const SharedPrefsSettingsRepository();

  static const _keySystemFont = 'system_font_family';
  static const _keyBrand = 'app_brand';
  static const _keyThemeMode = 'app_theme_mode';
  static const _keyFontSize = 'reader_font_size';
  static const _keyFontFamily = 'reader_font_family';
  static const _keyFontWeight = 'reader_font_weight';
  static const _keyLineHeight = 'reader_line_height';
  static const _keyLetterSpacing = 'reader_letter_spacing';
  static const _keyKeepAwake = 'reader_keep_awake';
  static const _keyBrightness = 'reader_brightness';
  static const _keyAutoOptimize = 'reader_auto_optimize';
  static const _keyFollowSystemBrightness = 'reader_follow_system_brightness';
  static const _keyTheme = 'reader_theme';
  static const _keyReadingMode = 'reader_reading_mode';
  static const _keyTextAlignment = 'reader_text_alignment';
  static const _keyMarginPreset = 'reader_margin_preset';
  static const _keyPageTurnAnimation = 'reader_page_turn_animation';
  static const _keyScrollAnimation = 'reader_scroll_animation';
  static const _keyChromeStyle = 'reader_chrome_style';

  @override
  Future<ReadingSettingsEntity> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('theme_mode');
    return ReadingSettingsEntity(
      systemFontFamily: prefs.getString(_keySystemFont),
      brand: switch (prefs.getString(_keyBrand)) {
        'emerald' => AppBrand.emerald,
        'ruby' => AppBrand.ruby,
        'sapphire' => AppBrand.sapphire,
        'amber' => AppBrand.amber,
        'rose' => AppBrand.rose,
        'coral' => AppBrand.coral,
        'peach' => AppBrand.peach,
        'lime' => AppBrand.lime,
        'teal' => AppBrand.teal,
        'sky' => AppBrand.sky,
        'indigo' => AppBrand.indigo,
        'slate' => AppBrand.slate,
        'charcoal' => AppBrand.charcoal,
        _ => AppBrand.violet,
      },
      themeMode: switch (prefs.getString(_keyThemeMode)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      fontSize: prefs.getDouble(_keyFontSize) ?? 18.0,
      fontFamily: prefs.getString(_keyFontFamily),
      fontWeight: prefs.getInt(_keyFontWeight),
      lineHeight: (prefs.getDouble(_keyLineHeight) ?? 1.8).clamp(1.0, 2.0),
      letterSpacing: prefs.getDouble(_keyLetterSpacing) ?? 0.0,
      keepScreenAwake: prefs.getBool(_keyKeepAwake) ?? false,
      brightness: prefs.getDouble(_keyBrightness) ?? 1.0,
      autoOptimizeBrightness: prefs.getBool(_keyAutoOptimize) ?? false,
      followSystemBrightness:
          prefs.getBool(_keyFollowSystemBrightness) ?? true,
      theme: switch (prefs.getString(_keyTheme)) {
        'parchment' => ReadingViewTheme.parchment,
        'ivory' => ReadingViewTheme.ivory,
        'sepia' => ReadingViewTheme.sepia,
        'blueLight' => ReadingViewTheme.blueLight,
        'warmGray' => ReadingViewTheme.warmGray,
        'mint' => ReadingViewTheme.mint,
        'forest' => ReadingViewTheme.forest,
        'ocean' => ReadingViewTheme.ocean,
        'midnight' => ReadingViewTheme.midnight,
        'charcoal' => ReadingViewTheme.charcoal,
        'nord' => ReadingViewTheme.nord,
        'dracula' => ReadingViewTheme.dracula,
        'amoled' => ReadingViewTheme.amoled,
        'light' => ReadingViewTheme.paper,
        'dark' => ReadingViewTheme.paper,
        'cream' => ReadingViewTheme.parchment,
        'gray' => ReadingViewTheme.charcoal,
        _ => ReadingViewTheme.paper,
      },
      readingMode: switch (prefs.getString(_keyReadingMode)) {
        'continuous' => ReadingMode.continuous,
        _ => ReadingMode.page,
      },
      textAlignment: switch (prefs.getString(_keyTextAlignment)) {
        'justify' => TextAlignment.justify,
        'center' => TextAlignment.center,
        'right' => TextAlignment.right,
        _ => TextAlignment.left,
      },
      marginPreset: switch (prefs.getString(_keyMarginPreset)) {
        'narrow' => MarginPreset.narrow,
        'wide' => MarginPreset.wide,
        _ => MarginPreset.normal,
      },
      pageTurnAnimation: switch (prefs.getString(_keyPageTurnAnimation)) {
        'fade' => PageTurnAnimation.fade,
        'reveal' => PageTurnAnimation.reveal,
        'cube' => PageTurnAnimation.cube,
        'depth' => PageTurnAnimation.depth,
        _ => PageTurnAnimation.slide,
      },
      scrollAnimation: switch (prefs.getString(_keyScrollAnimation)) {
        'snap' => ScrollAnimation.snap,
        'fadeEdges' => ScrollAnimation.fadeEdges,
        'parallax' => ScrollAnimation.parallax,
        'glow' => ScrollAnimation.glow,
        _ => ScrollAnimation.smooth,
      },
      chromeStyle: switch (prefs.getString(_keyChromeStyle)) {
        'frosted' => ReaderChromeStyle.frosted,
        _ => ReaderChromeStyle.translucent,
      },
    );
  }

  @override
  Future<void> save(ReadingSettingsEntity settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (settings.systemFontFamily != null) {
      await prefs.setString(_keySystemFont, settings.systemFontFamily!);
    } else {
      await prefs.remove(_keySystemFont);
    }
    await prefs.setString(_keyBrand, settings.brand.name);
    await prefs.setString(_keyThemeMode, switch (settings.themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    });
    await prefs.setDouble(_keyFontSize, settings.fontSize);
    if (settings.fontFamily != null) {
      await prefs.setString(_keyFontFamily, settings.fontFamily!);
    } else {
      await prefs.remove(_keyFontFamily);
    }
    if (settings.fontWeight != null) {
      await prefs.setInt(_keyFontWeight, settings.fontWeight!);
    } else {
      await prefs.remove(_keyFontWeight);
    }
    await prefs.setDouble(_keyLineHeight, settings.lineHeight);
    await prefs.setDouble(_keyLetterSpacing, settings.letterSpacing);
    await prefs.setBool(_keyKeepAwake, settings.keepScreenAwake);
    await prefs.setDouble(_keyBrightness, settings.brightness);
    await prefs.setBool(_keyAutoOptimize, settings.autoOptimizeBrightness);
    await prefs.setBool(
        _keyFollowSystemBrightness, settings.followSystemBrightness);
    await prefs.setString(_keyTheme, settings.theme.name);
    await prefs.setString(_keyReadingMode, settings.readingMode.name);
    await prefs.setString(_keyTextAlignment, settings.textAlignment.name);
    await prefs.setString(_keyMarginPreset, settings.marginPreset.name);
    await prefs.setString(_keyPageTurnAnimation, settings.pageTurnAnimation.name);
    await prefs.setString(_keyScrollAnimation, settings.scrollAnimation.name);
    await prefs.setString(_keyChromeStyle, settings.chromeStyle.name);
  }
}
