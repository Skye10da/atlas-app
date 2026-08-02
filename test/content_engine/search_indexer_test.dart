import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/index/search_indexer.dart';
import 'package:atlas_app/core/content_engine/models/atlas_document.dart';

AtlasDocument _doc(String title, List<String> paragraphs) => AtlasDocument(
      title: title,
      blocks: [
        for (final p in paragraphs) ParagraphBlock(text: p),
      ],
      metadata: DocumentMetadata(sourceUrl: 'https://example.com/$title'),
    );

void main() {
  group('SearchIndexer', () {
    test('indexes blocks and finds documents by term', () {
      final indexer = SearchIndexer();
      indexer.index('d1', _doc('one', ['The dragon sleeps beneath the mountain.']));
      indexer.index('d2', _doc('two', ['Knights ride at dawn.']));

      final hits = indexer.search('dragon');

      expect(hits, hasLength(1));
      expect(hits.single.docId, 'd1');
      // "The" is a stopword, so "dragon" lands at block position 0.
      expect(hits.single.positions['dragon'], [0]);
    });

    test('is case-insensitive and matches multiple terms', () {
      final indexer = SearchIndexer();
      indexer.index('d1', _doc('one', ['Dragon mountains and a DRAGON rider.']));

      final hits = indexer.search('dRaGoN');

      expect(hits.single.docId, 'd1');
      expect(hits.single.positions['dragon'], hasLength(2));
    });

    test('ranks documents by distinct matching terms', () {
      final indexer = SearchIndexer();
      // d2 matches both terms, d1 only one.
      indexer.index('d1', _doc('one', ['dragon only here']));
      indexer.index('d2', _doc('two', ['dragon and mountain together']));

      final hits = indexer.search('dragon mountain');

      expect(hits.first.docId, 'd2');
    });

    test('ignores stopwords in the query', () {
      final indexer = SearchIndexer();
      indexer.index('d1', _doc('one', ['a lone knight']));

      expect(indexer.search('the a lone'), hasLength(1));
      expect(indexer.search('the a'), isEmpty);
    });

    test('remove() drops a document and its terms', () {
      final indexer = SearchIndexer();
      indexer.index('d1', _doc('one', ['dragon only']));
      indexer.index('d2', _doc('two', ['dragon and more']));

      indexer.remove('d1');

      expect(indexer.docIds, ['d2']);
      final hits = indexer.search('dragon');
      expect(hits.single.docId, 'd2');
      expect(indexer.terms, contains('dragon'));
    });

    test('index() replaces a prior entry for the same doc id', () {
      final indexer = SearchIndexer();
      indexer.index('d1', _doc('one', ['dragon only']));
      indexer.index('d1', _doc('one', ['phoenix only']));

      // The old entry is fully replaced: "dragon" no longer exists anywhere.
      expect(indexer.terms, isNot(contains('dragon')));
      expect(indexer.terms, contains('phoenix'));
      expect(indexer.search('dragon'), isEmpty);
      expect(indexer.search('phoenix'), hasLength(1));
    });

    test('exposes positions and document count', () {
      final indexer = SearchIndexer();
      indexer.index('d1', _doc('one', ['alpha beta alpha']));

      expect(indexer.documentCount, 1);
      expect(indexer.positionsFor('d1')['alpha'], [0, 2]);
      expect(indexer.positionsFor('d1')['beta'], [1]);
      expect(indexer.positionsFor('missing'), isEmpty);
    });

    test('searchHit.matchesAll reflects AND semantics', () {
      final indexer = SearchIndexer();
      indexer.index('d1', _doc('one', ['dragon mountain']));

      final hit = indexer.search('dragon mountain').single;
      expect(hit.matchesAll(['dragon', 'mountain']), isTrue);
      expect(hit.matchesAll(['dragon', 'missing']), isFalse);
    });
  });
}
