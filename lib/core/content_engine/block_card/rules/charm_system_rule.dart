import 'package:atlas_app/core/content_engine/block_card/block_card_detector.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/core/content_engine/block_card/stat_sheet_parser.dart';

/// Example novel-specific plugin rule for Chinese-style 【】 system
/// windows (e.g. the "charm system" genre). Registered at runtime via
/// [BlockCardDetector.registerBlockCardRule] — never hard-wired into
/// the default rule set.
///
/// Handles:
/// - Multi-line 【】 panels (personal status sheets, comma-separated
///   stat tuples like "Physique: 45, Strength: 56")
/// - Announcement lines ("【charm system activated. …】") → title/body
/// - Task lines ("【Trial Task: …】") → titled quest card with body
class CharmSystemRule implements BlockCardRule {
  @override
  BlockCardType get type => BlockCardType.system;

  static final _lenticular = RegExp(r'【([^】]*)】');
  static final _charmVocab = RegExp(
    r'(charm|trial\s*task|personal\s*panel|novice\s*gift)',
    caseSensitive: false,
  );
  static final _header = RegExp(
    r'^(Personal Panel|Trial Task Options?|Trial Task)\s*[:：]?\s*(.*)$',
    caseSensitive: false,
  );

  @override
  bool signalMatches(String block) =>
      block.contains('【') &&
      (_charmVocab.hasMatch(block) ||
          _lenticular.allMatches(block).length >= 2);

  @override
  BlockCard? parse(String block) {
    final lines = _lenticular
        .allMatches(block)
        .map((m) => m.group(1)!.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    final titles = <String>{};
    final fields = <BlockCardField>[];
    final tags = <String>[];
    final bodyLines = <String>[];

    for (final line in lines) {
      final headerMatch = _header.firstMatch(line);
      if (headerMatch != null) {
        final headerText = headerMatch.group(1)!;
        titles.add(
          headerText.toLowerCase().startsWith('trial')
              ? 'Trial Task'
              : 'Personal Panel',
        );
        final rest = headerMatch.group(2)!.trim();
        if (rest.isEmpty) continue;
        if (headerText.toLowerCase().contains('options')) {
          tags.addAll(
            rest
                .split(RegExp(r'[、,，]'))
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty),
          );
        } else {
          bodyLines.add(rest);
        }
        continue;
      }

      // Comma-separated stat tuples: "Physique: 45, Strength: 56"
      if (line.contains(RegExp(r'[、,，]'))) {
        final parts = line
            .split(RegExp(r'[、,，]'))
            .map((p) => p.split(RegExp(r'[:：]')))
            .toList();
        if (parts.every(
          (p) =>
              p.length == 2 &&
              p.first.trim().length <= 20 &&
              p.last.trim().isNotEmpty,
        )) {
          fields.addAll(
            parts.map(
              (p) => BlockCardField(label: p[0].trim(), value: p[1].trim()),
            ),
          );
          continue;
        }
      }

      final kv = StatSheetParser.parseKvLines(line);
      if (kv.length == line.split(RegExp(r'[:：]')).length - 1 &&
          kv.isNotEmpty) {
        fields.addAll(kv);
        continue;
      }

      bodyLines.add(line);
    }

    if (fields.isEmpty && bodyLines.isEmpty && tags.isEmpty) return null;

    var confidence = 0.85;
    if (fields.length + tags.length >= 4) confidence = 0.92;
    if (fields.isEmpty && tags.isEmpty) confidence = 0.8;

    return BlockCard(
      type: BlockCardType.system,
      title: titles.isEmpty ? 'Charm System' : titles.first,
      fields: fields,
      tags: tags,
      footnote: bodyLines.isEmpty ? null : bodyLines.join('\n'),
      confidence: confidence,
      rawText: block,
    );
  }
}
