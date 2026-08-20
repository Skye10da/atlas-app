import 'dart:io';

import 'package:epub_plus/epub_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/import/epub_import_service.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.dir);

  final Directory dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;

  @override
  Future<String?> getApplicationSupportPath() async => '${dir.path}/support';
}

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late EpubImportService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('epub_import_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
    db = AppDatabase.memory();
    service = EpubImportService(db);
  });

  tearDown(() async {
    await db.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  /// Builds an EPUB3 whose nav item carries no `properties="nav"` — exactly
  /// what epub_plus's strict reader chokes on ("TOC item not found") and what
  /// older Atlas exports produced. The resilient importer must still handle it.
  List<int> brokenEpub3Bytes() {
    final chapters = <EpubChapter>[];
    final manifestItems = <EpubManifestItem>[];
    final spineItems = <EpubSpineItemRef>[];
    final navPoints = <EpubNavigationPoint>[];
    final html = <String, EpubTextContentFile>{};

    for (var i = 0; i < 2; i++) {
      final fileName = 'ch_${i + 1}.xhtml';
      final content =
          '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml">'
          '<head><title>Chapter ${i + 1}</title></head>'
          '<body><h2>Chapter ${i + 1}</h2><p>Body text ${i + 1}.</p></body></html>';
      html[fileName] = EpubTextContentFile(
        fileName: fileName,
        contentMimeType: 'application/xhtml+xml',
        content: content,
      );
      manifestItems.add(
        EpubManifestItem(
          id: 'ch_${i + 1}',
          href: fileName,
          mediaType: 'application/xhtml+xml',
        ),
      );
      spineItems.add(EpubSpineItemRef(idRef: 'ch_${i + 1}', isLinear: true));
      navPoints.add(
        EpubNavigationPoint(
          navigationLabels: [EpubNavigationLabel(text: 'Chapter ${i + 1}')],
          content: EpubNavigationContent(source: fileName),
        ),
      );
      chapters.add(
        EpubChapter(
          title: 'Chapter ${i + 1}',
          contentFileName: fileName,
          htmlContent: content,
        ),
      );
    }

    html['nav.xhtml'] = const EpubTextContentFile(
      fileName: 'nav.xhtml',
      contentMimeType: 'application/xhtml+xml',
      content:
          '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml">'
          '<head><title>Nav</title></head><body><nav><ol><li><a href="ch_1.xhtml">One</a></li></ol></nav></body></html>',
    );
    manifestItems.insert(
      0,
      const EpubManifestItem(
        id: 'nav',
        href: 'nav.xhtml',
        mediaType: 'application/xhtml+xml',
      ),
    );

    final book = EpubBook(
      title: 'Broken TOC',
      author: 'Author',
      authors: const ['Author'],
      schema: EpubSchema(
        contentDirectoryPath: 'OEBPS',
        package: EpubPackage(
          version: EpubVersion.epub3,
          metadata: const EpubMetadata(
            titles: ['Broken TOC'],
            creators: [EpubMetadataCreator(creator: 'Author', role: 'aut')],
          ),
          manifest: EpubManifest(items: manifestItems),
          spine: EpubSpine(
            tableOfContents: 'nav',
            items: spineItems,
            ltr: true,
          ),
          guide: const EpubGuide(),
        ),
        navigation: EpubNavigation(
          docTitle: const EpubNavigationDocTitle(titles: ['Broken TOC']),
          navMap: EpubNavigationMap(points: navPoints),
        ),
      ),
      content: EpubContent(html: html, allFiles: html),
      chapters: chapters,
    );

    return EpubWriter.writeBook(book)!;
  }

  test('imports an EPUB3 whose nav lacks properties="nav"', () async {
    final bytes = brokenEpub3Bytes();

    // Sanity: the strict reader cannot handle this file, so the fallback is real.
    expect(() => EpubReader.readBook(bytes), throwsException);

    final result = await service.importBytes(bytes, 'broken.epub');
    expect(result, isA<Success<String>>());

    final rows = await db.select(db.chapters).get();
    expect(rows.length, 2);
    expect(rows.map((r) => r.title), containsAll(['Chapter 1', 'Chapter 2']));

    final bookRow = await db.select(db.books).getSingle();
    expect(bookRow.title, 'Broken TOC');
    expect(bookRow.author, 'Author');
  });

  test('import populates metadata from dc-prefixed OPF elements', () async {
    const epub = EpubBook(
      title: 'Meta Book',
      author: 'Meta Author',
      authors: ['Meta Author'],
      schema: EpubSchema(
        contentDirectoryPath: 'OEBPS',
        package: EpubPackage(
          version: EpubVersion.epub3,
          metadata: EpubMetadata(
            titles: ['Meta Book'],
            creators: [
              EpubMetadataCreator(creator: 'Meta Author', role: 'aut'),
            ],
            description: 'Meta description.',
            subjects: ['Sci-fi', 'Drama'],
            sources: ['https://example.com/source'],
            languages: ['en'],
          ),
          manifest: EpubManifest(
            items: [
              EpubManifestItem(
                id: 'ch_1',
                href: 'ch_1.xhtml',
                mediaType: 'application/xhtml+xml',
              ),
            ],
          ),
          spine: EpubSpine(
            tableOfContents: 'nav',
            items: [EpubSpineItemRef(idRef: 'ch_1', isLinear: true)],
            ltr: true,
          ),
          guide: EpubGuide(),
        ),
        navigation: EpubNavigation(
          docTitle: EpubNavigationDocTitle(titles: ['Meta Book']),
          navMap: EpubNavigationMap(
            points: [
              EpubNavigationPoint(
                navigationLabels: [EpubNavigationLabel(text: 'One')],
                content: EpubNavigationContent(source: 'ch_1.xhtml'),
              ),
            ],
          ),
        ),
      ),
      content: EpubContent(
        html: {
          'ch_1.xhtml': EpubTextContentFile(
            fileName: 'ch_1.xhtml',
            contentMimeType: 'application/xhtml+xml',
            content:
                '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml">'
                '<head><title>One</title></head><body><p>Hello world.</p></body></html>',
          ),
        },
        allFiles: {
          'ch_1.xhtml': EpubTextContentFile(
            fileName: 'ch_1.xhtml',
            contentMimeType: 'application/xhtml+xml',
            content:
                '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml">'
                '<head><title>One</title></head><body><p>Hello world.</p></body></html>',
          ),
        },
      ),
    );

    final bytes = EpubWriter.writeBook(epub)!;
    final result = await service.importBytes(bytes, 'meta.epub');
    expect(result, isA<Success<String>>());

    final bookRow = await db.select(db.books).getSingle();
    expect(bookRow.title, 'Meta Book');
    expect(bookRow.author, 'Meta Author');
    expect(bookRow.description, 'Meta description.');
    expect(bookRow.language, 'en');
    expect(bookRow.tags, 'Sci-fi,Drama');
    expect(bookRow.sourceUrl, 'https://example.com/source');
  });
}
