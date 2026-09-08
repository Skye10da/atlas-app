// ignore_for_file: dead_code, unnecessary_type_check
import 'dart:async';

import 'package:flutter/material.dart' hide WordBoundary;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/molecules/app_error_state.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/services/platform_service.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/reader/domain/entities/bookmark_entity.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/domain/entities/reading_progress_snapshot.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/reader_repository_interface.dart';
import 'package:atlas_app/reader/presentation/providers/annotations_provider.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/book_search_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_shimmer.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/continuous_reader_layout.dart';
import 'package:atlas_app/reader/presentation/widgets/note_editor_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/paged_reader_layout.dart';
import 'package:atlas_app/reader/presentation/widgets/quote_share_card_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/real_flip_reader_layout.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_annotations_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/reader_settings_sheet.dart';
import 'package:atlas_app/reader/speech/selection_speaker.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_session.dart';
import 'package:atlas_app/reader/speech/speech_session_builder.dart';
import 'package:atlas_app/discover/presentation/providers/reading_analytics_providers.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_novel_identity.dart';

class ReaderContent extends HookConsumerWidget {
  const ReaderContent({
    super.key,
    required this.repo,
    required this.bookId,
    required this.settings,
  });

  final ReaderRepositoryInterface repo;
  final String bookId;
  final ReadingSettingsEntity settings;

  static const _selectionSpeaker = SelectionSpeaker();
  static const _sessionBuilder = SpeechSessionBuilder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentChapter = useState<ChapterEntity?>(null);
    final currentChapterIndex = useState<int>(0);
    final chapters = useState<List<ChapterEntity>>([]);
    final scrollProgress = useState<double>(0.0);
    final initialChapterId = useRef<String?>(null);
    final initialScrollProgress = useRef<double?>(null);
    final initialPosition = useRef<int?>(null);
    final readQueryParam = useRef<bool>(false);
    final loading = useState<bool>(true);
    final errorMessage = useState<String?>(null);
    final bookmarkedChapterIds = useState<Set<String>>({});
    final saveDebounceTimer = useRef<Timer?>(null);
    final platformService = useRef<PlatformService?>(null);

    final currentSentenceIndex = useState<int>(0);
    final currentSentenceTotal = useState<int>(0);

    final bookLanguage = useState<String?>(null);
    final bookTitle = useState<String?>(null);
    final bookAuthor = useState<String?>(null);
    final bookCoverPath = useState<String?>(null);
    final wtrRawId = useState<int?>(null);
    final restoredCheckpoint = useState<SpeechCheckpoint?>(null);
    final popInProgress = useRef<bool>(false);
    final isRedownloading = useState<bool>(false);

    // Reading session tracking for Discover Analytics
    final sessionStartTime = useRef<DateTime>(DateTime.now());
    final sessionViewedChapterIds = useRef<Set<String>>(<String>{});
    // Capture analytics service before dispose — `ref` cannot be used after
    // the widget is disposed (hooks `dispose` runs after element unmount).
    final analyticsService = ref.watch(readingAnalyticsServiceProvider);
    final analyticsServiceRef = useRef(analyticsService);
    analyticsServiceRef.value = analyticsService;

    void flushReadingSession() {
      final now = DateTime.now();
      final elapsed = now.difference(sessionStartTime.value).inSeconds;
      final chCount = sessionViewedChapterIds.value.isEmpty
          ? 1
          : sessionViewedChapterIds.value.length;
      if (elapsed >= 5) {
        analyticsServiceRef.value.recordReadingSession(
          bookId: bookId,
          durationSeconds: elapsed,
          chaptersRead: chCount,
        );
        sessionStartTime.value = now;
        sessionViewedChapterIds.value.clear();
      }
    }

    void resetPosition() {
      currentSentenceIndex.value = 0;
      currentSentenceTotal.value = 0;
    }

    Future<void> handleRedownload() async {
      final ch = currentChapter.value;
      if (ch == null || isRedownloading.value) return;
      isRedownloading.value = true;
      try {
        final service = ref.read(chapterDownloadServiceProvider);
        final result = await service.redownloadChapter(bookId, ch.index);
        if (!context.mounted) return;
        if (result is Success) {
          ref.invalidate(readerChapterContentProvider(ch));
          // Refresh chapter list so contentState/version updates in DB watch.
          ref.invalidate(novelChaptersProvider(bookId));
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Redownloaded "${ch.title}"')));
        } else {
          final err = (result as Failure).error;
          final msg = err is AppException
              ? err.userMessage
              : 'Redownload failed — check connection and try again.';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      } finally {
        if (context.mounted) isRedownloading.value = false;
      }
    }

    Future<void> saveProgress(ChapterEntity chapter) async {
      sessionViewedChapterIds.value.add(chapter.id);
      await repo.saveProgress(
        userId: 'local',
        bookId: bookId,
        chapterId: chapter.id,
        percentage: scrollProgress.value * 100,
        position: currentSentenceIndex.value,
        totalPositions: currentSentenceTotal.value,
      );
    }

    void advanceFromNarration(String finishedChapterId) {
      if (!context.mounted) return;
      final autoAdvance =
          ref.read(narrationSettingsProvider).value?.autoAdvanceChapter ?? true;
      if (!autoAdvance) return;
      final idx = chapters.value.indexWhere((c) => c.id == finishedChapterId);
      if (idx < 0 || idx >= chapters.value.length - 1) return;
      final next = chapters.value[idx + 1];
      resetPosition();
      currentChapter.value = next;
      currentChapterIndex.value = idx + 1;
      saveProgress(next);
    }

    void onSpeechEvent(SpeechEvent event) {
      switch (event) {
        case ChapterFinished(:final chapterId):
          advanceFromNarration(chapterId);
        case SentenceStarted(:final item):
          ref.read(activeWordBoundaryProvider.notifier).state = null;
          if (item.bookId == bookId) {
            ref.read(activeSpeechItemProvider.notifier).state = item;
          }
        case WordBoundary(:final item, :final start, :final end, :final word):
          ref.read(activeWordBoundaryProvider.notifier).state = WordBoundary(
            item,
            start,
            end,
            word,
          );
        case SpeechStopped() || SpeechCompleted():
          ref.read(activeSpeechItemProvider.notifier).state = null;
          ref.read(activeWordBoundaryProvider.notifier).state = null;
        default:
          break;
      }
    }

    Future<void> syncSpeechSession(
      ChapterEntity chapter,
      String content,
    ) async {
      final engine = ref.read(speechEngineProvider);
      if (engine.session?.chapterId == chapter.id) return;

      final narrationSettings =
          ref.read(narrationSettingsProvider).value ??
          const NarrationSettings();
      final checkpoint = restoredCheckpoint.value;
      final restoreHere =
          checkpoint != null &&
          checkpoint.bookId == bookId &&
          checkpoint.chapterId == chapter.id;

      final session = _sessionBuilder.build(
        bookId: bookId,
        chapter: chapter,
        content: content,
        language: bookLanguage.value ?? 'en',
        settings: narrationSettings,
        sentenceIndex: restoreHere ? checkpoint.sentenceIndex : 0,
        coverPath: bookCoverPath.value,
        bookTitle: bookTitle.value,
        author: bookAuthor.value,
      );
      await engine.loadSession(session);
    }

    void applySystemSettings() {
      final svc = ref.read(platformServiceProvider);
      platformService.value = svc;
      final s = settings;
      svc.setKeepScreenOn(s.keepScreenAwake);
      if (s.followSystemBrightness) {
        svc.resetBrightness();
      } else {
        svc.setBrightness(s.brightness, smooth: true);
      }
      if (s.autoOptimizeBrightness) {
        svc.optimizeForLowBattery();
      }
    }

    Future<void> loadNarrationContext(List<ChapterEntity> chList) async {
      if (!context.mounted) return;
      final bookResult = await repo.getBookById(bookId);
      if (!context.mounted) return;
      if (bookResult is Success<BookEntity>) {
        final book = bookResult.value;
        bookLanguage.value = book.language;
        bookTitle.value = book.title;
        bookAuthor.value = book.author;
        bookCoverPath.value = book.coverPath;
        wtrRawId.value =
            isWtrLabSource(
              sourceUrl: book.sourceUrl,
              sourceName: book.sourceName,
            )
            ? wtrRawIdOf(sourceId: book.sourceId, sourceUrl: book.sourceUrl)
            : null;
      }
      final checkpoint = await ref
          .read(speechRecoveryStoreProvider)
          .load(bookId);
      if (!context.mounted) return;
      restoredCheckpoint.value =
          checkpoint != null && chList.any((c) => c.id == checkpoint.chapterId)
          ? checkpoint
          : null;
    }

    Future<void> loadBookmarks() async {
      final result = await repo.getBookmarks(bookId);
      if (!context.mounted) return;
      if (result is Success<List<BookmarkEntity>>) {
        bookmarkedChapterIds.value = result.value
            .map((b) => b.chapterId)
            .toSet();
      }
    }

    Future<void> loadChapters() async {
      final result = await repo.getChapters(bookId);
      if (!context.mounted) return;
      if (result is Failure<List<ChapterEntity>>) {
        loading.value = false;
        errorMessage.value = result.error.userMessage;
        return;
      }
      final loaded = (result as Success<List<ChapterEntity>>).value;
      if (loaded.isEmpty) {
        loading.value = false;
        errorMessage.value = 'No chapters found.';
        return;
      }

      final progressResult = await repo.getReadingProgress(bookId);
      ReadingProgressSnapshot? progressSnap;
      if (progressResult is Success<ReadingProgressSnapshot?>) {
        progressSnap = progressResult.value;
      }

      final targetChapterId = initialChapterId.value ?? progressSnap?.chapterId;
      final initialIndex = targetChapterId != null
          ? loaded.indexWhere((c) => c.id == targetChapterId)
          : -1;
      final resolvedIndex = initialIndex >= 0 ? initialIndex : 0;

      chapters.value = loaded;
      currentChapterIndex.value = resolvedIndex;
      currentChapter.value = loaded[resolvedIndex];
      initialPosition.value = progressSnap?.position;
      currentSentenceIndex.value = progressSnap?.position ?? 0;
      initialChapterId.value = null;

      await Future.wait([loadBookmarks(), loadNarrationContext(loaded)]);

      if (!context.mounted) return;
      loading.value = false;
    }

    Future<void> toggleBookmark() async {
      final chapter = currentChapter.value;
      if (chapter == null) return;
      if (bookmarkedChapterIds.value.contains(chapter.id)) {
        final result = await repo.getBookmarks(bookId);
        if (result is Success<List<BookmarkEntity>>) {
          final existing = result.value
              .where((b) => b.chapterId == chapter.id)
              .toList();
          for (final b in existing) {
            await repo.removeBookmark(b.id);
          }
        }
      } else {
        final now = DateTime.now();
        await repo.addBookmark(
          BookmarkEntity(
            id: '${bookId}_${chapter.id}_${now.millisecondsSinceEpoch}',
            bookId: bookId,
            chapterId: chapter.id,
            position: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      ref.invalidate(bookmarksProvider(bookId));
      final nextSet = Set<String>.from(bookmarkedChapterIds.value);
      if (nextSet.contains(chapter.id)) {
        nextSet.remove(chapter.id);
      } else {
        nextSet.add(chapter.id);
      }
      bookmarkedChapterIds.value = nextSet;
    }

    Future<void> handlePop() async {
      if (popInProgress.value) return;
      popInProgress.value = true;
      saveDebounceTimer.value?.cancel();
      final chapter = currentChapter.value;
      if (chapter != null) {
        await saveProgress(chapter);
      }
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }

    useEffect(() {
      final speechSub = ref
          .read(speechEngineProvider)
          .events
          .listen(onSpeechEvent);
      loadChapters();

      return () {
        speechSub.cancel();
        saveDebounceTimer.value?.cancel();
        if (currentChapter.value != null) {
          saveProgress(currentChapter.value!);
        }
        flushReadingSession();
        platformService.value?.setKeepScreenOn(false);
        platformService.value?.resetBrightness();
      };
    }, const []);

    Map<String, String>? queryParams;
    try {
      queryParams = GoRouterState.of(context).uri.queryParameters;
    } catch (_) {}

    useEffect(
      () {
        if (!readQueryParam.value && queryParams != null) {
          initialChapterId.value = queryParams['chapterId'];
          final progressParam = queryParams['progress'];
          initialScrollProgress.value = progressParam != null
              ? double.tryParse(progressParam)
              : null;
          readQueryParam.value = true;
        }
        applySystemSettings();
        return null;
      },
      [
        queryParams,
        settings.keepScreenAwake,
        settings.brightness,
        settings.followSystemBrightness,
        settings.autoOptimizeBrightness,
      ],
    );

    if (loading.value) {
      final colorScheme = Theme.of(context).colorScheme;
      return Scaffold(
        backgroundColor: ReadingViewTheme.paper.resolve(colorScheme).background,
        body: const ChapterShimmer(vt: ReadingViewTheme.paper),
      );
    }
    if (errorMessage.value != null) {
      return Scaffold(
        body: AppErrorState(
          message: errorMessage.value!,
          technicalDetails: errorMessage.value!,
        ),
      );
    }

    final currCh = currentChapter.value;
    if (currCh != null) {
      if (ref.read(activeChapterIdProvider) != currCh.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ref.read(activeChapterIdProvider.notifier).state = currCh.id;
          }
        });
      }
      final content = ref
          .watch(readerChapterContentProvider(currCh))
          .valueOrNull;
      if (content != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) syncSpeechSession(currCh, content);
        });
      }
    }

    final isBookmarked =
        currCh != null && bookmarkedChapterIds.value.contains(currCh.id);

    final savedProgress = scrollProgress.value > 0
        ? scrollProgress.value
        : initialScrollProgress.value;
    final resumePosition = currentSentenceIndex.value > 0
        ? currentSentenceIndex.value
        : initialPosition.value;

    void onContinuousScrollProgress(double progress) {
      scrollProgress.value = progress;
    }

    void onContinuousChapterChanged(int index) {
      if (currentChapter.value?.id != chapters.value[index].id) {
        currentChapter.value = chapters.value[index];
        currentChapterIndex.value = index;
        saveProgress(chapters.value[index]);
      }
    }

    void onScrollDirectionChanged(ScrollDirection direction) {
      saveDebounceTimer.value?.cancel();
      saveDebounceTimer.value = Timer(const Duration(milliseconds: 500), () {
        if (currentChapter.value != null) saveProgress(currentChapter.value!);
      });
    }

    void onPositionChanged(int sentenceIndex, int totalSentences) {
      currentSentenceIndex.value = sentenceIndex;
      currentSentenceTotal.value = totalSentences;
    }

    void onPagedPageChanged(int chapterIdx) {
      currentChapter.value = chapters.value[chapterIdx];
      currentChapterIndex.value = chapterIdx;
      saveProgress(chapters.value[chapterIdx]);
    }

    void onPagedProgressChanged(double progress) {
      scrollProgress.value = progress;
    }

    void goToPagedChapter(int index) {
      if (currentChapter.value?.id != chapters.value[index].id) {
        resetPosition();
        currentChapter.value = chapters.value[index];
        currentChapterIndex.value = index;
      }
    }

    void showSettingsDrawer() {
      AppSheet.show(
        context: context,
        id: 'reader_settings',
        title: 'Reading Settings',
        initialHeight: 0.8,
        snapPoints: const [0.6, 0.8],
        child: ReaderSettingsSheet(
          initialSettings: settings,
          bookId: bookId,
          rawId: wtrRawId.value,
        ),
      );
    }

    void showSearchSheet() {
      BookSearchSheet.show(
        context,
        bookId: bookId,
        onResultSelected: (chapterIdx, charOffset) {
          if (settings.readingMode == ReadingMode.continuous) {
            resetPosition();
            currentChapter.value = chapters.value[chapterIdx];
            currentChapterIndex.value = chapterIdx;
          } else {
            goToPagedChapter(chapterIdx);
          }
        },
      );
    }

    void handleHighlight(
      String text,
      Color color,
      int start,
      int end, {
      HighlightStyleType styleType = HighlightStyleType.solid,
    }) {
      final chapter = currentChapter.value;
      if (chapter == null) return;
      ref
          .read(annotationsProvider(bookId).notifier)
          .addHighlight(
            chapterId: chapter.id,
            start: start,
            end: end,
            text: text,
            colorValue: color.toARGB32(),
            styleType: styleType,
          );
    }

    void handleErase(int start, int end) {
      final chapter = currentChapter.value;
      if (chapter == null) return;
      ref
          .read(annotationsProvider(bookId).notifier)
          .eraseOverlapping(chapter.id, start, end);
    }

    void handleAddNote(String text, String? sentence) {
      final chapter = currentChapter.value;
      if (chapter == null) return;
      NoteEditorSheet.show(
        context,
        bookId: bookId,
        chapterId: chapter.id,
        selectedText: text,
        sentence: sentence,
        chapterTitle: chapter.title,
      );
    }

    void handleShare(String text) {
      QuoteShareCardSheet.show(
        context,
        quoteText: text,
        bookTitle: bookTitle.value,
        author: bookAuthor.value,
        chapterTitle: currentChapter.value?.title,
        coverPath: bookCoverPath.value,
      );
    }

    void showAnnotationsSheet() {
      ReaderAnnotationsSheet.show(
        context,
        bookId: bookId,
        chapters: chapters.value,
        currentChapterId: currentChapter.value?.id,
        bookTitle: bookTitle.value,
        author: bookAuthor.value,
        coverPath: bookCoverPath.value,
        onJumpToChapter: (chapterId, startOffset) {
          final idx = chapters.value.indexWhere((c) => c.id == chapterId);
          if (idx >= 0) {
            resetPosition();
            currentChapter.value = chapters.value[idx];
            currentChapterIndex.value = idx;
          }
        },
      );
    }

    void handleListen(String text, String? sentence, int start, int end) {
      final chapter = currentChapter.value;
      final language = bookLanguage.value ?? 'en';
      if (chapter == null) return;
      final snippet = text.trim();
      if (snippet.isEmpty) return;
      _selectionSpeaker.speak(
        ref: ref,
        bookId: bookId,
        chapterId: chapter.id,
        text: snippet,
        language: language,
      );
    }

    Widget contentWidget;
    if (settings.readingMode == ReadingMode.continuous) {
      contentWidget = ContinuousReaderLayout(
        chapters: chapters.value,
        settings: settings,
        currentChapterIndex: currentChapterIndex.value,
        bookmarkedChapterIds: bookmarkedChapterIds.value,
        initialScrollProgress: savedProgress,
        restorePosition: resumePosition,
        onPositionChanged: onPositionChanged,
        onScrollProgress: onContinuousScrollProgress,
        onCurrentChapterChanged: onContinuousChapterChanged,
        onScrollDirectionChanged: onScrollDirectionChanged,
        onSettingsTap: showSettingsDrawer,
        onSearchTap: showSearchSheet,
        onRedownload: handleRedownload,
        isRedownloading: isRedownloading.value,
        onChapterSelected: (idx) {
          resetPosition();
          currentChapter.value = chapters.value[idx];
          currentChapterIndex.value = idx;
        },
        isBookmarked: isBookmarked,
        onBookmarkToggle: toggleBookmark,
        bookTitle: bookTitle.value,
        coverPath: bookCoverPath.value,
        onOpenAnnotations: showAnnotationsSheet,
        onHighlight: handleHighlight,
        onAddNote: handleAddNote,
        onShare: handleShare,
        onListen: handleListen,
        onErase: handleErase,
      );
    } else if (settings.readingMode == ReadingMode.realFlip) {
      contentWidget = RealFlipReaderLayout(
        chapters: chapters.value,
        settings: settings,
        currentChapterIndex: currentChapterIndex.value,
        bookmarkedChapterIds: bookmarkedChapterIds.value,
        initialProgress: savedProgress,
        restorePosition: resumePosition,
        onPositionChanged: onPositionChanged,
        onPageChanged: onPagedPageChanged,
        onProgressChanged: onPagedProgressChanged,
        onChapterSelected: goToPagedChapter,
        onSettingsTap: showSettingsDrawer,
        onSearchTap: showSearchSheet,
        onRedownload: handleRedownload,
        isRedownloading: isRedownloading.value,
        isBookmarked: isBookmarked,
        onBookmarkToggle: toggleBookmark,
        bookTitle: bookTitle.value,
        coverPath: bookCoverPath.value,
        onOpenAnnotations: showAnnotationsSheet,
        onHighlight: handleHighlight,
        onAddNote: handleAddNote,
        onShare: handleShare,
        onListen: handleListen,
        onErase: handleErase,
      );
    } else {
      contentWidget = PagedReaderLayout(
        chapters: chapters.value,
        settings: settings,
        currentChapterIndex: currentChapterIndex.value,
        bookmarkedChapterIds: bookmarkedChapterIds.value,
        initialProgress: savedProgress,
        restorePosition: resumePosition,
        onPositionChanged: onPositionChanged,
        onPageChanged: onPagedPageChanged,
        onProgressChanged: onPagedProgressChanged,
        onChapterSelected: goToPagedChapter,
        onSettingsTap: showSettingsDrawer,
        onSearchTap: showSearchSheet,
        onRedownload: handleRedownload,
        isRedownloading: isRedownloading.value,
        isBookmarked: isBookmarked,
        onBookmarkToggle: toggleBookmark,
        bookTitle: bookTitle.value,
        coverPath: bookCoverPath.value,
        onOpenAnnotations: showAnnotationsSheet,
        onHighlight: handleHighlight,
        onAddNote: handleAddNote,
        onShare: handleShare,
        onListen: handleListen,
        onErase: handleErase,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handlePop();
      },
      child: contentWidget,
    );
  }
}
