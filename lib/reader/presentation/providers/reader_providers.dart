import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/session/session_refresh_service.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/reader/application/chapter_download_service.dart';
import 'package:atlas_app/reader/application/novel_export_service.dart';
import 'package:atlas_app/reader/domain/entities/bookmark_entity.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';

final readerRepositoryProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  return DriftReaderRepository(db);
});

/// The stages a chapter goes through while its shimmer is shown. The stages are
/// advanced by real work as content is fetched, read and prepared for display.
enum ChapterLoadPhase { gettingText, processing, preparing, done }

extension ChapterLoadPhaseX on ChapterLoadPhase {
  String get label => switch (this) {
    ChapterLoadPhase.gettingText => 'Getting text',
    ChapterLoadPhase.processing => 'Processing text',
    ChapterLoadPhase.preparing => 'Preparing reader',
    ChapterLoadPhase.done => 'Done',
  };
}

/// Publishes the current load stage for a chapter so its shimmer + status
/// overlay can reflect real backend progress.
final chapterLoadPhaseProvider =
    StateProvider.family<ChapterLoadPhase, ChapterEntity>(
      (ref, chapter) => ChapterLoadPhase.gettingText,
    );

final readerChapterContentProvider =
    FutureProvider.family<String, ChapterEntity>((ref, chapter) async {
  final repo = ref.watch(readerRepositoryProvider);
  void publish(ChapterLoadPhase phase) =>
      scheduleMicrotask(() {
        ref.read(chapterLoadPhaseProvider(chapter).notifier).state = phase;
      });

  publish(ChapterLoadPhase.gettingText);

  if (!File(chapter.contentPath).existsSync()) {
    final downloadService = ref.watch(chapterDownloadServiceProvider);
    final downloadResult = await _downloadChapterWithSessionRefresh(
      ref,
      chapter,
      downloadService,
    );
    if (downloadResult is Failure) {
      return downloadResult.error.userMessage;
    }
  }

  publish(ChapterLoadPhase.processing);
  final result = await repo.getChapterContent(chapter.contentPath);
  publish(ChapterLoadPhase.preparing);
  return switch (result) {
    Success(value: final content) => content,
    Failure() => 'Failed to load chapter content.',
  };
});

/// The book's source URL for a chapter's book — used to map a session-expired
/// failure (which latches an origin) back to the chapter being displayed.
final chapterSourceUrlProvider =
    FutureProvider.family<String?, ChapterEntity>((ref, chapter) async {
  final result = await ref
      .read(readerRepositoryProvider)
      .getBookById(chapter.bookId);
  if (result is! Success<BookEntity>) return null;
  return result.value.sourceUrl;
});

/// Downloads [chapter]'s content, and when the fetch failed on an expired
/// session, runs the quick re-verify flow once (per origin) and retries.
Future<Result<void>> _downloadChapterWithSessionRefresh(
  Ref ref,
  ChapterEntity chapter,
  ChapterDownloadService downloadService,
) async {
  final first = await downloadService.downloadChapter(
    chapter.bookId,
    chapter.index,
  );
  if (first is! Failure) return first;

  final session = SessionRefreshService.instance;
  final bookResult = await ref
      .read(readerRepositoryProvider)
      .getBookById(chapter.bookId);
  if (bookResult is! Success<BookEntity>) return first;
  final sourceUrl = bookResult.value.sourceUrl;
  final origin = SessionRefreshService.originOf(sourceUrl);
  final invalid = session.lastInvalidOrigin.value;
  if (origin == null ||
      invalid == null ||
      !SessionRefreshService.sameOrigin(invalid, origin)) {
    return first;
  }
  // One automatic re-verify per origin per cycle; a manual button remains
  // available in the chapter error state.
  if (session.hasAutoRefreshed(origin)) return first;
  session.markAutoRefreshed(origin);
  final seedUrl = Uri.tryParse(sourceUrl ?? '');
  final ok = await session.ensureFresh(origin, seedUrl: seedUrl);
  if (!ok) return first;
  return downloadService.downloadChapter(chapter.bookId, chapter.index);
}

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

final novelExportServiceProvider = Provider((ref) {
  final imagePipeline = ref.watch(imagePipelineProvider);
  return NovelExportService(
    readerRepo: ref.watch(readerRepositoryProvider),
    chapterDownloadService: ref.watch(chapterDownloadServiceProvider),
    sourceRegistry: ref.watch(sourceRegistryProvider),
    imagePipeline: imagePipeline,
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

final lastReadChapterProvider =
    FutureProvider.family<ChapterEntity?, String>((ref, bookId) async {
  final db = ref.watch(databaseProvider);
  final progress = await db.getReadingProgress(bookId);
  if (progress == null) return null;

  final chapters = await ref.watch(novelChaptersProvider(bookId).future);
  for (final chapter in chapters) {
    if (chapter.id == progress.chapterId) return chapter;
  }
  return null;
});
