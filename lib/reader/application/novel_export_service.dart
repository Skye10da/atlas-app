import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:epub_plus/epub_plus.dart';
import 'package:path/path.dart' as p;

import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_engine/image/image_pipeline.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/reader/application/chapter_download_service.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/reader_repository_interface.dart';

/// Writes a book out of the app as either a self-contained [EPUB] (all chapter
/// text embedded, suitable for completed novels) or a lightweight [.atlas]
/// source-link package (metadata + cover + chapter pointers that re-imports
/// through the original source and re-fetches content on demand).
class NovelExportService {
  NovelExportService({
    required this.readerRepo,
    required this.chapterDownloadService,
    required this.sourceRegistry,
    this.imagePipeline,
  });

  final ReaderRepositoryInterface readerRepo;
  final ChapterDownloadService chapterDownloadService;
  final SourceRegistry sourceRegistry;
  final ImagePipeline? imagePipeline;

  static const _contentDir = 'OEBPS';
  static const _atlasFormat = 'atlas-source-v1';

  /// Downloads any missing chapters and writes a self-contained EPUB into
  /// [outputDirectory]. Returns the absolute path of the written file.
  Future<Result<String>> exportToEpub({
    required String bookId,
    required String outputDirectory,
    void Function(int completed, int total)? onFetchProgress,
  }) async {
    try {
      final bookResult = await readerRepo.getBookById(bookId);
      if (bookResult is! Success<BookEntity>) return _toFailure(bookResult);
      final book = bookResult.value;

      final downloadResults = await chapterDownloadService.downloadAllChapters(
        bookId,
        onProgress: onFetchProgress,
      );
      final failed = downloadResults.whereType<Failure<void>>();
      if (failed.isNotEmpty) {
        return Failure(
          DatabaseException(
            'Failed to download all chapters',
            failed.first.error,
          ),
        );
      }

      final chaptersResult = await readerRepo.getChapters(bookId);
      if (chaptersResult is! Success<List<ChapterEntity>>) {
        return _toFailure(chaptersResult);
      }
      final chapters = chaptersResult.value;
      if (chapters.isEmpty) {
        return const Failure(ValidationException('No chapters to export'));
      }

      final html = <String, EpubTextContentFile>{};
      final navPoints = <EpubNavigationPoint>[];
      final manifestItems = <EpubManifestItem>[];
      final spineItems = <EpubSpineItemRef>[];
      final epubChapters = <EpubChapter>[];

      for (final chapter in chapters) {
        final contentResult = await readerRepo.getChapterContent(
          chapter.contentPath,
        );
        if (contentResult is! Success<String>) {
          return _toFailure(contentResult);
        }
        final text = contentResult.value.trim();
        if (text.isEmpty) continue;

        final fileName = 'ch_${chapter.index + 1}.xhtml';
        final title = chapter.title.isEmpty
            ? 'Chapter ${chapter.index + 1}'
            : chapter.title;
        final xhtml = _chapterXhtml(title, _textToParagraphs(text));

        html[fileName] = EpubTextContentFile(
          fileName: fileName,
          contentMimeType: 'application/xhtml+xml',
          content: xhtml,
        );
        manifestItems.add(
          EpubManifestItem(
            id: fileName.replaceAll('.xhtml', ''),
            href: fileName,
            mediaType: 'application/xhtml+xml',
          ),
        );
        spineItems.add(
          EpubSpineItemRef(
            idRef: fileName.replaceAll('.xhtml', ''),
            isLinear: true,
          ),
        );
        navPoints.add(
          EpubNavigationPoint(
            navigationLabels: [EpubNavigationLabel(text: title)],
            content: EpubNavigationContent(source: fileName),
          ),
        );
        epubChapters.add(
          EpubChapter(
            title: title,
            contentFileName: fileName,
            htmlContent: xhtml,
          ),
        );
      }

      if (html.isEmpty) {
        return const Failure(
          ValidationException('No readable content to export'),
        );
      }

      final images = <String, EpubByteContentFile>{};
      final coverBytes = await _loadCoverBytes(book);
      if (coverBytes != null) {
        final ext = _coverExtension(coverBytes);
        images['cover.$ext'] = EpubByteContentFile(
          fileName: 'cover.$ext',
          contentMimeType: ext == 'png' ? 'image/png' : 'image/jpeg',
          content: coverBytes,
        );
        manifestItems.add(
          EpubManifestItem(
            id: 'cover-image',
            href: 'cover.$ext',
            mediaType: ext == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );
      }

      // EPUB 2 + NCX: the epub_plus writer preserves every field the NCX-based
      // reader needs (spine toc, manifest id/href/media-type), so the exported
      // book round-trips back through EpubReader.readBook cleanly.
      const ncxItem = EpubManifestItem(
        id: 'ncx',
        href: 'toc.ncx',
        mediaType: 'application/x-dtbncx+xml',
      );
      manifestItems.insert(0, ncxItem);
      final ncxContent = _ncxXml(book.title, book.author, navPoints);
      final allFiles = <String, EpubContentFile>{
        ...html,
        ...images,
        'toc.ncx': EpubTextContentFile(
          fileName: 'toc.ncx',
          contentMimeType: 'application/x-dtbncx+xml',
          content: ncxContent,
        ),
      };

      final epub = EpubBook(
        title: book.title,
        author: book.author ?? 'Unknown Author',
        authors: [book.author ?? 'Unknown Author'],
        schema: EpubSchema(
          contentDirectoryPath: _contentDir,
          package: EpubPackage(
            version: EpubVersion.epub2,
            metadata: EpubMetadata(
              titles: [book.title],
              creators: [
                EpubMetadataCreator(
                  creator: book.author ?? 'Unknown Author',
                  role: 'aut',
                ),
              ],
              description: book.description,
              identifiers: const [],
              sources: book.sourceUrl != null ? [book.sourceUrl!] : const [],
              languages: book.language != null ? [book.language!] : const [],
              subjects: book.tags,
            ),
            manifest: EpubManifest(items: manifestItems),
            spine: EpubSpine(
              tableOfContents: 'ncx',
              items: spineItems,
              ltr: true,
            ),
            guide: const EpubGuide(),
          ),
          navigation: EpubNavigation(
            docTitle: EpubNavigationDocTitle(titles: [book.title]),
            navMap: EpubNavigationMap(points: navPoints),
          ),
        ),
        content: EpubContent(html: html, images: images, allFiles: allFiles),
        chapters: epubChapters,
      );

      final bytes = EpubWriter.writeBook(epub);
      if (bytes == null) {
        return const Failure(ValidationException('Failed to build epub'));
      }

      final outputDir = Directory(outputDirectory);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      final filePath = p.join(
        outputDirectory,
        '${_sanitizeFileName(book.title)}.epub',
      );
      await File(filePath).writeAsBytes(bytes, flush: true);
      return Success(filePath);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to export epub', e), st);
    }
  }

  /// Writes a lightweight `.atlas` package that re-imports the book through
  /// its original source. Chapter bodies are not included; the re-import
  /// re-discovers them and fetches on demand.
  Future<Result<String>> exportSourceLink({
    required String bookId,
    required String outputDirectory,
  }) async {
    try {
      final bookResult = await readerRepo.getBookById(bookId);
      if (bookResult is! Success<BookEntity>) return _toFailure(bookResult);
      final book = bookResult.value;

      if (book.sourceUrl == null || book.sourceUrl!.isEmpty) {
        return const Failure(
          ValidationException('This book has no source link to export'),
        );
      }

      final chaptersResult = await readerRepo.getChapters(bookId);
      if (chaptersResult is! Success<List<ChapterEntity>>) {
        return _toFailure(chaptersResult);
      }

      final chapters = chaptersResult.value
          .map(
            (c) => {
              'id': c.id,
              'title': c.title,
              'index': c.index,
              'contentUrl': _chapterContentUrl(c),
            },
          )
          .toList();

      final manifest = <String, dynamic>{
        'format': _atlasFormat,
        'category': 'novel',
        'exportedAt': DateTime.now().toIso8601String(),
        'source': {
          'name': book.sourceName,
          'id': book.sourceId,
          'url': book.sourceUrl,
        },
        'book': {
          'title': book.title,
          'author': book.author,
          'description': book.description,
          'language': book.language,
          'genres': book.tags,
          'status': book.status,
          'rating': book.rating,
          'totalChapters': book.totalChapters,
        },
        'chapters': chapters,
      };

      final coverBase64 = await _resolveCoverBase64(book);
      if (coverBase64 != null) {
        manifest['coverBase64'] = coverBase64;
      }

      final outputDir = Directory(outputDirectory);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      final filePath = p.join(
        outputDirectory,
        '${_sanitizeFileName(book.title)}.atlas',
      );
      await File(filePath).writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
        flush: true,
      );
      return Success(filePath);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to export source link', e), st);
    }
  }

  /// Cover resolution used by the `.atlas` package: local file first, then the
  /// source metadata, then a network fetch of the cover URL. Any failure just
  /// yields null so a missing cover never blocks the export.
  Future<String?> _resolveCoverBase64(BookEntity book) async {
    try {
      Uint8List? bytes;
      final coverPath = book.coverPath;
      if (coverPath != null && await File(coverPath).exists()) {
        bytes = await File(coverPath).readAsBytes();
      }

      if (bytes == null && book.sourceUrl != null) {
        final uri = Uri.tryParse(book.sourceUrl!);
        if (uri != null) {
          final source = sourceRegistry.resolve(uri);
          if (source != null) {
            final novel = await source.getMetadata(uri);
            bytes = novel.coverBytes;
            if (bytes == null &&
                novel.coverUrl != null &&
                imagePipeline != null) {
              final stored = await imagePipeline!.download(
                Uri.parse(novel.coverUrl!),
              );
              if (stored != null && await File(stored).exists()) {
                bytes = await File(stored).readAsBytes();
              }
            }
          }
        }
      }

      if (bytes == null || bytes.isEmpty) return null;
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Reads a local cover file if one exists (used to embed covers in EPUBs).
  Future<Uint8List?> _loadCoverBytes(BookEntity book) async {
    try {
      final coverPath = book.coverPath;
      if (coverPath == null || !await File(coverPath).exists()) return null;
      final bytes = await File(coverPath).readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  String? _chapterContentUrl(ChapterEntity chapter) {
    final indexFile = chapter.contentPath;
    if (indexFile.isEmpty) return null;
    final chapterIndexFile = File(
      p.join(p.dirname(indexFile), '.chapter_index.json'),
    );
    if (!chapterIndexFile.existsSync()) return null;
    try {
      final decoded = jsonDecode(chapterIndexFile.readAsStringSync());
      if (decoded is! List) return null;
      for (final raw in decoded.whereType<Map>()) {
        if (raw['index'] == chapter.index && raw['contentUrl'] is String) {
          return raw['contentUrl'] as String;
        }
      }
    } catch (_) {}
    return null;
  }

  String _chapterXhtml(String title, List<String> paragraphs) {
    final body = paragraphs.map((p) => '<p>${_escapeXml(p)}</p>').join('\n');
    return '<?xml version="1.0" encoding="utf-8"?>\n'
        '<html xmlns="http://www.w3.org/1999/xhtml">\n'
        '<head><title>${_escapeXml(title)}</title></head>\n'
        '<body>\n'
        '<h2>${_escapeXml(title)}</h2>\n'
        '$body\n'
        '</body>\n'
        '</html>';
  }

  String _ncxXml(
    String title,
    String? author,
    List<EpubNavigationPoint> points,
  ) {
    final items = <String>[];
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final label = _escapeXml(point.navigationLabels.first.text ?? '');
      final source = point.content!.source ?? '';
      items.add(
        '    <navPoint id="navPoint-${i + 1}" playOrder="${i + 1}">\n'
        '      <navLabel><text>$label</text></navLabel>\n'
        '      <content src="${_escapeXml(source)}"/>\n'
        '    </navPoint>',
      );
    }
    final authorBlock = author != null && author.isNotEmpty
        ? '\n  <docAuthor><text>${_escapeXml(author)}</text></docAuthor>'
        : '';
    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1" '
        'xml:lang="en">\n'
        '  <head>\n'
        '    <meta name="dtb:uid" content="atlas-export"/>\n'
        '    <meta name="dtb:depth" content="1"/>\n'
        '    <meta name="dtb:totalPageCount" content="0"/>\n'
        '    <meta name="dtb:maxPageNumber" content="0"/>\n'
        '  </head>\n'
        '  <docTitle><text>${_escapeXml(title)}</text></docTitle>'
        '$authorBlock\n'
        '  <navMap>\n'
        '${items.join('\n')}\n'
        '  </navMap>\n'
        '</ncx>';
  }

  List<String> _textToParagraphs(String text) {
    final paragraphs = text
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return paragraphs.isEmpty ? [text.trim()] : paragraphs;
  }

  String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _coverExtension(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    return 'jpg';
  }

  String _sanitizeFileName(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final result = cleaned.isEmpty ? 'novel' : cleaned;
    return result.length > 120 ? result.substring(0, 120) : result;
  }

  Failure<T> _toFailure<T>(Result<dynamic> result) {
    final error = result is Failure
        ? result.error
        : const DatabaseException('Operation failed');
    return Failure<T>(error);
  }
}
