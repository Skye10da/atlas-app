import 'dart:io';

import 'package:epub_plus/epub_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/import/epub_import_service.dart';
import 'package:atlas_app/core/import/opened_file_import_service.dart';
import 'package:atlas_app/core/import/pdf_import_service.dart';
import 'package:atlas_app/library/application/atlas_source_import_service.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.dir);

  final Directory dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;

  @override
  Future<String?> getApplicationSupportPath() async => '${dir.path}/support';
}

/// Simulates a mobile/Apple runner: copies are named `opened_*`, anything else
/// is a user-opened file that must survive the import.
class _SimulatedMobileImporter extends OpenedFileImportService {
  _SimulatedMobileImporter({
    required super.epubService,
    required super.pdfService,
    required super.atlasService,
    required super.engine,
  });

  @override
  bool shouldDeleteTempCopy(String path) =>
      p.basename(path).startsWith('opened_');
}

/// Builds a minimal but importable EPUB3 (same recipe as the epub import
/// tests, including a TOC the strict reader chokes on — exactly what the
/// resilient fallback handles).
List<int> epubBytes() {
  final chapters = <EpubChapter>[];
  final manifestItems = <EpubManifestItem>[];
  final spineItems = <EpubSpineItemRef>[];
  final navPoints = <EpubNavigationPoint>[];
  final html = <String, EpubTextContentFile>{};

  for (var i = 0; i < 2; i++) {
    final fileName = 'ch_${i + 1}.xhtml';
    final content = '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml">'
        '<head><title>Chapter ${i + 1}</title></head>'
        '<body><h2>Chapter ${i + 1}</h2><p>Body text ${i + 1}.</p></body></html>';
    html[fileName] = EpubTextContentFile(
      fileName: fileName,
      contentMimeType: 'application/xhtml+xml',
      content: content,
    );
    manifestItems.add(
      EpubManifestItem(id: 'ch_${i + 1}', href: fileName, mediaType: 'application/xhtml+xml'),
    );
    spineItems.add(
      EpubSpineItemRef(idRef: 'ch_${i + 1}', isLinear: true),
    );
    navPoints.add(
      EpubNavigationPoint(
        navigationLabels: [EpubNavigationLabel(text: 'Chapter ${i + 1}')],
        content: EpubNavigationContent(source: fileName),
      ),
    );
    chapters.add(
      EpubChapter(title: 'Chapter ${i + 1}', contentFileName: fileName, htmlContent: content),
    );
  }

  html['nav.xhtml'] = const EpubTextContentFile(
    fileName: 'nav.xhtml',
    contentMimeType: 'application/xhtml+xml',
    content: '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml">'
        '<head><title>Nav</title></head><body><nav><ol><li><a href="ch_1.xhtml">One</a></li></ol></nav></body></html>',
  );
  manifestItems.insert(
    0,
    const EpubManifestItem(id: 'nav', href: 'nav.xhtml', mediaType: 'application/xhtml+xml'),
  );

  final book = EpubBook(
    title: 'Opened Test',
    author: 'Author',
    authors: const ['Author'],
    schema: EpubSchema(
      contentDirectoryPath: 'OEBPS',
      package: EpubPackage(
        version: EpubVersion.epub3,
        metadata: const EpubMetadata(
          titles: ['Opened Test'],
          creators: [EpubMetadataCreator(creator: 'Author', role: 'aut')],
        ),
        manifest: EpubManifest(items: manifestItems),
        spine: EpubSpine(tableOfContents: 'nav', items: spineItems, ltr: true),
        guide: const EpubGuide(),
      ),
      navigation: EpubNavigation(
        docTitle: const EpubNavigationDocTitle(titles: ['Opened Test']),
        navMap: EpubNavigationMap(points: navPoints),
      ),
    ),
    content: EpubContent(html: html, allFiles: html),
    chapters: chapters,
  );

  return EpubWriter.writeBook(book)!;
}

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late _SimulatedMobileImporter importer;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opened_file_import_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
    db = AppDatabase.memory();
    importer = _SimulatedMobileImporter(
      epubService: EpubImportService(db),
      pdfService: PdfImportService(db),
      atlasService: const AtlasSourceImportService(),
      engine: ContentAcquisitionEngine(registry: SourceRegistry(), db: db),
    );
  });

  tearDown(() async {
    await db.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  File writeTempFile(String name, [List<int>? bytes]) {
    final file = File(p.join(tempDir.path, name));
    file.writeAsBytesSync(bytes ?? epubBytes());
    return file;
  }

  test('removes the sandbox temp copy after a successful import', () async {
    final opened = writeTempFile('opened_123.epub');
    final result = await importer.import(opened.path);
    expect(result, isA<Success>());
    expect(opened.existsSync(), isFalse);
  });

  test('removes a sandbox temp copy even when the import fails', () async {
    final opened = writeTempFile('opened_456.xyz', [1, 2, 3]);
    final result = await importer.import(opened.path);
    expect(result, isA<Failure>());
    expect(opened.existsSync(), isFalse);
  });

  test('never deletes documents the user opened directly (desktop)', () async {
    final book = writeTempFile('my_favourite.epub');
    final result = await importer.import(book.path);
    expect(result, isA<Success>());
    expect(book.existsSync(), isTrue);
  });

  test('imports a PDF opened on desktop with format pdf and a stored file', () async {
    final opened = writeTempFile(
      'guide.pdf',
      [
        0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, // %PDF-1.4
      ],
    );
    final result = await importer.import(opened.path);
    expect(result, isA<Success<ImportOutcome>>());
    final bookId = (result as Success<ImportOutcome>).value.bookId;
    expect(bookId, 'guide');

    final row = await (db.select(db.books)..where((b) => b.id.equals(bookId))).getSingleOrNull();
    expect(row, isNotNull, reason: 'PDF book row was created');
    expect(row!.format, 'pdf');
    expect(row.filePath, isNotEmpty);
    expect(row.totalChapters, 0);

    final stored = File(p.join(row.filePath, 'book.pdf'));
    expect(stored.existsSync(), isTrue, reason: 'verbatim PDF kept on disk');
    expect(opened.existsSync(), isTrue, reason: 'desktop originals are never deleted');
  });
}