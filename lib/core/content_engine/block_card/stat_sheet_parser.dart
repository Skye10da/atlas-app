import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';

/// Shared parsing helpers for status-panel rules: key:value line
/// extraction, current/max bar detection, and block-type vocabulary
/// classification. Used by both built-in and plugin rules so numeric
/// formats are handled consistently across novels.
abstract final class StatSheetParser {
  static final _kvLine = RegExp(
    r'^\s*>?\s*[-•]?\s*(.{2,30}?)\s*[:：]\s*(.+?)\s*$',
  );
  static final _numericPair = RegExp(r'^([\d,.]+)\s*/\s*([\d,.]+)$');

  /// Extracts `Label: value` fields line-by-line. Lines whose value is
  /// a numeric current/max pair (`HP: 840/1000`, `Mana: 10/10`,
  /// `Current Ability (CA) : 28/200`) become [FieldDisplay.bar] fields.
  /// Sentinel values (`Locked`, `???`, `None`) are kept verbatim.
  static List<BlockCardField> parseKvLines(String text) {
    final fields = <BlockCardField>[];
    for (final line in text.split('\n')) {
      final m = _kvLine.firstMatch(line);
      if (m == null) continue;
      final label = m.group(1)!.trim();
      final value = m.group(2)!.trim();
      if (label.isEmpty || value.isEmpty) continue;

      final pair = _numericPair.firstMatch(value);
      if (pair != null) {
        final current = double.tryParse(pair.group(1)!.replaceAll(',', ''));
        final max = double.tryParse(pair.group(2)!.replaceAll(',', ''));
        if (current != null && max != null && max > 0) {
          fields.add(
            BlockCardField(
              label: label,
              value: value,
              display: FieldDisplay.bar,
              current: current,
              max: max,
            ),
          );
          continue;
        }
      }
      fields.add(BlockCardField(label: label, value: value));
    }
    return fields;
  }

  static final _questVocab = RegExp(
    r'(mission|objective|reward|penalty|quest\b|difficulty\b|time remaining|requirement|bonus objective|failure)',
    caseSensitive: false,
  );
  static final _levelUpVocab = RegExp(
    r'(level\s*(up|increased)|leveled?\s*up|\blevel\s*:?\s*\d+\s*(→|->)\s*\d+)',
    caseSensitive: false,
  );
  static final _skillVocab = RegExp(
    r'(skill\s*(acquired|gained|learned|added)|new skill|skill acquired)',
    caseSensitive: false,
  );
  static final _inventoryVocab = RegExp(
    r'(inventory|loot|items?\s*obtained|gift pack|rewards obtained|chest\b)',
    caseSensitive: false,
  );

  /// Vocabulary-based classification for blocks parsed generically.
  /// Priority: quest > level-up > skill-gain > inventory > system.
  static BlockCardType classify(String text) {
    if (_questVocab.hasMatch(text)) return BlockCardType.quest;
    if (_levelUpVocab.hasMatch(text)) return BlockCardType.levelUp;
    if (_skillVocab.hasMatch(text)) return BlockCardType.skillGain;
    if (_inventoryVocab.hasMatch(text)) return BlockCardType.inventory;
    return BlockCardType.system;
  }

  /// Fraction of non-whitespace characters enclosed in `[...]` / `<...>`
  /// units. Used to confirm a candidate is genuinely panel-shaped and
  /// not prose with one inline bracketed word.
  static double bracketedCoverage(String text) {
    final units = RegExp(r'\[[^\[\]\n]*\]|<[^<>\n]*>').allMatches(text);
    var unitChars = 0;
    for (final m in units) {
      unitChars += m.group(0)!.length;
    }
    final total = text.replaceAll(RegExp(r'\s'), '').length;
    if (total == 0) return 0;
    return unitChars / total;
  }
}
