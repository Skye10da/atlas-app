import 'dart:convert';
import 'dart:io';

import 'package:epub_plus/epub_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/application/atlas_source_import_service.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/reader/application/chapter_download_service.dart';
import 'package:atlas_app/reader/application/novel_export_service.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/reader_repository_interface.dart';

class _MockReaderRepo extends Mock implements ReaderRepositoryInterface {}

class _MockChapterDownloader extends Mock implements ChapterDownloadService {}

void main() {
  late Directory outDir;
  late _MockReaderRepo repo;
  late _MockChapterDownloader downloader;
  late NovelExportService service;
  late BookEntity book;
  late ChapterEntity ch0;
  late ChapterEntity ch1;

  setUp(() async {
    outDir = await Directory.systemTemp.createTemp('novel_export_test');
    repo = _MockReaderRepo();
    downloader = _MockChapterDownloader();
    service = NovelExportService(
      readerRepo: repo,
      chapterDownloadService: downloader,
      sourceRegistry: SourceRegistry(),
    );
    book = BookEntity(
      id: 'book1',
      title: 'The Example Saga',
      author: 'A. Author',
      description: 'A tale of examples and sagas.',
      format: 'web',
      totalChapters: 2,
      language: 'en',
      tags: const ['fantasy', 'adventure'],
      status: 'Ongoing',
      sourceUrl: 'https://example.com/novel/the-example-saga',
      itemType: ContentCategory.novel,
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );
    ch0 = ChapterEntity(
      id: 'book1_ch0',
      bookId: 'book1',
      index: 0,
      title: 'Chapter One',
      contentPath: '${outDir.path}/0.txt',
    );
    ch1 = ChapterEntity(
      id: 'book1_ch1',
      bookId: 'book1',
      index: 1,
      title: 'Chapter Two',
      contentPath: '${outDir.path}/1.txt',
    );

    when(() => repo.getBookById(any())).thenAnswer((_) async => Success(book));
    when(
      () => repo.getChapters(any()),
    ).thenAnswer((_) async => Success([ch0, ch1]));
    when(
      () => downloader.downloadAllChapters(
        any(),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async => [const Success(null), const Success(null)]);
    when(
      () => repo.getChapterContent('${outDir.path}/0.txt'),
    ).thenAnswer((_) async => const Success('Opening lines.\n\nMore prose.'));
    when(
      () => repo.getChapterContent('${outDir.path}/1.txt'),
    ).thenAnswer((_) async => const Success('Closing words.'));
  });

  tearDown(() async {
    try {
      await outDir.delete(recursive: true);
    } catch (_) {}
  });

  test('exportToEpub writes a readable epub with all chapters', () async {
    final result = await service.exportToEpub(
      bookId: 'book1',
      outputDirectory: outDir.path,
    );

    expect(result, isA<Success<String>>());
    final path = (result as Success<String>).value;
    expect(path, endsWith('.epub'));
    expect(File(path).existsSync(), isTrue);

    final bytes = await File(path).readAsBytes();
    final read = await EpubReader.readBook(bytes);
    expect(read.title, 'The Example Saga');
    expect(read.author, contains('A. Author'));
    expect(
      read.schema?.package?.metadata?.description,
      'A tale of examples and sagas.',
    );
    expect(read.schema?.package?.metadata?.languages, ['en']);
    expect(
      read.schema?.package?.metadata?.subjects,
      containsAll(['fantasy', 'adventure']),
    );
    expect(read.chapters.length, 2);
    expect(read.chapters.first.htmlContent, contains('Opening lines.'));
    expect(read.chapters.last.htmlContent, contains('Closing words.'));
    expect(read.chapters.first.htmlContent, contains('More prose.'));
  });

  test('exportToEpub embeds a local cover when one exists', () async {
    final cover = File('${outDir.path}/cover.jpg');
    await cover.writeAsBytes(List.filled(16, 0xFF));
    when(() => repo.getBookById('book1')).thenAnswer(
      (_) async => Success(
        BookEntity(
          id: book.id,
          title: book.title,
          author: book.author,
          format: book.format,
          totalChapters: book.totalChapters,
          language: book.language,
          tags: book.tags,
          status: book.status,
          sourceUrl: book.sourceUrl,
          coverPath: cover.path,
          itemType: book.itemType,
          createdAt: book.createdAt,
          updatedAt: book.updatedAt,
        ),
      ),
    );

    final result = await service.exportToEpub(
      bookId: 'book1',
      outputDirectory: outDir.path,
    );

    expect(result, isA<Success<String>>());
    final bytes = await File((result as Success<String>).value).readAsBytes();
    final read = await EpubReader.readBook(bytes);
    expect(
      read.schema!.package!.manifest!.items.map((i) => i.id),
      contains('cover-image'),
    );
  });

  test('exportToEpub fails when a chapter download fails', () async {
    when(
      () => downloader.downloadAllChapters(
        any(),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer(
      (_) async => [
        const Success(null),
        const Failure(DatabaseException('boom')),
      ],
    );

    final result = await service.exportToEpub(
      bookId: 'book1',
      outputDirectory: outDir.path,
    );

    expect(result, isA<Failure<String>>());
  });

  test(
    'exportSourceLink writes an .atlas manifest with source and chapters',
    () async {
      final result = await service.exportSourceLink(
        bookId: 'book1',
        outputDirectory: outDir.path,
      );

      expect(result, isA<Success<String>>());
      final path = (result as Success<String>).value;
      expect(path, endsWith('.atlas'));

      final decoded = jsonDecode(File(path).readAsStringSync()) as Map;
      expect(decoded['format'], AtlasSourceImportService.format);
      expect(decoded['category'], 'novel');
      final source = decoded['source'] as Map;
      expect(source['url'], book.sourceUrl);
      expect(decoded['coverBase64'], isNull);

      final bookMap = decoded['book'] as Map;
      expect(bookMap['title'], 'The Example Saga');
      expect(bookMap['status'], 'Ongoing');

      final chapters = decoded['chapters'] as List;
      expect(chapters.length, 2);
      expect((chapters[0] as Map)['index'], 0);
      expect((chapters[1] as Map)['index'], 1);
    },
  );

  test(
    'exportSourceLink embeds a base64 cover from the local cover file',
    () async {
      final cover = File('${outDir.path}/cover.jpg');
      await cover.writeAsBytes(List.filled(16, 0xFF));
      book = BookEntity(
        id: book.id,
        title: book.title,
        author: book.author,
        format: book.format,
        totalChapters: book.totalChapters,
        language: book.language,
        tags: book.tags,
        status: book.status,
        sourceUrl: book.sourceUrl,
        coverPath: cover.path,
        itemType: book.itemType,
        createdAt: book.createdAt,
        updatedAt: book.updatedAt,
      );

      final result = await service.exportSourceLink(
        bookId: 'book1',
        outputDirectory: outDir.path,
      );

      expect(result, isA<Success<String>>());
      final decoded =
          jsonDecode(File((result as Success<String>).value).readAsStringSync())
              as Map;
      expect(decoded['coverBase64'], isA<String>());
      expect(
        base64Decode(decoded['coverBase64'] as String),
        List.filled(16, 0xFF),
      );
    },
  );

  test('exportSourceLink fails when the book has no source URL', () async {
    final noSource = BookEntity(
      id: 'book2',
      title: 'Local Only',
      format: 'web',
      totalChapters: 1,
      itemType: ContentCategory.novel,
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );
    when(
      () => repo.getBookById('book2'),
    ).thenAnswer((_) async => Success(noSource));

    final result = await service.exportSourceLink(
      bookId: 'book2',
      outputDirectory: outDir.path,
    );

    expect(result, isA<Failure<String>>());
  });

  group('AtlasSourceImportService.parseSourceUrl', () {
    const service = AtlasSourceImportService();

    test('extracts the source URL from a valid package', () {
      final result = service.parseSourceUrl(
        utf8.encode(
          jsonEncode({
            'format': 'atlas-source-v1',
            'source': {'url': 'https://example.com/novel/x'},
          }),
        ),
      );

      expect(result, isA<Success<String?>>());
      expect((result as Success<String?>).value, 'https://example.com/novel/x');
    });

    test('rejects an unsupported format', () {
      final result = service.parseSourceUrl(
        utf8.encode(jsonEncode({'format': 'something-else'})),
      );

      expect(result, isA<Failure<String?>>());
    });

    test('rejects a package without a source URL', () {
      final result = service.parseSourceUrl(
        utf8.encode(jsonEncode({'format': 'atlas-source-v1', 'source': {}})),
      );

      expect(result, isA<Failure<String?>>());
    });

    test('rejects invalid json', () {
      final result = service.parseSourceUrl(utf8.encode('not json'));

      expect(result, isA<Failure<String?>>());
    });
  });
}
