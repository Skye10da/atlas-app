import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_detector.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';

void main() {
  final detector = BlockCardDetector();

  group('structural pre-filter', () {
    test('lone aphorism quote in lenticular brackets is prose', () {
      const quote =
          '【Things that cannot be pursued in youth eventually become lifelong regrets。】';
      expect(detector.looksBlockShaped(quote), isFalse);
    });

    test('single lenticular line with system keyword is a candidate', () {
      expect(
        detector.looksBlockShaped(
          '【charm system activated. This system aims to improve the host。】',
        ),
        isTrue,
      );
      expect(detector.looksBlockShaped('【Trial task initiated。】'), isTrue);
    });

    test('multi-line lenticular panel is a candidate', () {
      const panel = '''
【Personal Panel】
【Name: Lu Yan】
【Identity: Second-year high school student】''';
      expect(detector.looksBlockShaped(panel), isTrue);
    });

    test('prose with one inline bracketed word stays prose', () {
      expect(
        detector.looksBlockShaped(
          'She raised her hand and traced the shape of a [Ward] in the air.',
        ),
        isFalse,
      );
    });

    test('square-bracket tag chain is a candidate', () {
      expect(
        detector.looksBlockShaped(
          '[Flame Archor – Unnamed][Tier 9][Rank C][Potential for Evolution: 58%]',
        ),
        isTrue,
      );
    });

    test('angle-bracket system lines are candidates', () {
      expect(detector.looksBlockShaped('<Host: Jacob Ironfell>'), isTrue);
      expect(
        detector.looksBlockShaped('>> Rule 1: The Bond of Trust <<'),
        isTrue,
      );
    });

    test('underscore fences are candidates', () {
      expect(detector.looksBlockShaped('_____\n[WARNING]\n_____'), isTrue);
    });

    test('ding audio cue is a candidate', () {
      expect(detector.looksBlockShaped('[Ding!]'), isTrue);
      expect(detector.looksBlockShaped('Ding!!'), isTrue);
    });

    test(
      'quote-marker-prefixed consecutive key:value lines are candidates',
      () {
        const panel = '''
> Name : Kevin Jones
> Age : 34''';
        expect(detector.looksBlockShaped(panel), isTrue);
      },
    );

    test('plain narrative prose is not a candidate', () {
      expect(
        detector.looksBlockShaped(
          'A violent sound erupted from the road as the out-of-control sedan crashed into a tree.',
        ),
        isFalse,
      );
    });
  });

  group('SystemStatusRule', () {
    test('parses bordered HP/MP block into bars and text fields', () async {
      const chapter = '''
The battle was over.

======================
[Status Window]
HP: 2340/3250
MP: 860/1800
Class: Dungeon Reaver
======================

He closed the window.''';

      final spans = await detector.process(chapter);

      expect(spans, hasLength(3));
      expect(spans[0].isCard, isFalse);
      expect(spans[2].isCard, isFalse);

      final card = spans[1].card!;
      expect(card.type, BlockCardType.system);
      expect(
        card.confidence,
        greaterThanOrEqualTo(BlockCard.lowConfidenceThreshold),
      );
      final hp = card.fields.firstWhere((f) => f.label.toUpperCase() == 'HP');
      expect(hp.display, FieldDisplay.bar);
      expect(hp.ratio, closeTo(2340 / 3250, 0.001));
      expect(card.fields.any((f) => f.label.toLowerCase() == 'class'), isTrue);
    });

    test('fence-wrapped prose that no rule parses falls back', () async {
      const chapter = '''
_____
The old man sighed and walked away into the morning mist.
_____

Nobody expected what came next.''';

      final spans = await detector.process(chapter);
      expect(spans[0].isCard, isTrue);
      expect(spans[0].card!.isLowConfidence, isTrue);
      expect(spans[0].card!.rawText, contains('old man sighed'));
    });

    test('bare scene separators stay prose', () async {
      const chapter = '''
The battle was over.

_____''';

      final spans = await detector.process(chapter);
      expect(spans[1].isCard, isFalse);
    });
  });

  group('CultivationStatusRule', () {
    test('parses dantian percentage into a bar field', () async {
      const chapter = '''
He sat cross-legged and checked himself.

Cultivation Base: Qi Refinement Level 7
Dantian Capacity: 61%
Meridians: Clear

A faint golden light surrounded him.''';

      final spans = await detector.process(chapter);
      final card = spans[1].card!;
      expect(card.type, BlockCardType.cultivation);
      final dantian = card.fields.firstWhere(
        (f) => f.label.toLowerCase().contains('dantian'),
      );
      expect(dantian.display, FieldDisplay.bar);
      expect(dantian.ratio, closeTo(0.61, 0.001));
    });
  });

  group('BracketedLineRule', () {
    test(
      'square-bracket notification stack merges into one quest card',
      () async {
        const chapter = '''
[Welcome to the Harem System. Your subscription has been activated.]

[Mandatory Mission: Flirt with Alexia Vane.]

[Target: Alexia Vane. East wing. South hallway, by the windows.]''';

        final spans = await detector.process(chapter);
        // Panel rows are grouped into a single card.
        expect(spans, hasLength(1));
        final card = spans[0].card!;
        expect(
          card.confidence,
          greaterThanOrEqualTo(BlockCard.lowConfidenceThreshold),
        );
        expect(card.rawText, contains('Welcome to the Harem System'));
        expect(card.rawText, contains('[Target: Alexia Vane'));
        expect(card.type, BlockCardType.quest);
      },
    );

    test('level-up vocabulary classifies as levelUp', () async {
      const block = '''
━━━━━━━━━━━━━━━━━━━━━━━

Level Increased!

━━━━━━━━━━━━━━━━━━━━━━━

Level: 2 → 3

Strength +1

Endurance +2''';

      final card = (await detector.process(block))[0].card!;
      expect(card.type, BlockCardType.levelUp);
      expect(
        card.confidence,
        greaterThanOrEqualTo(BlockCard.lowConfidenceThreshold),
      );
    });

    test('skill acquisition classifies as skillGain', () async {
      const block = '''
━━━━━━━━━━━━━━━━━━━━━━━

Skill Acquired

━━━━━━━━━━━━━━━━━━━━━━━

Dagger Mastery''';

      final card = (await detector.process(block))[0].card!;
      expect(card.type, BlockCardType.skillGain);
    });

    test('<...> stat sheet parses key:value pairs and sentinels', () async {
      const block = '''
<Host: Jacob Ironfell>
<Age: 0 months>
<Class: Locked>
<Cheats: Locked>
<Skills: Locked>''';

      final card = (await detector.process(block))[0].card!;
      expect(
        card.confidence,
        greaterThanOrEqualTo(BlockCard.lowConfidenceThreshold),
      );
      expect(
        card.fields.any(
          (f) => f.label == 'Host' && f.value == 'Jacob Ironfell',
        ),
        isTrue,
      );
      expect(card.fields.any((f) => f.value == 'Locked'), isTrue);
    });

    test('tag chains produce tag pills', () async {
      const block =
          '[Flame Archor – Unnamed][Tier 9][Rank C][Potential for Evolution: 58%]';
      final card = (await detector.process(block))[0].card!;
      expect(card.tags, containsAll(['Tier 9', 'Rank C']));
      expect(card.fields.any((f) => f.label.contains('Potential')), isTrue);
    });

    test(
      'ding cue plus naked key:value stack parses without brackets',
      () async {
        const block = '''
Ding!!

System Notification
Target: Unknown Female Knight
Satisfaction Level: 72%
Current Satisfaction Points: 86''';

        final card = (await detector.process(block))[0].card!;
        expect(
          card.confidence,
          greaterThanOrEqualTo(BlockCard.lowConfidenceThreshold),
        );
        expect(card.fields.any((f) => f.label == 'Target'), isTrue);
      },
    );
  });

  group('offline round-trip', () {
    test('process preserves every paragraph with aiExtractor null', () async {
      const chapter = '''
"Boom!"

A violent sound erupted from the road.

——————

【Trial task initiated.】

【Trial Task: Having returned to high school, you may be filled with questions and confusion.】

He drew the three options in his notebook.

> Name : Liam Taylor
> Age : 22''';

      final detectorLocal = BlockCardDetector(aiExtractor: null);
      final spans = await detectorLocal.process(chapter);

      final sourceParagraphs = chapter
          .split(RegExp(r'\n\s*\n'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      // Flatten spans back into paragraphs: each card's rawText must
      // equal one-or-more consecutive source paragraphs joined by '\n';
      // prose must match its paragraph verbatim. Nothing may be
      // dropped, reordered, or altered.
      var idx = 0;
      for (final span in spans) {
        if (!span.isCard) {
          expect(
            span.prose!.trim(),
            sourceParagraphs[idx],
            reason: 'prose at paragraph $idx changed',
          );
          idx++;
          continue;
        }
        final raw = span.card!.rawText;
        var matched = false;
        for (
          var end = idx + 1;
          end <= sourceParagraphs.length && !matched;
          end++
        ) {
          if (sourceParagraphs.sublist(idx, end).join('\n') == raw) {
            idx = end;
            matched = true;
          }
        }
        expect(matched, isTrue, reason: 'card rawText not aligned: $raw');
      }
      expect(idx, sourceParagraphs.length);
    });
  });
}
