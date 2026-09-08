import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_detector.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/reader/application/chapter_download_service.dart';
import 'package:atlas_app/reader/application/novel_export_service.dart';
import 'package:atlas_app/reader/domain/entities/bookmark_entity.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/services/atlas_glossary_applier.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';
import 'package:atlas_app/reader/presentation/providers/atlas_glossary_providers.dart';
import 'package:atlas_app/reader/presentation/providers/translation_providers.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_novel_identity.dart';

final readerRepositoryProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  return DriftReaderRepository(db);
});

/// The id of the chapter the reader is actually displaying right now, kept in
/// sync by `ReaderContent`. Distinguishes a real, on-screen fetch from a
/// background prefetch of a neighboring chapter — only the former may trigger
/// the automatic full-screen session re-verify (see
/// `_downloadChapterWithSessionRefresh`), so a chapter loading silently ahead
/// of where the reader is can never cover the screen they're actually
/// reading.
final activeChapterIdProvider = StateProvider<String?>((_) => null);

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
      void publish(ChapterLoadPhase phase) => scheduleMicrotask(() {
        ref.read(chapterLoadPhaseProvider(chapter).notifier).state = phase;
      });

      // Check if the file is already cached on disk — if so, skip the
      // download phase entirely for a faster perceived load.
      final fileExists = await File(chapter.contentPath).exists();

      if (fileExists) {
        // File is cached: jump straight to processing (skip gettingText).
        publish(ChapterLoadPhase.processing);
      } else {
        publish(ChapterLoadPhase.gettingText);
        final downloadService = ref.watch(chapterDownloadServiceProvider);
        final downloadResult = await _downloadChapterWithSessionRefresh(
          ref,
          chapter,
          downloadService,
        );
        if (downloadResult is Failure) {
          // Propagate as a real provider failure (AsyncError) instead of
          // resolving with the error text as if it were chapter content — the
          // reader's error UI (with its Retry action) only ever sees this
          // through the `error` case of `AsyncValue.when`.
          throw downloadResult.error;
        }
        publish(ChapterLoadPhase.processing);
      }

      final result = await repo.getChapterContent(chapter.contentPath);
      // Offline/corrupted detection — automatically redownload in original
      // language when the file is missing, empty, or is the placeholder
      // written by `getChapterContent` (“# Chapter Content…”). This
      // satisfies the “offline behaviour: automatically, original” spec:
      // the user sees the fresh content without manually tapping Retry.
      if (result is Success<String>) {
        final content = result.value;
        final isPlaceholder =
            content.trim().isEmpty ||
            content.contains('The content file was not found') ||
            content.startsWith('# Chapter Content');
        if (isPlaceholder) {
          publish(ChapterLoadPhase.gettingText);
          final downloadService = ref.watch(chapterDownloadServiceProvider);
          final retry = await downloadService.redownloadChapter(
            chapter.bookId,
            chapter.index,
          );
          if (retry is Success) {
            final retried = await repo.getChapterContent(chapter.contentPath);
            if (retried is Success<String>) {
              publish(ChapterLoadPhase.preparing);
              return await _applyAtlasGlossary(
                ref,
                chapter.bookId,
                await _applyTranslation(ref, chapter, retried.value),
              );
            }
            // Fall through to throw the retried failure below.
            if (retried is Failure<String>) throw retried.error;
          }
          // Redownload failed — surface as provider error so the Retry
          // shimmer/error UI appears (user can tap Retry again).
          if (retry is Failure<void>) throw retry.error;
        }
      }
      publish(ChapterLoadPhase.preparing);
      return switch (result) {
        Success(value: final content) => await _applyAtlasGlossary(
          ref,
          chapter.bookId,
          await _applyTranslation(ref, chapter, content),
        ),
        Failure(error: final error) => throw error,
      };
    });

/// Scans the fully-prepared chapter text (after translation and
/// glossary transforms, so detection always matches what is displayed)
/// into an ordered list of prose/card [ContentSpan]s. Runs synchronously
/// in the same provider cycle as the content (no extra async round-trip),
/// since [BlockCardDetector.process] is pure and offline.
final chapterBlockCardSpansProvider =
    Provider.family<List<ContentSpan>, ChapterEntity>((ref, chapter) {
      final contentAsync = ref.watch(readerChapterContentProvider(chapter));
      return contentAsync.when(
        data: (content) => BlockCardDetector().processSync(content),
        loading: () => <ContentSpan>[],
        error: (_, _) => <ContentSpan>[],
      );
    });

/// Translates [content] for a non-WTR novel when the reader's translation
/// toggle is on. WTR novels are skipped: their Web / WebPlus / AI services
/// already translate during download, so re-translating here would double it.
/// The on-disk text is never rewritten — translation is applied per read, so
/// toggling it off instantly restores the source text.
Future<String> _applyTranslation(
  Ref ref,
  ChapterEntity chapter,
  String content,
) async {
  if (content.isEmpty) return content;

  final bookResult = await ref
      .read(readerRepositoryProvider)
      .getBookById(chapter.bookId);
  if (bookResult is! Success<BookEntity>) return content;
  final book = bookResult.value;
  if (isWtrLabSource(sourceUrl: book.sourceUrl, sourceName: book.sourceName)) {
    return content;
  }

  final enabled = await ref.watch(
    translationEnabledProvider(chapter.bookId).future,
  );
  if (!enabled) return content;
  final language = await ref.watch(
    targetLanguageProvider(chapter.bookId).future,
  );
  if (language == null) return content;

  final service = ref.watch(googleTranslateServiceProvider);
  final transport = ref.watch(googleTranslateTransportProvider);
  final paragraphs = content.split('\n\n');
  final translated = await service.translateParagraphs(
    transport,
    paragraphs: paragraphs,
    from: _sourceLanguageOf(book),
    to: language.code,
  );
  return translated.join('\n\n');
}

/// The source language Google Translate should assume for [book], falling back
/// to the site's common default (zh-CN) when the book carries no language tag.
String _sourceLanguageOf(BookEntity book) {
  final tag = book.language?.trim();
  if (tag == null || tag.isEmpty) return 'zh-CN';
  return tag.startsWith('zh') ? 'zh-CN' : tag;
}

/// Renders the user's per-novel glossary onto [content] as it is handed to the
/// reader. The stored chapter text is never rewritten — every load applies the
/// current term set, and watching the glossary rebuilds the chapter the moment
/// a term changes.
Future<String> _applyAtlasGlossary(
  Ref ref,
  String bookId,
  String content,
) async {
  final glossary = await ref.watch(atlasGlossaryProvider(bookId).future);
  return AtlasGlossaryApplier.apply(content, glossary);
}

/// The book's source URL for a chapter's book — used to map a session-expired
/// failure (which latches an origin) back to the chapter being displayed.
final chapterSourceUrlProvider = FutureProvider.family<String?, ChapterEntity>((
  ref,
  chapter,
) async {
  final result = await ref
      .read(readerRepositoryProvider)
      .getBookById(chapter.bookId);
  if (result is! Success<BookEntity>) return null;
  return result.value.sourceUrl;
});

/// Downloads [chapter]'s content. Automatic full-screen re-verify is disabled:
/// failures (including session-expired / bot-challenge) surface through the
/// chapter's inline error state (`ChapterContentLoader` → `Re-verify session`
/// button), which the user taps to open the visible re-verify flow. This
/// prevents an unsolicited fullscreen webview with no app bar from covering
/// the reader. Silent headless recovery still runs via `WebViewTransport`
/// → `fallbackFetcher` before this point.
Future<Result<void>> _downloadChapterWithSessionRefresh(
  Ref ref,
  ChapterEntity chapter,
  ChapterDownloadService downloadService,
) async {
  return downloadService.downloadChapter(
    chapter.bookId,
    chapter.index,
    targetLanguage: await _targetLanguageCode(ref, chapter.bookId),
  );
}

/// The book's chosen target language code (e.g. `es`) for a download, so WTR
/// Web/WebPlus chapters fetch pre-translated into the user's pick.
Future<String?> _targetLanguageCode(Ref ref, String bookId) async {
  return (await ref.watch(targetLanguageProvider(bookId).future))?.code;
}

/// Explicit redownload controller — force-overwrites the cached file even
/// when `contentState == availableOffline`. UI watches `isLoading` for
/// disabled-until-settled shimmer. Original language only (WTR Lab
/// re-translation is handled on display, not on disk).
final redownloadChapterProvider =
    FutureProvider.family<Result<void>, ChapterEntity>((ref, chapter) async {
      final service = ref.watch(chapterDownloadServiceProvider);
      final result = await service.redownloadChapter(
        chapter.bookId,
        chapter.index,
      );
      if (result is Success) {
        ref.invalidate(readerChapterContentProvider(chapter));
        // Also refresh the chapter list so `contentState`/`version` updates.
        ref.invalidate(novelChaptersProvider(chapter.bookId));
      }
      return result;
    });

/// Bulk redownload — overwrites every chapter. Used by book-details
/// “Redownload all”. Reports progress via `chapterDownloadingSetProvider`.
final redownloadAllProvider = FutureProvider.family<List<Result<void>>, String>(
  (ref, bookId) async {
    final service = ref.watch(chapterDownloadServiceProvider);
    final results = await service.redownloadAllChapters(bookId);
    // Invalidate all chapter content providers for this book.
    final chapters = await ref.watch(novelChaptersProvider(bookId).future);
    for (final ch in chapters) {
      ref.invalidate(readerChapterContentProvider(ch));
    }
    ref.invalidate(novelChaptersProvider(bookId));
    return results;
  },
);

final readerLoadingProvider = StateProvider<bool>((_) => false);

final bookmarksProvider = FutureProvider.family<List<BookmarkEntity>, String>((
  ref,
  bookId,
) async {
  final repo = ref.watch(readerRepositoryProvider);
  final result = await repo.getBookmarks(bookId);
  return switch (result) {
    Success(value: final bookmarks) => bookmarks,
    Failure() => <BookmarkEntity>[],
  };
});

final allBookmarksProvider = FutureProvider<List<BookmarkEntity>>((ref) async {
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

final lastReadChapterProvider = FutureProvider.family<ChapterEntity?, String>((
  ref,
  bookId,
) async {
  final db = ref.watch(databaseProvider);
  final progress = await db.getReadingProgress(bookId);
  if (progress == null) return null;

  final chapters = await ref.watch(novelChaptersProvider(bookId).future);
  for (final chapter in chapters) {
    if (chapter.id == progress.chapterId) return chapter;
  }
  return null;
});

/// Prefetches neighboring chapters (next 2 and previous 1) in the background
/// so that when the user navigates to them, their content is already cached
/// on disk and the shimmer is skipped entirely.
///
/// Call this once a chapter finishes loading (reaches [ChapterLoadPhase.done]).
/// Only the chapters that are *not* already cached are fetched — the disk-exists
/// check inside [readerChapterContentProvider] makes this cheap to call
/// repeatedly.
void prefetchNeighboringChapters(WidgetRef ref, ChapterEntity current) {
  final chaptersAsync = ref.read(novelChaptersProvider(current.bookId));
  final chapters = chaptersAsync.valueOrNull;
  if (chapters == null || chapters.isEmpty) return;

  // Prefetch next 2 chapters and previous 1.
  const lookAhead = 2;
  const lookBehind = 1;
  final start = (current.index - lookBehind).clamp(0, chapters.length - 1);
  final end = (current.index + lookAhead).clamp(0, chapters.length - 1);

  for (var i = start; i <= end; i++) {
    if (i == current.index) continue;
    final neighbor = chapters[i];
    // Fire-and-forget: the provider handles caching and dedup internally.
    ref.read(readerChapterContentProvider(neighbor).future);
  }
}
