import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/index/dictionary_indexer.dart';
import 'package:atlas_app/core/content_engine/models/atlas_document.dart';

AtlasDocument _doc(List<String> paragraphs) => AtlasDocument(
  title: 'doc',
  blocks: [for (final p in paragraphs) ParagraphBlock(text: p)],
  metadata: const DocumentMetadata(),
);

void main() {
  group('DictionaryIndexer', () {
    test('counts term frequency per document', () {
      final indexer = DictionaryIndexer();
      indexer.index('d1', _doc(['the cat sat, the cat slept']));

      expect(indexer.frequency('d1', 'cat'), 2);
      expect(indexer.frequency('d1', 'sat'), 1);
      expect(indexer.frequency('d1', 'the'), 0); // stopword
      expect(indexer.frequency('missing', 'cat'), 0);
    });

    test('is case-insensitive', () {
      final indexer = DictionaryIndexer();
      indexer.index('d1', _doc(['Cat CAT cat']));

      expect(indexer.frequency('d1', 'cat'), 3);
    });

    test('vocabulary sorts most-frequent first', () {
      final indexer = DictionaryIndexer();
      indexer.index('d1', _doc(['one two one three one']));

      final vocab = indexer.vocabulary('d1');
      expect(vocab.first.term, 'one');
      expect(vocab.first.frequency, 3);
      expect(vocab, hasLength(3));
    });

    test('keywords filters by minFrequency (default 3)', () {
      final indexer = DictionaryIndexer();
      indexer.index('d1', _doc(['alpha alpha alpha beta beta gamma']));

      expect(indexer.keywords('d1'), ['alpha']);
      expect(
        indexer.keywords('d1', minFrequency: 2),
        containsAll(['alpha', 'beta']),
      );
    });

    test('remove and clear work', () {
      final indexer = DictionaryIndexer();
      indexer.index('d1', _doc(['alpha alpha']));
      indexer.index('d2', _doc(['beta beta']));

      indexer.remove('d1');
      expect(indexer.docIds, ['d2']);

      indexer.clear();
      expect(indexer.docIds, isEmpty);
      expect(indexer.vocabulary('d2'), isEmpty);
    });
  });
}
