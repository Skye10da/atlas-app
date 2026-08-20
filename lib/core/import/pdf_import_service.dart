import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';

/// Imports PDF files into the library. Unlike EPUBs, PDFs are kept verbatim
/// (page rendering is handled by the reader via pdfrx) instead of being
/// decoded to text chapters, so the original file is stored on disk and a
/// lightweight `format = 'pdf'` book row is created.
///
/// As a bonus the first page is rendered to `cover.png` (used by the library
/// UI) and the document outline (`loadOutline`) is persisted as chapter rows so
/// the book details screen can list chapters. Any failure during rendering or
/// outline extraction is silently ignored — the import still succeeds with
/// `coverPath`/`totalChapters` including whatever managed to be extracted.
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

  /// Extracts metadata from PDF bytes without importing.
  /// Used by the import sheet to show a preview before the user confirms.
  Future<NovelModel> extractMetadata(List<int> bytes, String fileName) async {
    final title =
        fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');

    // Best-effort cover render from first page
    Uint8List? coverBytes;
    try {
      if (!kIsWeb) await pdfrxFlutterInitialize();
      // Write to temp file, render first page, read bytes back
      final tmpDir = await getTemporaryDirectory();
      final tmpPath = p.join(tmpDir.path, 'atlas_pdf_preview_$fileName');
      await File(tmpPath).writeAsBytes(bytes);
      try {
        final doc = await PdfDocument.openFile(tmpPath);
        try {
          if (doc.pages.isNotEmpty) {
            final page = doc.pages.first;
            const targetWidth = 360.0;
            final ratio = page.height / page.width;
            final pdfImage = await page.render(
              fullWidth: targetWidth,
              fullHeight: targetWidth * ratio,
            );
            if (pdfImage != null) {
              final image = await pdfImage.createImage(pixelSizeThreshold: 360);
              try {
                final byteData =
                    await image.toByteData(format: ui.ImageByteFormat.png);
                if (byteData != null) {
                  coverBytes = byteData.buffer.asUint8List();
                }
              } finally {
                image.dispose();
              }
            }
          }
        } finally {
          await doc.dispose();
        }
      } finally {
        try {
          await File(tmpPath).delete();
        } catch (_) {}
      }
    } catch (_) {}

    return NovelModel(
      sourceId: fileName,
      title: title,
      source: 'PDF File',
      sourceUrl: '',
      category: ContentCategory.book,
      fileFormat: 'pdf',
      coverBytes: coverBytes,
    );
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

      String? cover;
      var chapters = <_PdfChapter>[];
      try {
        if (!kIsWeb) await pdfrxFlutterInitialize();
        cover = await _extractCover(bookDir: bookDir, pdfPath: pdfPath);
        chapters = await _loadPdfChapters(pdfPath);
      } catch (_) {
        // Rendering/parsing is best-effort; never fail the import because of it.
      }

      final bookCompanion = BooksCompanion(
        id: Value(bookId),
        title: Value(title),
        author: const Value(null),
        format: const Value('pdf'),
        itemType: const Value('book'),
        filePath: Value(bookDir.path),
        fileSize: Value(bytes.length),
        totalChapters: Value(chapters.length),
        coverPath: cover != null ? Value(cover) : const Value(null),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      );
      await _db.into(_db.books).insert(bookCompanion);

      await _db.batch((batch) {
        for (final (index, chapter) in chapters.indexed) {
          final chapterId = '${bookId}_ch$index';
          batch.insert(_db.chapters, ChaptersCompanion(
            id: Value(chapterId),
            bookId: Value(bookId),
            index: Value(index),
            title: Value(chapter.title),
            contentPath: Value(pdfPath),
            wordCount: const Value(0),
            pageCount: Value(chapter.pageNumber),
            createdAt: Value(DateTime.now()),
          ));
        }
      });

      return Success(bookId);
    } on Exception catch (e) {
      return Failure(ValidationException('Failed to import PDF: $e'));
    }
  }

  /// Renders the first page of the PDF to `cover.png` in the book directory,
  /// returning the absolute cover path (or `null` if rendering is skipped).
  ///
  /// Best-effort: callers wrap this in a try/catch so a protected/corrupt PDF
  /// never blocks the import.
  Future<String?> _extractCover({
    required Directory bookDir,
    required String pdfPath,
  }) async {
    if (kIsWeb) return null;
    final doc = await PdfDocument.openFile(pdfPath);
    try {
      if (doc.pages.isEmpty) return null;
      final page = doc.pages.first;
      // ~360px wide keeps cover images small but crisp enough for the grid.
      const targetWidth = 360.0;
      final ratio = page.height / page.width;
      final pdfImage = await page.render(
        fullWidth: targetWidth,
        fullHeight: targetWidth * ratio,
      );
      if (pdfImage == null) return null;
      final image = await pdfImage.createImage(pixelSizeThreshold: 360);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return null;
        final coverPath = p.join(bookDir.path, 'cover.png');
        await File(coverPath).writeAsBytes(byteData.buffer.asUint8List());
        return coverPath;
      } finally {
        image.dispose();
      }
    } finally {
      await doc.dispose();
    }
  }

  /// Extracts the PDF outline as chapter-ish rows (title + destination page).
  ///
  /// Best-effort: PDFs without an outline fall back to page-range chapters
  /// (`['Page 1']` .. `['Page 11–20']`, 10 pages per group) so the details
  /// screen still shows a navigable chapter list. Returns an empty list when
  /// the document can't be opened or is password-protected.
  Future<List<_PdfChapter>> _loadPdfChapters(String pdfPath) async {
    if (kIsWeb) return const [];
    final doc = await PdfDocument.openFile(pdfPath);
    List<_PdfChapter> result;
    try {
      final outline = await doc.loadOutline();
      final flatten = <_PdfChapter>[];
      void visit(List<PdfOutlineNode> nodes) {
        for (final node in nodes) {
          final page = node.dest?.pageNumber;
          if (node.title.trim().isNotEmpty) {
            flatten.add(_PdfChapter(
              title: node.title.trim(),
              pageNumber: page ?? (flatten.isEmpty ? 1 : flatten.last.pageNumber),
            ));
          }
          if (node.children.isNotEmpty) visit(node.children);
        }
      }

      visit(outline);

      if (flatten.isNotEmpty) {
        result = flatten;
      } else {
        result = _pageRangeChapters(doc.pages.length);
      }
    } catch (_) {
      result = const [];
    } finally {
      await doc.dispose();
    }
    return result;
  }

  /// Builds pseudo-chapters covering sequential page ranges (10 pages each)
  /// for PDFs that don't have an outline.
  List<_PdfChapter> _pageRangeChapters(int totalPages) {
    if (totalPages <= 0) return const [];
    const groupSize = 10;
    final chapters = <_PdfChapter>[];
    for (var start = 1; start <= totalPages; start += groupSize) {
      final end = math.min(start + groupSize - 1, totalPages);
      chapters.add(_PdfChapter(
        title: start == end ? 'Page $start' : 'Pages $start–$end',
        pageNumber: start,
      ));
    }
    return chapters;
  }

  String _normalizeId(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }
}

/// Lightweight chapter record derived from a PDF outline (or page ranges).
class _PdfChapter {
  const _PdfChapter({required this.title, required this.pageNumber});

  final String title;

  /// 1-based PDF page the chapter (range) starts at.
  final int pageNumber;
}
