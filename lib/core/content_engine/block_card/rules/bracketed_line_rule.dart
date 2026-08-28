import 'package:atlas_app/core/content_engine/block_card/block_card_detector.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/core/content_engine/block_card/stat_sheet_parser.dart';

/// Generic built-in rule for system panels delivered as bracketed
/// lines or fenced plain-text blocks. Covers the dominant web-novel
/// formats observed across real sources:
///
/// - Whole-sentence units, one per paragraph: `[Welcome to the System.]`,
///   `<Binding process is complete>`
/// - Tag chains on one line: `[Tier 9][Rank C][Potential: 58%]`
/// - Key:value stat sheets: `[Name: Denzel]`, `<Host: Jacob>`, `Mana: 10/10`
/// - Box-drawing / underscore fenced windows with bare title + key:value
///   bodies ("Level Increased!", "[NIGHTMARE MODE CLEARED]", etc.)
/// - Audio-cue openers: `[Ding!]`, `Ding!!`
///
/// Type is classified from quest/level-up/skill/inventory vocabulary;
/// anything else defaults to [BlockCardType.system].
class BracketedLineRule implements BlockCardRule {
  @override
  BlockCardType get type => BlockCardType.system;

  static final _dingCue = RegExp(
    r'(?:^|\n)?\s*\[?\s*din[g]+!+\s*\]?',
    caseSensitive: false,
  );
  static final _fence = RegExp(
    r'━{2,}|═{2,}|╔|╗|╚|╝|(?:^|\n)\s*_{3,}\s*(?:\n|$)|(?:_ ?){5,}',
  );
  static final _unit = RegExp(r'\[([^\[\]\n]*)\]|<([^<>\n]*)>');
  static final _headerVocab = RegExp(
    r'(notification|alert|warning|quest|mission|objective|status|welcome|system|inventory|shop|lottery|choose|decision|skill acquired|reward|level)',
    caseSensitive: false,
  );

  @override
  bool signalMatches(String block) {
    if (_dingCue.hasMatch(block)) return true;
    if (_fence.hasMatch(block)) return true;
    return StatSheetParser.bracketedCoverage(block) >= 0.6;
  }

  @override
  BlockCard? parse(String block) {
    final unitTexts = <String>[];
    for (final m in _unit.allMatches(block)) {
      final text = (m.group(1) ?? m.group(2))?.trim() ?? '';
      if (text.isNotEmpty) unitTexts.add(text);
    }

    String? title;
    final tags = <String>[];
    String? footnote;

    if (unitTexts.isEmpty) {
      // Fenced window with no brackets: bare title line(s) plus loose
      // key:value rows ("Level Increased!" / "Level: 2 → 3" style).
      final contentLines = block
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !_fence.hasMatch(l))
          .toList();
      if (contentLines.isEmpty) return null;

      final kv = StatSheetParser.parseKvLines(contentLines.join('\n'));
      final extras = contentLines.where((l) => !l.contains(':')).toList();
      for (final line in extras) {
        if (title == null && _looksLikeHeader(line)) {
          title = line;
        } else if (footnote == null && line.length > 90) {
          footnote = line;
        } else {
          tags.add(line);
        }
      }
      final hasBody = kv.isNotEmpty || tags.isNotEmpty || footnote != null;
      if (!hasBody || (kv.isEmpty && title == null)) return null;
      var confidence = kv.length >= 2 ? 0.9 : 0.8;
      if (title != null) confidence = confidence < 0.85 ? 0.85 : confidence;
      return BlockCard(
        type: StatSheetParser.classify(block),
        title: title,
        fields: kv,
        tags: tags,
        footnote: footnote,
        confidence: confidence,
        rawText: block,
      );
    }

    // Units with a colon are key:value pairs handled by the parser.
    final kv = StatSheetParser.parseKvLines(unitTexts.join('\n'));
    for (final text in unitTexts) {
      if (text.contains(':')) continue;
      if (_looksLikeHeader(text) && text.length <= 48) {
        title ??= text;
      } else if (text.length > 90 && footnote == null) {
        footnote = text;
      } else if (text.length <= 40) {
        tags.add(text);
      } else {
        footnote ??= text;
      }
    }

    if (kv.isEmpty && tags.isEmpty && footnote == null && title == null) {
      return null;
    }
    return BlockCard(
      type: StatSheetParser.classify(block),
      title: title,
      fields: kv,
      tags: tags,
      footnote: footnote,
      confidence: kv.length >= 3 ? 0.9 : 0.8,
      rawText: block,
    );
  }

  bool _looksLikeHeader(String unit) =>
      _headerVocab.hasMatch(unit) ||
      (unit.toUpperCase() == unit && unit.length >= 4);
}
