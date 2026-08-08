import 'dart:async';

import 'package:flutter/material.dart' hide WordBoundary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/molecules/app_error_state.dart';
import 'package:atlas_app/core/design_system/organisms/draggable_bottom_sheet.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/services/platform_service.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/reader/domain/entities/bookmark_entity.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/entities/reading_progress_snapshot.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/reader_repository_interface.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_shimmer.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/continuous_reader_layout.dart';
import 'package:atlas_app/reader/presentation/widgets/paged_reader_layout.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/reader_settings_sheet.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_session_builder.dart';
import 'package:atlas_app/reader/speech/speech_session.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';

class ReaderContent extends ConsumerStatefulWidget {
  const ReaderContent({
    super.key,
    required this.repo,
    required this.bookId,
    required this.settings,
  });

  final ReaderRepositoryInterface repo;
  final String bookId;
  final ReadingSettingsEntity settings;

  @override
  ConsumerState<ReaderContent> createState() => _ReaderContentState();
}

class _ReaderContentState extends ConsumerState<ReaderContent> {
  ChapterEntity? _currentChapter;

  /// Source of truth for which chapter is active — set directly by every
  /// selection path (never re-derived via chapters.indexOf(_currentChapter),
  /// which was doing an equality search that could resolve to the wrong
  /// chapter whenever two ChapterEntitys compared equal, and fed that wrong
  /// index into both the reader layouts' scroll/page position *and* their
  /// app bar title — a single bad index explaining both symptoms at once).
  int _currentChapterIndex = 0;
  List<ChapterEntity> _chapters = [];
  double _scrollProgress = 0.0;
  String? _initialChapterId;
  double? _initialScrollProgress;
  int? _initialPosition;
  bool _readQueryParam = false;
  bool _loading = true;
  String? _errorMessage;
  Set<String> _bookmarkedChapterIds = {};
  Timer? _saveDebounceTimer;
  PlatformService? _platformService;

  /// Last reported reading position (flat sentence index + total) for the
  /// current chapter, used by [_saveProgress] instead of the old hardcoded
  /// `0`. Reset on each chapter change so a stale chapter's index is never
  /// persisted under another chapter.
  int _currentSentenceIndex = 0;
  int _currentSentenceTotal = 0;

  String? _bookLanguage;
  String? _bookTitle;
  String? _bookCoverPath;
  SpeechCheckpoint? _restoredCheckpoint;
  StreamSubscription<SpeechEvent>? _speechSub;
  final _sessionBuilder = const SpeechSessionBuilder();

  @override
  void initState() {
    super.initState();
    _speechSub = ref
        .read(speechEngineProvider)
        .events
        .listen(_onSpeechEvent);
    _loadChapters();
  }

  void _onSpeechEvent(SpeechEvent event) {
    switch (event) {
      case ChapterFinished(:final chapterId):
        _advanceFromNarration(chapterId);
      case SentenceStarted(:final item):
        ref.read(activeWordBoundaryProvider.notifier).state = null;
        if (item.bookId == widget.bookId) {
          ref.read(activeSpeechItemProvider.notifier).state = item;
        }
      case WordBoundary(:final item, :final start, :final end, :final word):
        ref.read(activeWordBoundaryProvider.notifier).state =
            WordBoundary(item, start, end, word);
      case SpeechStopped() || SpeechCompleted():
        ref.read(activeSpeechItemProvider.notifier).state = null;
        ref.read(activeWordBoundaryProvider.notifier).state = null;
      default:
        break;
    }
  }

  void _advanceFromNarration(String finishedChapterId) {
    if (!mounted) return;
    final autoAdvance =
        ref.read(narrationSettingsProvider).value?.autoAdvanceChapter ?? true;
    if (!autoAdvance) return;
    final idx = _chapters.indexWhere((c) => c.id == finishedChapterId);
    if (idx < 0 || idx >= _chapters.length - 1) return;
    final next = _chapters[idx + 1];
    _resetPosition();
    setState(() {
      _currentChapter = next;
      _currentChapterIndex = idx + 1;
    });
    _saveProgress(next);
  }

  /// (Re)builds and loads the SpeechSession for [chapter] once its content is
  /// available, seeking to a restored checkpoint when applicable. Idempotent
  /// per chapter.
  Future<void> _syncSpeechSession(ChapterEntity chapter, String content) async {
    final engine = ref.read(speechEngineProvider);
    if (engine.session?.chapterId == chapter.id) return;

    final settings =
        ref.read(narrationSettingsProvider).value ??
        const NarrationSettings();
    final checkpoint = _restoredCheckpoint;
    final restoreHere =
        checkpoint != null &&
        checkpoint.bookId == widget.bookId &&
        checkpoint.chapterId == chapter.id;

    final session = _sessionBuilder.build(
      bookId: widget.bookId,
      chapter: chapter,
      content: content,
      language: _bookLanguage ?? 'en',
      settings: settings,
      sentenceIndex: restoreHere ? checkpoint.sentenceIndex : 0,
    );
    await engine.loadSession(session);
  }

  @override
  void didUpdateWidget(ReaderContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final os = oldWidget.settings;
    final ns = widget.settings;
    if (os.keepScreenAwake != ns.keepScreenAwake ||
        os.brightness != ns.brightness ||
        os.followSystemBrightness != ns.followSystemBrightness) {
      _applySystemSettings();
    }
  }

  void _applySystemSettings() {
    final svc = ref.read(platformServiceProvider);
    _platformService = svc;
    final s = widget.settings;
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

  Future<void> _loadChapters() async {
    final result = await widget.repo.getChapters(widget.bookId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result is Failure<List<ChapterEntity>>) {
        _errorMessage = (result).error.userMessage;
        return;
      }
      final loaded = (result as Success<List<ChapterEntity>>).value;
      if (loaded.isEmpty) {
        _errorMessage = 'No chapters found.';
        return;
      }
      _chapters = loaded;
      final initialIndex = _initialChapterId != null
          ? loaded.indexWhere((c) => c.id == _initialChapterId)
          : -1;
      if (_currentChapter == null) {
        _currentChapterIndex = initialIndex >= 0 ? initialIndex : 0;
        _currentChapter = loaded[_currentChapterIndex];
      }
      _initialChapterId = null;
    });
    await _loadBookmarks();
    await _loadNarrationContext();
    await _loadReadingProgress();
  }

  Future<void> _loadNarrationContext() async {
    if (!mounted) return;
    final bookResult = await widget.repo.getBookById(widget.bookId);
    if (bookResult is Success<BookEntity>) {
      _bookLanguage = bookResult.value.language;
      _bookTitle = bookResult.value.title;
      _bookCoverPath = bookResult.value.coverPath;
    }
    final checkpoint =
        await ref.read(speechRecoveryStoreProvider).load(widget.bookId);
    if (!mounted) return;
    setState(() {
      _restoredCheckpoint =
          checkpoint != null && _chapters.any((c) => c.id == checkpoint.chapterId)
          ? checkpoint
          : null;
    });
  }

  Future<void> _loadReadingProgress() async {
    final result = await widget.repo.getReadingProgress(widget.bookId);
    if (!mounted) return;
    if (result is Success<ReadingProgressSnapshot?>) {
      final snap = result.value;
      setState(() => _initialPosition = snap?.position);
    }
  }

  Future<void> _loadBookmarks() async {
    final result = await widget.repo.getBookmarks(widget.bookId);
    if (!mounted) return;
    if (result is Success<List<BookmarkEntity>>) {
      setState(() {
        _bookmarkedChapterIds =
            result.value.map((b) => b.chapterId).toSet();
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final chapter = _currentChapter;
    if (chapter == null) return;
    if (_bookmarkedChapterIds.contains(chapter.id)) {
      final result = await widget.repo.getBookmarks(widget.bookId);
      if (result is Success<List<BookmarkEntity>>) {
        final existing =
            result.value.where((b) => b.chapterId == chapter.id).toList();
        for (final b in existing) {
          await widget.repo.removeBookmark(b.id);
        }
      }
    } else {
      final now = DateTime.now();
      await widget.repo.addBookmark(BookmarkEntity(
        id: '${widget.bookId}_${chapter.id}_${now.millisecondsSinceEpoch}',
        bookId: widget.bookId,
        chapterId: chapter.id,
        position: 0,
        createdAt: now,
        updatedAt: now,
      ));
    }
    ref.invalidate(bookmarksProvider(widget.bookId));
    setState(() {
      if (_bookmarkedChapterIds.contains(chapter.id)) {
        _bookmarkedChapterIds.remove(chapter.id);
      } else {
        _bookmarkedChapterIds.add(chapter.id);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_readQueryParam) {
      final params = GoRouterState.of(context).uri.queryParameters;
      _initialChapterId = params['chapterId'];
      final progressParam = params['progress'];
      _initialScrollProgress =
          progressParam != null ? double.tryParse(progressParam) : null;
      _readQueryParam = true;
    }
    _applySystemSettings();
  }

  @override
  void dispose() {
    _speechSub?.cancel();
    _saveDebounceTimer?.cancel();
    // Best-effort fallback only (e.g. the widget is torn down by something
    // other than the user popping the reader route, such as a hot restart).
    // dispose() cannot be awaited by our caller, so this write can still
    // lose the race against a screen that refreshes as soon as the route
    // pops. The PopScope in build() is what guarantees the save actually
    // lands before a normal back-navigation completes — see _handlePop.
    if (_currentChapter != null) {
      _saveProgress(_currentChapter!);
    }
    _platformService?.setKeepScreenOn(false);
    _platformService?.resetBrightness();
    super.dispose();
  }

  bool _popInProgress = false;

  /// Flushes the current reading position to the database and then performs
  /// the pop ourselves, so that anything awaiting the pushed route's Future
  /// (e.g. `await navigator.push(route)` on the details screen) only resolves
  /// once the save has actually landed — closing the race that let the
  /// details/library screens read the old progress right after returning
  /// from the reader.
  Future<void> _handlePop() async {
    if (_popInProgress) return;
    _popInProgress = true;
    _saveDebounceTimer?.cancel();
    final chapter = _currentChapter;
    if (chapter != null) {
      await _saveProgress(chapter);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handlePop();
      },
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: ReadingViewTheme.light.background,
        body: const ChapterShimmer(vt: ReadingViewTheme.light),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        body: AppErrorState(
          message: _errorMessage!,
          technicalDetails: _errorMessage!,
        ),
      );
    }

    final chapters = _chapters;
    final settings = widget.settings;

    final currentChapter = _currentChapter;
    if (currentChapter != null) {
      final content = ref.watch(readerChapterContentProvider(currentChapter)).valueOrNull;
      if (content != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncSpeechSession(currentChapter, content);
        });
      }
    }

    final isBookmarked = _currentChapter != null &&
        _bookmarkedChapterIds.contains(_currentChapter!.id);

    final savedProgress = _scrollProgress > 0
        ? _scrollProgress
        : _initialScrollProgress;
    // The live sentence index (relative to the current chapter) is preferred
    // when it has been reported, so a mid-book mode switch carries the reader
    // forward instead of snapping back to the chapter-1-era resume point.
    final resumePosition =
        _currentSentenceIndex > 0 ? _currentSentenceIndex : _initialPosition;
    if (settings.readingMode == ReadingMode.continuous) {
      return ContinuousReaderLayout(
        chapters: chapters,
        settings: settings,
        currentChapterIndex: _currentChapterIndex,
        bookmarkedChapterIds: _bookmarkedChapterIds,
        initialScrollProgress: savedProgress,
        restorePosition: resumePosition,
        onPositionChanged: _onPositionChanged,
        onScrollProgress: _onContinuousScrollProgress,
        onCurrentChapterChanged: _onContinuousChapterChanged,
        onScrollDirectionChanged: _onScrollDirectionChanged,
        onSettingsTap: _showSettingsDrawer,
        onChapterSelected: (idx) {
          _resetPosition();
          setState(() {
            _currentChapter = _chapters[idx];
            _currentChapterIndex = idx;
          });
        },
        isBookmarked: isBookmarked,
        onBookmarkToggle: _toggleBookmark,
        bookTitle: _bookTitle,
        coverPath: _bookCoverPath,
      );
    }

    return PagedReaderLayout(
      chapters: chapters,
      settings: settings,
      currentChapterIndex: _currentChapterIndex,
      bookmarkedChapterIds: _bookmarkedChapterIds,
      initialProgress: savedProgress,
      restorePosition: resumePosition,
      onPositionChanged: _onPositionChanged,
      onPageChanged: _onPagedPageChanged,
      onProgressChanged: _onPagedProgressChanged,
      onChapterSelected: _goToPagedChapter,
      onSettingsTap: _showSettingsDrawer,
      isBookmarked: isBookmarked,
      onBookmarkToggle: _toggleBookmark,
      bookTitle: _bookTitle,
      coverPath: _bookCoverPath,
    );
  }

  void _onContinuousScrollProgress(double progress) {
    _scrollProgress = progress;
  }

  void _onContinuousChapterChanged(int index) {
    if (_currentChapter?.id != _chapters[index].id) {
      _resetPosition();
      setState(() {
        _currentChapter = _chapters[index];
        _currentChapterIndex = index;
      });
      _saveProgress(_chapters[index]);
    }
  }

  void _onScrollDirectionChanged(ScrollDirection direction) {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_currentChapter != null) _saveProgress(_currentChapter!);
    });
  }

  void _resetPosition() {
    _currentSentenceIndex = 0;
    _currentSentenceTotal = 0;
  }

  /// Stores the reader's current reading position so [_saveProgress] can
  /// persist it instead of the old hardcoded `0`. Called by both layouts as
  /// the user pages/scrolls.
  void _onPositionChanged(int sentenceIndex, int totalSentences) {
    _currentSentenceIndex = sentenceIndex;
    _currentSentenceTotal = totalSentences;
  }

  Future<void> _saveProgress(ChapterEntity chapter) async {
    await widget.repo.saveProgress(
      userId: 'local',
      bookId: widget.bookId,
      chapterId: chapter.id,
      percentage: _scrollProgress * 100,
      position: _currentSentenceIndex,
      totalPositions: _currentSentenceTotal,
    );
  }

  void _onPagedPageChanged(int chapterIndex) {
    // PagedReaderLayout reports the new page's exact sentence position (via
    // _onPositionChanged, which updates _currentSentenceIndex/_currentSentenceTotal)
    // BEFORE invoking this callback, so _saveProgress below always persists
    // the freshly reported position for whichever chapter we just landed on
    // — never a stale index left over from the chapter we paged away from.
    setState(() {
      _currentChapter = _chapters[chapterIndex];
      _currentChapterIndex = chapterIndex;
    });
    _saveProgress(_chapters[chapterIndex]);
  }

  void _onPagedProgressChanged(double progress) {
    _scrollProgress = progress;
  }

  void _goToPagedChapter(int index) {
    if (_currentChapter?.id != _chapters[index].id) {
      _resetPosition();
      setState(() {
        _currentChapter = _chapters[index];
        _currentChapterIndex = index;
      });
    }
  }

  void _showSettingsDrawer() {
    DraggableBottomSheet.show(
      context: context,
      id: 'reader_settings',
      initialHeight: 0.8,
      child: ReaderSettingsSheet(
        initialSettings: widget.settings,
      ),
    );
  }
}