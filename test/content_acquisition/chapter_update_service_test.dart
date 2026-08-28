import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_acquisition/application/chapter_update_service.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:drift/drift.dart' show Value;

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
  _FakeSource({required this.chapters});

  List<ChapterModel> chapters;
  final String host = 'example.com';

  @override
  bool canHandle(Uri uri) => uri.host == host;

  @override
  ContentCategory get contentCategory => ContentCategory.novel;

  @override
  String get sourceName => 'fake';

  @override
  Future<NovelModel> getMetadata(Uri uri) async => NovelModel(
    sourceId: 'novel-1',
    title: 'Test Novel',
    source: sourceName,
    sourceUrl: uri.toString(),
    category: ContentCategory.novel,
  );

  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) async => chapters;

  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) async => chapter;
}

class _HangingSource implements SourceAdapter {
  @override
  bool canHandle(Uri uri) => uri.host == 'hang.com';

  @override
  ContentCategory get contentCategory => ContentCategory.novel;

  @override
  String get sourceName => 'hanging';

  @override
  Future<NovelModel> getMetadata(Uri uri) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) {
    // Simulates a stalled TLS handshake / unresponsive host.
    return Completer<List<ChapterModel>>().future;
  }

  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) async => chapter;
}

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late SourceRegistry registry;
  late _FakeSource source;
  late ChapterUpdateService service;
  late String bookDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('update_check_test');
    PathProviderPlatform.instance = _FakePathProvider(
      Directory('${tempDir.path}/support'),
    );
    db = AppDatabase.memory();
    registry = SourceRegistry();
    source = _FakeSource(chapters: []);
    registry.register(source);
    service = ChapterUpdateService(
      db: db,
      registry: registry,
      fetchTimeout: const Duration(milliseconds: 200),
    );

    bookDir = '${tempDir.path}/books/test_novel';
    await Directory(bookDir).create(recursive: true);
    await db
        .into(db.books)
        .insert(
          BooksCompanion.insert(
            id: 'test_novel',
            title: 'Test Novel',
            format: 'web',
            totalChapters: 2,
            filePath: bookDir,
            itemType: Value(ContentCategory.novel.name),
            status: const Value('Ongoing'),
            sourceName: const Value('fake'),
            sourceId: const Value('novel-1'),
            sourceUrl: const Value('https://example.com/novel'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
    for (var i = 0; i < 2; i++) {
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              id: 'test_novel_ch$i',
              bookId: 'test_novel',
              index: i,
              title: 'Chapter $i',
              contentPath: '$bookDir/$i.txt',
              wordCount: 10,
              pageCount: 1,
              createdAt: DateTime.now(),
            ),
          );
    }
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

  ChapterModel remote(int i) => ChapterModel(
    id: 'remote-$i',
    title: 'Chapter $i',
    index: i,
    contentUrl: 'https://example.com/ch$i',
  );

  test('appends newly released chapters and flags the book', () async {
    source.chapters = [remote(0), remote(1), remote(2), remote(3)];

    final outcome = await service.refreshBook('test_novel');

    expect(outcome.success, isTrue);
    expect(outcome.newChapters, 2);

    final book = await (db.select(
      db.books,
    )..where((b) => b.id.equals('test_novel'))).getSingle();
    expect(book.totalChapters, 4);
    expect(book.hasUpdate, isTrue);
    expect(book.newChapterCount, 2);
    expect(book.lastCheckedAt, isNotNull);

    final rows = await (db.select(
      db.chapters,
    )..where((c) => c.bookId.equals('test_novel'))).get();
    expect(rows.length, 4);
  });

  test('repeated checks do not duplicate existing chapters', () async {
    source.chapters = [remote(0), remote(1), remote(2)];

    await service.refreshBook('test_novel');
    final outcome = await service.refreshBook('test_novel');

    expect(outcome.newChapters, 0);
    final book = await (db.select(
      db.books,
    )..where((b) => b.id.equals('test_novel'))).getSingle();
    expect(book.newChapterCount, 1);
    final rows = await (db.select(
      db.chapters,
    )..where((c) => c.bookId.equals('test_novel'))).get();
    expect(rows.length, 3);
  });

  test('mid-list insertion only stores the genuinely new chapter', () async {
    // Source inserted "Prologue" at the front; every existing chapter's
    // remote index shifted by one but titles are unchanged.
    source.chapters = [
      const ChapterModel(
        id: 'remote-prologue',
        title: 'Prologue',
        index: 0,
        contentUrl: 'https://example.com/prologue',
      ),
      const ChapterModel(
        id: 'remote-0',
        title: 'Chapter 0',
        index: 1,
        contentUrl: 'https://example.com/ch0',
      ),
      const ChapterModel(
        id: 'remote-1',
        title: 'Chapter 1',
        index: 2,
        contentUrl: 'https://example.com/ch1',
      ),
    ];

    final outcome = await service.refreshBook('test_novel');

    expect(outcome.newChapters, 1);
    final rows = await (db.select(
      db.chapters,
    )..where((c) => c.bookId.equals('test_novel'))).get();
    expect(rows.length, 3);
    expect(
      rows.map((r) => r.title),
      containsAll(['Chapter 0', 'Chapter 1', 'Prologue']),
    );
  });

  test('checkTrackedBooks skips books with tracking disabled', () async {
    source.chapters = [remote(0), remote(1), remote(2)];
    await (db.update(db.books)..where((b) => b.id.equals('test_novel'))).write(
      const BooksCompanion(updateTrackingEnabled: Value(false)),
    );

    final result = await service.checkTrackedBooks();

    expect(result.booksWithUpdates, 0);
    final rows = await (db.select(
      db.chapters,
    )..where((c) => c.bookId.equals('test_novel'))).get();
    expect(rows.length, 2);
  });

  test('refreshing a book without a usable source reports failure', () async {
    await db
        .into(db.books)
        .insert(
          BooksCompanion.insert(
            id: 'local_epub',
            title: 'Local EPUB',
            format: 'epub',
            totalChapters: 1,
            filePath: bookDir,
            itemType: Value(ContentCategory.book.name),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    final outcome = await service.refreshBook('local_epub');

    expect(outcome.success, isFalse);
    expect(outcome.error, isNotNull);
  });

  test('an unresponsive source times out instead of hanging forever', () async {
    registry.register(_HangingSource());
    await db
        .into(db.books)
        .insert(
          BooksCompanion.insert(
            id: 'hanging_novel',
            title: 'Hanging Novel',
            format: 'web',
            totalChapters: 1,
            filePath: bookDir,
            itemType: Value(ContentCategory.novel.name),
            sourceName: const Value('hanging'),
            sourceId: const Value('hang-1'),
            sourceUrl: const Value('https://hang.com/novel'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    final outcome = await service
        .refreshBook('hanging_novel')
        .timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw StateError('refreshBook hung past deadline'),
        );

    expect(outcome.success, isFalse);
    expect(outcome.error, contains('too long'));
  });
}
