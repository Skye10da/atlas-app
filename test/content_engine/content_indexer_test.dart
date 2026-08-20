import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/index/content_indexer.dart';
import 'package:atlas_app/core/content_engine/models/atlas_document.dart';

AtlasDocument _doc(String text) => AtlasDocument(
  title: 'doc',
  blocks: [ParagraphBlock(text: text)],
  metadata: const DocumentMetadata(),
);

void main() {
  group('ContentIndexer', () {
    test('indexes into search and dictionary, and attaches annotations', () {
      final indexer = ContentIndexer();
      const doc = AtlasDocument(
        title: 'doc',
        blocks: [
          ParagraphBlock(text: 'Mary walked, John smiled, John waved.'),
          ParagraphBlock(text: 'Within the City, guards patrolled the City.'),
        ],
        metadata: DocumentMetadata(),
      );

      final result = indexer.index('d1', doc);

      expect(indexer.search.search('John'), hasLength(1));
      expect(indexer.dictionary.frequency('d1', 'walked'), 1);

      final types = result.annotations.map((a) => a.type).toSet();
      expect(types, contains('character'));
      expect(types, contains('place'));
    });

    test('does not mutate the document when nothing is extracted', () {
      final indexer = ContentIndexer();
      final doc = _doc('the cat sat on the mat');

      final result = indexer.index('d1', doc);

      expect(result, same(doc));
      expect(result.annotations, isEmpty);
    });

    test('remove clears the doc from search and dictionary', () {
      final indexer = ContentIndexer();
      indexer.index('d1', _doc('John arrived. John waited.'));

      indexer.remove('d1');

      expect(indexer.search.docIds, isEmpty);
      expect(indexer.dictionary.docIds, isEmpty);
    });

    test('clear empties everything', () {
      final indexer = ContentIndexer();
      indexer.index('d1', _doc('John arrived.'));
      indexer.index('d2', _doc('Mary arrived.'));

      indexer.clear();

      expect(indexer.search.documentCount, 0);
      expect(indexer.dictionary.docIds, isEmpty);
    });
  });
}
