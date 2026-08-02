import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/index/character_extractor.dart';
import 'package:atlas_app/core/content_engine/models/atlas_document.dart';

AtlasDocument _doc(String text) => AtlasDocument(
      title: 'doc',
      blocks: [ParagraphBlock(text: text)],
      metadata: const DocumentMetadata(),
    );

void main() {
  group('CharacterExtractor', () {
    test('extracts repeated mid-sentence capitalized names', () {
      const extractor = CharacterExtractor();
      final doc = _doc(
        'Mary met John in the woods. Later John saw Mary again. '
        'John smiled at Mary.',
      );

      final annotations = extractor.extract(doc);

      // John appears mid-sentence twice, Mary twice.
      expect(annotations, hasLength(2));
      final john = annotations.firstWhere((a) => a.text == 'John');
      final mary = annotations.firstWhere((a) => a.text == 'Mary');
      expect(john.type, 'character');
      expect(mary.type, 'character');
    });

    test('ignores sentence-initial-only capitalization', () {
      const extractor = CharacterExtractor();
      final doc = _doc(
        'The cat sat. The dog barked. The cat slept.',
      );

      final annotations = extractor.extract(doc);

      // "The" is only capitalized at sentence start — not a character.
      expect(annotations.where((a) => a.text == 'The'), isEmpty);
    });

    test('marks known place markers as places', () {
      const extractor = CharacterExtractor();
      final doc = _doc(
        'They reached the City gates. The City is old. '
        'In the City, guards patrol.',
      );

      final annotations = extractor.extract(doc);

      final city = annotations.firstWhere((a) => a.text == 'City');
      expect(city.type, 'place');
    });

    test('respects minMentions threshold', () {
      const extractor = CharacterExtractor(minMentions: 3);
      final doc = _doc(
        'Solo appeared once. Solo waved. Solo left.',
      );

      expect(extractor.extract(doc), isEmpty);
    });

    test('respects minLength threshold', () {
      const extractor = CharacterExtractor(minLength: 4);
      final doc = _doc('AI is powerful. AI learns. AI grows.');

      expect(extractor.extract(doc), isEmpty);
    });

    test('skips non-mixed-case tokens', () {
      const extractor = CharacterExtractor();
      final doc = _doc('DRAGON flies. DRAGON burns. DRAGON roars.');

      expect(extractor.extract(doc), isEmpty);
    });

    test('returns empty for empty text', () {
      const extractor = CharacterExtractor();
      expect(extractor.extract(_doc('')), isEmpty);
    });
  });
}
