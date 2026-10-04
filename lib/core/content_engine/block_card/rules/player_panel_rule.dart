import 'package:atlas_app/core/content_engine/block_card/block_card_detector.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/core/content_engine/block_card/stat_sheet_parser.dart';

/// Football scout panel for manager-style novels (Glory of the Football
/// Manager System): CA/PA 0-200 + Key Attributes + Personal Profile.
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
/// Also covers `PERSONAL PROFILE`, `Managerial Attributes` and
/// `THE GAFFER'S EYE` blocks from the same novel.
class PlayerPanelRule implements BlockCardRule {
  @override
  BlockCardType get type => BlockCardType.footballScout;

  static final _signal = RegExp(
    r'(current\s*ability|potential\s*ability|\bCA\b\s*[:：]|\bPA\b\s*[:：]|personal\s*profile|managerial\s*attributes|the\s*gaffer.s\s*eye)',
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
      type: BlockCardType.footballScout,
      title: title,
      subtitle: null,
      fields: fields,
      confidence: 0.90,
      rawText: block,
    );
  }
}
