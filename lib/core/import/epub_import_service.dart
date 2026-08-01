import 'dart:io';

import 'package:drift/drift.dart';
import 'package:epub_plus/epub_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';

class EpubImportService {
  const EpubImportService(this._db);

  final AppDatabase _db;

  Future<Result<void>> pickAndImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
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

      return _importFromBytes(bytes, file.name);
    } on Exception catch (e) {
      return Failure(ValidationException('Failed to pick file: $e'));
    }
  }

  Future<Result<void>> _importFromBytes(List<int> bytes, String fileName) async {
    try {
      final book = await EpubReader.readBook(bytes);

      final title = book.title ?? fileName.replaceAll('.epub', '');
      final author = book.author ?? 'Unknown Author';
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

      String? coverPath;
      final manifest = book.schema?.package?.manifest;
      final items = manifest?.items ?? [];
      final metaItems = book.schema?.package?.metadata?.metaItems ?? [];

      EpubManifestItem? coverItem;
      for (final item in items) {
        if (item.id?.toLowerCase() == 'cover-image') {
          coverItem = item;
          break;
        }
      }
      if (coverItem == null) {
        for (final meta in metaItems) {
          if (meta.name?.toLowerCase() == 'cover' && meta.content != null) {
            final cid = meta.content!.toLowerCase();
            for (final item in items) {
              if (item.id?.toLowerCase() == cid) {
                coverItem = item;
                break;
              }
            }
            if (coverItem != null) break;
          }
        }
      }
      if (coverItem == null) {
        for (final item in items) {
          if ((item.properties ?? '').toLowerCase().contains('cover-image')) {
            coverItem = item;
            break;
          }
        }
      }
      if (coverItem?.href != null) {
        final href = coverItem!.href!;
        final imageFile = book.content?.images[href];
        if (imageFile?.content != null) {
          final ext = switch (coverItem.mediaType) {
            'image/jpeg' || 'image/jpg' => 'jpg',
            'image/png' => 'png',
            'image/gif' => 'gif',
            'image/webp' => 'webp',
            _ => 'jpg',
          };
          coverPath = p.join(bookDir.path, 'cover.$ext');
          await File(coverPath).writeAsBytes(imageFile!.content!);
        }
      }

      var chapterIndex = 0;
      final flatChapters = _flattenChapters(book.chapters);

      if (flatChapters.isNotEmpty) {
        for (final epubChapter in flatChapters) {
          final html = epubChapter.htmlContent;
          if (html == null) continue;

          final text = _stripHtml(html).trim();
          if (text.isEmpty) continue;

          final chTitle = epubChapter.title ?? 'Chapter ${chapterIndex + 1}';
          chapterIndex = await _writeChapter(bookId, bookDir, chTitle, text, chapterIndex);
        }
      }

      if (chapterIndex == 0) {
        final content = book.content;
        if (content != null) {
          for (final entry in content.html.entries) {
            final raw = entry.value.content;
            if (raw == null) continue;
            final text = _stripHtml(raw).trim();
            if (text.isEmpty) continue;
            chapterIndex = await _writeChapter(bookId, bookDir, 'Chapter ${chapterIndex + 1}', text, chapterIndex);
          }
        }
      }

      if (chapterIndex == 0) {
        return const Failure(ValidationException('No readable content found'));
      }

      await _db.into(_db.books).insert(BooksCompanion(
        id: Value(bookId),
        title: Value(title),
        author: Value(author),
        format: const Value('epub'),
        itemType: const Value('book'),
        filePath: Value(bookDir.path),
        totalChapters: Value(chapterIndex),
        coverPath: coverPath != null ? Value(coverPath) : const Value(null),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      return const Success(null);
    } on Exception catch (e) {
      return Failure(ValidationException('Failed to import epub: $e'));
    }
  }

  Future<int> _writeChapter(String bookId, Directory bookDir, String title, String text, int index) async {
    final chapterId = '${bookId}_ch$index';
    final contentPath = p.join(bookDir.path, '$chapterId.txt');
    await File(contentPath).writeAsString(text);
    await _db.into(_db.chapters).insert(ChaptersCompanion(
      id: Value(chapterId),
      bookId: Value(bookId),
      index: Value(index),
      title: Value(title),
      contentPath: Value(contentPath),
      wordCount: Value(text.split(RegExp(r'\s+')).length),
      pageCount: Value((text.length / 2000).ceil()),
      createdAt: Value(DateTime.now()),
    ));
    return index + 1;
  }

  List<EpubChapter> _flattenChapters(List<EpubChapter> chapters) {
    final flat = <EpubChapter>[];
    for (final ch in chapters) {
      flat.add(ch);
      flat.addAll(_flattenChapters(ch.subChapters));
    }
    return flat;
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<head>.*?</head>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<script.*?>.*?</script>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<style.*?>.*?</style>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeId(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }
}
