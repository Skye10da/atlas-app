import 'dart:convert';
import 'dart:io';

import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_state.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';

class ChapterDownloadService {
  ChapterDownloadService({
    required this.sourceRegistry,
    required this.readerRepo,
    required this.db,
  });

  final SourceRegistry sourceRegistry;
  final DriftReaderRepository readerRepo;
  final AppDatabase db;

  Future<Result<void>> downloadChapter(String bookId, int chapterIndex) async {
    try {
      final bookResult = await readerRepo.getBookById(bookId);
      if (bookResult is! Success<BookEntity>) return bookResult;
      final book = bookResult.value;

      final source = _resolveSource(book);
      if (source == null) {
        return const Failure(DatabaseException('No source available for this book'));
      }

      final chapterModels = await _loadChapterModels(book);
      if (chapterIndex >= chapterModels.length) {
        return const Failure(DatabaseException('Chapter index out of range'));
      }

      final model = chapterModels[chapterIndex];
      final fetched = await source.getChapter(model);
      if (fetched.content == null) {
        return const Failure(DatabaseException('Source returned empty content'));
      }

      return readerRepo.updateChapterContent(bookId, chapterIndex, fetched.content!);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to download chapter', e), st);
    }
  }

  Future<List<Result<void>>> downloadAllChapters(String bookId, {void Function(int, int)? onProgress}) async {
    final chaptersResult = await readerRepo.getChapters(bookId);
    if (chaptersResult is! Success<List<ChapterEntity>>) return [chaptersResult];
    final chapters = chaptersResult.value;

    final results = <Result<void>>[];
    final total = chapters.length;
    int completed = 0;
    for (final ch in chapters) {
      if (ch.contentState == ContentState.availableOffline.index) {
        results.add(const Success(null));
        completed++;
        continue;
      }
      final result = await downloadChapter(bookId, ch.index);
      results.add(result);
      completed++;
      onProgress?.call(completed, total);
    }
    return results;
  }

  Future<bool> hasChapterIndex(String bookId) async {
    final bookResult = await readerRepo.getBookById(bookId);
    if (bookResult is! Success<BookEntity>) return false;
    final book = bookResult.value;
    if (book.filePath == null) return false;
    return File('${book.filePath}/.chapter_index.json').existsSync();
  }

  SourceAdapter? _resolveSource(BookEntity book) {
    if (book.sourceUrl == null) return null;
    final uri = Uri.tryParse(book.sourceUrl!);
    if (uri == null) return null;
    return sourceRegistry.resolve(uri);
  }

  Future<List<ChapterModel>> _loadChapterModels(BookEntity book) async {
    if (book.filePath == null) return [];
    final indexFile = File('${book.filePath}/.chapter_index.json');
    if (!await indexFile.exists()) return [];
    final json = await indexFile.readAsString();
    final decoded = jsonDecode(json);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((raw) {
      final id = raw['id'];
      final title = raw['title'];
      final index = raw['index'];
      final contentUrl = raw['contentUrl'];
      return ChapterModel(
        id: id is String ? id : '',
        title: title is String ? title : 'Untitled',
        index: index is num ? index.toInt() : 0,
        contentUrl: contentUrl is String ? contentUrl : null,
      );
    }).toList();
  }
}
