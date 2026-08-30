import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/content_acquisition/utils/book_id_normalizer.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';

class TextChapterData {
  const TextChapterData({
    required this.title,
    required this.content,
  });

  final String title;
  final String content;
}

class TextImportService {
  const TextImportService(this._db);

  final AppDatabase _db;

  static final RegExp _chapterHeadingRegex = RegExp(
    r'^(?:'
    // English: Chapter 1, Ch. 1, Book 1, Section 1, Part 1, Act 1, Volume 1
    r'(?:chapter|ch\.|book|section|part|act|volume|vol\.)\s+([0-9ivxlcdm]+|[一二三四五六七八九十百千万]+)(?:[:\.\s\-–—]+(.*))?'
    r'|'
    // CJK: 第1章, 第一章, 第1回, 第1节, etc.
    r'(?:第)?\s*([0-9一二三四五六七八九十百千万]+)\s*(?:[章回节卷集幕篇部])(?:[:\.\s\-–—]+(.*))?'
    r'|'
    // Markdown headers: # Title, ## Title, ### Title
    r'(#{1,3})\s+(.+)'
    r'|'
    // Standard section names
    r'(prologue|epilogue|interlude|preface|foreword|introduction|afterword|appendix)'
    r')$',
    caseSensitive: false,
    multiLine: true,
  );

  /// Prompts user to pick a TXT or Markdown file and imports it.
  Future<Result<String?>> pickAndImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'text', 'md', 'markdown'],
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

  /// Extracts metadata and chapter count from raw bytes for import preview.
  Future<NovelModel> extractMetadata(List<int> bytes, String fileName) async {
    final text = _decodeBytes(bytes);
    final baseName = _stripExtension(fileName);
    final chapters = splitChapters(text, fallbackTitle: baseName);

    return NovelModel(
      sourceId: fileName,
      title: baseName,
      source: 'Text File',
      sourceUrl: '',
      category: ContentCategory.book,
      fileFormat: p.extension(fileName).replaceFirst('.', '').toLowerCase(),
      chapterCount: chapters.length,
    );
  }

  /// Imports a TXT/Markdown file from bytes, writes chapter files to disk,
  /// and persists book and chapter entries in SQLite.
  Future<Result<String>> importBytes(List<int> bytes, String fileName) async {
    try {
      final text = _decodeBytes(bytes);
      if (text.trim().isEmpty) {
        return const Failure(ValidationException('File contains no readable text'));
      }

      final baseName = _stripExtension(fileName);
      final bookId = BookIdNormalizer.normalize(baseName);

      final existing = await (_db.select(
        _db.books,
      )..where((b) => b.id.equals(bookId))).get();
      if (existing.isNotEmpty) {
        return const Failure(DuplicateBookException('Book already exists'));
      }

      final chapters = splitChapters(text, fallbackTitle: baseName);
      if (chapters.isEmpty) {
        return const Failure(ValidationException('No readable content found'));
      }

      final dir = await getApplicationDocumentsDirectory();
      final bookDir = Directory(p.join(dir.path, 'books', bookId));
      if (!await bookDir.exists()) {
        await bookDir.create(recursive: true);
      }

      final ext = p.extension(fileName).toLowerCase();
      final format = (ext == '.md' || ext == '.markdown') ? 'md' : 'txt';

      // Concurrently write chapter files to disk
      final chapterPaths = <String>[];
      final writeFutures = <Future<void>>[];
      for (var i = 0; i < chapters.length; i++) {
        final chPath = p.join(bookDir.path, 'chapter_$i.$format');
        chapterPaths.add(chPath);
        writeFutures.add(File(chPath).writeAsString(chapters[i].content));
      }
      await Future.wait(writeFutures);

      // Insert chapter records into database
      await _db.batch((batch) {
        for (var i = 0; i < chapters.length; i++) {
          final ch = chapters[i];
          final words = ch.content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
          batch.insert(
            _db.chapters,
            ChaptersCompanion(
              id: Value('${bookId}_ch_$i'),
              bookId: Value(bookId),
              index: Value(i),
              title: Value(ch.title),
              contentPath: Value(chapterPaths[i]),
              contentState: const Value(2), // ContentState.availableOffline.index
              wordCount: Value(words),
              pageCount: Value(max(1, (ch.content.length / 2000).ceil())),
              version: const Value(1),
              createdAt: Value(DateTime.now()),
            ),
          );
        }
      });

      // Insert book record
      await _db.into(_db.books).insert(
        BooksCompanion(
          id: Value(bookId),
          title: Value(baseName),
          format: Value(format),
          itemType: const Value('book'),
          filePath: Value(bookDir.path),
          totalChapters: Value(chapters.length),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      return Success(bookId);
    } on Exception catch (e) {
      return Failure(ValidationException('Failed to import text file: $e'));
    }
  }

  /// Parses and splits [rawText] into chapters using regex pattern detection
  /// or word-budget chunking.
  static List<TextChapterData> splitChapters(
    String rawText, {
    String fallbackTitle = 'Chapter 1',
  }) {
    final text = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final matches = _chapterHeadingRegex.allMatches(text).toList();

    // If at least 2 chapter headings are found, split based on headers
    if (matches.length >= 2) {
      final chapters = <TextChapterData>[];

      // Any text prior to the first heading is treated as Prologue/Introduction
      final firstStart = matches[0].start;
      if (firstStart > 0) {
        final preText = text.substring(0, firstStart).trim();
        if (preText.isNotEmpty) {
          chapters.add(
            TextChapterData(
              title: 'Introduction',
              content: preText,
            ),
          );
        }
      }

      for (var i = 0; i < matches.length; i++) {
        final m = matches[i];
        final headerLine = text.substring(m.start, m.end).trim();
        final cleanTitle = _cleanHeaderTitle(headerLine);

        final contentStart = m.end;
        final contentEnd = i + 1 < matches.length ? matches[i + 1].start : text.length;
        final chapterContent = text.substring(contentStart, contentEnd).trim();

        chapters.add(
          TextChapterData(
            title: cleanTitle.isNotEmpty ? cleanTitle : 'Chapter ${chapters.length + 1}',
            content: chapterContent.isNotEmpty ? chapterContent : headerLine,
          ),
        );
      }

      if (chapters.isNotEmpty) {
        return chapters;
      }
    }

    // Fallback: If text is under ~15,000 chars (~2,500 words), keep as single chapter
    const targetChunkChars = 14000;
    if (text.length <= targetChunkChars) {
      return [
        TextChapterData(
          title: fallbackTitle,
          content: text.trim(),
        ),
      ];
    }

    // Chunk longer unstructured text by paragraph boundaries
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    final chapters = <TextChapterData>[];
    var currentChunk = StringBuffer();
    var currentLength = 0;
    var chapterIndex = 1;

    for (final p in paragraphs) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) continue;

      if (currentLength > 0 && currentLength + trimmed.length > targetChunkChars) {
        chapters.add(
          TextChapterData(
            title: 'Chapter $chapterIndex',
            content: currentChunk.toString().trim(),
          ),
        );
        chapterIndex++;
        currentChunk = StringBuffer();
        currentLength = 0;
      }

      if (currentChunk.isNotEmpty) {
        currentChunk.write('\n\n');
      }
      currentChunk.write(trimmed);
      currentLength += trimmed.length;
    }

    if (currentChunk.isNotEmpty) {
      chapters.add(
        TextChapterData(
          title: 'Chapter $chapterIndex',
          content: currentChunk.toString().trim(),
        ),
      );
    }

    return chapters;
  }

  static String _cleanHeaderTitle(String header) {
    var cleaned = header.trim();
    // Strip markdown # prefix
    while (cleaned.startsWith('#')) {
      cleaned = cleaned.substring(1).trim();
    }
    return cleaned;
  }

  static String _stripExtension(String fileName) {
    return fileName.replaceAll(
      RegExp(r'\.(txt|text|md|markdown)$', caseSensitive: false),
      '',
    );
  }

  static String _decodeBytes(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }
}

