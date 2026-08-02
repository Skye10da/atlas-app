import 'package:atlas_app/core/content_engine/index/tokenizer.dart';
import 'package:atlas_app/core/content_engine/models/atlas_document.dart';

/// A single document's entry in the [SearchIndexer]: term positions over its
/// text-bearing blocks, plus its total token count for scoring.
class _DocEntry {
  _DocEntry(this.docId);

  final String docId;
  final Map<String, List<int>> postings = {};
  int tokenCount = 0;
}

/// In-memory inverted index over [AtlasDocument] text blocks. Maps each
/// normalized term to the documents containing it and the block positions
/// where it appears, so search can return exact page/block locations.
///
/// Phase 3 (index): this is the search half of "Search Indexer". It is
/// deliberately DB-agnostic — a persisted index can wrap the same [SearchHit]
/// contract later.
class SearchIndexer {
  SearchIndexer({Tokenizer tokenizer = const Tokenizer()})
      : _tokenizer = tokenizer;

  final Tokenizer _tokenizer;
  final Map<String, Map<String, _DocEntry>> _terms = {};
  final Map<String, _DocEntry> _docs = {};

  /// Indexes [document] under [docId], replacing any prior entry for that id.
  void index(String docId, AtlasDocument document) {
    remove(docId);
    final entry = _DocEntry(docId);
    for (final block in document.textBlocks) {
      final tokens = _tokenizer.tokenize(block.text);
      entry.tokenCount += tokens.length;
      for (var i = 0; i < tokens.length; i++) {
        final term = tokens[i];
        final positions = entry.postings.putIfAbsent(term, () => []);
        positions.add(i);
      }
    }
    _docs[docId] = entry;
    for (final term in entry.postings.keys) {
      _terms.putIfAbsent(term, () => {})[docId] = entry;
    }
  }

  void remove(String docId) {
    final entry = _docs.remove(docId);
    if (entry == null) return;
    for (final term in entry.postings.keys) {
      _terms[term]?.remove(docId);
      if (_terms[term]?.isEmpty ?? false) _terms.remove(term);
    }
  }

  void clear() {
    _terms.clear();
    _docs.clear();
  }

  /// Terms currently in the index (for diagnostics and auto-suggest).
  Set<String> get terms => Set.unmodifiable(_terms.keys);

  /// Documents currently in the index.
  Set<String> get docIds => Set.unmodifiable(_docs.keys);

  int get documentCount => _docs.length;

  /// Returns matching documents ranked by how many distinct query terms hit.
  /// Each hit carries the block positions so the reader can jump to them.
  List<SearchHit> search(String query) {
    final terms = _tokenizer.tokenize(query);
    if (terms.isEmpty) return const [];

    final scores = <String, int>{};
    final hitByDoc = <String, SearchHit>{};
    for (final term in terms) {
      final bucket = _terms[term];
      if (bucket == null) continue;
      for (final entry in bucket.values) {
        scores[entry.docId] = (scores[entry.docId] ?? 0) + 1;
        (hitByDoc[entry.docId] ??= SearchHit(
          docId: entry.docId,
          positions: {},
          tokenCount: entry.tokenCount,
        ))
            .positions[term] = entry.postings[term]!;
      }
    }

    final hits = hitByDoc.values.toList()
      ..sort((a, b) {
        final byTerms = (scores[b.docId] ?? 0).compareTo(scores[a.docId] ?? 0);
        if (byTerms != 0) return byTerms;
        return a.tokenCount.compareTo(b.tokenCount);
      });
    return hits;
  }

  /// Positions of every indexed term in [docId], keyed by term.
  Map<String, List<int>> positionsFor(String docId) =>
      Map.unmodifiable(_docs[docId]?.postings ?? const {});
}

/// A search result: the matching document and the positions of each hit term.
class SearchHit {
  SearchHit({
    required this.docId,
    required this.positions,
    required this.tokenCount,
  });

  final String docId;

  /// Hit term → block positions within the document.
  final Map<String, List<int>> positions;
  final int tokenCount;

  /// True when every query term matched (AND semantics across terms).
  bool matchesAll(List<String> terms) =>
      terms.every(positions.containsKey);
}
