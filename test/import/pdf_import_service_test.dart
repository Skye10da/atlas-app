import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/import/pdf_import_service.dart';

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
  late PdfImportService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_import_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
    db = AppDatabase.memory();
    service = PdfImportService(db);
  });

  tearDown(() async {
    await db.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('imports a PDF and stores the file verbatim', () async {
    const bytes = <int>[0x25, 0x50, 0x44, 0x46, 1, 2, 3]; // %PDF...
    final result = await service.importBytes(bytes, 'My Book.pdf');
    expect(result, isA<Success<String>>());

    final bookRow = await db.select(db.books).getSingle();
    expect(bookRow.title, 'My Book');
    expect(bookRow.format, 'pdf');
    expect(bookRow.itemType, 'book');
    expect(bookRow.totalChapters, 0);
    expect(bookRow.fileSize, bytes.length);
    expect(bookRow.coverPath, isNull);

    final pdfFile = File(p.join(bookRow.filePath, 'book.pdf'));
    expect(pdfFile.existsSync(), isTrue);
    expect(await pdfFile.readAsBytes(), bytes);
  });

  test('does not persist chapters or cover for an unparseable PDF', () async {
    // These bytes are not a valid PDF, so cover rendering and outline
    // extraction must fail gracefully instead of failing the import.
    const bytes = <int>[0x25, 0x50, 0x44, 0x46, 1, 2, 3];
    final result = await service.importBytes(bytes, 'Broken.pdf');
    expect(result, isA<Success<String>>());

    final bookRow = await db.select(db.books).getSingle();
    expect(bookRow.totalChapters, 0);
    expect(bookRow.coverPath, isNull);

    final chapterRows = await db.select(db.chapters).get();
    expect(chapterRows, isEmpty);
  });

  test('rejects a duplicate PDF import', () async {
    const bytes = <int>[0x25, 0x50, 0x44, 0x46];
    await service.importBytes(bytes, 'Dup.pdf');
    final result = await service.importBytes(bytes, 'Dup.pdf');
    expect(result, isA<Failure<void>>());
    expect(
      result,
      isA<Failure<void>>().having(
        (f) => f.error.code,
        'code',
        'DUPLICATE_BOOK',
      ),
    );
  });
}
