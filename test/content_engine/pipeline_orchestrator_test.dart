import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/content_engine/models/atlas_document.dart';
import 'package:atlas_app/core/content_engine/pipeline/content_pipeline_orchestrator.dart';
import 'package:atlas_app/core/content_engine/pipeline/rich_source.dart';
import 'package:atlas_app/core/content_engine/storage/document_cache.dart';

SourceRegistry _registry(List<SourceAdapter> sources) {
  final registry = SourceRegistry();
  for (final source in sources) {
    registry.register(source);
  }
  return registry;
}

class _FakeRichSource implements SourceAdapter, RichSource {
  _FakeRichSource();

  @override
  bool canHandle(Uri uri) => uri.host == 'example.com';

  @override
  ContentCategory get contentCategory => ContentCategory.novel;

  @override
  String get sourceName => 'fake-rich';

  @override
  Future<NovelModel> getMetadata(Uri uri) async => throw UnimplementedError();

  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) async =>
      throw UnimplementedError();

  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) async =>
      throw UnimplementedError();

  @override
  Future<AtlasDocument> getDocument(ChapterModel chapter) async =>
      AtlasDocument(
        title: chapter.title,
        blocks: [
          const ParagraphBlock(text: 'hello world'),
          const HeadingBlock(text: 'Sub', level: 2),
        ],
        metadata: DocumentMetadata(
          sourceUrl: chapter.contentUrl,
          sourceId: 'fake-rich',
          sourceName: 'fake-rich',
        ),
      );
}

class _FakeTextSource implements SourceAdapter {
  @override
  bool canHandle(Uri uri) => uri.host == 'books.com';

  @override
  ContentCategory get contentCategory => ContentCategory.book;

  @override
  String get sourceName => 'fake-text';

  @override
  Future<NovelModel> getMetadata(Uri uri) async => throw UnimplementedError();

  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) async =>
      throw UnimplementedError();

  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) async => ChapterModel(
        id: chapter.id,
        title: chapter.title,
        index: chapter.index,
        contentUrl: chapter.contentUrl,
        content: '  plain text body  ',
        wordCount: 3,
      );
}

void main() {
  late Directory tempDir;
  late DocumentCache cache;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pipeline_test');
    cache = DocumentCache(basePath: tempDir.path);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('ContentPipelineOrchestrator', () {
    test('discovery returns the adapter that can handle the URL', () {
      final orchestrator = ContentPipelineOrchestrator(
        registry: _registry([_FakeRichSource()]),
        cache: cache,
      );
      expect(orchestrator.discover(Uri.parse('https://example.com/a')),
          isA<_FakeRichSource>());
      expect(orchestrator.discover(Uri.parse('https://other.com/a')), isNull);
    });

    test('delivers a rich document with post-normalize version+checksum',
        () async {
      final orchestrator = ContentPipelineOrchestrator(
        registry: _registry([_FakeRichSource()]),
        cache: cache,
      );
      const chapter = ChapterModel(
        id: 'ch1',
        title: 'Chapter 1',
        index: 0,
        contentUrl: 'https://example.com/ch1',
      );

      final result = await orchestrator.deliver(
        bookId: 'book1',
        url: Uri.parse('https://example.com/ch1'),
        chapter: chapter,
      );

      expect(result.text, 'hello world\n\nSub');
      expect(result.wordCount, 3);
      expect(result.version, 2);
      expect(result.checksum, hasLength(64));
      expect(result.document.title, 'Chapter 1');
      expect(result.document.blocks, hasLength(2));
    });

    test('indexes delivered documents into the post-normalize indexer stage',
        () async {
      final orchestrator = ContentPipelineOrchestrator(
        registry: _registry([_FakeRichSource()]),
        cache: cache,
      );
      const chapter = ChapterModel(
        id: 'ch1',
        title: 'Chapter 1',
        index: 0,
        contentUrl: 'https://example.com/ch1',
      );

      await orchestrator.deliver(
        bookId: 'book1',
        url: Uri.parse('https://example.com/ch1'),
        chapter: chapter,
      );

      final hits = orchestrator.indexer.search.search('hello');
      expect(hits, hasLength(1));
      expect(hits.single.docId, 'ch1');
      expect(orchestrator.indexer.dictionary.frequency('ch1', 'hello'), 1);
    });

    test('version stays unchanged when checksum matches previous', () async {
      final orchestrator = ContentPipelineOrchestrator(
        registry: _registry([_FakeRichSource()]),
        cache: cache,
      );
      const chapter = ChapterModel(
        id: 'ch1',
        title: 'Chapter 1',
        index: 0,
        contentUrl: 'https://example.com/ch1',
      );

      final first = await orchestrator.deliver(
        bookId: 'book1',
        url: Uri.parse('https://example.com/ch1'),
        chapter: chapter,
      );
      final second = await orchestrator.deliver(
        bookId: 'book1',
        url: Uri.parse('https://example.com/ch1'),
        chapter: chapter,
        previousVersion: first.version,
        previousChecksum: first.checksum,
      );

      expect(second.version, first.version);
      expect(second.checksum, first.checksum);
    });

    test('caches the AtlasDocument JSON and loads it back', () async {
      final orchestrator = ContentPipelineOrchestrator(
        registry: _registry([_FakeRichSource()]),
        cache: cache,
      );
      const chapter = ChapterModel(
        id: 'ch1',
        title: 'Chapter 1',
        index: 0,
        contentUrl: 'https://example.com/ch1',
      );

      await orchestrator.deliver(
        bookId: 'book1',
        url: Uri.parse('https://example.com/ch1'),
        chapter: chapter,
      );

      expect(await cache.has('book1', 'ch1'), isTrue);
      final loaded = await cache.load('book1', 'ch1');
      expect(loaded, isNotNull);
      expect(loaded!.title, 'Chapter 1');
      expect(loaded.blocks, hasLength(2));
    });

    test('falls back to a text-only document for non-rich sources', () async {
      final orchestrator = ContentPipelineOrchestrator(
        registry: _registry([_FakeTextSource()]),
        cache: cache,
      );
      const chapter = ChapterModel(
        id: 'ch1',
        title: 'Chapter 1',
        index: 0,
        contentUrl: 'https://books.com/ch1',
      );

      final result = await orchestrator.deliver(
        bookId: 'book1',
        url: Uri.parse('https://books.com/ch1'),
        chapter: chapter,
      );

      expect(result.text, 'plain text body');
      expect(result.document.blocks.single, isA<ParagraphBlock>());
      expect(await cache.has('book1', 'ch1'), isTrue);
    });

    test('throws when no adapter can handle the URL', () async {
      final orchestrator = ContentPipelineOrchestrator(
        registry: _registry([_FakeRichSource()]),
        cache: cache,
      );
      const chapter = ChapterModel(
        id: 'ch1',
        title: 'Chapter 1',
        index: 0,
        contentUrl: 'https://unhandled.com/ch1',
      );

      await expectLater(
        orchestrator.deliver(
          bookId: 'book1',
          url: Uri.parse('https://unhandled.com/ch1'),
          chapter: chapter,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
