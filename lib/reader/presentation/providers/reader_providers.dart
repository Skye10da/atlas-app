import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/reader/application/chapter_download_service.dart';
import 'package:atlas_app/reader/domain/entities/bookmark_entity.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';

final readerRepositoryProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  return DriftReaderRepository(db);
});

final readerChapterContentProvider =
    FutureProvider.family<String, ChapterEntity>((ref, chapter) async {
  final repo = ref.watch(readerRepositoryProvider);

  if (!File(chapter.contentPath).existsSync()) {
    final downloadService = ref.watch(chapterDownloadServiceProvider);
    final downloadResult = await downloadService.downloadChapter(
      chapter.bookId,
      chapter.index,
    );
    if (downloadResult is Failure) {
      return 'Failed to load chapter content.';
    }
  }

  final result = await repo.getChapterContent(chapter.contentPath);
  return switch (result) {
    Success(value: final content) => content,
    Failure() => 'Failed to load chapter content.',
  };
});

final readerLoadingProvider = StateProvider<bool>((_) => false);

final bookmarksProvider =
    FutureProvider.family<List<BookmarkEntity>, String>((ref, bookId) async {
  final repo = ref.watch(readerRepositoryProvider);
  final result = await repo.getBookmarks(bookId);
  return switch (result) {
    Success(value: final bookmarks) => bookmarks,
    Failure() => <BookmarkEntity>[],
  };
});

final allBookmarksProvider =
    FutureProvider<List<BookmarkEntity>>((ref) async {
  final repo = ref.watch(readerRepositoryProvider);
  final result = await repo.getAllBookmarks();
  return switch (result) {
    Success(value: final bookmarks) => bookmarks,
    Failure() => <BookmarkEntity>[],
  };
});

final chapterDownloadServiceProvider = Provider((ref) {
  final registry = ref.watch(sourceRegistryProvider);
  final db = ref.watch(databaseProvider);
  final readerRepo = ref.watch(readerRepositoryProvider);
  return ChapterDownloadService(
    sourceRegistry: registry,
    readerRepo: readerRepo,
    db: db,
  );
});

final novelChaptersProvider =
    FutureProvider.family<List<ChapterEntity>, String>((ref, bookId) async {
  final repo = ref.watch(readerRepositoryProvider);
  final result = await repo.getChapters(bookId);
  return switch (result) {
    Success(value: final chapters) => chapters,
    Failure() => <ChapterEntity>[],
  };
});

final chapterDownloadingSetProvider = StateProvider<Set<String>>((ref) => {});
