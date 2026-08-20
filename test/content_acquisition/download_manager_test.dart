import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/content_acquisition/services/cache_manager.dart';
import 'package:atlas_app/core/content_acquisition/services/download_manager.dart';

class _FakeSource implements SourceAdapter {
  _FakeSource({this.failFirst = false, this.delay = Duration.zero});

  final bool failFirst;
  bool failAlways = false;
  final Duration delay;
  int fetchCount = 0;

  @override
  bool canHandle(Uri uri) => true;

  @override
  ContentCategory get contentCategory => ContentCategory.novel;

  @override
  String get sourceName => 'fake';

  @override
  Future<NovelModel> getMetadata(Uri uri) async => throw UnimplementedError();

  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) async =>
      throw UnimplementedError();

  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) async {
    fetchCount++;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (failAlways) throw Exception('permanent failure');
    if (failFirst && fetchCount == 1) {
      throw Exception('transient failure');
    }
    return ChapterModel(
      id: chapter.id,
      title: chapter.title,
      index: chapter.index,
      contentUrl: chapter.contentUrl,
      content: 'content of ${chapter.id}',
      wordCount: 3,
    );
  }
}

void main() {
  late Directory tempDir;
  late CacheManager cache;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('download_manager_test');
    cache = CacheManager(basePath: tempDir.path);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  ChapterModel chapter(int i) => ChapterModel(
    id: 'ch$i',
    title: 'Chapter $i',
    index: i,
    contentUrl: 'https://example.com/$i',
  );

  group('DownloadManager', () {
    test(
      'downloads a chapter and reports queued → downloading → done',
      () async {
        final source = _FakeSource();
        final manager = DownloadManager(cacheManager: cache, workerCount: 1);

        final statuses = <DownloadStatus>[];
        manager.events.listen((e) => statuses.add(e.status));

        manager.enqueue('book1', chapter(0), source);
        await manager.waitForIdle();

        expect(statuses, [
          DownloadStatus.queued,
          DownloadStatus.downloading,
          DownloadStatus.done,
        ]);
        expect(await cache.hasChapter('book1', 'ch0'), isTrue);
        expect(await cache.getChapter('book1', 'ch0'), 'content of ch0');
      },
    );

    test('enqueues multiple chapters', () async {
      final source = _FakeSource();
      final manager = DownloadManager(cacheManager: cache, workerCount: 2);

      manager.enqueueMany('book1', [
        chapter(0),
        chapter(1),
        chapter(2),
      ], source);
      await manager.waitForIdle();

      for (var i = 0; i < 3; i++) {
        expect(await cache.hasChapter('book1', 'ch$i'), isTrue);
      }
      expect(source.fetchCount, 3);
    });

    test('runs up to workerCount tasks concurrently', () async {
      final source = _FakeSource(delay: const Duration(milliseconds: 40));
      final manager = DownloadManager(cacheManager: cache, workerCount: 2);

      final started = <String>[];
      final maxConcurrent = <int>[];
      final active = <String>{};
      manager.events.listen((e) {
        if (e.status == DownloadStatus.downloading) {
          active.add(e.chapterId);
          maxConcurrent.add(active.length);
        } else if (e.status == DownloadStatus.done) {
          active.remove(e.chapterId);
        }
        started.add(e.chapterId);
      });

      manager.enqueueMany('book1', [
        chapter(0),
        chapter(1),
        chapter(2),
        chapter(3),
      ], source);
      await manager.waitForIdle();

      expect(maxConcurrent.reduce((a, b) => a > b ? a : b), 2);
      expect(await cache.hasChapter('book1', 'ch3'), isTrue);
    });

    test('retries a transient failure then succeeds', () async {
      final source = _FakeSource(failFirst: true);
      final manager = DownloadManager(
        cacheManager: cache,
        workerCount: 1,
        maxAttempts: 3,
        retryBackoff: const Duration(milliseconds: 10),
      );

      final statuses = <DownloadStatus>[];
      manager.events.listen((e) => statuses.add(e.status));

      manager.enqueue('book1', chapter(0), source);
      await manager.waitForIdle();

      expect(
        statuses.where((s) => s == DownloadStatus.downloading),
        hasLength(2),
      );
      expect(statuses.last, DownloadStatus.done);
      expect(source.fetchCount, 2);
      expect(await cache.hasChapter('book1', 'ch0'), isTrue);
    });

    test('reports failed after exhausting attempts', () async {
      final source = _FakeSource()..failAlways = true;
      final manager = DownloadManager(
        cacheManager: cache,
        workerCount: 1,
        maxAttempts: 3,
        retryBackoff: const Duration(milliseconds: 10),
      );

      final errors = <String>[];
      manager.events.listen((e) {
        if (e.status == DownloadStatus.failed) errors.add(e.error ?? '');
      });

      manager.enqueue('book1', chapter(0), source);
      await manager.waitForIdle();

      expect(source.fetchCount, 3);
      expect(errors, hasLength(1));
      expect(await cache.hasChapter('book1', 'ch0'), isFalse);
    });

    test('cancel removes a queued task', () async {
      final source = _FakeSource(delay: const Duration(milliseconds: 100));
      final manager = DownloadManager(cacheManager: cache, workerCount: 1);

      final statuses = <DownloadStatus>[];
      final ch1Events = <DownloadStatus>[];
      manager.events.listen((e) {
        statuses.add(e.status);
        if (e.chapterId == 'ch1') ch1Events.add(e.status);
      });

      manager.enqueue('book1', chapter(0), source);
      manager.enqueue('book1', chapter(1), source);
      manager.cancel('book1', 'ch1');

      await manager.waitForIdle();

      expect(ch1Events, [DownloadStatus.queued, DownloadStatus.cancelled]);
      expect(await cache.hasChapter('book1', 'ch1'), isFalse);
      expect(await cache.hasChapter('book1', 'ch0'), isTrue);
    });

    test('isDownloaded reflects cache state', () async {
      final source = _FakeSource();
      final manager = DownloadManager(cacheManager: cache, workerCount: 1);

      expect(await manager.isDownloaded('book1', 'ch0'), isFalse);
      manager.enqueue('book1', chapter(0), source);
      await manager.waitForIdle();
      expect(await manager.isDownloaded('book1', 'ch0'), isTrue);
    });

    test('deduplicates identical book+chapter keys', () async {
      final source = _FakeSource();
      final manager = DownloadManager(cacheManager: cache, workerCount: 1);

      manager.enqueue('book1', chapter(0), source);
      manager.enqueue('book1', chapter(0), source);
      await manager.waitForIdle();

      expect(source.fetchCount, 1);
    });
  });
}
