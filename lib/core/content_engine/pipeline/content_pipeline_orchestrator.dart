import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_engine/index/content_indexer.dart';
import 'package:atlas_app/core/content_engine/models/atlas_document.dart';
import 'package:atlas_app/core/content_engine/models/content_hasher.dart';
import 'package:atlas_app/core/content_engine/pipeline/pipeline_result.dart';
import 'package:atlas_app/core/content_engine/pipeline/rich_source.dart';
import 'package:atlas_app/core/content_engine/storage/document_cache.dart';

/// Orchestrates the full content pipeline for a single chapter:
///
/// discovery → source resolution → plugin selection → transport → DOM
/// construction → clean → normalize → post-normalize (version+checksum) →
/// index → cache → deliver.
///
/// Discovery, source resolution, plugin selection, transport, DOM, clean and
/// normalize are all delegated to the [SourceAdapter] (the template tail runs
/// the clean→normalize [ContentPipeline]); this class owns the stages that
/// cross adapter boundaries and the delivery contract.
class ContentPipelineOrchestrator {
  ContentPipelineOrchestrator({
    required this.registry,
    DocumentCache? cache,
    ContentIndexer? indexer,
    this.hasher = const ContentHasher(),
  }) : cache = cache ?? DocumentCache(),
       indexer = indexer ?? ContentIndexer();

  final SourceRegistry registry;
  final DocumentCache cache;
  final ContentIndexer indexer;
  final ContentHasher hasher;

  /// Stage 1 — discovery: find an adapter that can handle the URL.
  SourceAdapter? discover(Uri url) => registry.resolve(url);

  /// Full run for a chapter. Returns the delivered [PipelineResult] with
  /// post-normalize version + checksum, caching the [AtlasDocument] JSON.
  Future<PipelineResult> deliver({
    required String bookId,
    required Uri url,
    required ChapterModel chapter,
    int previousVersion = 1,
    String? previousChecksum,
  }) async {
    final source = discover(url);
    if (source == null) {
      throw StateError('No source adapter can handle $url');
    }

    final document = source is RichSource
        ? await (source as RichSource).getDocument(chapter)
        : await _documentFromText(source, chapter);

    final text = document.renderToText();
    final checksum = hasher.sha256Of(text);
    final changed = previousChecksum == null || previousChecksum != checksum;
    final version = changed ? previousVersion + 1 : previousVersion;

    final indexed = indexer.index(chapter.id, document);
    final result = PipelineResult(
      document: indexed,
      text: text,
      wordCount: indexed.wordCount,
      version: version,
      checksum: checksum,
    );

    await cache.save(bookId, chapter.id, indexed);

    return result;
  }

  Future<AtlasDocument> _documentFromText(
    SourceAdapter source,
    ChapterModel chapter,
  ) async {
    final fetched = await source.getChapter(chapter);
    final text = fetched.content ?? '';
    return AtlasDocument(
      title: chapter.title,
      blocks: [ParagraphBlock(text: text.trim())],
      metadata: DocumentMetadata(
        sourceUrl: chapter.contentUrl,
        sourceId: source.sourceName,
        sourceName: source.sourceName,
      ),
    );
  }
}
