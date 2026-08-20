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
  void publish(ChapterLoadPhase phase) =>
      scheduleMicrotask(() {
        ref.read(chapterLoadPhaseProvider(chapter).notifier).state = phase;
      });

  publish(ChapterLoadPhase.gettingText);

  if (!await File(chapter.contentPath).exists()) {
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
  }

  publish(ChapterLoadPhase.processing);
  final result = await repo.getChapterContent(chapter.contentPath);
  publish(ChapterLoadPhase.preparing);
  return switch (result) {
    Success(value: final content) =>
      await _applyAtlasGlossary(
        ref,
        chapter.bookId,
        await _applyTranslation(ref, chapter, content),
      ),
    Failure(error: final error) => throw error,
  };
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

  final enabled = await ref.watch(translationEnabledProvider(chapter.bookId).future);
  if (!enabled) return content;
  final language = await ref.watch(targetLanguageProvider(chapter.bookId).future);
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
final chapterSourceUrlProvider =
    FutureProvider.family<String?, ChapterEntity>((ref, chapter) async {
  final result = await ref
      .read(readerRepositoryProvider)
      .getBookById(chapter.bookId);
  if (result is! Success<BookEntity>) return null;
  return result.value.sourceUrl;
});

/// Downloads [chapter]'s content, and when the fetch failed on an expired
/// session *for the chapter currently on screen*, runs the quick re-verify
/// flow once (per origin) and retries.
Future<Result<void>> _downloadChapterWithSessionRefresh(
  Ref ref,
  ChapterEntity chapter,
  ChapterDownloadService downloadService,
) async {
  final first = await downloadService.downloadChapter(
    chapter.bookId,
    chapter.index,
    targetLanguage: await _targetLanguageCode(ref, chapter.bookId),
  );
  if (first is! Failure) return first;

  // A background prefetch of a neighboring chapter must never silently push
  // the full-screen re-verify webview over whatever the reader is actually
  // looking at. Only the chapter currently on screen gets the automatic
  // recovery; every other failure (including this one) surfaces through the
  // chapter's own error state, where "Retry" / "Re-verify session" are one
  // tap away.
  if (ref.read(activeChapterIdProvider) != chapter.id) return first;

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
  // Prefer the URL that triggered the wall (the chapter URL with its active
  // `?service=` param) so the refresh webview opens the page that needs
  // re-verification, falling back to the novel's source URL.
  final seedUrl =
      session.lastInvalidSeedUrl.value ?? Uri.tryParse(sourceUrl ?? '');
  final ok = await session.ensureFresh(origin, seedUrl: seedUrl);
  if (!ok) return first;
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
