import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/content_acquisition/services/cache_manager.dart';
import 'package:atlas_app/core/content_acquisition/services/download_manager.dart';
import 'package:atlas_app/core/content_engine/image/image_pipeline.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/core/database/database.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.dir);

  final Directory dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      '${dir.path}/documents';
}

class _FakeSource implements SourceAdapter {
  _FakeSource({required this.novel, required this.chapters});

  final NovelModel novel;
  final List<ChapterModel> chapters;

  @override
  bool canHandle(Uri uri) => uri.host == 'example.com';

  @override
  ContentCategory get contentCategory => ContentCategory.novel;

  @override
  String get sourceName => novel.source;

  @override
  Future<NovelModel> getMetadata(Uri uri) async => novel;

  @override
  Future<List<ChapterModel>> getChapters(NovelModel n) async => chapters;

  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) async => ChapterModel(
        id: chapter.id,
        title: chapter.title,
        index: chapter.index,
        contentUrl: chapter.contentUrl,
        content: 'content ${chapter.index}',
        wordCount: 3,
      );
}

void main() {
  late Directory tempDir;
  late AppDatabase db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('engine_test');
    PathProviderPlatform.instance = _FakePathProvider(
      Directory('${tempDir.path}/support'),
    );
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
    var attempts = 0;
    while (attempts < 5) {
      try {
        await tempDir.delete(recursive: true);
        break;
      } catch (_) {
        attempts++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  ChapterModel chapter(int i) => ChapterModel(
        id: 'ch$i',
        title: 'Chapter $i',
        index: i,
        contentUrl: 'https://example.com/ch$i',
      );

  group('ContentAcquisitionEngine.resumeDownloads', () {
    test('re-enqueues chapters whose DB state is not availableOffline',
        () async {
      final source = _FakeSource(
        novel: const NovelModel(
          title: 'Test Novel',
          sourceId: 'novel-1',
          source: 'fake',
          sourceUrl: 'https://example.com/novel',
          category: ContentCategory.novel,
        ),
        chapters: [chapter(0), chapter(1), chapter(2)],
      );
      final registry = SourceRegistry()..register(source);
      final engine = ContentAcquisitionEngine(
        registry: registry,
        db: db,
        cacheManager: CacheManager(basePath: '${tempDir.path}/cache'),
      );

      final outcome = await engine.importAndSave('https://example.com/novel');
      final statuses = <DownloadStatus>[];
      engine.downloadManager.events.listen((e) => statuses.add(e.status));

      final resumed = await engine.resumeDownloads();
      await engine.downloadManager.waitForIdle();

      expect(resumed, 3);
      expect(
        statuses.where((s) => s == DownloadStatus.done),
        hasLength(3),
      );
      for (var i = 0; i < 3; i++) {
        expect(
          await engine.downloadManager.isDownloaded(outcome.bookId, 'ch$i'),
          isTrue,
        );
      }
      expect(outcome.category, ContentCategory.novel);
    });

    test('does not re-enqueue chapters already available offline', () async {
      final source = _FakeSource(
        novel: const NovelModel(
          title: 'Test Novel',
          sourceId: 'novel-2',
          source: 'fake',
          sourceUrl: 'https://example.com/novel2',
          category: ContentCategory.novel,
        ),
        chapters: [chapter(0)],
      );
      final registry = SourceRegistry()..register(source);
      final engine = ContentAcquisitionEngine(
        registry: registry,
        db: db,
        cacheManager: CacheManager(basePath: '${tempDir.path}/cache'),
      );

      final outcome = await engine.importAndSave('https://example.com/novel2');
      await engine.downloadAllChapters(outcome.bookId);
      await engine.downloadManager.waitForIdle();

      final resumed = await engine.resumeDownloads();
      await engine.downloadManager.waitForIdle();

      expect(resumed, 0);
    });
  });

  group('ContentAcquisitionEngine.importAndSave cover download', () {
    test('saves a cover via ImagePipeline when one is wired in', () async {
      final coverBytes = List<int>.generate(32, (i) => i);
      final transport = _CoverTransport(coverBytes);
      final pipeline = ImagePipeline(
        transport: transport,
        basePath: '${tempDir.path}/images',
      );
      final source = _FakeSource(
        novel: const NovelModel(
          title: 'Cover Novel',
          sourceId: 'novel-3',
          source: 'fake',
          sourceUrl: 'https://example.com/cover-novel',
          coverUrl: 'https://example.com/cover.jpg',
          category: ContentCategory.novel,
        ),
        chapters: [chapter(0)],
      );
      final registry = SourceRegistry()..register(source);
      final engine = ContentAcquisitionEngine(
        registry: registry,
        db: db,
        cacheManager: CacheManager(basePath: '${tempDir.path}/cache'),
        imagePipeline: pipeline,
      );

      final outcome = await engine.importAndSave(
        'https://example.com/cover-novel',
      );

      expect(transport.coverRequests, 1);
      final book = await (db.select(db.books)
            ..where((b) => b.id.equals(outcome.bookId)))
          .getSingle();
      expect(book.coverPath, isNotNull);
      expect(File(book.coverPath!).existsSync(), isTrue);
      expect(await File(book.coverPath!).readAsBytes(), coverBytes);
    });

    test('import succeeds without coverBytes/coverUrl or pipeline', () async {
      final source = _FakeSource(
        novel: const NovelModel(
          title: 'Bare Novel',
          sourceId: 'novel-4',
          source: 'fake',
          sourceUrl: 'https://example.com/bare',
          category: ContentCategory.novel,
        ),
        chapters: [chapter(0)],
      );
      final registry = SourceRegistry()..register(source);
      final engine = ContentAcquisitionEngine(
        registry: registry,
        db: db,
        cacheManager: CacheManager(basePath: '${tempDir.path}/cache'),
      );

      final outcome = await engine.importAndSave('https://example.com/bare');

      final book = await (db.select(db.books)
            ..where((b) => b.id.equals(outcome.bookId)))
          .getSingle();
      expect(book.coverPath, isNull);
    });
  });
}

class _CoverTransport implements Transport {
  _CoverTransport(this.bytes);

  final List<int> bytes;
  int coverRequests = 0;

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async =>
      throw UnimplementedError();

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async =>
      throw UnimplementedError();

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    coverRequests++;
    return bytes;
  }
}
