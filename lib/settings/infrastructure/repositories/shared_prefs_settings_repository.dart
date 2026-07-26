import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/domain/repository_interfaces/settings_repository_interface.dart';

final class SharedPrefsSettingsRepository implements SettingsRepositoryInterface {
  const SharedPrefsSettingsRepository();

  static const _keyFontSize = 'reader_font_size';
  static const _keyFontFamily = 'reader_font_family';
  static const _keyLineHeight = 'reader_line_height';
  static const _keyLetterSpacing = 'reader_letter_spacing';
  static const _keyKeepAwake = 'reader_keep_awake';
  static const _keyBrightness = 'reader_brightness';
  static const _keyTheme = 'reader_theme';
  static const _keyReadingMode = 'reader_reading_mode';
  static const _keyTextAlignment = 'reader_text_alignment';
  static const _keyMarginPreset = 'reader_margin_preset';

  @override
  Future<ReadingSettingsEntity> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReadingSettingsEntity(
      fontSize: prefs.getDouble(_keyFontSize) ?? 18.0,
      fontFamily: prefs.getString(_keyFontFamily),
      lineHeight: prefs.getDouble(_keyLineHeight) ?? 1.8,
      letterSpacing: prefs.getDouble(_keyLetterSpacing) ?? 0.0,
      keepScreenAwake: prefs.getBool(_keyKeepAwake) ?? false,
      brightness: prefs.getDouble(_keyBrightness) ?? 1.0,
      theme: switch (prefs.getString(_keyTheme)) {
        'dark' => ReadingViewTheme.dark,
        'sepia' => ReadingViewTheme.sepia,
        'forest' => ReadingViewTheme.forest,
        'ocean' => ReadingViewTheme.ocean,
        'dracula' => ReadingViewTheme.dracula,
        'amoled' => ReadingViewTheme.amoled,
        'cream' => ReadingViewTheme.cream,
        'gray' => ReadingViewTheme.gray,
        _ => ReadingViewTheme.light,
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
    );
  }

  @override
  Future<void> save(ReadingSettingsEntity settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, settings.fontSize);
    if (settings.fontFamily != null) {
      await prefs.setString(_keyFontFamily, settings.fontFamily!);
    } else {
      await prefs.remove(_keyFontFamily);
    }
    await prefs.setDouble(_keyLineHeight, settings.lineHeight);
    await prefs.setDouble(_keyLetterSpacing, settings.letterSpacing);
    await prefs.setBool(_keyKeepAwake, settings.keepScreenAwake);
    await prefs.setDouble(_keyBrightness, settings.brightness);
    await prefs.setString(_keyTheme, settings.theme.name);
    await prefs.setString(_keyReadingMode, settings.readingMode.name);
    await prefs.setString(_keyTextAlignment, settings.textAlignment.name);
    await prefs.setString(_keyMarginPreset, settings.marginPreset.name);
  }
}
