import 'package:atlas_app/core/content_engine/block_card/block_card_detector.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/core/content_engine/block_card/stat_sheet_parser.dart';

/// Example novel-specific plugin rule for Football-Manager-style
/// player scan panels, e.g.:
///
/// ```
/// > Name : Kevin "Kev" Jones
/// > Age : 34
/// > Position : Striker (ST)
/// > Current Ability (CA) : 28/200
/// > Potential Ability (PA) : 35/200
/// > Key Attributes :
/// > - Finishing : 6
/// ```
///
/// CA/PA pairs become [FieldDisplay.bar] fields with real ratios.
/// Registered at runtime via [BlockCardDetector.registerBlockCardRule].
class PlayerPanelRule implements BlockCardRule {
  @override
  BlockCardType get type => BlockCardType.system;

  static final _signal = RegExp(
    r'(current\s*ability|potential\s*ability|\bCA\b\s*[:：]|\bPA\b\s*[:：])',
    caseSensitive: false,
  );

  @override
  bool signalMatches(String block) => _signal.hasMatch(block);

  @override
  BlockCard? parse(String block) {
    final fields = StatSheetParser.parseKvLines(block);
    if (fields.length < 3) return null;

    String? title;
    for (final f in fields) {
      if (f.label.toLowerCase() == 'name') {
        title = f.value;
        break;
      }
    }
    fields.removeWhere((f) => f.label.toLowerCase() == 'name');
    fields.removeWhere((f) => f.label.toLowerCase().contains('key attribute'));

    if (fields.isEmpty) return null;

    return BlockCard(
      type: BlockCardType.system,
      title: title,
      subtitle: null,
      fields: fields,
      confidence: 0.9,
      rawText: block,
    );
  }
}
