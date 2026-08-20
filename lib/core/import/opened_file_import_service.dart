import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/import/epub_import_service.dart';
import 'package:atlas_app/core/import/pdf_import_service.dart';
import 'package:atlas_app/library/application/atlas_source_import_service.dart';

/// Imports a file the OS asked the app to open. Routes by extension onto the
/// existing importers so EPUBs/PDFs/Atlas packages opened out of the OS land
/// in the library and reader exactly as if picked in-app.
class OpenedFileImportService {
  const OpenedFileImportService({
    required this.epubService,
    required this.pdfService,
    required this.atlasService,
    required this.engine,
  });

  final EpubImportService epubService;
  final PdfImportService pdfService;
  final AtlasSourceImportService atlasService;
  final ContentAcquisitionEngine engine;

  Future<Result<ImportOutcome>> import(String path) async {
    final file = File(path);
    final fileName = p.basename(path);
    try {
      final bytes = await file.readAsBytes();
      final ext = p.extension(path).toLowerCase();
      final Result<ImportOutcome> result = switch (ext) {
        '.epub' => await _importEpub(bytes, fileName),
        '.pdf' => await _importPdf(bytes, fileName),
        '.atlas' => await _importAtlas(bytes),
        _ => const Failure(ValidationException('Unsupported file type')),
      };
      await _cleanupTempCopy(path);
      return result;
    } on Exception catch (e) {
      await _cleanupTempCopy(path);
      return Failure(ValidationException('Failed to read file: $e'));
    }
  }

  /// Removes the sandbox copy the OS dropped for an "Open with Atlas" open,
  /// both on success and failure (an orphaned copy is useless). See
  /// [shouldDeleteTempCopy]; documents the user picked on desktop are never
  /// touched.
  Future<void> _cleanupTempCopy(String path) async {
    if (!shouldDeleteTempCopy(path)) return;
    try {
      await File(path).delete();
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  /// Whether [path] is a temporary copy made by a native runner for us to
  /// import, rather than a file opened directly on desktop. iOS/macOS/Android
  /// runners copy the opened document into their caches named
  /// `opened_<timestamp>.<ext>`; on desktop the shell passes the document's
  /// original path, which is never a temp copy.
  ///
  /// Overridable so tests can exercise cleanup regardless of host platform.
  bool shouldDeleteTempCopy(String path) {
    final name = p.basename(path);
    if (!name.startsWith('opened_')) return false;
    return Platform.isIOS || Platform.isAndroid || Platform.isMacOS;
  }

  /// Routes in-memory [bytes] + [fileName] to the correct importer by
  /// extension.  Public entry point for callers who already have the file
  /// content in memory (e.g. the file-picker import sheet) so they don't
  /// need to write a temporary copy to disk first.
  Future<Result<ImportOutcome>> importBytes(
    List<int> bytes,
    String fileName,
  ) async {
    final ext = p.extension(fileName).toLowerCase();
    return switch (ext) {
      '.epub' => await _importEpub(bytes, fileName),
      '.pdf' => await _importPdf(bytes, fileName),
      '.atlas' => await _importAtlas(bytes),
      _ => const Failure(ValidationException('Unsupported file type')),
    };
  }

  Future<Result<ImportOutcome>> _importEpub(List<int> bytes, String fileName) async {
    final result = await epubService.importBytes(bytes, fileName);
    return switch (result) {
      Success(value: final bookId) => Success(
          ImportOutcome(bookId: bookId, category: ContentCategory.book)),
      Failure(error: final error) => Failure(error),
    };
  }

  Future<Result<ImportOutcome>> _importPdf(List<int> bytes, String fileName) async {
    final result = await pdfService.importBytes(bytes, fileName);
    return switch (result) {
      Success(value: final bookId) => Success(
          ImportOutcome(bookId: bookId, category: ContentCategory.book),
        ),
      Failure(error: final error) => Failure(error),
    };
  }

  Future<Result<ImportOutcome>> _importAtlas(List<int> bytes) async {
    final parsed = atlasService.parseSourceUrl(bytes);
    if (parsed is Failure<String?>) {
      return Failure(parsed.error);
    }
    final sourceUrl = (parsed as Success<String?>).value!;
    try {
      final outcome = await engine.importAndSave(sourceUrl);
      return Success(outcome);
    } on Exception catch (e) {
      return Failure(ValidationException('Failed to import Atlas package: $e'));
    }
  }
}