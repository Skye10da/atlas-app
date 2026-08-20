import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';

class ChapterStyle {
  ChapterStyle._({
    required this.accentColor,
    required this.titleStyle,
    required this.dropCapStyle,
    required this.bannerBackground,
  });

  final Color accentColor;
  final TextStyle titleStyle;
  final TextStyle dropCapStyle;
  final Color bannerBackground;

  static const String ornamentalDivider = ' \u2766 ';

  static const _displayFont = 'Playfair Display';

  static ChapterStyle forChapter(int index, ColorScheme colorScheme) {
    const themes = ReadingViewTheme.values;
    final theme = themes[(index + 1) % themes.length];

    return ChapterStyle._(
      accentColor: theme.resolve(colorScheme).accent,
      bannerBackground: theme.resolve(colorScheme).surface,
      titleStyle: GoogleFonts.getFont(
        _displayFont,
        textStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: theme.resolve(colorScheme).text,
        ),
      ),
      dropCapStyle: GoogleFonts.getFont(
        _displayFont,
        textStyle: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.bold,
          color: theme.resolve(colorScheme).accent,
          height: 1.1,
        ),
      ),
    );
  }
}
