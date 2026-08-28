import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_detector.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/core/content_engine/block_card/rules/charm_system_rule.dart';
import 'package:atlas_app/core/content_engine/block_card/rules/player_panel_rule.dart';

void main() {
  BlockCardDetector.registerBlockCardRule(CharmSystemRule());
  BlockCardDetector.registerBlockCardRule(PlayerPanelRule());

  group('CharmSystemRule', () {
    test('parses the Personal Panel into a fully themed card', () async {
      const panel = '''
【Personal Panel】
【Name: Lu Yan】
【Identity: Second-year high school student】
【Charm: 18】
【Height: 159 cm, Weight: 95 kg】
【Physique: 45, Strength: 56, Agility: 33, Spirit: 24】
【Appearance Set: None】
【Others: Not yet unlocked.】''';

      final spans = await BlockCardDetector().process(panel);
      expect(spans, hasLength(1));

      final card = spans[0].card!;
      expect(card.type, BlockCardType.system);
      expect(card.title, 'Personal Panel');
      expect(
        card.confidence,
        greaterThanOrEqualTo(BlockCard.lowConfidenceThreshold),
      );
      expect(
        card.fields.map((f) => f.label),
        containsAll([
          'Name',
          'Identity',
          'Charm',
          'Physique',
          'Strength',
          'Agility',
          'Spirit',
        ]),
      );
      // Comma-separated tuples split into individual fields.
      final physique = card.fields.firstWhere((f) => f.label == 'Physique');
      expect(physique.value, '45');
    });

    test('trial task options become tag pills on a titled quest card', () async {
      const block =
          '【Trial Task Options: Perseverance, EQ, IQ (Select one; this will unlock detailed related tasks. Once chosen, it cannot be changed.)】';

      final card = (await BlockCardDetector().process(block))[0].card!;
      expect(card.title, 'Trial Task');
      expect(card.tags, containsAll(['Perseverance', 'EQ']));
      expect(
        card.confidence,
        greaterThanOrEqualTo(BlockCard.lowConfidenceThreshold),
      );
    });

    test('announcement lines keep their body text as footnote', () async {
      const block =
          '【charm system activated. This system aims to improve the host\'s appearance and charm, and can modify height and disabilities。】';

      final card = (await BlockCardDetector().process(block))[0].card!;
      expect(card.title, 'Charm System');
      expect(card.footnote, isNotNull);
      expect(card.footnote, contains('appearance and charm'));
      expect(card.isLowConfidence, isFalse);
    });
  });

  group('PlayerPanelRule', () {
    test('football scan panel produces bars with real ratios', () async {
      const panel = '''
> Name : Kevin "Kev" Jones
> Age : 34
> Position : Striker (ST)
> Current Ability (CA) : 28/200
> Potential Ability (PA) : 35/200
> Key Attributes :
> - Finishing : 6
> - Pace : 4
> - Bravery : 12''';

      final spans = await BlockCardDetector().process(panel);
      expect(spans, hasLength(1));

      final card = spans[0].card!;
      expect(card.title, 'Kevin "Kev" Jones');
      expect(
        card.confidence,
        greaterThanOrEqualTo(BlockCard.lowConfidenceThreshold),
      );

      final ca = card.fields.firstWhere(
        (f) => f.label.contains('Current Ability'),
      );
      expect(ca.display, FieldDisplay.bar);
      expect(ca.ratio, closeTo(0.14, 0.001));

      final pa = card.fields.firstWhere(
        (f) => f.label.contains('Potential Ability'),
      );
      expect(pa.display, FieldDisplay.bar);
      expect(pa.ratio, closeTo(0.175, 0.001));

      expect(
        card.fields.any((f) => f.label == 'Finishing' && f.value == '6'),
        isTrue,
      );
      expect(
        card.fields.any((f) => f.label.toLowerCase().contains('key attribute')),
        isFalse,
      );
    });

    test(
      'mana-style current/max values inside bracketed sheets become bars',
      () async {
        const sheet = '''
[Name: Denzel Ridrat]
[Age: 22 years]
[Strength: 10]
[Mana: 10/10]
[Rank: E]''';

        final card = (await BlockCardDetector().process(sheet))[0].card!;
        final mana = card.fields.firstWhere((f) => f.label == 'Mana');
        expect(mana.display, FieldDisplay.bar);
        expect(mana.ratio, 1.0);
        expect(
          card.fields.any((f) => f.label == 'Rank' && f.value == 'E'),
          isTrue,
        );
      },
    );
  });
}
