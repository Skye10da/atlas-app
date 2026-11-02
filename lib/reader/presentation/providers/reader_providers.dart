import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/content_acquisition/services/cache_manager.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_detector.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_intelligence.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/intelligence/application/ingestion/story_backfill_service.dart';
import 'package:atlas_app/intelligence/domain/entities/correction_record.dart';
import 'package:atlas_app/intelligence/presentation/providers/intelligence_providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/reader/application/chapter_download_service.dart';
import 'package:atlas_app/reader/application/novel_export_service.dart';
import 'package:atlas_app/reader/domain/entities/bookmark_entity.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/entities/atlas_glossary_entry.dart';
import 'package:atlas_app/reader/domain/services/atlas_glossary_applier.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';
import 'package:atlas_app/reader/presentation/providers/atlas_glossary_providers.dart';
import 'package:atlas_app/reader/presentation/providers/translation_providers.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';
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

/// Bounded fail-safe timeouts for the chapter finalization chain.
///
/// Root-cause history for the "stuck on Preparing reader" reader bug: the
/// finalization chain inside [readerChapterContentProvider]
/// (`_applyTranslation` → `getBookById` → `targetLanguageProvider` →
/// translation, then `_applyAtlasGlossary`) used to await SharedPreferences-
/// and drift-backed lookups **without any bound**. When one of those
/// under­lying futures wedged (cold-start platform plugins, busy background
/// database isolate), the provider body never returned and the reader stayed
/// on "Preparing reader" forever — the only workaround was closing and
/// reopening the reader, because reopening disposes the element and by then
/// the blocked dependency had resolved.
///
/// Every await in that chain is therefore capped and capped below the whole
/// chain's own deadline, so the provider always resolves (fail-soft to the
/// raw chapter text). Mutable rather than `const` so tests can shrink the
/// durations; tests must call [reset] when done.
@visibleForTesting
class ReaderLoadFailSafes {
  static const _translationEnabledDefault = Duration(seconds: 15);
  static const _glossaryDefault = Duration(seconds: 15);
  static const _bookLookupDefault = Duration(seconds: 5);
  static const _targetLanguageDefault = Duration(seconds: 3);
  static const _finalizationDefault = Duration(seconds: 30);

  /// `translationEnabledProvider(chapter.bookId).future` inside
  /// [_applyTranslation].
  static Duration translationEnabled = _translationEnabledDefault;

  /// `atlasGlossaryProvider(bookId).future` inside [_applyAtlasGlossary].
  static Duration glossary = _glossaryDefault;

  /// `getBookById` (drift) inside [_applyTranslation].
  static Duration bookLookup = _bookLookupDefault;

  /// `targetLanguageProvider(bookId).future` inside [_applyTranslation] and
  /// [_targetLanguageCode].
  static Duration targetLanguage = _targetLanguageDefault;

  /// The whole translation + glossary transform chain inside
  /// [readerChapterContentProvider]'s `finalizeContent`.
  static Duration finalization = _finalizationDefault;

  /// Restores every duration to its production default.
  static void reset() {
    translationEnabled = _translationEnabledDefault;
    glossary = _glossaryDefault;
    bookLookup = _bookLookupDefault;
    targetLanguage = _targetLanguageDefault;
    finalization = _finalizationDefault;
  }
}

/// Publishes the current load stage for a chapter so its shimmer + status
/// overlay can reflect real backend progress.
final chapterLoadPhaseProvider = StateProvider.family<ChapterLoadPhase, ChapterEntity>(
  (ref, chapter) => ChapterLoadPhase.gettingText,
);

final readerChapterContentProvider = FutureProvider.family<String, ChapterEntity>((
  ref,
  chapter,
) async {
  final repo = ref.watch(readerRepositoryProvider);
  void publish(ChapterLoadPhase phase) => scheduleMicrotask(() {
    try {
      ref.read(chapterLoadPhaseProvider(chapter).notifier).state = phase;
    } catch (_) {}
  });

  // Runs translation + glossary and then feeds the final display text into
  // the Layer 1 story-memory pipeline (fire-and-forget, idempotent per
  // book/read-through/chapter/content-hash), so Atlas Intelligence keeps
  // pace with what the reader actually displays no matter which fetch path
  // (cache, redownload, network) produced the text.
  //
  // Deadline discipline (root cause of the historic "stuck on Preparing
  // reader" bug): every await inside is individually capped (see
  // [ReaderLoadFailSafes]) and the whole chain runs under
  // [ReaderLoadFailSafes.finalization]. If anything wedges anyway, we fail
  // soft to the raw chapter text, so `finalizeContent` can never hang the
  // provider and the reader can never sit on "Preparing reader" until it is
  // closed and reopened.
  Future<String> finalizeContent(String rawText) async {
    String display;
    try {
      display = await _applyAtlasGlossary(
        ref,
        chapter.bookId,
        await _applyTranslation(ref, chapter, rawText),
      ).timeout(ReaderLoadFailSafes.finalization, onTimeout: () => rawText);
    } catch (_) {
      display = rawText;
    }
    // "Preparing reader" is only true once the display text is final: the
    // transforms above run while the pill still shows "Processing text".
    // Publishing it here (instead of before the transforms) also keeps the
    // pill honest about which stage the work is actually in.
    publish(ChapterLoadPhase.preparing);
    unawaited(_scheduleStoryMemoryIngestion(
      ref,
      chapter: chapter,
      displayText: display,
    ));
    return display;
  }

  // Fast path: check local cache directly first.
  // When neighbor or current chapter is triggered, the first call is to fetch
  // directly from cache since it may already be cached for +1, -1, or active chapter.
  final chapterFile = File(chapter.contentPath);
  var fileExists = chapterFile.existsSync() && chapterFile.lengthSync() > 0;

  if (!fileExists) {
    // Check neighboring/index fallbacks in local directory and CacheManager
    String? cachedText;

    // 1. Check parent directory of chapterFile first (direct filesystem check, no plugin dependency)
    try {
      if (chapterFile.parent.existsSync()) {
        final candidateNames = [
          '${chapter.index}.txt',
          '${chapter.index + 1}.txt',
          'ch_${chapter.index}.txt',
          'chapter_${chapter.index}.txt',
          '${chapter.id}.txt',
        ];
        for (final name in candidateNames) {
          final f = File(p.join(chapterFile.parent.path, name));
          if (f.existsSync() && f.lengthSync() > 0) {
            final t = await f.readAsString();
            if (t.trim().isNotEmpty && !t.contains('The content file was not found')) {
              cachedText = t;
              break;
            }
          }
        }
      }
    } catch (_) {}

    // 2. Check CacheManager fallback if not found in parent directory
    if (cachedText == null) {
      try {
        final cacheManager = CacheManager();
        final candidateIds = [
          chapter.id,
          '${chapter.index}',
          '${chapter.index + 1}',
          'ch_${chapter.index}',
          'ch${chapter.index}',
          'chapter_${chapter.index}',
        ];
        for (final cid in candidateIds) {
          if (await cacheManager.hasChapter(chapter.bookId, cid)) {
            final text = await cacheManager.getChapter(chapter.bookId, cid);
            if (text != null && text.trim().isNotEmpty) {
              cachedText = text;
              break;
            }
          }
        }
      } catch (_) {}
    }

    if (cachedText != null && cachedText.trim().isNotEmpty) {
      try {
        await chapterFile.parent.create(recursive: true);
        await chapterFile.writeAsString(cachedText);
        fileExists = true;
      } catch (_) {}
    }
  }

  if (fileExists) {
    final cachedResult = await repo.getChapterContent(chapter.contentPath);
    if (cachedResult is Success<String>) {
      final content = cachedResult.value;
      final isPlaceholder = content.trim().isEmpty ||
          content.contains('The content file was not found') ||
          content.trim() == '# Chapter Content\n\nThe content file was not found.';
      if (!isPlaceholder) {
        // Cached content found: jump straight to processing and return without
        // network. `finalizeContent` publishes "preparing" itself once the
        // display text is final.
        publish(ChapterLoadPhase.processing);
        return await finalizeContent(content);
      }
    }
  }

  // Not available in local cache: fetch from network source.
  publish(ChapterLoadPhase.gettingText);
  final downloadService = ref.watch(chapterDownloadServiceProvider);
  final downloadResult = await _downloadChapterWithSessionRefresh(ref, chapter, downloadService);
  if (downloadResult is Failure) {
    // Propagate as a real provider failure (AsyncError) instead of
    // resolving with the error text as if it were chapter content — the
    // reader's error UI (with its Retry action) only ever sees this
    // through the `error` case of `AsyncValue.when`.
    throw downloadResult.error;
  }
  publish(ChapterLoadPhase.processing);

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
      final retry = await downloadService.redownloadChapter(chapter.bookId, chapter.index);
      if (retry is Success) {
        final retried = await repo.getChapterContent(chapter.contentPath);
        if (retried is Success<String>) {
          return await finalizeContent(retried.value);
        }
        // Fall through to throw the retried failure below.
        if (retried is Failure<String>) throw retried.error;
      }
      // Redownload failed — surface as provider error so the Retry
      // shimmer/error UI appears (user can tap Retry again).
      if (retry is Failure<void>) throw retry.error;
    }
  }
  return switch (result) {
    Success(value: final content) => await finalizeContent(content),
    Failure(error: final error) => throw error,
  };
});

final _blockCardSpanCache = <(String, int, int), List<ContentSpan>>{};

/// Local-only BlockCard corrections for a book (reuses `story_corrections`
/// with `entity_type='block_card'`). No global, explicit menu-driven only.
final blockCardLocalCorrectionsProvider =
    FutureProvider.family<List<CorrectionRecord>, String>((ref, bookId) async {
  final repo = ref.watch(correctionRepositoryProvider);
  final res = await repo.getCorrections(bookId);
  if (res is Success<List<CorrectionRecord>>) {
    return res.value
        .where((r) => r.entityType.id == BlockCardIntelligenceScorer.entityTypeId)
        .toList();
  }
  return const [];
});

/// Scans the fully-prepared chapter text (after translation and
/// glossary transforms, so detection always matches what is displayed)
/// into an ordered list of prose/card [ContentSpan]s. Runs synchronously
/// in the same provider cycle as the content (no extra async round-trip),
/// since [BlockCardDetector.process] is pure and offline, then applies
/// local intelligence rescoring (confirm +0.20 / reject -0.40 + type override).
final chapterBlockCardSpansProvider = Provider.family<List<ContentSpan>, ChapterEntity>((
  ref,
  chapter,
) {
  final contentAsync = ref.watch(readerChapterContentProvider(chapter));
  // Respect user setting — when disabled, cards are never rendered.
  final settings = ref.watch(readingSettingsProvider).valueOrNull;
  final enabled = settings?.enableBlockCards ?? true;
  if (!enabled) {
    return contentAsync.when(
      data: (content) => content.isEmpty ? <ContentSpan>[] : [ContentSpan.prose(content)],
      loading: () => <ContentSpan>[],
      error: (_, _) => <ContentSpan>[],
    );
  }
  // Wire intelligence: local corrections trigger rescore without extra async per card.
  final correctionsAsync = ref.watch(blockCardLocalCorrectionsProvider(chapter.bookId));
  final corrections = correctionsAsync.valueOrNull ?? const <CorrectionRecord>[];
  const scorer = BlockCardIntelligenceScorer();

  return contentAsync.when(
    data: (content) {
      if (content.isEmpty) return <ContentSpan>[];
      // Cache key includes corrections length/hash so a new feedback invalidates.
      final correctionsHash = corrections.length.hashCode ^ corrections.fold<int>(0, (p, e) => p ^ e.pattern.hashCode);
      final key = (chapter.id, content.length, content.hashCode ^ correctionsHash);
      final cached = _blockCardSpanCache[key];
      if (cached != null) return cached;
      if (_blockCardSpanCache.length > 30) {
        _blockCardSpanCache.remove(_blockCardSpanCache.keys.first);
      }
      // Sync CPU work inside a build — a timeout can't preempt it, so a slow
      // scan here freezes the whole isolate on the very frame that should
      // paint the chapter text.
      final parsed = BlockCardDetector().processSync(content);
      if (corrections.isEmpty) {
        _blockCardSpanCache[key] = parsed;
        return parsed;
      }
      final rescored = parsed.map((span) {
        if (!span.isCard || span.card == null) return span;
        final result = scorer.rescore(span.card!, corrections);
        if (result.card == span.card) return span;
        return ContentSpan.card(result.card);
      }).toList();
      _blockCardSpanCache[key] = rescored;
      return rescored;
    },
    loading: () => <ContentSpan>[],
    error: (_, _) => <ContentSpan>[],
  );
});

/// Translates [content] for a non-WTR novel when the reader's translation
/// toggle is on. WTR novels are skipped: their Web / WebPlus / AI services
/// already translate during download, so re-translating here would double it.
/// The on-disk text is never rewritten — translation is applied per read, so
/// toggling it off instantly restores the source text.
Future<String> _applyTranslation(Ref ref, ChapterEntity chapter, String content) async {
  if (content.isEmpty) return content;

  // Fast path: translation off => no drift, no network. Saves 1 drift query
  // on every cached-chapter open (the common offline, already-downloaded case).
  //
  // Every lookup below is both `read`-based (never `watch` — a watch would
  // invalidate and re-run the whole chapter load the moment the dependency
  // first resolves, re-publishing a phase mid-load) AND capped by a
  // [ReaderLoadFailSafes] duration. That last part is the actual fix for the
  // historic "stuck on Preparing reader" bug: `getBookById` (drift) and
  // `targetLanguageProvider` (SharedPreferences) used to be awaited without
  // any bound; when either wedged the provider never returned and the only
  // workaround was closing and reopening the reader.
  //
  // Each provider's already-resolved value is used when present (warm
  // sessions skip the awaits entirely); otherwise its `.future` is awaited
  // under a fail-safe timeout with a fail-soft fallback, so a cold/slow or
  // wedged dependency can never stall the chapter — it only skips the
  // transform for this read.
  final enabledSyncValue = ref
      .read(translationEnabledProvider(chapter.bookId))
      .valueOrNull;
  final enabled = enabledSyncValue ??
      await ref
          .read(translationEnabledProvider(chapter.bookId).future)
          .timeout(
            ReaderLoadFailSafes.translationEnabled,
            onTimeout: () => false,
          );
  if (!enabled) return content;

  BookEntity? book;
  try {
    final bookResult = await ref
        .read(readerRepositoryProvider)
        .getBookById(chapter.bookId)
        .timeout(
          ReaderLoadFailSafes.bookLookup,
          onTimeout: () => throw TimeoutException(
            'ReaderLoadFailSafes.bookLookup exceeded',
          ),
        );
    if (bookResult is Success<BookEntity>) book = bookResult.value;
  } catch (_) {
    // Wedged or failed book lookup: skip translation rather than stall.
    return content;
  }
  if (book == null) return content;
  if (isWtrLabSource(sourceUrl: book.sourceUrl, sourceName: book.sourceName)) {
    return content;
  }

  final languageAsyncValue = ref
      .read(targetLanguageProvider(chapter.bookId))
      .valueOrNull;
  final language = languageAsyncValue ??
      await ref
          .read(targetLanguageProvider(chapter.bookId).future)
          .timeout(
            ReaderLoadFailSafes.targetLanguage,
            onTimeout: () => null,
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
/// current term set. Uses `ref.read` (not `watch`) on the glossary `.future`
/// so the first glossary resolution does not invalidate and re-run the chapter
/// load (the "Preparing reader" stall); glossary mutations instead invalidate
/// [readerChapterContentProvider] explicitly (see `glossary_tab.dart`).
///
/// Bounded: the glossary load is capped by
/// [ReaderLoadFailSafes.glossary] (fail-soft: empty glossary → unchanged
/// content), so a wedged SharedPreferences-backed load can never hang the
/// chapter between "preparing" and display. Awaiting the provider future also
/// ensures an invalidated provider supplies its refreshed value instead of
/// stale data retained while the refresh is in progress.
Future<String> _applyAtlasGlossary(Ref ref, String bookId, String content) async {
  try {
    final glossary = await ref
        .read(atlasGlossaryProvider(bookId).future)
        .timeout(
          ReaderLoadFailSafes.glossary,
          onTimeout: () => const <AtlasGlossaryEntry>[],
        );
    if (glossary.isEmpty) return content;
    final applied = AtlasGlossaryApplier.apply(content, glossary);
    return applied;
  } catch (_) {
    return content;
  }
}

/// The book's source URL for a chapter's book — used to map a session-expired
/// failure (which latches an origin) back to the chapter being displayed.
final chapterSourceUrlProvider = FutureProvider.family<String?, ChapterEntity>((
  ref,
  chapter,
) async {
  final result = await ref.read(readerRepositoryProvider).getBookById(chapter.bookId);
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
///
/// `ref.read` (not `watch`) — awaiting the `.future` with `watch` would
/// invalidate this provider the moment `targetLanguageProvider` first
/// resolves, re-running the load before the download even started. Capped
/// by [ReaderLoadFailSafes.targetLanguage]: a wedged lookup must never stall
/// the download start; fail-soft fallback downloads in the original language.
Future<String?> _targetLanguageCode(Ref ref, String bookId) async {
  return (await ref
          .read(targetLanguageProvider(bookId).future)
          .timeout(
            ReaderLoadFailSafes.targetLanguage,
            onTimeout: () => null,
          ))
      ?.code;
}

/// Explicit redownload controller — force-overwrites the cached file even
/// when `contentState == availableOffline`. UI watches `isLoading` for
/// disabled-until-settled shimmer. Original language only (WTR Lab
/// re-translation is handled on display, not on disk).
final redownloadChapterProvider = FutureProvider.family<Result<void>, ChapterEntity>((
  ref,
  chapter,
) async {
  final service = ref.watch(chapterDownloadServiceProvider);
  final result = await service.redownloadChapter(chapter.bookId, chapter.index);
  if (result is Success) {
    ref.invalidate(readerChapterContentProvider(chapter));
    // Also refresh the chapter list so `contentState`/`version` updates.
    ref.invalidate(novelChaptersProvider(chapter.bookId));
  }
  return result;
});

/// Bulk redownload — overwrites every chapter. Used by book-details
/// “Redownload all”. Reports progress via `chapterDownloadingSetProvider`.
final redownloadAllProvider = FutureProvider.family<List<Result<void>>, String>((
  ref,
  bookId,
) async {
  final service = ref.watch(chapterDownloadServiceProvider);
  final results = await service.redownloadAllChapters(bookId);
  // Invalidate all chapter content providers for this book.
  final chapters = await ref.watch(novelChaptersProvider(bookId).future);
  for (final ch in chapters) {
    ref.invalidate(readerChapterContentProvider(ch));
  }
  ref.invalidate(novelChaptersProvider(bookId));
  return results;
});

final readerLoadingProvider = StateProvider<bool>((_) => false);

final bookmarksProvider = FutureProvider.family<List<BookmarkEntity>, String>((ref, bookId) async {
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
  return ChapterDownloadService(sourceRegistry: registry, readerRepo: readerRepo, db: db);
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

final novelChaptersProvider = FutureProvider.family<List<ChapterEntity>, String>((
  ref,
  bookId,
) async {
  final repo = ref.watch(readerRepositoryProvider);
  final result = await repo.getChapters(bookId);
  return switch (result) {
    Success(value: final chapters) => chapters,
    Failure() => <ChapterEntity>[],
  };
});

final chapterDownloadingSetProvider = StateProvider<Set<String>>((ref) => {});

final lastReadChapterProvider = FutureProvider.family<ChapterEntity?, String>((ref, bookId) async {
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
    // Disk-only prefetch: never start network downloads in the background
    // the moment the reader opens. Chapters whose file is missing are
    // fetched on demand when actually visited (the paged layout's
    // allowRemoteFetch path handles reconciliation there). This also removed
    // a crash trigger: auto-fetching missing-file chapters of "downloaded" books at open
    // could hard-crash the app on Windows.
    if (!File(neighbor.contentPath).existsSync()) continue;
    // Fire-and-forget: the provider handles caching and dedup internally.
    ref.read(readerChapterContentProvider(neighbor).future);
  }
}

/// Feed-and-forget Layer 1 story-memory ingestion for one chapter of final
/// display text. Best-effort by design: extraction, scene indexing and log
/// bookkeeping run on a background isolate through
/// [StoryMemoryIngestionService] and must never surface to the reader UI,
/// including when this provider's [ref] has already been disposed.
Future<void> _scheduleStoryMemoryIngestion(
  Ref ref, {
  required ChapterEntity chapter,
  required String displayText,
}) async {
  try {
    final service = ref.read(storyMemoryIngestionServiceProvider);
    final bookId = chapter.bookId;
    final rt = await ref.read(activeReadThroughProvider(bookId).future);
    await service.ingestChapter(
      bookId: bookId,
      readThroughId: rt.id,
      chapterIndex: chapter.index,
      chapterText: displayText,
    );
  } catch (_) {
    // Intentionally silent: non-critical background work.
  }
}

/// The display-driven ingestion only sees chapters the reader actually opens.
/// The backfill pass covers the rest — chapters cached by bulk downloads and
/// prefetches — reading cached files only, rate-limited and cancellable.
final storyBackfillServiceProvider = Provider<StoryBackfillService>((ref) {
  return StoryBackfillService(
    memoryRepository: ref.watch(storyMemoryRepositoryProvider),
    ingestionService: ref.watch(storyMemoryIngestionServiceProvider),
  );
});

/// Foreground helper: safe to call from widgets — the service deduplicates
/// concurrent runs and the ingestion log makes repeated passes no-ops.
Future<void> maybeStartStoryBackfill(WidgetRef ref, String bookId) async {
  try {
    final chapters = await ref.read(novelChaptersProvider(bookId).future);
    if (chapters.isEmpty) return;
    final rt = await ref.read(activeReadThroughProvider(bookId).future);
    // Consolidation sweep first: it fixes readers-visible duplicate
    // entities immediately (the common case on books ingested before the
    // merge pipeline existed) while the backfill runs afterwards.
    unawaited(_consolidateStoryEntities(ref, bookId, rt.id));
    final service = ref.read(storyBackfillServiceProvider);
    unawaited(service.backfillBook(
      bookId: bookId,
      readThroughId: rt.id,
      totalChapters: chapters.length,
      chapterTextResolver: (index) =>
          _cachedChapterText(chapters, index),
      onProgress: (progress) {
        try {
          ref.read(storyBackfillProgressProvider(bookId).notifier).state =
              progress;
        } catch (_) {
          // Provider may be gone (page navigated away): the run continues.
        }
      },
    ).whenComplete(() {
      // Chapters ingested by this run may have spawned new duplicates —
      // consolidate once more when the dust settles.
      unawaited(_consolidateStoryEntities(ref, bookId, rt.id));
    }));
  } catch (_) {
    // Intentionally silent.
  }
}

/// Fire-and-forget whole-book entity deduplication sweep (see
/// [EntityConsolidationService]). Best-effort: failures are swallowed —
/// the next details-page open re-tries.
Future<void> _consolidateStoryEntities(
  WidgetRef ref,
  String bookId,
  String readThroughId,
) async {
  try {
    await ref
        .read(entityConsolidationServiceProvider)
        .consolidateBook(bookId: bookId, readThroughId: readThroughId);
  } catch (_) {
    // Intentionally silent: non-critical background work.
  }
}

/// Reads a chapter's cached file for backfill ingestion. Never hits the
/// network or the display pipeline (translation/glossary) — backfill runs on
/// the same raw text the cache already holds. Fully async: a synchronous
/// chapter-file read here used to jank the UI isolate on every backfill step.
Future<String?> _cachedChapterText(List<ChapterEntity> chapters, int index) async {
  if (index < 0 || index >= chapters.length) return null;
  try {
    final file = File(chapters[index].contentPath);
    if (!await file.exists() || await file.length() <= 0) return null;
    final text = await file.readAsString();
    if (text.trim().isEmpty || text.contains('The content file was not found')) {
      return null;
    }
    return text;
  } catch (_) {
    return null;
  }
}


