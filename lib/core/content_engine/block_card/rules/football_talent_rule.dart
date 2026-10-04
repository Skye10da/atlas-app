import 'package:atlas_app/core/content_engine/block_card/block_card_detector.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';

/// Football talent/ability-steal panel for ability-steal novels
/// (All Football Abilities Are Mine!): bracketed talent grade blocks.
///
/// ```
/// [Yoon Jung-ho]
/// [Possessed Talents: Football Prodigy (B), Powerful Long Shot (C)]
/// (You can obtain one talent by meeting the required condition.)
/// (Condition: Play football together for at least 60 minutes.)
/// ```
///
/// Also covers:
/// ```
/// [Select the talent you wish to obtain.]
/// - Football Prodigy (B)
/// ```
/// ```
/// [Ho-young]
/// [Possessed Talents: Football Prodigy (B+), ...]
/// ```
/// ```
/// [It will take 30 days to fully acquire this talent. ...]
/// ```
/// Grades: C-/C/C+/B-/B/B+/A-/A/U/L with optional ↑ upgrade marker.
class FootballTalentRule implements BlockCardRule {
  @override
  BlockCardType get type => BlockCardType.footballTalent;

  static final _signal = RegExp(
    r'(possessed\s*talents|select\s*the\s*talent|it\s*will\s*take\s*\d+\s*days\s*to\s*fully\s*acquire)',
    caseSensitive: false,
  );

  // [Name] or [Select the talent ...]
  static final _bracketHeader = RegExp(r'^\s*\[([^\]]+)\]\s*$', multiLine: true);
  // [Possessed Talents: Football Prodigy (B), Powerful Long Shot (C)]
  static final _possessedTalents = RegExp(
    r'\[Possessed Talents:\s*([^\]]+)\]',
    caseSensitive: false,
  );
  // Talent (Grade) — e.g. Football Prodigy (B+), Thunder Thighs of Cha Boom (L)
  static final _talentGrade = RegExp(r'(.+?)\s*\(([A-Z][+-]?|U|L)\)');
  // (Condition ... ) or (You can obtain ...)
  static final _condition = RegExp(r'\(Condition[^\)]*\)', caseSensitive: false);
  static final _obtainHint = RegExp(r'\(You can obtain[^\)]*\)', caseSensitive: false);
  // Upgrade marker [Talent (B+2)↑] or [Powerful Long Shot (C+)↑]
  static final _upgrade = RegExp(r'\[([^\]]+\([A-Z][+-]?\d*\)\s*↑[^\]]*)\]');

  @override
  bool signalMatches(String block) => _signal.hasMatch(block);

  @override
  BlockCard? parse(String block) {
    final fields = <BlockCardField>[];
    final tags = <String>[];
    String? title;
    String? subtitle;
    String? footnote;

    // Title: first bracket line that is a name (not Possessed Talents/Select/It will take)
    for (final m in _bracketHeader.allMatches(block)) {
      final inner = m.group(1)!.trim();
      final lower = inner.toLowerCase();
      if (lower.startsWith('possessed talents')) continue;
      if (lower.startsWith('select the talent')) {
        title = 'Select Talent';
        subtitle = inner;
        continue;
      }
      if (lower.startsWith('it will take')) {
        // Cooldown notification — treat as system-like but still footballTalent
        final cooldown = inner;
        return BlockCard(
          type: BlockCardType.footballTalent,
          title: 'Talent Cooldown',
          subtitle: null,
          fields: [BlockCardField(label: 'Cooldown', value: cooldown)],
          footnote: cooldown,
          confidence: 0.90,
          rawText: block,
        );
      }
      // Check for upgrade marker inside brackets
      if (inner.contains('↑')) {
        // Keep as is
        title = inner.replaceAll('↑', '').trim();
        subtitle = 'Talent Upgraded';
        // Also add as field
        final gradeMatch = _talentGrade.firstMatch(inner);
        if (gradeMatch != null) {
          tags.add(inner.trim());
        }
        continue;
      }
      if (title == null && inner.isNotEmpty && !inner.contains(':')) {
        // Likely a player name like Yoon Jung-ho, Ho-young, Cha Bum-kun
        title = inner;
      }
    }

    // Possessed Talents -> tags/fields
    final possessedMatch = _possessedTalents.firstMatch(block);
    if (possessedMatch != null) {
      final talentsRaw = possessedMatch.group(1)!;
      final parts = talentsRaw.split(',');
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final gm = _talentGrade.firstMatch(trimmed);
        if (gm != null) {
          final name = gm.group(1)!.trim();
          final grade = gm.group(2)!.trim();
          // Store as tag chip: "Football Prodigy (B)"
          tags.add('$name ($grade)');
          // Also as field for accessibility
          fields.add(BlockCardField(label: name, value: grade));
        } else {
          tags.add(trimmed);
        }
      }
    }

    // Conditions -> footnote or fields
    final conditionMatches = _condition.allMatches(block).toList();
    if (conditionMatches.isNotEmpty) {
      final condValues = conditionMatches.map((m) => m.group(0)!.trim()).join(' ');
      // Strip parentheses for display but keep original as footnote
      footnote = condValues;
      // Also add as list field
      fields.add(BlockCardField(label: 'Condition', value: condValues, display: FieldDisplay.list));
    } else if (_obtainHint.hasMatch(block)) {
      final hint = _obtainHint.firstMatch(block)!.group(0)!.trim();
      footnote ??= hint;
    }

    // Handle Select list items: "- Football Prodigy (B)" lines
    final selectLines = RegExp(r'^\s*[-•]\s*(.+?)\s*\(([A-Z][+-]?|U|L)\)\s*$', multiLine: true)
        .allMatches(block);
    for (final m in selectLines) {
      final name = m.group(1)!.trim();
      final grade = m.group(2)!.trim();
      final tag = '$name ($grade)';
      if (!tags.contains(tag)) {
        tags.add(tag);
        fields.add(BlockCardField(label: name, value: grade));
      }
    }

    // Upgrade marker bare line without header (e.g. [Powerful Long Shot (C+)↑])
    if (title == null && _upgrade.hasMatch(block)) {
      final up = _upgrade.firstMatch(block)!.group(1)!.trim();
      tags.add(up);
      fields.add(BlockCardField(label: 'Upgrade', value: up));
      title = 'Talent Upgraded';
    }

    // Must have at least title or talents
    if (title == null && tags.isEmpty && fields.isEmpty) return null;
    if (tags.isEmpty && fields.isEmpty) return null;

    // Confidence: dense talent panels with Name + Possessed Talents + Condition are high
    final hasName = title != null && title != 'Select Talent';
    final hasTalents = tags.isNotEmpty;
    final hasCondition = footnote != null;
    double confidence = 0.88;
    if (hasName && hasTalents && hasCondition) confidence = 0.92;
    if (hasTalents && hasCondition) confidence = 0.90;
    if (tags.length >= 3) confidence = 0.92;

    return BlockCard(
      type: BlockCardType.footballTalent,
      title: title,
      subtitle: subtitle,
      fields: fields,
      tags: tags,
      footnote: footnote,
      confidence: confidence,
      rawText: block,
    );
  }
}
