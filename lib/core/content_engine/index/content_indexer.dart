import 'package:atlas_app/core/content_engine/index/character_extractor.dart';
import 'package:atlas_app/core/content_engine/index/dictionary_indexer.dart';
import 'package:atlas_app/core/content_engine/index/search_indexer.dart';
import 'package:atlas_app/core/content_engine/models/atlas_document.dart';

/// Facade over the Phase 3 indexers, invoked by the pipeline's post-normalize
/// stage. Indexing a document here keeps a single entry point for the reader
/// and future persisted indexes.
class ContentIndexer {
  ContentIndexer({
    SearchIndexer? search,
    DictionaryIndexer? dictionary,
    this.extractor = const CharacterExtractor(),
  })  : search = search ?? SearchIndexer(),
        dictionary = dictionary ?? DictionaryIndexer();

  final SearchIndexer search;
  final DictionaryIndexer dictionary;
  final CharacterExtractor extractor;

  /// Indexes [document] and attaches character/place annotations to it.
  /// Returns the document with annotations populated (best-effort: a document
  /// with no text is left untouched rather than throwing).
  AtlasDocument index(String docId, AtlasDocument document) {
    search.index(docId, document);
    dictionary.index(docId, document);

    final annotations = extractor.extract(document);
    if (annotations.isEmpty) return document;

    final merged = <Annotation>[...document.annotations, ...annotations];
    return AtlasDocument(
      title: document.title,
      blocks: document.blocks,
      annotations: merged,
      metadata: document.metadata,
    );
  }

  void remove(String docId) {
    search.remove(docId);
    dictionary.remove(docId);
  }

  void clear() {
    search.clear();
    dictionary.clear();
  }
}
