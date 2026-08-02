import 'package:atlas_app/core/content_engine/index/tokenizer.dart';
import 'package:atlas_app/core/content_engine/models/atlas_document.dart';

/// Per-document vocabulary and term-frequency profile over [AtlasDocument]
/// text blocks. This is the "Dictionary Indexer" — a compact fingerprint of
/// what a document talks about, used for auto-glossaries, word-study features
/// and downstream AI context building.
class DictionaryIndexer {
  DictionaryIndexer({Tokenizer tokenizer = const Tokenizer()})
      : _tokenizer = tokenizer;

  final Tokenizer _tokenizer;
  final Map<String, Map<String, int>> _documents = {};

  /// Builds (or replaces) the vocabulary entry for [document] under [docId].
  void index(String docId, AtlasDocument document) {
    final frequencies = <String, int>{};
    for (final block in document.textBlocks) {
      for (final term in _tokenizer.tokenize(block.text)) {
        frequencies[term] = (frequencies[term] ?? 0) + 1;
      }
    }
    _documents[docId] = frequencies;
  }

  void remove(String docId) => _documents.remove(docId);

  void clear() => _documents.clear();

  /// Frequency of [term] within [docId]; 0 when absent or not indexed.
  int frequency(String docId, String term) =>
      _documents[docId]?[term.toLowerCase()] ?? 0;

  /// All terms and their frequencies for [docId], most frequent first.
  List<DictionaryEntry> vocabulary(String docId) {
    final frequencies = _documents[docId];
    if (frequencies == null) return const [];
    final entries = frequencies.entries
        .map((e) => DictionaryEntry(term: e.key, frequency: e.value))
        .toList()
      ..sort((a, b) => b.frequency.compareTo(a.frequency));
    return entries;
  }

  /// Terms appearing in [docId] at or above [minFrequency] — a quick "key
  /// words" surface for a chapter.
  List<String> keywords(String docId, {int minFrequency = 3}) {
    final frequencies = _documents[docId];
    if (frequencies == null) return const [];
    return frequencies.entries
        .where((e) => e.value >= minFrequency)
        .map((e) => e.key)
        .toList();
  }

  Set<String> get docIds => Set.unmodifiable(_documents.keys);
}

class DictionaryEntry {
  const DictionaryEntry({required this.term, required this.frequency});

  final String term;
  final int frequency;
}
