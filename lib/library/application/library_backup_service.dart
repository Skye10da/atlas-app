import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/logging/logger.dart';

class BackupRestoreSummary {
  const BackupRestoreSummary({
    required this.booksRestored,
    required this.bookmarksRestored,
    required this.wordsRestored,
  });

  final int booksRestored;
  final int bookmarksRestored;
  final int wordsRestored;
}

final libraryBackupServiceProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  return LibraryBackupService(db);
});

class LibraryBackupService {
  const LibraryBackupService(this._db);

  final AppDatabase _db;

  /// Serializes all books, reading progress, bookmarks, and vocabulary into
  /// a formatted JSON string.
  Future<String> exportBackupJson() async {
    final books = await _db.select(_db.books).get();
    final progressList = await _db.select(_db.readingProgress).get();
    final bookmarks = await _db.select(_db.bookmarks).get();
    final dictionaryWords = await _db.select(_db.dictionaryWords).get();
    final webBookmarks = await _db.select(_db.webBookmarks).get();

    final backupMap = {
      'format': 'atlas_backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'books': books.map((b) => {
        'id': b.id,
        'title': b.title,
        'author': b.author,
        'coverPath': b.coverPath,
        'format': b.format,
        'totalChapters': b.totalChapters,
        'description': b.description,
        'sourceUrl': b.sourceUrl,
        'sourceName': b.sourceName,
        'sourceId': b.sourceId,
        'filePath': b.filePath,
        'createdAt': b.createdAt.toIso8601String(),
        'updatedAt': b.updatedAt.toIso8601String(),
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
      'dictionaryWords': dictionaryWords.map((dw) => {
        'id': dw.id,
        'word': dw.word,
        'definition': dw.definition,
        'language': dw.language,
        'languageLabel': dw.languageLabel,
        'partOfSpeech': dw.partOfSpeech,
        'fullJson': dw.fullJson,
        'sourceSentence': dw.sourceSentence,
        'sourceTitle': dw.sourceTitle,
        'savedAt': dw.savedAt.toIso8601String(),
      }).toList(),
      'webBookmarks': webBookmarks.map((wb) => {
        'id': wb.id,
        'url': wb.url,
        'title': wb.title,
        'createdAt': wb.createdAt.toIso8601String(),
      }).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(backupMap);
  }

  /// Exports backup and prompts user to save it to a file.
  Future<String?> exportBackupToFile() async {
    try {
      final jsonString = await exportBackupJson();
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'atlas_backup_$dateStr.json';

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Atlas Library Backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputPath == null) {
        final dir = await getApplicationDocumentsDirectory();
        final fallbackFile = File('${dir.path}/$fileName');
        await fallbackFile.writeAsString(jsonString);
        return fallbackFile.path;
      }

      final file = File(outputPath);
      await file.writeAsString(jsonString);
      return outputPath;
    } catch (e, st) {
      AppLogger.error('Export backup failed', e, st);
      return null;
    }
  }

  /// Parses a JSON backup string and restores entities into the database.
  Future<Result<BackupRestoreSummary>> restoreBackupJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic> || decoded['format'] != 'atlas_backup') {
        return const Failure(DatabaseException('Invalid Atlas backup file format.'));
      }

      int restoredBooks = 0;
      int restoredBookmarks = 0;
      int restoredWords = 0;

      await _db.transaction(() async {
        // 1. Restore Books
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
            final filePath = raw['filePath'] as String? ?? '';
            final totalChapters = (raw['totalChapters'] as num?)?.toInt() ?? 0;

            await _db.into(_db.books).insertOnConflictUpdate(
              BooksCompanion.insert(
                id: id,
                title: title,
                format: raw['format'] as String? ?? 'novel',
                filePath: filePath,
                totalChapters: totalChapters,
                createdAt: createdAt,
                updatedAt: updatedAt,
                author: Value(raw['author'] as String?),
                coverPath: Value(raw['coverPath'] as String?),
                description: Value(raw['description'] as String?),
                sourceUrl: Value(raw['sourceUrl'] as String?),
                sourceName: Value(raw['sourceName'] as String?),
                sourceId: Value(raw['sourceId'] as String?),
              ),
            );
            restoredBooks++;
          }
        }

        // 2. Restore Reading Progress
        if (decoded['readingProgress'] is List) {
          for (final raw in (decoded['readingProgress'] as List).whereType<Map<String, dynamic>>()) {
            final bookId = raw['bookId'] as String?;
            if (bookId == null) continue;
            final id = raw['id'] as String? ?? 'progress_$bookId';
            final chapterId = raw['chapterId'] as String? ?? '';
            final percentage = (raw['percentage'] as num?)?.toDouble() ?? 0.0;
            final position = (raw['position'] as num?)?.toInt() ?? 0;
            final totalPositions = (raw['totalPositions'] as num?)?.toInt() ?? 1;
            final readingTimeSeconds = (raw['readingTimeSeconds'] as num?)?.toInt() ?? 0;
            final isCompleted = raw['isCompleted'] as bool? ?? false;
            final lastReadAt = raw['lastReadAt'] != null
                ? DateTime.tryParse(raw['lastReadAt'] as String) ?? DateTime.now()
                : DateTime.now();

            await _db.into(_db.readingProgress).insertOnConflictUpdate(
              ReadingProgressCompanion.insert(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                percentage: percentage,
                position: position,
                totalPositions: totalPositions,
                lastReadAt: lastReadAt,
                readingTimeSeconds: readingTimeSeconds,
                isCompleted: Value(isCompleted),
              ),
            );
          }
        }

        // 3. Restore Bookmarks
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
              BookmarksCompanion.insert(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                position: position,
                note: Value(raw['note'] as String?),
                color: Value(raw['color'] as String?),
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
            );
            restoredBookmarks++;
          }
        }

        // 4. Restore Dictionary Words
        if (decoded['dictionaryWords'] is List) {
          for (final raw in (decoded['dictionaryWords'] as List).whereType<Map<String, dynamic>>()) {
            final id = raw['id'] as String?;
            final word = raw['word'] as String?;
            final def = raw['definition'] as String?;
            if (id == null || word == null || def == null) continue;
            final savedAt = raw['savedAt'] != null
                ? DateTime.tryParse(raw['savedAt'] as String) ?? DateTime.now()
                : DateTime.now();

            await _db.into(_db.dictionaryWords).insertOnConflictUpdate(
              DictionaryWordsCompanion.insert(
                id: id,
                word: word,
                definition: def,
                language: raw['language'] as String? ?? 'en',
                languageLabel: raw['languageLabel'] as String? ?? 'English',
                partOfSpeech: raw['partOfSpeech'] as String? ?? 'n',
                fullJson: raw['fullJson'] as String? ?? '{}',
                savedAt: savedAt,
                sourceSentence: Value(raw['sourceSentence'] as String?),
                sourceTitle: Value(raw['sourceTitle'] as String?),
              ),
            );
            restoredWords++;
          }
        }
      });

      return Success(
        BackupRestoreSummary(
          booksRestored: restoredBooks,
          bookmarksRestored: restoredBookmarks,
          wordsRestored: restoredWords,
        ),
      );
    } catch (e, st) {
      AppLogger.error('Restore backup failed', e, st);
      return Failure(DatabaseException('Failed to restore backup: $e', e), st);
    }
  }

  /// Prompts user to pick a JSON backup file and restores it.
  Future<Result<BackupRestoreSummary>> restoreBackupFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Atlas Backup File',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return const Failure(DatabaseException('No backup file selected.'));
      }

      final path = result.files.single.path;
      if (path == null) {
        return const Failure(DatabaseException('Unable to access selected file.'));
      }

      final file = File(path);
      final jsonString = await file.readAsString();
      return restoreBackupJson(jsonString);
    } catch (e, st) {
      AppLogger.error('Restore from file failed', e, st);
      return Failure(DatabaseException('Failed to import backup file: $e', e), st);
    }
  }
}

