import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/infrastructure/services/annotations_storage_service.dart';

class BackupManifestSummary {
  const BackupManifestSummary({
    required this.version,
    required this.format,
    required this.exportedAt,
    required this.booksCount,
    required this.novelsCount,
    required this.chaptersCount,
    required this.readingProgressCount,
    required this.bookmarksCount,
    required this.wordsCount,
    required this.annotationsCount,
    required this.hasBundledFiles,
    this.totalFileSizeBytes,
  });

  final int version;
  final String format;
  final DateTime exportedAt;
  final int booksCount;
  final int novelsCount;
  final int chaptersCount;
  final int readingProgressCount;
  final int bookmarksCount;
  final int wordsCount;
  final int annotationsCount;
  final bool hasBundledFiles;
  final int? totalFileSizeBytes;

  int get totalItems => booksCount + novelsCount;
}

class BackupRestoreSummary {
  const BackupRestoreSummary({
    required this.booksRestored,
    this.novelsRestored = 0,
    this.chaptersRestored = 0,
    this.readingProgressRestored = 0,
    required this.bookmarksRestored,
    this.charactersRestored = 0,
    required this.wordsRestored,
    this.annotationsRestored = 0,
    this.sessionsRestored = 0,
    this.filesRestored = 0,
  });

  final int booksRestored;
  final int novelsRestored;
  final int chaptersRestored;
  final int readingProgressRestored;
  final int bookmarksRestored;
  final int charactersRestored;
  final int wordsRestored;
  final int annotationsRestored;
  final int sessionsRestored;
  final int filesRestored;

  int get totalBooks => booksRestored + novelsRestored;
}

final libraryBackupServiceProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  return LibraryBackupService(db);
});

class LibraryBackupService {
  const LibraryBackupService(
    this._db, {
    this.annotationsStorage = const AnnotationsStorageService(),
    this.getDocumentsDirectory = getApplicationDocumentsDirectory,
  });

  final AppDatabase _db;
  final AnnotationsStorageService annotationsStorage;
  final Future<Directory> Function() getDocumentsDirectory;

  /// Serializes all books, novels, chapters, reading progress with exact positions,
  /// bookmarks, vocabulary, analytics, and annotations into a structured JSON string.
  Future<String> exportBackupJson({
    bool includeAnalytics = true,
    bool includeAnnotations = true,
  }) async {
    final books = await _db.select(_db.books).get();
    final chapters = await _db.select(_db.chapters).get();
    final progressList = await _db.select(_db.readingProgress).get();
    final bookmarks = await _db.select(_db.bookmarks).get();
    final characters = await _db.select(_db.characters).get();
    final dictionaryWords = await _db.select(_db.dictionaryWords).get();
    final webBookmarks = await _db.select(_db.webBookmarks).get();

    // 1. Collect Reading Analytics
    List<Map<String, dynamic>> readingSessionsJson = [];
    List<Map<String, dynamic>> readingGoalsJson = [];
    if (includeAnalytics) {
      try {
        final sessions = await _db.customSelect('SELECT * FROM reading_sessions').get();
        readingSessionsJson = sessions.map((row) => row.data).toList();
      } catch (_) {}

      try {
        final goals = await _db.customSelect('SELECT * FROM reading_goals').get();
        readingGoalsJson = goals.map((row) => row.data).toList();
      } catch (_) {}
    }

    // 2. Collect Annotations per Book
    final Map<String, dynamic> annotationsJson = {};
    if (includeAnnotations) {
      for (final book in books) {
        try {
          final state = await annotationsStorage.loadAnnotations(book.id);
          if (state != null && (state.highlights.isNotEmpty || state.notes.isNotEmpty)) {
            annotationsJson[book.id] = {
              'highlights': {
                for (final e in state.highlights.entries)
                  e.key: e.value.map((h) => h.toJson()).toList(),
              },
              'notes': {
                for (final e in state.notes.entries)
                  e.key: e.value.map((n) => n.toJson()).toList(),
              },
            };
          }
        } catch (_) {}
      }
    }

    final backupMap = <String, dynamic>{
      'format': 'atlas_backup',
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'Atlas',
      'books': books.map((b) => {
        'id': b.id,
        'title': b.title,
        'author': b.author,
        'coverPath': b.coverPath,
        'format': b.format,
        'itemType': b.itemType,
        'fileSize': b.fileSize,
        'totalChapters': b.totalChapters,
        'description': b.description,
        'language': b.language,
        'tags': b.tags,
        'rating': b.rating,
        'status': b.status,
        'sourceUrl': b.sourceUrl,
        'sourceName': b.sourceName,
        'sourceId': b.sourceId,
        'filePath': b.filePath,
        'updateTrackingEnabled': b.updateTrackingEnabled,
        'lastCheckedAt': b.lastCheckedAt?.toIso8601String(),
        'newChapterCount': b.newChapterCount,
        'hasUpdate': b.hasUpdate,
        'createdAt': b.createdAt.toIso8601String(),
        'updatedAt': b.updatedAt.toIso8601String(),
        'lastOpenedAt': b.lastOpenedAt?.toIso8601String(),
      }).toList(),
      'chapters': chapters.map((c) => {
        'id': c.id,
        'bookId': c.bookId,
        'index': c.index,
        'title': c.title,
        'contentPath': c.contentPath,
        'wordCount': c.wordCount,
        'contentState': c.contentState,
        'pageCount': c.pageCount,
        'version': c.version,
        'checksum': c.checksum,
        'previousVersionRef': c.previousVersionRef,
        'createdAt': c.createdAt.toIso8601String(),
      }).toList(),
      'readingProgress': progressList.map((p) => {
        'id': p.id,
        'bookId': p.bookId,
        'chapterId': p.chapterId,
        'percentage': p.percentage,
        'position': p.position,
        'totalPositions': p.totalPositions,
        'readingTimeSeconds': p.readingTimeSeconds,
        'isCompleted': p.isCompleted,
        'lastReadAt': p.lastReadAt.toIso8601String(),
      }).toList(),
      'bookmarks': bookmarks.map((bm) => {
        'id': bm.id,
        'bookId': bm.bookId,
        'chapterId': bm.chapterId,
        'position': bm.position,
        'note': bm.note,
        'color': bm.color,
        'createdAt': bm.createdAt.toIso8601String(),
        'updatedAt': bm.updatedAt.toIso8601String(),
      }).toList(),
      'characters': characters.map((c) => {
        'id': c.id,
        'bookId': c.bookId,
        'name': c.name,
        'aliases': c.aliases,
        'description': c.description,
        'role': c.role,
        'firstAppearance': c.firstAppearance,
        'notes': c.notes,
        'createdAt': c.createdAt.toIso8601String(),
        'updatedAt': c.updatedAt.toIso8601String(),
      }).toList(),
      'dictionaryWords': dictionaryWords.map((dw) => {
        'id': dw.id,
        'word': dw.word,
        'definition': dw.definition,
        'language': dw.language,
        'languageLabel': dw.languageLabel,
        'source': dw.source,
        'sourceLabel': dw.sourceLabel,
        'phonetic': dw.phonetic,
        'partOfSpeech': dw.partOfSpeech,
        'fullJson': dw.fullJson,
        'sourceSentence': dw.sourceSentence,
        'sourceTitle': dw.sourceTitle,
        'reviewLevel': dw.reviewLevel,
        'reviewCount': dw.reviewCount,
        'lastReviewedAt': dw.lastReviewedAt?.toIso8601String(),
        'nextReviewAt': dw.nextReviewAt?.toIso8601String(),
        'savedAt': dw.savedAt.toIso8601String(),
      }).toList(),
      'webBookmarks': webBookmarks.map((wb) => {
        'id': wb.id,
        'url': wb.url,
        'title': wb.title,
        'createdAt': wb.createdAt.toIso8601String(),
      }).toList(),
      'readingSessions': readingSessionsJson,
      'readingGoals': readingGoalsJson,
      'annotations': annotationsJson,
    };

    return const JsonEncoder.withIndent('  ').convert(backupMap);
  }

  /// Exports a complete self-contained `.atlas` archive (ZIP) containing:
  /// - `backup.json`: full database metadata manifest
  /// - `covers/`: book & novel cover images
  /// - `books/`: local book files, epubs, pdfs, and downloaded novel chapters
  /// - `annotations/`: book annotation JSON files
  Future<List<int>> exportBackupArchive({
    bool includeFiles = true,
    bool includeOfflineChapters = true,
    bool includeAnalytics = true,
    bool includeAnnotations = true,
  }) async {
    final archive = Archive();

    // 1. Generate Metadata Manifest
    final jsonString = await exportBackupJson(
      includeAnalytics: includeAnalytics,
      includeAnnotations: includeAnnotations,
    );
    final jsonBytes = utf8.encode(jsonString);
    archive.addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes));

    if (!includeFiles) {
      return ZipEncoder().encode(archive);
    }

    final books = await _db.select(_db.books).get();
    final chapters = await _db.select(_db.chapters).get();

    // 2. Package Cover Images
    for (final book in books) {
      if (book.coverPath != null && book.coverPath!.isNotEmpty) {
        try {
          final coverFile = File(book.coverPath!);
          if (await coverFile.exists()) {
            final ext = p.extension(book.coverPath!).replaceAll('.', '');
            final coverExt = ext.isNotEmpty ? ext : 'jpg';
            final coverBytes = await coverFile.readAsBytes();
            archive.addFile(
              ArchiveFile(
                'covers/${book.id}.$coverExt',
                coverBytes.length,
                coverBytes,
              ),
            );
          }
        } catch (e) {
          AppLogger.warning('Failed to package cover for book ${book.id}: $e');
        }
      }
    }

    // 3. Package Local Book Files & Offline Chapters
    for (final book in books) {
      if (book.filePath.isNotEmpty) {
        try {
          final entity = FileSystemEntity.typeSync(book.filePath);
          if (entity == FileSystemEntityType.file) {
            final file = File(book.filePath);
            if (await file.exists()) {
              final fileName = p.basename(book.filePath);
              final bytes = await file.readAsBytes();
              archive.addFile(
                ArchiveFile(
                  'books/${book.id}/$fileName',
                  bytes.length,
                  bytes,
                ),
              );
            }
          } else if (entity == FileSystemEntityType.directory) {
            final dir = Directory(book.filePath);
            if (await dir.exists()) {
              await for (final child in dir.list(recursive: true)) {
                if (child is File) {
                  // Skip chapter txt files if user explicitly excluded offline cache
                  final isChapterTxt = child.path.endsWith('.txt');
                  if (isChapterTxt && !includeOfflineChapters) continue;

                  final relPath = p.relative(child.path, from: dir.path).replaceAll('\\', '/');
                  final bytes = await child.readAsBytes();
                  archive.addFile(
                    ArchiveFile(
                      'books/${book.id}/$relPath',
                      bytes.length,
                      bytes,
                    ),
                  );
                }
              }
            }
          }
        } catch (e) {
          AppLogger.warning('Failed to package book files for ${book.id}: $e');
        }
      }
    }

    // 4. Package Discovered/Downloaded Chapters from contentPath if outside book.filePath
    if (includeOfflineChapters) {
      for (final ch in chapters) {
        if (ch.contentPath.isNotEmpty) {
          try {
            final file = File(ch.contentPath);
            if (await file.exists() && await file.length() > 0) {
              final archivePath = 'chapters/${ch.bookId}/${p.basename(ch.contentPath)}';
              if (archive.findFile(archivePath) == null) {
                final bytes = await file.readAsBytes();
                archive.addFile(
                  ArchiveFile(
                    archivePath,
                    bytes.length,
                    bytes,
                  ),
                );
              }
            }
          } catch (_) {}
        }
      }
    }

    // 5. Package Annotations Files
    if (includeAnnotations) {
      for (final book in books) {
        try {
          final safeName = book.id.replaceAll(RegExp(r'[^\w\.-]'), '_');
          final dir = await getDocumentsDirectory();
          final annotFile = File(p.join(dir.path, 'annotations', 'annotations_$safeName.json'));
          if (await annotFile.exists()) {
            final bytes = await annotFile.readAsBytes();
            archive.addFile(
              ArchiveFile(
                'annotations/annotations_$safeName.json',
                bytes.length,
                bytes,
              ),
            );
          }
        } catch (_) {}
      }
    }

    return ZipEncoder().encode(archive);
  }

  /// Exports backup and prompts user to save it to a file.
  /// [isArchive]: true generates a self-contained `.atlas` package; false generates `.json`.
  Future<String?> exportBackupToFile({
    bool isArchive = true,
    bool includeOfflineChapters = true,
    bool includeAnalytics = true,
    bool includeAnnotations = true,
  }) async {
    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final ext = isArchive ? 'atlas' : 'json';
      final fileName = 'atlas_backup_$dateStr.$ext';

      // Generate data BEFORE showing the save dialog: on Android & iOS
      // FilePicker.saveFile requires `bytes` to write via MediaStore/SAF.
      final List<int> data = isArchive
          ? await exportBackupArchive(
              includeOfflineChapters: includeOfflineChapters,
              includeAnalytics: includeAnalytics,
              includeAnnotations: includeAnnotations,
            )
          : utf8.encode(
              await exportBackupJson(
                includeAnalytics: includeAnalytics,
                includeAnnotations: includeAnnotations,
              ),
            );

      final Uint8List fileBytes = Uint8List.fromList(data);

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Atlas Library Backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [ext],
        bytes: fileBytes,
      );

      if (outputPath == null) {
        final dir = await getDocumentsDirectory();
        final fallbackFile = File(p.join(dir.path, fileName));
        await fallbackFile.writeAsBytes(data);
        return fallbackFile.path;
      }

      // On desktop the picker returns a path without writing; on mobile
      // bytes are already written via SAF but File.write is safe to retry.
      try {
        final file = File(outputPath);
        final shouldWrite = !await file.exists() || await file.length() != data.length;
        if (shouldWrite) {
          await file.writeAsBytes(data);
        }
      } catch (_) {
        // Scoped-storage paths on Android may not be writable via File API;
        // bytes were already handled by the picker, so ignore.
      }
      return outputPath;
    } catch (e, st) {
      AppLogger.error('Export backup failed', e, st);
      return null;
    }
  }

  /// Inspects a backup file without modifying the database, returning a manifest summary.
  Future<Result<BackupManifestSummary>> inspectBackupBytes(
    List<int> bytes, {
    String? fileName,
  }) async {
    try {
      final isZip = bytes.length >= 4 &&
          bytes[0] == 0x50 &&
          bytes[1] == 0x4B &&
          (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07);

      Map<String, dynamic> decoded;
      bool hasBundledFiles = false;

      if (isZip) {
        final archive = ZipDecoder().decodeBytes(bytes);
        final manifestFile = archive.findFile('backup.json');
        if (manifestFile == null) {
          return const Failure(DatabaseException('Invalid Atlas archive: missing backup.json.'));
        }
        final rawContent = utf8.decode(manifestFile.content as List<int>);
        decoded = jsonDecode(rawContent) as Map<String, dynamic>;
        hasBundledFiles = archive.files.any((f) => f.name.startsWith('covers/') || f.name.startsWith('books/'));
      } else {
        final rawContent = utf8.decode(bytes);
        decoded = jsonDecode(rawContent) as Map<String, dynamic>;
      }

      if (decoded['format'] != 'atlas_backup') {
        return const Failure(DatabaseException('Unrecognized Atlas backup format.'));
      }

      final booksList = (decoded['books'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      final chaptersList = (decoded['chapters'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      final progressList = (decoded['readingProgress'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      final bookmarksList = (decoded['bookmarks'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      final wordsList = (decoded['dictionaryWords'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      final annotationsMap = decoded['annotations'] as Map<String, dynamic>? ?? {};

      int novelsCount = 0;
      int booksCount = 0;
      for (final b in booksList) {
        final itemType = b['itemType'] as String? ?? b['format'] as String? ?? 'book';
        if (itemType == 'novel' || b['format'] == 'novel') {
          novelsCount++;
        } else {
          booksCount++;
        }
      }

      final exportedAt = decoded['exportedAt'] != null
          ? DateTime.tryParse(decoded['exportedAt'] as String) ?? DateTime.now()
          : DateTime.now();

      return Success(
        BackupManifestSummary(
          version: (decoded['version'] as num?)?.toInt() ?? 1,
          format: isZip ? 'atlas_archive' : 'atlas_json',
          exportedAt: exportedAt,
          booksCount: booksCount,
          novelsCount: novelsCount,
          chaptersCount: chaptersList.length,
          readingProgressCount: progressList.length,
          bookmarksCount: bookmarksList.length,
          wordsCount: wordsList.length,
          annotationsCount: annotationsMap.length,
          hasBundledFiles: hasBundledFiles,
          totalFileSizeBytes: bytes.length,
        ),
      );
    } catch (e, st) {
      return Failure(DatabaseException('Failed to inspect backup: $e', e), st);
    }
  }

  /// Inspects a backup file from a filesystem path.
  Future<Result<BackupManifestSummary>> inspectBackupFile(File file) async {
    try {
      if (!await file.exists()) {
        return const Failure(DatabaseException('Backup file not found.'));
      }
      final bytes = await file.readAsBytes();
      return await inspectBackupBytes(bytes, fileName: file.path);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to read backup file: $e', e), st);
    }
  }

  /// Restores backup from raw bytes. Automatically detects whether [bytes] is
  /// an `.atlas` ZIP archive or a raw JSON string.
  /// If [cleanRestore] is true, deletes current library contents before restore.
  Future<Result<BackupRestoreSummary>> restoreBackupBytes(
    List<int> bytes, {
    String? fileName,
    bool cleanRestore = false,
  }) async {
    try {
      final isZip = bytes.length >= 4 &&
          bytes[0] == 0x50 &&
          bytes[1] == 0x4B &&
          (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07);

      if (isZip) {
        return await _restoreArchive(bytes, cleanRestore: cleanRestore);
      } else {
        final jsonString = utf8.decode(bytes);
        return await restoreBackupJson(jsonString, cleanRestore: cleanRestore);
      }
    } catch (e, st) {
      AppLogger.error('Restore backup bytes failed', e, st);
      return Failure(DatabaseException('Failed to restore backup: $e', e), st);
    }
  }

  /// Restores entities from an Atlas ZIP archive and extracts all bundled covers,
  /// book files, and offline chapters to local documents directory, re-anchoring paths.
  Future<Result<BackupRestoreSummary>> _restoreArchive(
    List<int> bytes, {
    bool cleanRestore = false,
  }) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final manifestFile = archive.findFile('backup.json');
      if (manifestFile == null) {
        return const Failure(DatabaseException('Invalid Atlas archive: missing backup.json.'));
      }

      final jsonString = utf8.decode(manifestFile.content as List<int>);
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic> || decoded['format'] != 'atlas_backup') {
        return const Failure(DatabaseException('Invalid Atlas backup format inside archive.'));
      }

      final docsDir = await getDocumentsDirectory();
      final Map<String, String> bookIdToCoverPath = {};
      final Map<String, String> bookIdToDirPath = {};
      final Map<String, String> chapterIdToContentPath = {};
      int filesRestored = 0;

      // 1. Extract Bundled Files and Build Re-anchor Mappings
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final name = file.name;
        final content = file.content as List<int>;

        if (name.startsWith('covers/')) {
          // covers/<bookId>.<ext>
          final coverBase = p.basename(name);
          final dotIdx = coverBase.indexOf('.');
          final bookId = dotIdx > 0 ? coverBase.substring(0, dotIdx) : coverBase;
          final targetPath = p.join(docsDir.path, 'books', bookId, coverBase);
          final targetFile = File(targetPath);
          await targetFile.parent.create(recursive: true);
          await targetFile.writeAsBytes(content);
          bookIdToCoverPath[bookId] = targetPath;
          filesRestored++;
        } else if (name.startsWith('books/')) {
          // books/<bookId>/<relPath>
          final pathWithoutPrefix = name.substring('books/'.length);
          final parts = pathWithoutPrefix.split('/');
          if (parts.isNotEmpty) {
            final bookId = parts.first;
            final targetPath = p.join(docsDir.path, 'books', pathWithoutPrefix);
            final targetFile = File(targetPath);
            await targetFile.parent.create(recursive: true);
            await targetFile.writeAsBytes(content);
            bookIdToDirPath[bookId] = p.join(docsDir.path, 'books', bookId);
            filesRestored++;
          }
        } else if (name.startsWith('chapters/')) {
          // chapters/<bookId>/<fileName>
          final pathWithoutPrefix = name.substring('chapters/'.length);
          final targetPath = p.join(docsDir.path, 'chapters', pathWithoutPrefix);
          final targetFile = File(targetPath);
          await targetFile.parent.create(recursive: true);
          await targetFile.writeAsBytes(content);
          final chapterFileName = p.basename(name);
          // e.g. "1.txt" or "book1_ch1.txt"
          chapterIdToContentPath[chapterFileName] = targetPath;
          filesRestored++;
        } else if (name.startsWith('annotations/')) {
          // annotations/annotations_<safeName>.json
          final fileName = p.basename(name);
          final targetPath = p.join(docsDir.path, 'annotations', fileName);
          final targetFile = File(targetPath);
          await targetFile.parent.create(recursive: true);
          await targetFile.writeAsBytes(content);
          filesRestored++;
        }
      }

      return await _restoreDatabase(
        decoded,
        cleanRestore: cleanRestore,
        reanchoredCovers: bookIdToCoverPath,
        reanchoredBookDirs: bookIdToDirPath,
        reanchoredChapters: chapterIdToContentPath,
        filesRestoredCount: filesRestored,
      );
    } catch (e, st) {
      AppLogger.error('Restore archive failed', e, st);
      return Failure(DatabaseException('Failed to restore archive: $e', e), st);
    }
  }

  /// Parses a JSON backup string and restores entities into the database.
  Future<Result<BackupRestoreSummary>> restoreBackupJson(
    String jsonString, {
    bool cleanRestore = false,
  }) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic> || decoded['format'] != 'atlas_backup') {
        return const Failure(DatabaseException('Invalid Atlas backup file format.'));
      }

      return await _restoreDatabase(decoded, cleanRestore: cleanRestore);
    } catch (e, st) {
      AppLogger.error('Restore backup JSON failed', e, st);
      return Failure(DatabaseException('Failed to restore backup: $e', e), st);
    }
  }

  /// Internal engine to restore database entities, map reading progress,
  /// re-anchor paths, and optionally restore annotations and analytics.
  Future<Result<BackupRestoreSummary>> _restoreDatabase(
    Map<String, dynamic> decoded, {
    bool cleanRestore = false,
    Map<String, String>? reanchoredCovers,
    Map<String, String>? reanchoredBookDirs,
    Map<String, String>? reanchoredChapters,
    int filesRestoredCount = 0,
  }) async {
    int restoredBooks = 0;
    int restoredNovels = 0;
    int restoredChapters = 0;
    int restoredProgress = 0;
    int restoredBookmarks = 0;
    int restoredCharacters = 0;
    int restoredWords = 0;
    int restoredAnnotations = 0;
    int restoredSessions = 0;

    final docsDir = await getDocumentsDirectory();

    await _db.transaction(() async {
      if (cleanRestore) {
        await _db.delete(_db.readingProgress).go();
        await _db.delete(_db.chapters).go();
        await _db.delete(_db.bookmarks).go();
        await _db.delete(_db.characters).go();
        await _db.delete(_db.books).go();
        try {
          await _db.customStatement('DELETE FROM reading_sessions');
          await _db.customStatement('DELETE FROM reading_goals');
        } catch (_) {}
      }

      // 1. Restore Books & Novels
      if (decoded['books'] is List) {
        for (final raw in (decoded['books'] as List).whereType<Map<String, dynamic>>()) {
          final id = raw['id'] as String?;
          final title = raw['title'] as String?;
          if (id == null || title == null) continue;

          final createdAt = raw['createdAt'] != null
              ? DateTime.tryParse(raw['createdAt'] as String) ?? DateTime.now()
              : DateTime.now();
          final updatedAt = raw['updatedAt'] != null
              ? DateTime.tryParse(raw['updatedAt'] as String) ?? createdAt
              : createdAt;
          final lastOpenedAt = raw['lastOpenedAt'] != null
              ? DateTime.tryParse(raw['lastOpenedAt'] as String)
              : null;
          final lastCheckedAt = raw['lastCheckedAt'] != null
              ? DateTime.tryParse(raw['lastCheckedAt'] as String)
              : null;

          final itemTypeRaw = raw['itemType'] as String? ?? raw['format'] as String? ?? 'book';
          final isNovel = itemTypeRaw == 'novel' || (raw['format'] as String?) == 'novel';
          final itemType = isNovel ? 'novel' : 'book';

          // Resolve coverPath: prioritize extracted archive cover, then fallback to local path
          String? coverPath = reanchoredCovers?[id] ?? raw['coverPath'] as String?;
          if (coverPath != null && !File(coverPath).existsSync()) {
            final defaultCover = p.join(docsDir.path, 'books', id, 'cover.jpg');
            if (File(defaultCover).existsSync()) {
              coverPath = defaultCover;
            }
          }

          // Resolve filePath: prioritize extracted archive book dir, then fallback to local path
          String filePath = reanchoredBookDirs?[id] ?? raw['filePath'] as String? ?? '';
          if (filePath.isEmpty || !Directory(filePath).existsSync()) {
            final defaultBookDir = p.join(docsDir.path, 'books', id);
            if (Directory(defaultBookDir).existsSync()) {
              filePath = defaultBookDir;
            }
          }

          final totalChapters = (raw['totalChapters'] as num?)?.toInt() ?? 0;
          final fileSize = (raw['fileSize'] as num?)?.toInt();
          final rating = (raw['rating'] as num?)?.toDouble();
          final newChapterCount = (raw['newChapterCount'] as num?)?.toInt() ?? 0;
          final hasUpdate = raw['hasUpdate'] as bool? ?? false;
          final updateTracking = raw['updateTrackingEnabled'] as bool? ?? true;

          await _db.into(_db.books).insertOnConflictUpdate(
            BooksCompanion(
              id: Value(id),
              title: Value(title),
              format: Value(raw['format'] as String? ?? (isNovel ? 'novel' : 'epub')),
              itemType: Value(itemType),
              filePath: Value(filePath),
              totalChapters: Value(totalChapters),
              fileSize: Value(fileSize),
              author: Value(raw['author'] as String?),
              coverPath: Value(coverPath),
              description: Value(raw['description'] as String?),
              language: Value(raw['language'] as String?),
              tags: Value(raw['tags'] as String?),
              rating: Value(rating),
              status: Value(raw['status'] as String?),
              sourceName: Value(raw['sourceName'] as String?),
              sourceId: Value(raw['sourceId'] as String?),
              sourceUrl: Value(raw['sourceUrl'] as String?),
              updateTrackingEnabled: Value(updateTracking),
              lastCheckedAt: Value(lastCheckedAt),
              newChapterCount: Value(newChapterCount),
              hasUpdate: Value(hasUpdate),
              createdAt: Value(createdAt),
              updatedAt: Value(updatedAt),
              lastOpenedAt: Value(lastOpenedAt),
            ),
          );

          if (isNovel) {
            restoredNovels++;
          } else {
            restoredBooks++;
          }
        }
      }

      // 2. Restore Chapters
      if (decoded['chapters'] is List) {
        for (final raw in (decoded['chapters'] as List).whereType<Map<String, dynamic>>()) {
          final id = raw['id'] as String?;
          final bookId = raw['bookId'] as String?;
          if (id == null || bookId == null) continue;

          final index = (raw['index'] as num?)?.toInt() ?? 0;
          final title = raw['title'] as String? ?? 'Chapter ${index + 1}';
          final wordCount = (raw['wordCount'] as num?)?.toInt() ?? 0;
          final pageCount = (raw['pageCount'] as num?)?.toInt() ?? 1;
          final contentState = (raw['contentState'] as num?)?.toInt() ?? 0;
          final version = (raw['version'] as num?)?.toInt() ?? 1;
          final checksum = raw['checksum'] as String?;
          final previousVersionRef = raw['previousVersionRef'] as String?;
          final createdAt = raw['createdAt'] != null
              ? DateTime.tryParse(raw['createdAt'] as String) ?? DateTime.now()
              : DateTime.now();

          // Re-anchor contentPath
          String contentPath = raw['contentPath'] as String? ?? '';
          final baseName = p.basename(contentPath);
          if (reanchoredChapters != null && reanchoredChapters.containsKey(baseName)) {
            contentPath = reanchoredChapters[baseName]!;
          } else {
            // Check if file exists in the standard docs book directory
            final standardPath = p.join(docsDir.path, 'books', bookId, '$index.txt');
            final idNamedPath = p.join(docsDir.path, 'books', bookId, '$id.txt');
            if (File(standardPath).existsSync()) {
              contentPath = standardPath;
            } else if (File(idNamedPath).existsSync()) {
              contentPath = idNamedPath;
            } else if (contentPath.isEmpty) {
              contentPath = standardPath;
            }
          }

          await _db.into(_db.chapters).insertOnConflictUpdate(
            ChaptersCompanion(
              id: Value(id),
              bookId: Value(bookId),
              index: Value(index),
              title: Value(title),
              contentPath: Value(contentPath),
              wordCount: Value(wordCount),
              pageCount: Value(pageCount),
              contentState: Value(contentState),
              version: Value(version),
              checksum: Value(checksum),
              previousVersionRef: Value(previousVersionRef),
              createdAt: Value(createdAt),
            ),
          );
          restoredChapters++;
        }
      }

      // 3. Restore Reading Progress & Position
      // Ensure primary key `id` matches `bookId` so DriftReaderRepository and AppDatabase
      // queries (which query by id == bookId) immediately discover the exact reading state.
      if (decoded['readingProgress'] is List) {
        for (final raw in (decoded['readingProgress'] as List).whereType<Map<String, dynamic>>()) {
          final bookId = raw['bookId'] as String?;
          if (bookId == null) continue;

          final chapterId = raw['chapterId'] as String? ?? '';
          final rawPercentage = (raw['percentage'] as num?)?.toDouble() ?? 0.0;
          // Normalize legacy 0..100 percentage if encountered
          final percentage = (rawPercentage > 1.0 ? rawPercentage / 100.0 : rawPercentage).clamp(0.0, 1.0);
          final position = (raw['position'] as num?)?.toInt() ?? 0;
          final totalPositions = (raw['totalPositions'] as num?)?.toInt() ?? 1;
          final readingTimeSeconds = (raw['readingTimeSeconds'] as num?)?.toInt() ?? 0;
          final isCompleted = raw['isCompleted'] as bool? ?? (percentage >= 0.95);
          final lastReadAt = raw['lastReadAt'] != null
              ? DateTime.tryParse(raw['lastReadAt'] as String) ?? DateTime.now()
              : DateTime.now();

          await _db.into(_db.readingProgress).insertOnConflictUpdate(
            ReadingProgressCompanion(
              id: Value(bookId),
              bookId: Value(bookId),
              chapterId: Value(chapterId),
              percentage: Value(percentage),
              position: Value(position),
              totalPositions: Value(totalPositions),
              lastReadAt: Value(lastReadAt),
              readingTimeSeconds: Value(readingTimeSeconds),
              isCompleted: Value(isCompleted),
            ),
          );
          restoredProgress++;
        }
      }

      // 4. Restore Bookmarks
      if (decoded['bookmarks'] is List) {
        for (final raw in (decoded['bookmarks'] as List).whereType<Map<String, dynamic>>()) {
          final id = raw['id'] as String?;
          final bookId = raw['bookId'] as String?;
          final chapterId = raw['chapterId'] as String?;
          if (id == null || bookId == null || chapterId == null) continue;

          final position = (raw['position'] as num?)?.toInt() ?? 0;
          final createdAt = raw['createdAt'] != null
              ? DateTime.tryParse(raw['createdAt'] as String) ?? DateTime.now()
              : DateTime.now();
          final updatedAt = raw['updatedAt'] != null
              ? DateTime.tryParse(raw['updatedAt'] as String) ?? createdAt
              : createdAt;

          await _db.into(_db.bookmarks).insertOnConflictUpdate(
            BookmarksCompanion(
              id: Value(id),
              bookId: Value(bookId),
              chapterId: Value(chapterId),
              position: Value(position),
              note: Value(raw['note'] as String?),
              color: Value(raw['color'] as String?),
              createdAt: Value(createdAt),
              updatedAt: Value(updatedAt),
            ),
          );
          restoredBookmarks++;
        }
      }

      // 5. Restore Characters
      if (decoded['characters'] is List) {
        for (final raw in (decoded['characters'] as List).whereType<Map<String, dynamic>>()) {
          final id = raw['id'] as String?;
          final bookId = raw['bookId'] as String?;
          final name = raw['name'] as String?;
          if (id == null || bookId == null || name == null) continue;

          final createdAt = raw['createdAt'] != null
              ? DateTime.tryParse(raw['createdAt'] as String) ?? DateTime.now()
              : DateTime.now();
          final updatedAt = raw['updatedAt'] != null
              ? DateTime.tryParse(raw['updatedAt'] as String) ?? createdAt
              : createdAt;

          await _db.into(_db.characters).insertOnConflictUpdate(
            CharactersCompanion(
              id: Value(id),
              bookId: Value(bookId),
              name: Value(name),
              aliases: Value(raw['aliases'] as String?),
              description: Value(raw['description'] as String?),
              role: Value(raw['role'] as String?),
              firstAppearance: Value(raw['firstAppearance'] as String?),
              notes: Value(raw['notes'] as String?),
              createdAt: Value(createdAt),
              updatedAt: Value(updatedAt),
            ),
          );
          restoredCharacters++;
        }
      }

      // 6. Restore Dictionary Words
      if (decoded['dictionaryWords'] is List) {
        for (final raw in (decoded['dictionaryWords'] as List).whereType<Map<String, dynamic>>()) {
          final id = raw['id'] as String?;
          final word = raw['word'] as String?;
          final def = raw['definition'] as String?;
          if (id == null || word == null || def == null) continue;

          final savedAt = raw['savedAt'] != null
              ? DateTime.tryParse(raw['savedAt'] as String) ?? DateTime.now()
              : DateTime.now();
          final lastReviewedAt = raw['lastReviewedAt'] != null
              ? DateTime.tryParse(raw['lastReviewedAt'] as String)
              : null;
          final nextReviewAt = raw['nextReviewAt'] != null
              ? DateTime.tryParse(raw['nextReviewAt'] as String)
              : null;

          await _db.into(_db.dictionaryWords).insertOnConflictUpdate(
            DictionaryWordsCompanion(
              id: Value(id),
              word: Value(word),
              definition: Value(def),
              language: Value(raw['language'] as String? ?? 'en'),
              languageLabel: Value(raw['languageLabel'] as String? ?? 'English'),
              source: Value(raw['source'] as String? ?? 'wiktionary'),
              sourceLabel: Value(raw['sourceLabel'] as String? ?? 'Wiktionary'),
              phonetic: Value(raw['phonetic'] as String?),
              partOfSpeech: Value(raw['partOfSpeech'] as String? ?? 'n'),
              fullJson: Value(raw['fullJson'] as String? ?? '{}'),
              savedAt: Value(savedAt),
              sourceSentence: Value(raw['sourceSentence'] as String?),
              sourceTitle: Value(raw['sourceTitle'] as String?),
              reviewLevel: Value((raw['reviewLevel'] as num?)?.toInt() ?? 0),
              reviewCount: Value((raw['reviewCount'] as num?)?.toInt() ?? 0),
              lastReviewedAt: Value(lastReviewedAt),
              nextReviewAt: Value(nextReviewAt),
            ),
          );
          restoredWords++;
        }
      }

      // 7. Restore Reading Analytics
      if (decoded['readingSessions'] is List) {
        for (final row in (decoded['readingSessions'] as List).whereType<Map<String, dynamic>>()) {
          final id = row['id']?.toString();
          final bookId = row['book_id']?.toString() ?? row['bookId']?.toString();
          final duration = (row['duration_seconds'] as num?)?.toInt() ?? (row['durationSeconds'] as num?)?.toInt() ?? 0;
          final chaptersRead = (row['chapters_read'] as num?)?.toInt() ?? (row['chaptersRead'] as num?)?.toInt() ?? 1;
          final createdAt = (row['created_at'] as num?)?.toInt() ?? (row['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
          final sessionDate = (row['session_date'] as num?)?.toInt() ?? (row['sessionDate'] as num?)?.toInt() ?? createdAt;
          if (id != null && bookId != null) {
            try {
              await _db.customStatement(
                '''
                INSERT OR REPLACE INTO reading_sessions (id, book_id, duration_seconds, chapters_read, created_at, session_date)
                VALUES (?, ?, ?, ?, ?, ?)
                ''',
                [id, bookId, duration, chaptersRead, createdAt, sessionDate],
              );
              restoredSessions++;
            } catch (_) {}
          }
        }
      }

      if (decoded['readingGoals'] is List) {
        for (final row in (decoded['readingGoals'] as List).whereType<Map<String, dynamic>>()) {
          final id = row['id']?.toString();
          final weeklyTarget = (row['weekly_chapter_target'] as num?)?.toInt() ?? (row['weeklyChapterTarget'] as num?)?.toInt() ?? 20;
          final dailyTarget = (row['daily_minute_target'] as num?)?.toInt() ?? (row['dailyMinuteTarget'] as num?)?.toInt() ?? 30;
          final updatedAt = (row['updated_at'] as num?)?.toInt() ?? (row['updatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
          if (id != null) {
            try {
              await _db.customStatement(
                '''
                INSERT OR REPLACE INTO reading_goals (id, weekly_chapter_target, daily_minute_target, updated_at)
                VALUES (?, ?, ?, ?)
                ''',
                [id, weeklyTarget, dailyTarget, updatedAt],
              );
            } catch (_) {}
          }
        }
      }

      // 8. Restore Annotations
      if (decoded['annotations'] is Map) {
        final rawAnnotations = decoded['annotations'] as Map<String, dynamic>;
        for (final entry in rawAnnotations.entries) {
          final bookId = entry.key;
          final bookData = entry.value as Map<String, dynamic>?;
          if (bookData == null) continue;

          final rawHighlights = bookData['highlights'] as Map<String, dynamic>? ?? {};
          final highlights = <String, List<HighlightEntry>>{};
          for (final hEntry in rawHighlights.entries) {
            final list = (hEntry.value as List<dynamic>?)
                    ?.map((e) => HighlightEntry.fromJson(e as Map<String, dynamic>))
                    .toList() ??
                const [];
            if (list.isNotEmpty) highlights[hEntry.key] = list;
          }

          final rawNotes = bookData['notes'] as Map<String, dynamic>? ?? {};
          final notes = <String, List<NoteEntry>>{};
          for (final nEntry in rawNotes.entries) {
            final list = (nEntry.value as List<dynamic>?)
                    ?.map((e) => NoteEntry.fromJson(e as Map<String, dynamic>))
                    .toList() ??
                const [];
            if (list.isNotEmpty) notes[nEntry.key] = list;
          }

          if (highlights.isNotEmpty || notes.isNotEmpty) {
            await annotationsStorage.saveAnnotations(
              bookId,
              ReaderAnnotationsState(highlights: highlights, notes: notes),
            );
            restoredAnnotations++;
          }
        }
      }
    });

    return Success(
      BackupRestoreSummary(
        booksRestored: restoredBooks,
        novelsRestored: restoredNovels,
        chaptersRestored: restoredChapters,
        readingProgressRestored: restoredProgress,
        bookmarksRestored: restoredBookmarks,
        charactersRestored: restoredCharacters,
        wordsRestored: restoredWords,
        annotationsRestored: restoredAnnotations,
        sessionsRestored: restoredSessions,
        filesRestored: filesRestoredCount,
      ),
    );
  }

  /// Prompts user to pick a backup file (.atlas, .zip, or .json) and restores it.
  /// On Android, .atlas has no system MIME mapping, so FileType.custom would
  /// hide it. We use FileType.any on Android to guarantee visibility and handle
  /// scoped-storage via withData/bytes.
  Future<Result<BackupRestoreSummary>> restoreBackupFromFile({
    bool cleanRestore = false,
  }) async {
    try {
      final isAndroid = !kIsWeb && Platform.isAndroid;
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Atlas Backup File',
        type: isAndroid ? FileType.any : FileType.custom,
        allowedExtensions: isAndroid ? null : ['atlas', 'zip', 'json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return const Failure(DatabaseException('No backup file selected.'));
      }

      final picked = result.files.single;
      List<int> bytes;
      String resolvedPath;
      if (picked.bytes != null) {
        bytes = picked.bytes!;
        resolvedPath = picked.path ?? picked.name;
      } else if (picked.path != null) {
        final file = File(picked.path!);
        bytes = await file.readAsBytes();
        resolvedPath = file.path;
      } else {
        return const Failure(DatabaseException('Unable to access selected file.'));
      }

      return await restoreBackupBytes(bytes, fileName: resolvedPath, cleanRestore: cleanRestore);
    } catch (e, st) {
      AppLogger.error('Restore from file failed', e, st);
      return Failure(DatabaseException('Failed to import backup file: $e', e), st);
    }
  }
}
