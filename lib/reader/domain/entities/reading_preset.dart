import 'package:flutter/material.dart';

import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

enum ReadingPresetId {
  classicPaper,
  modernClean,
  midnightOled,
  warmAmber,
  focusMinimal,
  antiqueBook,
  cedarWood,
}

class ReadingPreset {
  const ReadingPreset({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.theme,
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.textAlignment,
    required this.marginPreset,
    this.fontWeight,
  });

  final ReadingPresetId id;
  final String name;
  final String subtitle;
  final IconData icon;
  final ReadingViewTheme theme;
  final String? fontFamily;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final TextAlignment textAlignment;
  final MarginPreset marginPreset;
  final int? fontWeight;

  bool matches({
    required ReadingViewTheme currentTheme,
    required String? currentFontFamily,
    required double currentFontSize,
    required double currentLineHeight,
  }) {
    return theme == currentTheme &&
        fontFamily == currentFontFamily &&
        (fontSize - currentFontSize).abs() < 1.0 &&
        (lineHeight - currentLineHeight).abs() < 0.15;
  }

  static const List<ReadingPreset> presets = [
    ReadingPreset(
      id: ReadingPresetId.classicPaper,
      name: 'Classic Paper',
      subtitle: 'Warm serif & soft tone',
      icon: Icons.auto_stories,
      theme: ReadingViewTheme.paper,
      fontFamily: 'Playfair Display',
      fontSize: 18.0,
      lineHeight: 1.6,
      letterSpacing: 0.0,
      textAlignment: TextAlignment.left,
      marginPreset: MarginPreset.normal,
      fontWeight: 400,
    ),
    ReadingPreset(
      id: ReadingPresetId.antiqueBook,
      name: 'Antique Book',
      subtitle: 'Aged vellum & authentic ink',
      icon: Icons.import_contacts,
      theme: ReadingViewTheme.book,
      fontFamily: 'Playfair Display',
      fontSize: 18.0,
      lineHeight: 1.65,
      letterSpacing: 0.1,
      textAlignment: TextAlignment.left,
      marginPreset: MarginPreset.normal,
      fontWeight: 400,
    ),
    ReadingPreset(
      id: ReadingPresetId.cedarWood,
      name: 'Cedar Wood',
      subtitle: 'Rich wood tone & warm prose',
      icon: Icons.table_restaurant,
      theme: ReadingViewTheme.wood,
      fontFamily: 'Open Sans',
      fontSize: 17.0,
      lineHeight: 1.6,
      letterSpacing: 0.0,
      textAlignment: TextAlignment.left,
      marginPreset: MarginPreset.normal,
      fontWeight: 400,
    ),
    ReadingPreset(
      id: ReadingPresetId.modernClean,
      name: 'Modern Clean',
      subtitle: 'Crisp sans & balanced flow',
      icon: Icons.text_fields,
      theme: ReadingViewTheme.ivory,
      fontFamily: 'Inter',
      fontSize: 16.0,
      lineHeight: 1.5,
      letterSpacing: 0.0,
      textAlignment: TextAlignment.left,
      marginPreset: MarginPreset.normal,
      fontWeight: 400,
    ),
    ReadingPreset(
      id: ReadingPresetId.midnightOled,
      name: 'Midnight OLED',
      subtitle: 'Deep black & low eye strain',
      icon: Icons.dark_mode,
      theme: ReadingViewTheme.amoled,
      fontFamily: 'Inter',
      fontSize: 17.0,
      lineHeight: 1.6,
      letterSpacing: 0.2,
      textAlignment: TextAlignment.left,
      marginPreset: MarginPreset.normal,
      fontWeight: 400,
    ),
    ReadingPreset(
      id: ReadingPresetId.warmAmber,
      name: 'Warm Sepia',
      subtitle: 'Cozy amber for evening',
      icon: Icons.wb_sunny,
      theme: ReadingViewTheme.sepia,
      fontFamily: 'Open Sans',
      fontSize: 17.0,
      lineHeight: 1.5,
      letterSpacing: 0.0,
      textAlignment: TextAlignment.left,
      marginPreset: MarginPreset.normal,
      fontWeight: 400,
    ),
    ReadingPreset(
      id: ReadingPresetId.focusMinimal,
      name: 'Focus Minimal',
      subtitle: 'Airy margins & crisp contrast',
      icon: Icons.filter_center_focus,
      theme: ReadingViewTheme.warmGray,
      fontFamily: null,
      fontSize: 18.0,
      lineHeight: 1.7,
      letterSpacing: 0.3,
      textAlignment: TextAlignment.justify,
      marginPreset: MarginPreset.wide,
      fontWeight: 500,
    ),
  ];
}

