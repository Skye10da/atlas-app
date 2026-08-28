/// Adaptive visual themes for BlockCard rendering. One theme per
/// BlockCardType, derived from the active reader palette
/// ([ReadingColors]) so cards stay readable across all reader themes.
///
/// Genre identity is preserved through accent hues (system = cyan
/// terminal family, cultivation = parchment gold/seal red family),
/// automatically adjusted for contrast on light and dark backgrounds.
/// Typography intentionally omits fontFamily — styles inherit the
/// app's default/system font.
library;

import 'package:flutter/material.dart';

import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';

/// Builds a concrete [BlockCardTheme] from the reader's resolved
/// palette. Plugins register builders via [registerBlockCardTheme] so
/// novel-specific card types are adaptive to every reader theme too.
typedef BlockCardThemeBuilder = BlockCardTheme Function(ReadingColors colors);

@immutable
class BlockCardTheme {
  const BlockCardTheme({
    required this.label,
    required this.icon,
    required this.background,
    required this.border,
    required this.glowOrAccent,
    required this.titleColor,
    required this.labelColor,
    required this.valueColor,
    required this.titleStyle,
    required this.labelStyle,
    required this.valueStyle,
    required this.eyebrowStyle,
    required this.footnoteStyle,
    required this.radius,
    required this.cardBorder,
    required this.shadows,
    required this.barColors,
    required this.tagBackground,
    required this.tagText,
    this.dashedBorder = false,
  });
  final String label; // small eyebrow text, e.g. "SYSTEM NOTIFICATION"
  final IconData icon;

  final Color background;
  final Color border;
  final Color glowOrAccent; // corner brackets / seal / accent line
  final Color titleColor;
  final Color labelColor; // muted "key" text
  final Color valueColor; // "value" text

  final TextStyle titleStyle;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final TextStyle eyebrowStyle;
  final TextStyle footnoteStyle;

  final BorderRadius radius;
  final Border cardBorder;
  final List<BoxShadow> shadows;
  final bool dashedBorder; // fallback theme only

  /// Bar colors keyed by common field labels (hp/mp/exp) so fields can
  /// opt into semantic color instead of one flat bar color. Falls back
  /// to [glowOrAccent] if the label isn't in this map.
  final Map<String, Color> barColors;

  /// Chip/tag background + text color, for FieldDisplay.tag fields.
  final Color tagBackground;
  final Color tagText;
}

const Color _systemHue = Color(0xFF54E1FF);
const Color _goldHue = Color(0xFFB9974F);

bool _isDarkBackground(ReadingColors colors) =>
    colors.background.computeLuminance() < 0.5;

/// Nudges a genre hue toward black on light backgrounds (or white on
/// dark ones) so it keeps enough contrast against the reader palette.
Color _adaptHue(
  Color hue,
  ReadingColors colors, {
  double darkLift = 0,
  double lightDrop = 0.2,
}) {
  if (_isDarkBackground(colors)) {
    return darkLift <= 0 ? hue : Color.lerp(hue, Colors.white, darkLift)!;
  }
  return Color.lerp(hue, Colors.black, lightDrop)!;
}

Color _cardBackground(Color hue, ReadingColors colors) {
  final blend = _isDarkBackground(colors) ? 0.07 : 0.09;
  return Color.lerp(colors.background, hue, blend)!;
}

Color _borderColor(Color hue, ReadingColors colors) {
  return Color.lerp(_adaptHue(hue, colors), colors.background, 0.15)!;
}

BlockCardTheme _genreTheme({
  required ReadingColors colors,
  required String label,
  required IconData icon,
  required Color hue,
  double fontSize = 17,
  required Map<String, Color> semanticBarColors,
}) {
  final dark = _isDarkBackground(colors);
  final accent = _adaptHue(hue, colors);
  final background = _cardBackground(hue, colors);
  final text = colors.text;

  final barColors = semanticBarColors.map(
    (k, v) => MapEntry(k, _adaptHue(v, colors)),
  );

  return BlockCardTheme(
    label: label,
    icon: icon,
    background: background,
    border: _borderColor(hue, colors),
    glowOrAccent: accent,
    titleColor: text,
    labelColor: text.withValues(alpha: 0.55),
    valueColor: text.withValues(alpha: 0.95),
    titleStyle: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      letterSpacing: 0.3,
      color: text,
      height: 1.25,
    ),
    labelStyle: TextStyle(fontSize: 12.5, color: text.withValues(alpha: 0.55)),
    valueStyle: TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: text.withValues(alpha: 0.95),
    ),
    eyebrowStyle: TextStyle(fontSize: 11, letterSpacing: 2.2, color: accent),
    footnoteStyle: TextStyle(
      fontSize: 11.5,
      fontStyle: FontStyle.italic,
      color: text.withValues(alpha: 0.7),
    ),
    radius: BorderRadius.zero,
    cardBorder: Border.all(color: _borderColor(hue, colors), width: 1),
    shadows: dark
        ? [BoxShadow(color: hue.withValues(alpha: 0.14), blurRadius: 26)]
        : const [],
    barColors: barColors,
    tagBackground: hue.withValues(alpha: dark ? 0.16 : 0.12),
    tagText: Color.lerp(accent, text, 0.25)!,
  );
}

/// Dark terminal/HUD-flavored theme for LitRPG-style system windows,
/// tinted by the reader's palette.
BlockCardTheme systemThemeFor(ReadingColors colors) => _genreTheme(
  colors: colors,
  label: 'SYSTEM NOTIFICATION',
  icon: Icons.memory_rounded,
  hue: _systemHue,
  semanticBarColors: const {
    'hp': Color(0xFFFF5A6E),
    'mp': Color(0xFF5AA9FF),
    'exp': _systemHue,
    'xp': _systemHue,
  },
);

/// Parchment/seal-flavored theme for xianxia/wuxia cultivation status,
/// tinted by the reader's palette.
BlockCardTheme cultivationThemeFor(ReadingColors colors) => _genreTheme(
  colors: colors,
  label: 'BREAKTHROUGH',
  icon: Icons.filter_hdr_rounded,
  hue: _goldHue,
  fontSize: 20,
  semanticBarColors: const {
    'cultivation base': _goldHue,
    'dantian': _goldHue,
    'qi': _goldHue,
  },
);

/// Muted "we're not confident about this" fallback. Used whenever
/// BlockCard.isLowConfidence is true, regardless of BlockCardType —
/// a rendering fallback, not a genre. Ink tones derive from the
/// reader's own text color so it works on any theme.
BlockCardTheme fallbackThemeFor(ReadingColors colors) {
  final ink = colors.text;
  return BlockCardTheme(
    label: 'UNPARSED STATUS TEXT',
    icon: Icons.help_outline_rounded,
    background: ink.withValues(alpha: 0.04),
    border: ink.withValues(alpha: 0.35),
    glowOrAccent: ink.withValues(alpha: 0.35),
    titleColor: ink.withValues(alpha: 0.7),
    labelColor: ink.withValues(alpha: 0.4),
    valueColor: ink.withValues(alpha: 0.7),
    titleStyle: TextStyle(fontSize: 12.5, color: ink.withValues(alpha: 0.7)),
    labelStyle: TextStyle(fontSize: 12.5, color: ink.withValues(alpha: 0.4)),
    valueStyle: TextStyle(fontSize: 12.5, color: ink.withValues(alpha: 0.7)),
    eyebrowStyle: TextStyle(
      fontSize: 10,
      letterSpacing: 1.5,
      color: ink.withValues(alpha: 0.4),
    ),
    footnoteStyle: TextStyle(fontSize: 11, color: ink.withValues(alpha: 0.55)),
    radius: BorderRadius.zero,
    cardBorder: Border.all(color: ink.withValues(alpha: 0.35), width: 1),
    shadows: const [],
    barColors: const {},
    tagBackground: ink.withValues(alpha: 0.06),
    tagText: ink.withValues(alpha: 0.7),
    dashedBorder: true,
  );
}

/// Registry mapping BlockCardType -> theme builder. Plugins can
/// register new types/themes at startup (see [registerBlockCardTheme]).
final Map<BlockCardType, BlockCardThemeBuilder> _blockCardRegistry = {
  BlockCardType.system: systemThemeFor,
  BlockCardType.levelUp: systemThemeFor,
  BlockCardType.skillGain: systemThemeFor,
  BlockCardType.inventory: systemThemeFor,
  BlockCardType.quest: systemThemeFor,
  BlockCardType.cultivation: cultivationThemeFor,
  BlockCardType.custom: fallbackThemeFor,
};

/// Resolves the theme to use for a card against the active reader
/// palette: low confidence always wins, so a mis-detected "system"
/// block with weak field extraction still renders as the honest
/// fallback box instead of a wrong stat sheet.
BlockCardTheme resolveBlockCardTheme(BlockCard card, ReadingColors colors) {
  if (card.isLowConfidence) return fallbackThemeFor(colors);
  return (_blockCardRegistry[card.type] ?? fallbackThemeFor)(colors);
}

/// For plugin/user-added block types (e.g. a novel-specific "forge
/// affinity" card). Call once at plugin registration time. The builder
/// receives the active [ReadingColors], so registered variants are
/// adaptive to every reader theme automatically.
void registerBlockCardTheme(BlockCardType type, BlockCardThemeBuilder builder) {
  _blockCardRegistry[type] = builder;
}
