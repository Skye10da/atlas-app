import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';

class ReadingSettingsEntity {
  const ReadingSettingsEntity({
    this.fontSize = 18.0,
    this.fontFamily,
    this.lineHeight = 1.8,
    this.letterSpacing = 0.0,
    this.keepScreenAwake = false,
    this.brightness = 1.0,
    this.theme = ReadingViewTheme.light,
    this.readingMode = ReadingMode.page,
    this.textAlignment = TextAlignment.left,
    this.marginPreset = MarginPreset.normal,
  });

  final double fontSize;
  final String? fontFamily;
  final double lineHeight;
  final double letterSpacing;
  final bool keepScreenAwake;
  final double brightness;
  final ReadingViewTheme theme;
  final ReadingMode readingMode;
  final TextAlignment textAlignment;
  final MarginPreset marginPreset;

  ReadingSettingsEntity copyWith({
    double? fontSize,
    String? fontFamily,
    double? lineHeight,
    double? letterSpacing,
    bool? keepScreenAwake,
    double? brightness,
    ReadingViewTheme? theme,
    ReadingMode? readingMode,
    TextAlignment? textAlignment,
    MarginPreset? marginPreset,
  }) {
    return ReadingSettingsEntity(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      brightness: brightness ?? this.brightness,
      theme: theme ?? this.theme,
      readingMode: readingMode ?? this.readingMode,
      textAlignment: textAlignment ?? this.textAlignment,
      marginPreset: marginPreset ?? this.marginPreset,
    );
  }
}
