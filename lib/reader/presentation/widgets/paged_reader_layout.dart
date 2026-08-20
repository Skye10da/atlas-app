import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:atlas_app/core/design_system/molecules/app_error_state.dart';
import 'package:atlas_app/core/design_system/organisms/draggable_bottom_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/controllers/reader_chrome_controller.dart';
import 'package:atlas_app/reader/presentation/providers/annotations_provider.dart';
import 'package:atlas_app/reader/presentation/providers/atlas_glossary_providers.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/utils/glossary_highlight_ranges.dart';
import 'package:atlas_app/reader/presentation/utils/reader_key_events.dart';
import 'package:atlas_app/reader/presentation/utils/chapter_position_resolver.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_chrome_pieces.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_index_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_shimmer.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_styles.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/glossary_term_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/pager.dart';
import 'package:atlas_app/core/design_system/widgets/app_context_menu.dart';
import 'package:atlas_app/reader/presentation/widgets/word_lookup_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bar_surface.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bottom_nav.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_chrome_bar.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_command_palette.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_edge_regions.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_mini_player.dart';
import 'package:atlas_app/reader/presentation/widgets/now_playing_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_right_panel.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';

class PagedReaderLayout extends ConsumerStatefulWidget {
  const PagedReaderLayout({
    super.key,
    required this.chapters,
    required this.settings,
    required this.currentChapterIndex,
    required this.bookmarkedChapterIds,
    this.initialProgress,
    required this.onPageChanged,
    required this.onProgressChanged,
    required this.onChapterSelected,
    required this.onSettingsTap,
    required this.isBookmarked,
    required this.onBookmarkToggle,
    this.bookTitle,
    this.coverPath,
    this.onHighlight,
    this.onAddNote,
    this.onShare,
    this.onSearchWeb,
    this.onListen,
    this.onErase,
    this.restorePosition,
    this.onPositionChanged,
  });

  final List<ChapterEntity> chapters;
  final ReadingSettingsEntity settings;
  final int currentChapterIndex;
  final Set<String> bookmarkedChapterIds;
  final double? initialProgress;
  final void Function(int chapterIndex) onPageChanged;
  final void Function(double progress) onProgressChanged;
  final void Function(int chapterIndex) onChapterSelected;
  final VoidCallback onSettingsTap;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;
  final String? bookTitle;
  final String? coverPath;

  /// A flat sentence index (from [onPositionChanged]) to resume at on open.
  /// `null` or `0` means "resume at the top of the current chapter".
  final int? restorePosition;

  /// Reports the current reading position as a flat sentence index into the
  /// chapter's rebuildable sentence sequence (plus the total), for persisting
  /// exact-position resume. Omit to disable position reporting.
  final void Function(int sentenceIndex, int totalSentences)? onPositionChanged;

  /// Called with the selected text and chosen color when the reader taps a
  /// highlight swatch in the context menu. Omit to hide highlighting.
  final void Function(String text, Color color, int start, int end)?
  onHighlight;

  /// Called with the selected text (and surrounding sentence, if available)
  /// when the reader taps "Note". Omit to hide the note action.
  final void Function(String text, String? sentence)? onAddNote;

  /// Called with the selected text when the reader taps "Share". Omit to
  /// hide the share action.
  final void Function(String text)? onShare;

  /// Called with the selected text when the reader taps "Search the web".
  /// Omit to hide the search action.
  final void Function(String text)? onSearchWeb;

  /// Called to speak the selected sentence once ("Listen"). Omit to hide the
  /// listen action.
  final void Function(String text, String? sentence, int start, int end)?
  onListen;

  /// Called to remove any stored highlight overlapping the selection. Omit to
  /// hide the erase action.
  final void Function(int start, int end)? onErase;

  @override
  ConsumerState<PagedReaderLayout> createState() => _PagedReaderLayoutState();
}

class _PagedReaderLayoutState extends ConsumerState<PagedReaderLayout>
    with ReaderChromeController {
  final _pageController = PageController();
  final Map<int, List<String>> _pageCache = {};
  final Map<int, String> _contentCache = {};
  final Set<int> _loadedChapters = {};

  /// Chapters whose fetch failed (network / source error) — rendered as an
  /// error state with a Retry action instead of an endless shimmer. A chapter
  /// in this set is, deliberately, also absent from [_pageCache], which is
  /// what already keeps [_maxNavigableGlobalPage] from letting the reader
  /// page past it until a retry succeeds.
  final Set<int> _failedChapters = {};
  final ValueNotifier<double> _progress = ValueNotifier<double>(0.0);
  int _totalPages = 0;
  int _currentGlobalPage = 0;
  String _cacheKey = '';
  bool _pendingChapterJump = true;
  double _layoutWidth = 0;
  double _layoutHeight = 0;
  int? _neighborPrefetchScheduledFor;
  static const double _maxReadingWidth = 720.0;

  /// The chapter the exact-position resume applies to — the chapter the reader
  /// opened on, so a later chapter selection never re-fires the resume.
  late final int _resumeChapterIndex = widget.currentChapterIndex;

  @override
  void initState() {
    super.initState();
    _cacheKey = _computeCacheKey();
  }

  bool _chromeInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_chromeInitialized) {
      _chromeInitialized = true;
      initReaderChrome(
        isDarkTheme:
            Theme.of(context).colorScheme.brightness == Brightness.dark,
      );
    }
  }

  @override
  void dispose() {
    disposeReaderChrome();
    _pageController.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _onDesktopSpreadTapUp(TapUpDetails details, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final x = details.localPosition.dx;
    final spreadBefore = _currentGlobalPage ~/ 2;
    if (x < width / 3) {
      if (spreadBefore > 0) {
        final target = (spreadBefore - 1) * 2;
        _pageController.animateToPage(
          target ~/ 2,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    } else if (x > width * 2 / 3) {
      if (_currentGlobalPage < _totalPages - 1) {
        final target = (spreadBefore + 1) * 2;
        if (_canAdvanceTo(target)) {
          _pageController.animateToPage(
            target ~/ 2,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        }
      }
    } else {
      toggleChrome(
        isDarkTheme:
            Theme.of(context).colorScheme.brightness == Brightness.dark,
      );
    }
  }

  void _onMobileTapUp(TapUpDetails details, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final x = details.localPosition.dx;
    if (x < width / 3) {
      if (_currentGlobalPage > 0) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    } else if (x > width * 2 / 3) {
      if (_currentGlobalPage < _totalPages - 1 &&
          _canAdvanceTo(_currentGlobalPage + 1)) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    } else {
      toggleChrome(
        isDarkTheme:
            Theme.of(context).colorScheme.brightness == Brightness.dark,
      );
    }
  }

  void _applyBrightness(double newBrightness) {
    final notifier = ref.read(readingSettingsProvider.notifier);
    notifier.setBrightness(newBrightness);
    final svc = ref.read(platformServiceProvider);
    svc.setBrightness(newBrightness, smooth: true);
  }

  int get _totalSpreads => (_totalPages + 1) ~/ 2;

  double _pageWidthForCurrentMode() {
    final rawWidth = _layoutWidth > 0 ? _layoutWidth : 800.0;
    if (isWideDesktop) {
      final maxSpreadWidth =
          rawWidth -
          ((rightPanelVisible || narrationPanelVisible)
              ? ReaderChromeController.rightPanelWidth
              : 0);
      final pageArea = maxSpreadWidth * 0.9;
      return (pageArea / 2).clamp(280.0, 520.0);
    }
    return rawWidth > _maxReadingWidth ? _maxReadingWidth : rawWidth;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isDesktop = MediaQuery.of(context).size.width >= 840;
    if (!isDesktop) return KeyEventResult.ignored;

    final common = handleCommonReaderKeys(
      event,
      commandPaletteVisible: commandPaletteVisible,
      onClosePalette: () => setState(() => commandPaletteVisible = false),
      onToggleChrome: () => toggleChrome(
        isDarkTheme:
            Theme.of(context).colorScheme.brightness == Brightness.dark,
      ),
      onOpenPalette: () => setState(() => commandPaletteVisible = true),
    );
    if (common != KeyEventResult.ignored) return common;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      resetChromeTimer(
        isDarkTheme:
            Theme.of(context).colorScheme.brightness == Brightness.dark,
      );
      if (_currentGlobalPage > 0) {
        final step = isWideDesktop ? 2 : 1;
        final target = _currentGlobalPage - step;
        if (isWideDesktop) {
          _pageController.animateToPage(
            target ~/ 2,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        } else {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        }
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      resetChromeTimer(
        isDarkTheme:
            Theme.of(context).colorScheme.brightness == Brightness.dark,
      );
      if (_currentGlobalPage < _totalPages - 1) {
        if (isWideDesktop) {
          final target = _currentGlobalPage + 2;
          if (_canAdvanceTo(target)) {
            _pageController.animateToPage(
              target ~/ 2,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
            );
          }
        } else if (_canAdvanceTo(_currentGlobalPage + 1)) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        }
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  String _computeCacheKey() {
    final s = widget.settings;
    // Round to whole pixels: transient size fluctuations during route
    // transitions (e.g. exiting the reader) can otherwise register as a
    // "layout changed" event and trigger repagination of every loaded
    // chapter mid-animation.
    final w = _layoutWidth.round();
    final h = _layoutHeight.round();
    return '${s.fontSize}_${s.fontFamily}_${s.fontWeight}_${s.lineHeight}_${s.marginPreset.name}_${s.textAlignment.name}_${w}x$h';
  }

  bool _needsRepagination() {
    final newKey = _computeCacheKey();
    if (newKey != _cacheKey) {
      _cacheKey = newKey;
      return true;
    }
    return false;
  }

  (int chapterIndex, int pageInChapter) _globalToLocal(int global) {
    int remaining = global;
    for (int i = 0; i < widget.chapters.length; i++) {
      final len = _pagesFor(i);
      if (remaining < len) return (i, remaining);
      remaining -= len;
    }
    final last = widget.chapters.length - 1;
    return (last, (_pagesFor(last) - 1).clamp(0, 0));
  }

  int _localToGlobal(int chapterIndex, int pageInChapter) {
    int offset = 0;
    for (int i = 0; i < chapterIndex; i++) {
      offset += _pagesFor(i);
    }
    return offset + pageInChapter;
  }

  int _pagesFor(int index) {
    final cached = _pageCache[index];
    if (cached != null) return cached.length;
    final chapter = widget.chapters[index];
    if (chapter.pageCount > 0) return chapter.pageCount;
    // Not yet paginated this session AND no persisted estimate — treating
    // this as 0 pages (the old behavior) silently collapsed every global
    // page-index computation that summed over unpaginated preceding
    // chapters, which is what made jumping to a chapter beyond the first
    // land back on chapter 1 (studied in novel_reader's per-chapter-only
    // pagination model, which sidesteps this by never summing across
    // chapters at all — see reading_area.dart's ValueKey('chapter_$i')
    // pattern). A word-count estimate keeps Atlas's cross-chapter cache
    // and prefetch, while avoiding the confident-zero collapse.
    return _estimatedPageCount(chapter.wordCount);
  }

  /// ~275 words/page is a standard paperback-equivalent estimate. Only used
  /// until real pagination (which accounts for the reader's actual font
  /// size, margins, and viewport) replaces it — this is a placeholder for
  /// jump-target math, never for rendering.
  int _estimatedPageCount(int wordCount) {
    if (wordCount <= 0) return 1;
    return math.max(1, (wordCount / 275).ceil());
  }

  static const ChapterPositionResolver _resolver = ChapterPositionResolver();

  /// Whether an exact resume was requested (a saved sentence index > 0).
  bool get _hasPendingRestore =>
      widget.restorePosition != null && widget.restorePosition! > 0;

  /// Character offset of [localPage]'s first character within chapter
  /// [chapterIndex]'s paginated content (0 for the first page).
  int _pageStartOffset(int chapterIndex, int localPage) {
    final cache = _pageCache[chapterIndex];
    if (cache == null || localPage <= 0) return 0;
    var offset = 0;
    final upto = math.min(localPage, cache.length);
    for (var i = 0; i < upto; i++) {
      offset += cache[i].length;
    }
    return offset;
  }

  List<HighlightEntry> _highlightsFor(ChapterEntity chapter, String content) {
    final userHighlights =
        ref.watch(annotationsProvider(chapter.bookId)).highlights[chapter.id] ??
        const [];
    if (content.isEmpty) return userHighlights;
    final entries =
        ref.watch(atlasGlossaryProvider(chapter.bookId)).valueOrNull ??
        const [];
    return [
      ...userHighlights,
      ...glossaryHighlightRanges(
        chapterId: chapter.id,
        content: content,
        entries: entries,
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
    ];
  }

  /// The local page of [chapterIndex] that contains [charOffset], or the last
  /// page when the offset is past the end.
  int _localPageForCharOffset(int chapterIndex, int charOffset) {
    final cache = _pageCache[chapterIndex];
    if (cache == null || cache.isEmpty) return 0;
    var start = 0;
    for (var i = 0; i < cache.length; i++) {
      final end = start + cache[i].length;
      if (charOffset < end) return i;
      start = end;
    }
    return cache.length - 1;
  }

  /// Resolves the exact resume sentence ([widget.restorePosition]) to a local
  /// page in [chapterIndex], or `null` until that chapter's content has been
  /// paginated.
  int? _restoreLocalPage(int chapterIndex) {
    final pos = widget.restorePosition;
    if (pos == null || pos <= 0) return null;
    final content = _contentCache[chapterIndex];
    if (content == null || content.isEmpty) return null;
    final cache = _pageCache[chapterIndex];
    if (cache == null || cache.isEmpty) return null;
    final charOffset = _resolver.charOffsetForSentenceIndex(content, pos);
    if (charOffset == null) return null;
    return _localPageForCharOffset(chapterIndex, charOffset);
  }

  /// Reports the flat sentence index at the top of the current page so the
  /// parent can persist an exact-position resume.
  void _reportPositionFromCurrentPage() {
    final onPosition = widget.onPositionChanged;
    if (onPosition == null) return;
    final (chIdx, localPage) = _globalToLocal(_currentGlobalPage);
    final content = _contentCache[chIdx];
    if (content == null || content.isEmpty) return;
    final offset = _pageStartOffset(chIdx, localPage);
    final resolved = _resolver.resolve(content, offset);
    onPosition(resolved.index, resolved.total);
  }

  /// Jumps the controller to [target] global page. Retries across a few
  /// frames if the PageView hasn't attached yet (common right after this
  /// layout is freshly created, e.g. on a reading-mode switch) — a single
  /// unconditional postFrameCallback would otherwise silently drop the jump
  /// whenever `hasClients` isn't true on that exact frame, leaving the
  /// PageView stuck on its default page 0 with no retry, since callers
  /// already consider the pending jump "handled" by the time this runs.
  void _jumpControllerTo(int target, {int retries = 5}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(isWideDesktop ? target ~/ 2 : target);
        return;
      }
      if (retries > 0) {
        _jumpControllerTo(target, retries: retries - 1);
      }
    });
  }

  @override
  void didUpdateWidget(PagedReaderLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentChapterIndex == oldWidget.currentChapterIndex) return;
    // Only an explicit chapter selection (index sheet / palette / panel)
    // should re-anchor the pages here. Natural paging across a chapter
    // boundary also changes `currentChapterIndex`, but the PageView has
    // already positioned itself — jumping would snap the reader back to
    // page 0 of the chapter they just left behind.
    final explicit = _pendingExplicitChapter;
    _pendingExplicitChapter = null;
    if (explicit != widget.currentChapterIndex) return;
    final targetIndex = widget.currentChapterIndex;
    if (_pageCache[targetIndex] == null) {
      // Not paginated yet: defer so the jump lands on real content instead of
      // being clamped back to the nearest loaded chapter. `build` fires the
      // jump once pagination completes.
      _pendingJumpToChapter = targetIndex;
      return;
    }
    final target = _localToGlobal(targetIndex, 0);
    _currentGlobalPage = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.animateToPage(
          isWideDesktop ? target ~/ 2 : target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
    _reportPositionFromCurrentPage();
  }

  /// The deepest global page the reader may navigate to. When a chapter is
  /// still loading, only its *first* page may be entered — so its shimmer and
  /// status overlay can be shown — and no page beyond that is reachable until
  /// its content has been paginated. Chapters that ARE paginated are always
  /// navigable, even when reached out of order by an explicit jump — otherwise
  /// leaping from 21 → 40 would be clamped back to the nearest loaded chapter.
  int _maxNavigableGlobalPage() {
    int maxPage = 0;
    if (widget.chapters.isNotEmpty) {
      var lastReady = -1;
      for (var i = 0; i < widget.chapters.length; i++) {
        if (_pageCache[i] != null) {
          lastReady = i;
        } else {
          break;
        }
      }
      maxPage = lastReady == -1
          ? 0
          : lastReady == widget.chapters.length - 1
          ? _localToGlobal(lastReady, math.max(0, _pagesFor(lastReady) - 1))
          : _localToGlobal(lastReady + 1, 0);
    }
    for (var i = 0; i < widget.chapters.length; i++) {
      final cache = _pageCache[i];
      if (cache == null || cache.isEmpty) continue;
      final end = _localToGlobal(i, cache.length - 1);
      if (end > maxPage) maxPage = end;
    }
    return maxPage;
  }

  /// Whether advancing to [globalPage] is allowed given the chapters that
  /// still have their shimmer active.
  bool _canAdvanceTo(int globalPage) {
    if (globalPage >= _totalPages) return false;
    return globalPage <= _maxNavigableGlobalPage();
  }

  void _ensureChapterLoaded(int index) {
    // A chapter that already failed only retries when the reader taps
    // "Retry" (`_retryChapter`) — never silently on every page turn or
    // prefetch pass, which would just hammer a source that's already down.
    if (_loadedChapters.contains(index) || _failedChapters.contains(index)) {
      return;
    }
    _loadedChapters.add(index);
    final chapter = widget.chapters[index];
    final cached = ref.read(readerChapterContentProvider(chapter));
    cached.whenOrNull(
      data: (content) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onContentLoaded(index, content);
      }),
    );
    if (cached is! AsyncData) {
      _loadContent(index, chapter);
    }
  }

  Future<void> _loadContent(int index, ChapterEntity chapter) async {
    try {
      // Route through `readerChapterContentProvider` (not a raw file read) so
      // downloaded chapters get the same on-device translation + glossary pass
      // the continuous reader applies. The provider also owns download +
      // session-refresh handling.
      final content = await ref.read(
        readerChapterContentProvider(chapter).future,
      );
      if (!mounted) return;
      if (_failedChapters.remove(index) && mounted) setState(() {});
      _onContentLoaded(index, content);
    } on Object {
      _markChapterFailed(index);
    }
  }

  /// Marks [index] as failed so its page shows a Retry action instead of an
  /// endless shimmer, and lets a future retry re-trigger the fetch (dropping
  /// it from [_loadedChapters], which is what gates re-entry into
  /// [_ensureChapterLoaded]).
  void _markChapterFailed(int index) {
    _loadedChapters.remove(index);
    if (!mounted) return;
    setState(() => _failedChapters.add(index));
  }

  /// Retries a failed chapter fetch: clears the failed/loaded markers and
  /// re-kicks the same load path a fresh page-in would use.
  void _retryChapter(int index) {
    setState(() => _failedChapters.remove(index));
    ref.invalidate(readerChapterContentProvider(widget.chapters[index]));
    _ensureChapterLoaded(index);
  }

  /// The shimmer-or-error placeholder shown for a chapter whose pages aren't
  /// cached yet — a plain loading shimmer while it's in flight, or a Retry
  /// prompt once [_markChapterFailed] has recorded a failure. Building this
  /// does not itself trigger a (re)fetch; callers decide that.
  Widget _buildChapterLoadingState(
    int chIdx,
    ReadingViewTheme vt, {
    required bool showHeaders,
    required ColorScheme colorScheme,
  }) {
    if (_failedChapters.contains(chIdx)) {
      return Container(
        color: vt.resolve(colorScheme).background,
        child: AppErrorState(
          message:
              'Could not load this chapter. Check your connection and try again.',
          onRetry: () => _retryChapter(chIdx),
        ),
      );
    }
    return Stack(
      children: [
        const Positioned.fill(child: SizedBox.expand()),
        ChapterShimmer(
          vt: vt,
          showHeaders: showHeaders,
          fontSize: widget.settings.fontSize,
          lineHeight: widget.settings.lineHeight,
        ),
        ReaderLoadingOverlay(chapter: widget.chapters[chIdx], vt: vt),
      ],
    );
  }

  void _recomputeTotalPages() {
    _totalPages = 0;
    for (int i = 0; i < widget.chapters.length; i++) {
      _totalPages += _pagesFor(i);
    }
  }

  final Set<int> _paginationInFlight = {};

  /// Character offset within each chapter's text where the next chunk of
  /// pagination should resume. Entries are removed once pagination completes.
  final Map<int, int> _chunkedOffset = {};

  /// Pages accumulated across multiple frames for a chapter that is still
  /// being paginated. Written to [_pageCache] only once all text is covered.
  final Map<int, List<String>> _chunkedAccumulator = {};

  /// Maximum number of pages to lay out per frame before yielding.
  static const int _chunkedMaxPagesPerFrame = 5;

  /// Runs pagination for [index] after the current frame has been painted,
  /// so any in-progress build can show a loading spinner first instead of
  /// the UI thread blocking silently on the previous frame.
  void _schedulePagination(int index, String content) {
    if (_paginationInFlight.contains(index)) return;
    _paginationInFlight.add(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paginationInFlight.remove(index);
      if (!mounted) return;
      _paginateChapterIncremental(index, content);
    });
  }

  /// Paginates [content] for chapter [index] in chunks of
  /// [_chunkedMaxPagesPerFrame] pages, yielding back to the event loop
  /// between chunks so the UI stays responsive for long chapters.
  void _paginateChapterIncremental(int index, String content) {
    final colorScheme = Theme.of(context).colorScheme;
    final s = widget.settings;
    final horizontalMargin = switch (s.marginPreset) {
      MarginPreset.narrow => AppSpacing.md,
      MarginPreset.normal => AppSpacing.lg,
      MarginPreset.wide => AppSpacing.xxl,
    };
    final verticalMargin = switch (s.marginPreset) {
      MarginPreset.narrow => AppSpacing.sm,
      MarginPreset.normal => AppSpacing.md,
      MarginPreset.wide => AppSpacing.lg,
    };
    final rawHeight = _layoutHeight > 0
        ? _layoutHeight
        : MediaQuery.of(context).size.height;
    final width = _pageWidthForCurrentMode();
    final pageWidth = width - horizontalMargin * 2;
    final pageHeight = rawHeight - verticalMargin * 2;

    final baseStyle = TextStyle(
      fontSize: s.fontSize,
      height: s.lineHeight,
      letterSpacing: s.letterSpacing,
      color: s.theme.resolve(colorScheme).text,
      fontWeight: s.fontWeight != null ? FontWeight(s.fontWeight!) : null,
    );
    final textStyle = s.fontFamily != null
        ? GoogleFonts.getFont(s.fontFamily!, textStyle: baseStyle)
        : baseStyle;

    final startOffset = _chunkedOffset[index] ?? 0;
    final result = Pager.paginateChunked(
      text: content,
      textStyle: textStyle,
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      startIndex: startOffset,
      maxPages: _chunkedMaxPagesPerFrame,
    );

    _chunkedAccumulator.putIfAbsent(index, () => []).addAll(result.pages);

    if (result.complete) {
      _pageCache[index] = _chunkedAccumulator.remove(index) ?? [''];
      _chunkedOffset.remove(index);
      _recomputeTotalPages();
      ref
              .read(chapterLoadPhaseProvider(widget.chapters[index]).notifier)
              .state =
          ChapterLoadPhase.done;
      setState(() {});
    } else {
      _chunkedOffset[index] = result.endIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _paginateChapterIncremental(index, content);
      });
    }
  }

  void _onContentLoaded(int index, String content) {
    _contentCache[index] = content;
    if (_needsRepagination() || _pageCache[index] == null) {
      _schedulePagination(index, content);
    } else {
      _recomputeTotalPages();
      ref
              .read(chapterLoadPhaseProvider(widget.chapters[index]).notifier)
              .state =
          ChapterLoadPhase.done;
    }
    if (mounted) setState(() {});
  }

  /// Loads the chapters adjacent to [currentIndex] one frame *after* the
  /// current chapter has had a chance to render — so opening (or turning to)
  /// a chapter never pays the cost of paginating its neighbors too. As the
  /// reader progresses and `currentIndex` changes on a later build, this
  /// naturally prefetches the new neighbors the same way, one at a time.
  void _scheduleNeighborPrefetch(int currentIndex, int chapterCount) {
    if (_neighborPrefetchScheduledFor == currentIndex) return;
    _neighborPrefetchScheduledFor = currentIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (currentIndex > 0) _ensureChapterLoaded(currentIndex - 1);
      if (currentIndex < chapterCount - 1) {
        _ensureChapterLoaded(currentIndex + 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vt = widget.settings.theme;
    final colorScheme = Theme.of(context).colorScheme;
    final chapters = widget.chapters;
    final currentIndex = widget.currentChapterIndex;

    _ensureChapterLoaded(currentIndex);
    _scheduleNeighborPrefetch(currentIndex, chapters.length);

    final needsRepaginate = _needsRepagination();
    if (needsRepaginate) {
      // A settings change (font size, margins, etc.) invalidates all cached
      // pages. Cancel any in-flight chunked pagination so each chapter can
      // be re-scheduled fresh on the next frame.
      _paginationInFlight.clear();
      _chunkedOffset.clear();
      _chunkedAccumulator.clear();
    }
    for (final index in List<int>.from(_loadedChapters)) {
      if (_pageCache[index] == null || needsRepaginate) {
        final content = _contentCache[index];
        if (content != null) {
          _schedulePagination(index, content);
        }
      }
    }

    // Re-paginate any loaded chapter whose rendered text changed — the
    // translation toggle, a language switch or a glossary edit invalidates
    // `readerChapterContentProvider`, which re-resolves here with new content.
    // Without this, pages would keep showing the stale text until the chapter
    // was revisited.
    for (final index in List<int>.from(_loadedChapters)) {
      final content = ref
          .watch(readerChapterContentProvider(widget.chapters[index]))
          .valueOrNull;
      if (content != null && _contentCache[index] != content) {
        _contentCache[index] = content;
        // Cancel any in-flight pagination for this chapter so the new
        // content can be paginated fresh.
        _paginationInFlight.remove(index);
        _chunkedOffset.remove(index);
        _chunkedAccumulator.remove(index);
        _schedulePagination(index, content);
      }
    }

    // A deferred explicit jump can fire now that its chapter is paginated.
    final pendingJump = _pendingJumpToChapter;
    if (pendingJump != null && _pageCache[pendingJump] != null) {
      _pendingJumpToChapter = null;
      final target = _localToGlobal(pendingJump, 0);
      _currentGlobalPage = target;
      _jumpControllerTo(target);
      _reportPositionFromCurrentPage();
    }

    // Capture where the reader currently sits, in chapter-relative terms,
    // using this build's *pre-recompute* page counts — so that if a
    // background pagination pass (below) changes how many pages a
    // preceding chapter actually has, we can re-express the same logical
    // position in the new page-index space instead of leaving the global
    // page pointer stranded on whatever content now happens to live there.
    final oldTotalPages = _totalPages;
    int? anchorChapter;
    int? anchorLocalPage;
    if (!_pendingChapterJump && oldTotalPages > 0) {
      final (ch, pg) = _globalToLocal(_currentGlobalPage);
      anchorChapter = ch;
      anchorLocalPage = pg;
    }

    _totalPages = 0;
    for (int i = 0; i < chapters.length; i++) {
      _totalPages += _pagesFor(i);
    }

    if (anchorChapter != null && _totalPages != oldTotalPages) {
      final newGlobalPage = _localToGlobal(
        anchorChapter,
        anchorLocalPage!,
      ).clamp(0, _totalPages - 1);
      if (newGlobalPage != _currentGlobalPage) {
        _currentGlobalPage = newGlobalPage;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(
              isWideDesktop ? newGlobalPage ~/ 2 : newGlobalPage,
            );
          }
        });
      }
    } else if (needsRepaginate && _currentGlobalPage >= _totalPages) {
      _currentGlobalPage = 0;
    }

    if (_pendingChapterJump) {
      // Exact-position resume: resolve the saved sentence index to a page
      // within the chapter we opened on. Kept armed until that chapter's
      // content has been paginated, so a slow/async load never strands the
      // reader on chapter one — and never approximated from a whole-book
      // percentage, which is what used to land on the wrong chapter.
      final resumePage = _restoreLocalPage(_resumeChapterIndex);
      if (resumePage != null) {
        _pendingChapterJump = false;
        final target = _localToGlobal(_resumeChapterIndex, resumePage);
        _currentGlobalPage = target;
        _progress.value = _totalPages > 0
            ? _currentGlobalPage / _totalPages
            : 0.0;
        widget.onProgressChanged(
          _totalPages > 0 ? _currentGlobalPage / _totalPages : 0.0,
        );
        _jumpControllerTo(target);
      } else if (!_hasPendingRestore && _totalPages > 0) {
        // No exact resume (legacy row or no saved position): land on the top
        // of the current chapter, never a whole-book estimate. When a resume
        // IS pending but not yet resolvable, stay armed for the next build.
        _pendingChapterJump = false;
        final target = _localToGlobal(widget.currentChapterIndex, 0);
        _currentGlobalPage = target;
        _progress.value = _totalPages > 0
            ? _currentGlobalPage / _totalPages
            : 0.0;
        widget.onProgressChanged(
          _totalPages > 0 ? _currentGlobalPage / _totalPages : 0.0,
        );
        _jumpControllerTo(target);
      }
    }

    _progress.value = _totalPages > 0 ? _currentGlobalPage / _totalPages : 0.0;

    if (!_contentCache.containsKey(currentIndex) || _totalPages == 0) {
      return Scaffold(
        backgroundColor: vt.resolve(colorScheme).background,
        extendBodyBehindAppBar: true,
        appBar: ReaderBarSurface(
          style: widget.settings.chromeStyle,
          color: colorScheme.surfaceContainerHigh,
          child: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            foregroundColor: colorScheme.onSurface,
            title: Text(
              chapters[widget.currentChapterIndex].title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.text_fields,
                  color: vt.resolve(colorScheme).text,
                ),
                onPressed: widget.onSettingsTap,
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: SizedBox.expand()),
            ChapterShimmer(
              vt: vt,
              showHeaders: true,
              fontSize: widget.settings.fontSize,
              lineHeight: widget.settings.lineHeight,
            ),
            ReaderLoadingOverlay(chapter: chapters[currentIndex], vt: vt),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: vt.resolve(colorScheme).background,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: chromeVisible
          ? ReaderBarSurface(
              style: widget.settings.chromeStyle,
              color: colorScheme.surfaceContainerHigh,
              child: ReaderChromeBar(
                title: chapters[currentIndex].title,
                textColor: colorScheme.onSurface,
                showPanelToggle: isDesktop,
                rightPanelVisible: rightPanelVisible,
                onTogglePanel: toggleRightPanel,
                onSettingsTap: widget.onSettingsTap,
              ),
            )
          : null,
      bottomNavigationBar: chromeVisible
          ? ReaderBarSurface(
              style: widget.settings.chromeStyle,
              color: colorScheme.surfaceContainerHigh,
              child: ReaderBottomNav(
                textColor: colorScheme.onSurface,
                onSettingsTap: widget.onSettingsTap,
                onChapterIndexTap: () => _showChapterIndex(context),
                onBookmarkTap: widget.onBookmarkToggle,
                isBookmarked: widget.isBookmarked,
                currentChapterTitle: chapters[currentIndex].title,
                currentChapterNumber: currentIndex,
                totalChapters: chapters.length,
                bookTitle: widget.bookTitle,
                coverPath: widget.coverPath,
                progress: _progress,
                progressColor: widget.settings.theme
                    .resolve(colorScheme)
                    .accent,
                onListenTap: isDesktop ? toggleNarrationPanel : null,
              ),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth != _layoutWidth ||
              constraints.maxHeight != _layoutHeight) {
            _layoutWidth = constraints.maxWidth;
            _layoutHeight = constraints.maxHeight;
            _cacheKey = '';
          }
          return Stack(
            children: [
              Focus(
                autofocus: true,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.escape) {
                    if (rightPanelVisible || narrationPanelVisible) {
                      hideRightPanel();
                      return KeyEventResult.handled;
                    }
                  }
                  return _handleKeyEvent(node, event);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (details) {
                    if (rightPanelVisible || narrationPanelVisible) {
                      hideRightPanel();
                      return;
                    }
                    if (!isDesktop) {
                      _onMobileTapUp(details, constraints);
                    } else if (isWideDesktop) {
                      _onDesktopSpreadTapUp(details, constraints);
                    } else {
                      toggleChrome(
                        isDarkTheme:
                            Theme.of(context).colorScheme.brightness ==
                            Brightness.dark,
                      );
                    }
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (pageIndex) {
                      // Any page change supersedes a deferred leap.
                      _pendingJumpToChapter = null;
                      var global = isWideDesktop ? pageIndex * 2 : pageIndex;
                      final maxAllowed = _maxNavigableGlobalPage();
                      if (global > maxAllowed) {
                        global = maxAllowed;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _pageController.hasClients) {
                            _pageController.jumpToPage(
                              isWideDesktop ? maxAllowed ~/ 2 : maxAllowed,
                            );
                          }
                        });
                      }
                      _currentGlobalPage = global;
                      _progress.value = _totalPages > 0
                          ? _currentGlobalPage / _totalPages
                          : 0.0;
                      final (chIdx, _) = _globalToLocal(_currentGlobalPage);
                      _ensureChapterLoaded(chIdx);
                      if (chIdx + 1 < chapters.length) {
                        _ensureChapterLoaded(chIdx + 1);
                      }
                      // Report the exact sentence position for the page we've
                      // just landed on BEFORE notifying the parent of the
                      // chapter/page change. The parent's onPageChanged
                      // handler persists progress synchronously using
                      // whatever position was last reported — if that
                      // notification fired first, the save would always
                      // capture the *previous* page's position (one turn
                      // behind), and when the turn also crossed a chapter
                      // boundary, that stale position would be persisted
                      // under the *new* chapter's id, corrupting resume.
                      _reportPositionFromCurrentPage();
                      widget.onPageChanged(chIdx);
                      widget.onProgressChanged(
                        _totalPages > 0
                            ? _currentGlobalPage / _totalPages
                            : 0.0,
                      );
                      resetChromeTimer(
                        isDarkTheme:
                            Theme.of(context).colorScheme.brightness ==
                            Brightness.dark,
                      );
                    },
                    itemCount: isWideDesktop ? _totalSpreads : _totalPages,
                    itemBuilder: (context, index) {
                      if (isWideDesktop) {
                        return _buildSpread(
                          index,
                          vt,
                          chapters,
                          colorScheme: colorScheme,
                        );
                      }
                      return _buildSinglePage(
                        index,
                        vt,
                        chapters,
                        colorScheme: colorScheme,
                      );
                    },
                  ),
                ),
              ),
              if (!isDesktop)
                BrightnessEdgeGestureRegion(
                  onVerticalDragStart: (details) => onEdgeBrightnessStart(
                    details,
                    followSystemBrightness:
                        widget.settings.followSystemBrightness,
                    currentBrightness: widget.settings.brightness,
                  ),
                  onVerticalDragUpdate: (details) => onEdgeBrightnessUpdate(
                    details,
                    onChanged: _applyBrightness,
                  ),
                  onVerticalDragEnd: onEdgeBrightnessEnd,
                ),
              if (isDesktop)
                DesktopRightPanelRegion(
                  visible: rightPanelVisible || narrationPanelVisible,
                  chromeVisible: chromeVisible,
                  panelWidth: ReaderChromeController.rightPanelWidth,
                  onHoverReveal: showRightPanelOnHover,
                  panel: narrationPanelVisible
                      ? NowPlayingPanel(
                          bookTitle: widget.bookTitle,
                          coverPath: widget.coverPath,
                          chapterTitle: chapters[currentIndex].title,
                          accent: widget.settings.theme
                              .resolve(colorScheme)
                              .accent,
                          onClose: closeNarrationPanel,
                        )
                      : ReaderRightPanel(
                          chapters: chapters,
                          currentChapterIndex: currentIndex,
                          bookmarkedChapterIds: widget.bookmarkedChapterIds,
                          onChapterSelected: (idx) {
                            _selectChapterExplicitly(idx);
                          },
                          onBookmarkToggle: widget.onBookmarkToggle,
                          isBookmarked: widget.isBookmarked,
                          onClose: hideRightPanel,
                          settings: widget.settings,
                        ),
                ),
              if (commandPaletteVisible)
                ReaderCommandPalette(
                  chapters: chapters,
                  currentChapterIndex: currentIndex,
                  onChapterSelected: (idx) {
                    _selectChapterExplicitly(idx);
                  },
                  onToggleBookmark: widget.onBookmarkToggle,
                  isBookmarked: widget.isBookmarked,
                  onToggleSettings: widget.onSettingsTap,
                  onTogglePanel: toggleRightPanel,
                  onClose: () => setState(() => commandPaletteVisible = false),
                ),
              if (!narrationPanelVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: NarrationMiniPlayer(
                    bookTitle: widget.bookTitle,
                    coverPath: widget.coverPath,
                    chapterTitle: chapters[currentIndex].title,
                    accent: widget.settings.theme.resolve(colorScheme).accent,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _wrapWithPageAnimation(Widget page, int index) {
    final animation = widget.settings.pageTurnAnimation;
    if (animation == PageTurnAnimation.slide) return page;

    return ClipRect(
      key: ValueKey('page_$index'),
      child: ListenableBuilder(
        listenable: _pageController,
        builder: (context, child) {
          final pagePos = _pageController.hasClients
              ? (_pageController.page ?? index.toDouble())
              : index.toDouble();
          final offset = pagePos - index;
          final absOffset = offset.abs().clamp(0.0, 1.0);
          final viewportWidth = _layoutWidth > 0 ? _layoutWidth : 360.0;
          final isLeaving = offset < 0;

          switch (animation) {
            case PageTurnAnimation.fade:
              return Opacity(
                opacity: (1.0 - absOffset).clamp(0.0, 1.0),
                child: child,
              );

            case PageTurnAnimation.reveal:
              final slideOffset = offset.clamp(-1.0, 0.0);
              return Transform.translate(
                offset: Offset(-slideOffset * viewportWidth, 0),
                child: child,
              );

            case PageTurnAnimation.cube:
              final angle = (isLeaving ? -offset : offset).clamp(
                -math.pi / 2,
                math.pi / 2,
              );
              final showBackFace = angle.abs() > math.pi / 4;
              return Transform(
                alignment: isLeaving
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: showBackFace ? const SizedBox() : child!,
              );

            case PageTurnAnimation.depth:
              if (isLeaving) {
                final scale = 1.0 - absOffset * 0.15;
                return Transform.scale(
                  scale: scale.clamp(0.85, 1.0),
                  child: Opacity(
                    opacity: (1.0 - absOffset * 1.2).clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              }
              final slideOffset = offset.clamp(0.0, 1.0);
              return Transform.translate(
                offset: Offset(slideOffset * viewportWidth * 0.3, 0),
                child: child,
              );

            default:
              return child!;
          }
        },
        child: page,
      ),
    );
  }

  /// The chapter an explicit selection (index sheet / palette / panel) asked
  /// to jump to, consumed by [didUpdateWidget]. Distinct from natural paging,
  /// which must never re-anchor the pages.
  int? _pendingExplicitChapter;

  /// A chapter the reader selected but whose content hasn't paginated yet.
  /// The jump fires as soon as it does, so a far leap (e.g. 21 → 40) is never
  /// swallowed by the navigation gate.
  int? _pendingJumpToChapter;

  /// Forwards an explicit chapter selection, marking it so [didUpdateWidget]
  /// anchors the pages once the parent rebuilds with the new index.
  void _selectChapterExplicitly(int idx) {
    _pendingExplicitChapter = idx;
    _ensureChapterLoaded(idx);
    widget.onChapterSelected(idx);
  }

  void _showChapterIndex(BuildContext context) {
    final (curChIdx, _) = _globalToLocal(_currentGlobalPage);
    ChapterIndexSheet.show(
      context,
      sheetId: 'paged_chapter_index',
      chapters: widget.chapters,
      currentChapterIndex: curChIdx,
      onChapterTap: (idx) {
        _selectChapterExplicitly(idx);
      },
    );
  }

  Widget _buildSinglePage(
    int globalPage,
    ReadingViewTheme vt,
    List<ChapterEntity> chapters, {
    required ColorScheme colorScheme,
  }) {
    final (chIdx, pageInChapter) = _globalToLocal(globalPage);
    final pages = _pageCache[chIdx];
    if (pages == null) {
      _ensureChapterLoaded(chIdx);
      return _buildChapterLoadingState(
        chIdx,
        vt,
        showHeaders: pageInChapter == 0,
        colorScheme: colorScheme,
      );
    }
    final clampedPage = pageInChapter.clamp(0, pages.length - 1);
    final content = pages[clampedPage];
    final isFirstOfChapter = clampedPage == 0;
    final isLastOfChapter = clampedPage == pages.length - 1;
    final chapter = chapters[chIdx];
    final pageStartOffset = _pageStartOffset(chIdx, clampedPage);

    final pageWidget = _PagedPageView(
      content: content,
      chapterTitle: chapter.title,
      chapterIndex: chIdx,
      bookId: chapter.bookId,
      chapterId: chapter.id,
      pageStartOffset: pageStartOffset,
      highlights: _highlightsFor(chapter, _contentCache[chIdx] ?? ''),
      isFirstPageOfChapter: isFirstOfChapter,
      isLastPageOfChapter: isLastOfChapter,
      textStyle: TextStyle(
        fontSize: widget.settings.fontSize,
        height: widget.settings.lineHeight,
        letterSpacing: widget.settings.letterSpacing,
        color: vt.resolve(colorScheme).text,
        fontWeight: widget.settings.fontWeight != null
            ? FontWeight(widget.settings.fontWeight!)
            : null,
      ),
      fontFamily: widget.settings.fontFamily,
      textAlignment: widget.settings.textAlignment,
      marginPreset: widget.settings.marginPreset,
      vt: vt,
      showHeaders: true,
      chapterStyle: ChapterStyle.forChapter(chIdx, colorScheme),
      onHighlight: widget.onHighlight,
      onAddNote: widget.onAddNote,
      onShare: widget.onShare,
      onSearchWeb: widget.onSearchWeb,
      onListen: widget.onListen,
      onErase: widget.onErase,
      onSetGlossaryTerm: (term) => _openGlossaryTerm(chapter.bookId, term),
    );
    return _wrapWithPageAnimation(pageWidget, globalPage);
  }

  Widget _buildSpread(
    int spreadIndex,
    ReadingViewTheme vt,
    List<ChapterEntity> chapters, {
    required ColorScheme colorScheme,
  }) {
    final leftGlobalPage = spreadIndex * 2;
    final rightGlobalPage = spreadIndex * 2 + 1;
    final (leftChIdx, _) = _globalToLocal(leftGlobalPage);
    final (rightChIdx, _) = _globalToLocal(rightGlobalPage);

    Widget side(int globalPage, int chIdx) {
      if (_pageCache[chIdx] == null) {
        _ensureChapterLoaded(chIdx);
        return _buildChapterLoadingState(
          chIdx,
          vt,
          showHeaders: _isFirstPageOfChapter(globalPage),
          colorScheme: colorScheme,
        );
      }
      final (_, pageInChapter) = _globalToLocal(globalPage);
      final chapter = chapters[chIdx];
      return _PagedPageView(
        content: _pageContentAt(globalPage),
        chapterTitle: chapter.title,
        chapterIndex: chIdx,
        bookId: chapter.bookId,
        chapterId: chapter.id,
        pageStartOffset: _pageStartOffset(chIdx, pageInChapter),
        highlights: _highlightsFor(chapter, _contentCache[chIdx] ?? ''),
        isFirstPageOfChapter: _isFirstPageOfChapter(globalPage),
        isLastPageOfChapter: _isLastPageOfChapter(globalPage),
        textStyle: TextStyle(
          fontSize: widget.settings.fontSize,
          height: widget.settings.lineHeight,
          letterSpacing: widget.settings.letterSpacing,
          color: vt.resolve(colorScheme).text,
          fontWeight: widget.settings.fontWeight != null
              ? FontWeight(widget.settings.fontWeight!)
              : null,
        ),
        fontFamily: widget.settings.fontFamily,
        textAlignment: widget.settings.textAlignment,
        marginPreset: widget.settings.marginPreset,
        vt: vt,
        showHeaders: false,
        chapterStyle: ChapterStyle.forChapter(chIdx, colorScheme),
        onHighlight: widget.onHighlight,
        onAddNote: widget.onAddNote,
        onShare: widget.onShare,
        onSearchWeb: widget.onSearchWeb,
        onListen: widget.onListen,
        onErase: widget.onErase,
        onSetGlossaryTerm: (term) => _openGlossaryTerm(chapter.bookId, term),
      );
    }

    return Row(
      children: [
        Expanded(
          child: rightGlobalPage <= _totalPages
              ? side(leftGlobalPage, leftChIdx)
              : Container(color: vt.resolve(colorScheme).background),
        ),
        Container(
          width: 1,
          color: vt.resolve(colorScheme).text.withValues(alpha: 0.1),
        ),
        Expanded(
          child: rightGlobalPage < _totalPages
              ? side(rightGlobalPage, rightChIdx)
              : Container(color: vt.resolve(colorScheme).background),
        ),
      ],
    );
  }

  void _openGlossaryTerm(String bookId, String term) {
    DraggableBottomSheet.show(
      context: context,
      id: 'glossary_term',
      initialHeight: 0.6,
      child: GlossaryTermSheet(bookId: bookId, term: term),
    );
  }

  String _pageContentAt(int globalPage) {
    final (chIdx, pageInChapter) = _globalToLocal(globalPage);
    final pages = _pageCache[chIdx];
    if (pages == null || pages.isEmpty) return '';
    return pages[pageInChapter.clamp(0, pages.length - 1)];
  }

  bool _isFirstPageOfChapter(int globalPage) {
    final (_, pageInChapter) = _globalToLocal(globalPage);
    return pageInChapter == 0;
  }

  bool _isLastPageOfChapter(int globalPage) {
    final (chIdx, pageInChapter) = _globalToLocal(globalPage);
    final pages = _pageCache[chIdx];
    return pages != null &&
        pageInChapter.clamp(0, pages.length - 1) == pages.length - 1;
  }
}

class _PagedPageView extends StatelessWidget {
  const _PagedPageView({
    required this.content,
    required this.chapterTitle,
    required this.chapterIndex,
    this.bookId,
    this.chapterId,
    this.pageStartOffset = 0,
    this.highlights = const [],
    required this.isFirstPageOfChapter,
    required this.isLastPageOfChapter,
    required this.textStyle,
    this.fontFamily,
    required this.textAlignment,
    required this.marginPreset,
    required this.vt,
    this.showHeaders = true,
    this.chapterStyle,
    this.onHighlight,
    this.onAddNote,
    this.onShare,
    this.onSearchWeb,
    this.onListen,
    this.onErase,
    this.onSetGlossaryTerm,
  });

  final String content;
  final String chapterTitle;
  final int chapterIndex;

  /// Book/chapter identity for storing page-relative selections back as
  /// chapter-relative highlights. Omit to disable highlight handling.
  final String? bookId;
  final String? chapterId;

  /// Character offset of this page within its chapter's content, so
  /// page-local selection offsets can be mapped to chapter-global offsets.
  final int pageStartOffset;

  /// Stored highlights for this chapter; those intersecting this page's slice
  /// are rendered as backgrounds.
  final List<HighlightEntry> highlights;

  final bool isFirstPageOfChapter;
  final bool isLastPageOfChapter;
  final TextStyle textStyle;
  final String? fontFamily;
  final TextAlignment textAlignment;
  final MarginPreset marginPreset;
  final ReadingViewTheme vt;
  final bool showHeaders;
  final ChapterStyle? chapterStyle;
  final void Function(String text, Color color, int start, int end)?
  onHighlight;
  final void Function(String text, String? sentence)? onAddNote;
  final void Function(String text)? onShare;
  final void Function(String text)? onSearchWeb;
  final void Function(String text, String? sentence, int start, int end)?
  onListen;
  final void Function(int start, int end)? onErase;

  /// Called with the selected text so the host can define a glossary term for
  /// it. Omit to hide the "Set as term…" action.
  final ValueChanged<String>? onSetGlossaryTerm;

  EdgeInsets get _padding => switch (marginPreset) {
    MarginPreset.narrow => const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    MarginPreset.normal => const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    MarginPreset.wide => const EdgeInsets.symmetric(
      horizontal: AppSpacing.xxl,
      vertical: AppSpacing.lg,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedStyle = fontFamily != null
        ? GoogleFonts.getFont(fontFamily!, textStyle: textStyle)
        : textStyle;
    final cs = chapterStyle;

    return Container(
      color: vt.resolve(colorScheme).background,
      child: Column(
        children: [
          if (isFirstPageOfChapter && showHeaders && cs != null)
            ChapterHeaderBanner(
              chapterNumber: chapterIndex + 1,
              title: chapterTitle,
              style: cs,
            ),
          if (isFirstPageOfChapter && showHeaders && cs != null)
            ChapterOrnamentalDivider(
              accentColor: cs.accentColor,
              verticalPadding: 4,
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: _padding,
              child: _buildText(resolvedStyle, cs),
            ),
          ),
          if (isLastPageOfChapter && showHeaders) ...[
            if (cs != null)
              ChapterOrnamentalDivider(accentColor: cs.accentColor),
            ChapterEndFooter(
              chapterNumber: chapterIndex + 1,
              textColor: vt.resolve(colorScheme).text,
              baseFontSize: textStyle.fontSize!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildText(TextStyle resolvedStyle, ChapterStyle? cs) {
    final c = content;
    final contextMenu = _contextMenuBuilder(c);
    final pageHighlights = _pageHighlights(c);

    final spans = _pageSpans(c, resolvedStyle, pageHighlights);

    if (cs != null && isFirstPageOfChapter && c.isNotEmpty) {
      return SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(text: c.substring(0, 1), style: cs.dropCapStyle),
            ..._restSpans(c, resolvedStyle, pageHighlights),
          ],
        ),
        textAlign: textAlignment.flutterTextAlign,
        contextMenuBuilder: contextMenu,
      );
    }
    return SelectableText.rich(
      TextSpan(children: spans),
      textAlign: textAlignment.flutterTextAlign,
      contextMenuBuilder: contextMenu,
    );
  }

  /// Highlights whose chapter-global range intersects this page's slice,
  /// translated into page-local coordinates (may be empty).
  List<HighlightEntry> _pageHighlights(String pageContent) {
    if (chapterId == null || pageStartOffset >= pageContent.length) {
      return const [];
    }
    final out = <HighlightEntry>[];
    for (final h in highlights) {
      final localStart = h.start - pageStartOffset;
      final localEnd = h.end - pageStartOffset;
      if (localEnd <= 0 || localStart >= pageContent.length) continue;
      out.add(
        HighlightEntry(
          chapterId: h.chapterId,
          start: localStart.clamp(0, pageContent.length),
          end: localEnd.clamp(0, pageContent.length),
          text: h.text,
          colorValue: h.colorValue,
        ),
      );
    }
    return out;
  }

  /// Plain body spans (drop-cap first char excluded) with highlight layering.
  List<TextSpan> _restSpans(
    String c,
    TextStyle resolvedStyle,
    List<HighlightEntry> pageHighlights,
  ) {
    final spans = <TextSpan>[];
    var cursor = 1;
    for (final h in pageHighlights) {
      if (h.end <= 1) continue;
      final start = h.start < 1 ? 1 : h.start;
      final end = h.end;
      if (start > cursor) {
        spans.add(
          TextSpan(text: c.substring(cursor, start), style: resolvedStyle),
        );
      }
      spans.add(
        TextSpan(
          text: c.substring(start, end > c.length ? c.length : end),
          style: resolvedStyle.copyWith(
            backgroundColor: h.color.withValues(alpha: 0.30),
          ),
        ),
      );
      cursor = end > c.length ? c.length : end;
    }
    if (cursor < c.length) {
      spans.add(TextSpan(text: c.substring(cursor), style: resolvedStyle));
    }
    return spans;
  }

  /// Whole-page spans with highlight layering (first char kept plain).
  List<TextSpan> _pageSpans(
    String c,
    TextStyle resolvedStyle,
    List<HighlightEntry> pageHighlights,
  ) {
    if (pageHighlights.isEmpty) {
      return [TextSpan(text: c, style: resolvedStyle)];
    }
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final h in pageHighlights) {
      if (h.start > cursor) {
        spans.add(
          TextSpan(text: c.substring(cursor, h.start), style: resolvedStyle),
        );
      }
      spans.add(
        TextSpan(
          text: c.substring(h.start, h.end > c.length ? c.length : h.end),
          style: resolvedStyle.copyWith(
            backgroundColor: h.color.withValues(alpha: 0.30),
          ),
        ),
      );
      cursor = h.end > c.length ? c.length : h.end;
    }
    if (cursor < c.length) {
      spans.add(TextSpan(text: c.substring(cursor), style: resolvedStyle));
    }
    return spans;
  }

  static const _highlightPalette = [
    AppContextMenuHighlightOption(color: Color(0xFFFFF176), label: 'Yellow'),
    AppContextMenuHighlightOption(color: Color(0xFFA5D6A7), label: 'Green'),
    AppContextMenuHighlightOption(color: Color(0xFF90CAF9), label: 'Blue'),
    AppContextMenuHighlightOption(color: Color(0xFFF48FB1), label: 'Pink'),
    AppContextMenuHighlightOption(color: Color(0xFFCE93D8), label: 'Purple'),
  ];

  EditableTextContextMenuBuilder _contextMenuBuilder(String fullText) {
    return AppContextMenu.builder(
      build: (ctx, editable, anchor) {
        final sel = editable.textEditingValue.selection;
        final hasSelection = sel.isValid && !sel.isCollapsed;
        final word = hasSelection
            ? fullText.substring(sel.start, sel.end).trim()
            : '';
        final sentence = hasSelection && word.isNotEmpty
            ? _sentenceAround(fullText, sel)
            : null;
        final showSelectionActions = hasSelection && word.isNotEmpty;
        final srcTitle = chapterTitle;
        final chapterOffset = pageStartOffset;
        final globalStart = chapterOffset + sel.start;
        final globalEnd = chapterOffset + sel.end;
        final hasOverlappingHighlight = highlights.any(
          (h) => h.overlaps(globalStart, globalEnd),
        );
        final eraseEnabled =
            showSelectionActions && hasOverlappingHighlight && onErase != null;

        return AppContextMenu(
          anchor: anchor,
          highlightColors: showSelectionActions ? _highlightPalette : const [],
          onHighlightSelected: showSelectionActions && onHighlight != null
              ? (color) => onHighlight!(word, color, globalStart, globalEnd)
              : null,
          quickActions: [
            AppContextMenuAction(
              label: 'Copy',
              icon: Icons.content_copy_rounded,
              onPressed: () {
                final data = editable.textEditingValue.selection.textInside(
                  editable.textEditingValue.text,
                );
                Clipboard.setData(ClipboardData(text: data));
              },
            ),
            if (showSelectionActions && onAddNote != null)
              AppContextMenuAction(
                label: 'Note',
                icon: Icons.edit_note_rounded,
                onPressed: () => onAddNote!(word, sentence),
              ),
            if (showSelectionActions && onListen != null)
              AppContextMenuAction(
                label: 'Listen',
                icon: Icons.play_circle_outline_rounded,
                onPressed: () =>
                    onListen!(word, sentence, globalStart, globalEnd),
              ),
            if (showSelectionActions && onShare != null)
              AppContextMenuAction(
                label: 'Share',
                icon: Icons.ios_share_rounded,
                onPressed: () => onShare!(word),
              ),
          ],
          listActions: [
            if (showSelectionActions)
              AppContextMenuAction(
                label: 'Look up "$word"',
                icon: Icons.translate_rounded,
                onPressed: () => _showDefine(
                  ctx,
                  word,
                  sentence: sentence,
                  sourceTitle: srcTitle,
                ),
              ),
            if (showSelectionActions && onSetGlossaryTerm != null)
              AppContextMenuAction(
                label: 'Set as term…',
                icon: Icons.settings_suggest_outlined,
                onPressed: () => onSetGlossaryTerm!(word),
              ),
            if (eraseEnabled)
              AppContextMenuAction(
                label: 'Erase highlight',
                icon: Icons.format_color_reset_rounded,
                destructive: true,
                onPressed: () => onErase!(globalStart, globalEnd),
              ),
            if (showSelectionActions && onSearchWeb != null)
              AppContextMenuAction(
                label: 'Search the web for "$word"',
                icon: Icons.search_rounded,
                onPressed: () => onSearchWeb!(word),
              ),
            AppContextMenuAction(
              label: 'Select all',
              icon: Icons.select_all_rounded,
              onPressed: () =>
                  editable.selectAll(SelectionChangedCause.toolbar),
            ),
          ],
        );
      },
    );
  }

  String _sentenceAround(String fullText, TextSelection sel) {
    if (!sel.isValid || sel.isCollapsed) return '';
    const punctuation = '.!?\n';
    int start = sel.start;
    while (start > 0) {
      if (punctuation.contains(fullText[start - 1])) break;
      start--;
    }
    int end = sel.end;
    while (end < fullText.length) {
      if (punctuation.contains(fullText[end])) break;
      end++;
    }
    if (end < fullText.length) end++;
    return fullText.substring(start, end).trim();
  }

  void _showDefine(
    BuildContext ctx,
    String word, {
    String? sentence,
    String? sourceTitle,
  }) {
    DraggableBottomSheet.show(
      context: ctx,
      id: 'word_lookup',
      initialHeight: 0.7,
      child: WordLookupSheet(
        word: word,
        sourceSentence: sentence,
        sourceTitle: sourceTitle,
      ),
    );
  }
}
