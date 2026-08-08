import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';

/// Imports PDF files into the library. Unlike EPUBs, PDFs are kept verbatim
/// (page rendering is handled by the reader via pdfx) instead of being
/// converted to text chapters, so the original file is stored on disk and a
/// lightweight `format = 'pdf'` book row is created.
class PdfImportService {
  const PdfImportService(this._db);

  final AppDatabase _db;

  /// Prompts the user to pick a PDF and imports it. Returns the imported book
  /// id, or `null` when the picker was cancelled (a success result).
  Future<Result<String?>> pickAndImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return const Success(null);
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        return const Failure(ValidationException('Could not read file'));
      }

      return importBytes(bytes, file.name);
    } on Exception catch (e) {
      return Failure(ValidationException('Failed to pick file: $e'));
    }
  }

  /// Imports a PDF from raw bytes. Public entry point so the pipeline can be
  /// exercised without the file picker. Resolves to the imported book id.
  Future<Result<String>> importBytes(List<int> bytes, String fileName) {
    return _importFromBytes(bytes, fileName);
  }

  Future<Result<String>> _importFromBytes(List<int> bytes, String fileName) async {
    try {
      final title = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      final bookId = _normalizeId(title);

      final existing = await (_db.select(_db.books)..where((b) => b.id.equals(bookId))).get();
      if (existing.isNotEmpty) {
        return const Failure(DuplicateBookException('Book already exists'));
      }

      final dir = await getApplicationDocumentsDirectory();
      final bookDir = Directory(p.join(dir.path, 'books', bookId));
      if (!await bookDir.exists()) {
        await bookDir.create(recursive: true);
      }

      final pdfPath = p.join(bookDir.path, 'book.pdf');
      await File(pdfPath).writeAsBytes(bytes);

      await _db.into(_db.books).insert(BooksCompanion(
        id: Value(bookId),
        title: Value(title),
        author: const Value(null),
        format: const Value('pdf'),
        itemType: const Value('book'),
        filePath: Value(bookDir.path),
        fileSize: Value(bytes.length),
        totalChapters: const Value(0),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      return Success(bookId);
    } on Exception catch (e) {
      return Failure(ValidationException('Failed to import PDF: $e'));
    }
  }

  String _normalizeId(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }
}
