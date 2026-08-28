import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/molecules/app_error_state.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
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
import 'package:atlas_app/reader/presentation/utils/pager_boundary.dart';
import 'package:atlas_app/reader/presentation/utils/reader_key_events.dart';
import 'package:atlas_app/reader/presentation/utils/chapter_position_resolver.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_index_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_pager.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_shimmer.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_styles.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/glossary_term_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/paged_page_view.dart';
import 'package:atlas_app/reader/presentation/widgets/pager.dart';
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
  /// Outer pager: one page per CHAPTER. Every cross-chapter motion — swipe
  /// past a seam, explicit selection, narration advance — animates here.
  late PageController _outerController;

  /// Inner pagers, one per chapter, created lazily and kept alive for the
  /// session so a chapter remembers the panel the reader left it on.
  final Map<int, PageController> _innerControllers = {};
  final Map<int, List<String>> _pageCache = {};
  final Map<int, String> _contentCache = {};
  final Set<int> _loadedChapters = {};

  /// Chapters whose fetch failed (network / source error) — rendered as an
  /// error state with a Retry action instead of an endless shimmer. A chapter
  /// in this set is, deliberately, also absent from [_pageCache], so its
  /// outer item keeps showing this error until a retry succeeds.
  final Set<int> _failedChapters = {};
  final ValueNotifier<double> _progress = ValueNotifier<double>(0.0);
  String _cacheKey = '';
  double _layoutWidth = 0;
  double _layoutHeight = 0;
  int? _neighborPrefetchScheduledFor;
  static const double _maxReadingWidth = 720.0;

  /// The chapter currently displayed (the outer pager's settled index). The
  /// single source of truth at chapter granularity; the chrome bar reads it,
  /// which is what makes chrome and content structurally incapable of
  /// disagreeing.
  int _chapterIndex = 0;

  /// The last settled panel per chapter (pages on handset, spreads on wide
  /// desktop). Seeds freshly created inner controllers so revisiting a
  /// chapter resumes where the reader left off.
  final Map<int, int> _lastPanelIndex = {};

  /// True while a chapter transition animation runs; boundary intents from
  /// inner pagers are swallowed meanwhile so one swipe can't fire twice.
  bool _chapterTurnLocked = false;

  /// The chapter the exact-position resume applies to — the chapter the reader
  /// opened on, so a later chapter selection never re-fires the resume.
  late final int _resumeChapterIndex = widget.currentChapterIndex;

  /// Armed when an exact resume was requested (a saved sentence index > 0);
  /// disarmed once that chapter's content has paginated AND the sentence
  /// resolved to a panel.
  bool _restorePending = false;

  @override
  void initState() {
    super.initState();
    // Landing on the right chapter is structural now: the outer controller
    // starts at the opened chapter before the first frame paints. No post-
    // build jump means nothing can race pagination and leave the reader
    // looking at one chapter while the chrome bar claims another.
    _chapterIndex = widget.currentChapterIndex;
    _outerController = PageController(initialPage: _chapterIndex);
    _restorePending =
        widget.restorePosition != null && widget.restorePosition! > 0;
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
    _outerController.dispose();
    for (final controller in _innerControllers.values) {
      controller.dispose();
    }
    _progress.dispose();
    super.dispose();
  }

  void _onMobileTapUp(TapUpDetails details, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final x = details.localPosition.dx;
    if (x < width / 3) {
      _turnBack();
    } else if (x > width * 2 / 3) {
      _turnForward();
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
      _turnBack();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      resetChromeTimer(
        isDarkTheme:
            Theme.of(context).colorScheme.brightness == Brightness.dark,
      );
      _turnForward();
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

  static const ChapterPositionResolver _resolver = ChapterPositionResolver();

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

  /// The first real page under the reader's current panel in [chIdx] —
  /// spread mode maps a spread back to its left page, which is where the
  /// reported sentence position is taken from.
  int _currentLocalPage(int chIdx) {
    final pages = _pageCache[chIdx];
    if (pages == null || pages.isEmpty) return 0;
    final panel = _lastPanelIndex[chIdx] ?? 0;
    final base = isWideDesktop ? panel * 2 : panel;
    return base.clamp(0, pages.length - 1);
  }

  /// Reports the flat sentence index at the top of the current panel so the
  /// parent can persist an exact-position resume.
  void _reportPositionFromCurrentPage() {
    final onPosition = widget.onPositionChanged;
    if (onPosition == null) return;
    final content = _contentCache[_chapterIndex];
    if (content == null || content.isEmpty) return;
    final localPage = _currentLocalPage(_chapterIndex);
    final offset = _pageStartOffset(_chapterIndex, localPage);
    final resolved = _resolver.resolve(content, offset);
    onPosition(resolved.index, resolved.total);
  }

  /// Returns the inner controller for [chapterIdx], creating it seeded at the
  /// chapter's remembered panel — so the FIRST build of a revisited chapter's
  /// pager already shows the right page with no post-frame jump.
  PageController _innerControllerFor(int chapterIdx) {
    return _innerControllers.putIfAbsent(chapterIdx, () {
      return PageController(initialPage: _lastPanelIndex[chapterIdx] ?? 0);
    });
  }

  /// How many locally addressable panels [chapterIdx] currently has — pages
  /// on handset, two-page spreads on wide desktop.
  int _panelCountFor(int chapterIdx) {
    final pages = _pageCache[chapterIdx]?.length ?? 0;
    return isWideDesktop ? spreadCount(pages) : pages;
  }

  /// Whole-book progress as a chapter-based fraction. Deliberately free of
  /// any cross-chapter page-count sums.
  double get _computedProgress => chapterFraction(
    chapterIndex: _chapterIndex,
    chapterCount: widget.chapters.length,
    localIndex: _lastPanelIndex[_chapterIndex] ?? 0,
    localCount: math.max(1, _panelCountFor(_chapterIndex)),
  );

  /// Pushes [_computedProgress] to both the chrome bar notifier and the
  /// parent (which persists it).
  void _updateProgress() {
    final value = _computedProgress;
    _progress.value = value;
    widget.onProgressChanged(value);
  }

  /// Advances within the current chapter when panels remain; spills across
  /// the chapter seam otherwise. This is the single entry point for tap
  /// zones and arrow keys.
  void _turnForward() {
    _turnPanel(forward: true);
  }

  void _turnBack() {
    _turnPanel(forward: false);
  }

  void _turnPanel({required bool forward}) {
    if (_chapterTurnLocked) return;
    final controller = _innerControllers[_chapterIndex];
    final count = _panelCountFor(_chapterIndex);
    if (controller == null || !controller.hasClients || count <= 0) {
      // This chapter hasn't finished paginating — no local panels exist to
      // move through, so treat the gesture as a chapter-level turn.
      _turnChapter(forward);
      return;
    }
    final page = controller.page ?? 0;
    if (forward && page < count - 1) {
      controller.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
      return;
    }
    if (!forward && page > 0) {
      controller.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
      return;
    }
    _turnChapter(forward);
  }

  /// Animates the OUTER pager to the neighboring chapter. The outer
  /// `onPageChanged` does all bookkeeping when the animation settles.
  void _turnChapter(bool forward) {
    if (_chapterTurnLocked) return;
    final target = _chapterIndex + (forward ? 1 : -1);
    if (target < 0 || target >= widget.chapters.length) return;
    _ensureChapterLoaded(target);
    setState(() => _chapterTurnLocked = true);
    _outerController
        .animateToPage(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        )
        .whenComplete(() {
          if (mounted) setState(() => _chapterTurnLocked = false);
        });
  }

  /// Bookkeeping for the outer pager settling on [chapterIdx]: loads the
  /// chapter and its neighbors, then reports position BEFORE notifying the
  /// parent. The parent's onPageChanged handler persists progress
  /// synchronously using whatever position was last reported — if that
  /// notification fired first, the save would capture the *previous*
  /// chapter's position under the *new* chapter's id, corrupting resume.
  void _onOuterPageChanged(int chapterIdx) {
    if (chapterIdx == _chapterIndex) return;
    _chapterIndex = chapterIdx;
    _ensureChapterLoaded(chapterIdx);
    if (chapterIdx + 1 < widget.chapters.length) {
      _ensureChapterLoaded(chapterIdx + 1);
    }
    if (chapterIdx > 0) {
      _ensureChapterLoaded(chapterIdx - 1);
    }
    _reportPositionFromCurrentPage();
    widget.onPageChanged(chapterIdx);
    _updateProgress();
    resetChromeTimer(
      isDarkTheme: Theme.of(context).colorScheme.brightness == Brightness.dark,
    );
  }

  /// A chapter's inner pager settled on [panel]. Remembers it (so revisits
  /// resume there), and refreshes progress/position when it's the displayed
  /// chapter.
  void _onInnerPageChanged(int chapterIdx, int panel) {
    _lastPanelIndex[chapterIdx] = panel;
    if (chapterIdx != _chapterIndex) return;
    _reportPositionFromCurrentPage();
    widget.onPageChanged(chapterIdx);
    _updateProgress();
  }

  @override
  void didUpdateWidget(PagedReaderLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentChapterIndex == oldWidget.currentChapterIndex) return;
    // The parent only changes currentChapterIndex for an EXTERNAL navigation
    // request (index sheet, palette, side panel, narration advance). Natural
    // paging echoes this widget's own callbacks back unchanged — and since
    // the outer pager is already settled on [_chapterIndex] at that point,
    // the guard below makes those echoes no-ops. No flag bookkeeping, no
    // re-anchoring: a mismatch between parent state and displayed chapter
    // IS the navigation request.
    if (widget.currentChapterIndex == _chapterIndex) return;
    _navigateToChapter(widget.currentChapterIndex, startAtTop: true);
  }

  /// Moves to [target]: loads its content, animates the outer chapter pager
  /// there, and starts that chapter from its top (explicit selections never
  /// resume a remembered mid-chapter panel). The outer `onPageChanged` fires
  /// as the animation settles and does all reporting/bookkeeping.
  void _navigateToChapter(int target, {required bool startAtTop}) {
    _ensureChapterLoaded(target);
    if (startAtTop) {
      _lastPanelIndex[target] = 0;
      final controller = _innerControllers[target];
      if (controller != null && controller.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && controller.hasClients && (controller.page ?? 0) != 0) {
            controller.jumpToPage(0);
          }
        });
      }
    }
    if (!_outerController.hasClients) {
      // Corner case: the parent rebuilt with a new chapter before this
      // layout ever attached its pager (e.g. a mode switch raced a
      // selection). Recreating the not-yet-attached controller with the
      // right initial page is the only way to honor the request.
      _outerController.dispose();
      _outerController = PageController(initialPage: target);
      _chapterIndex = target;
      return;
    }
    setState(() => _chapterTurnLocked = true);
    _outerController
        .animateToPage(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        )
        .whenComplete(() {
          if (mounted) setState(() => _chapterTurnLocked = false);
        });
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
      // Prefetch neighboring chapters so the next page turn is instant.
      prefetchNeighboringChapters(ref, chapter);
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

  final Set<int> _paginationInFlight = {};

  /// Bumped whenever cached pagination state is invalidated (settings change,
  /// re-rendered text). Chunked chains capture the value at their start and
  /// abort themselves when it moves on, so chains scheduled before an
  /// invalidation can never interleave with fresh ones.
  int _paginationEpoch = 0;

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
    final epoch = _paginationEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || epoch != _paginationEpoch) {
        _paginationInFlight.remove(index);
        return;
      }
      _paginateChapterIncremental(index, content, epoch);
    });
  }

  /// Paginates [content] for chapter [index] in chunks of
  /// [_chunkedMaxPagesPerFrame] pages, yielding back to the event loop
  /// between chunks so the UI stays responsive for long chapters.
  void _paginateChapterIncremental(int index, String content, int epoch) {
    if (epoch != _paginationEpoch || !mounted) {
      _paginationInFlight.remove(index);
      return;
    }
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
        ? baseStyle.copyWith(fontFamily: s.fontFamily)
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
      _paginationInFlight.remove(index);
      _pageCache[index] = _chunkedAccumulator.remove(index) ?? [''];
      _chunkedOffset.remove(index);
      ref
              .read(chapterLoadPhaseProvider(widget.chapters[index]).notifier)
              .state =
          ChapterLoadPhase.done;
      if (mounted) {
        // A re-pagination can shrink this chapter (settings change); make
        // sure the panel the reader occupies still exists.
        _clampInnerAfterRepagination(index);
        if (index == _chapterIndex) {
          _updateProgress();
          _reportPositionFromCurrentPage();
        }
        setState(() {});
      }
    } else {
      _chunkedOffset[index] = result.endIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || epoch != _paginationEpoch) {
          _paginationInFlight.remove(index);
          return;
        }
        _paginateChapterIncremental(index, content, epoch);
      });
    }
  }

  /// If repagination left the reader's inner pager pointing past the last
  /// panel of [chapterIdx] (a settings change can shrink a chapter), snap it
  /// back to that last panel.
  void _clampInnerAfterRepagination(int chapterIdx) {
    final controller = _innerControllers[chapterIdx];
    if (controller == null || !controller.hasClients) return;
    final count = _panelCountFor(chapterIdx);
    if (count <= 0) return;
    final page = controller.page ?? 0;
    if (page > count - 1) {
      controller.jumpToPage(count - 1);
      _lastPanelIndex[chapterIdx] = count - 1;
    }
  }

  void _onContentLoaded(int index, String content) {
    _contentCache[index] = content;
    if (_needsRepagination() || _pageCache[index] == null) {
      _schedulePagination(index, content);
    } else {
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
    // The DISPLAYED chapter drives everything chrome-related — titles,
    // chapter number, palette highlight, prefetch. It can only diverge from
    // `widget.currentChapterIndex` for the few frames an external navigation
    // animation is still settling.
    final currentIndex = _chapterIndex;

    _ensureChapterLoaded(currentIndex);
    _scheduleNeighborPrefetch(currentIndex, chapters.length);

    final needsRepaginate = _needsRepagination();
    if (needsRepaginate) {
      // A settings change (font size, margins, etc.) invalidates all cached
      // pages. Cancel any in-flight chunked pagination so each chapter can
      // be re-scheduled fresh on the next frame.
      _paginationEpoch++;
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
        _paginationEpoch++;
        _paginationInFlight.remove(index);
        _chunkedOffset.remove(index);
        _chunkedAccumulator.remove(index);
        _schedulePagination(index, content);
      }
    }

    // Exact-position resume: resolve the saved sentence index to a panel of
    // the chapter we opened on. Stays armed until that chapter's content has
    // paginated, so a slow/async load never strands the reader elsewhere —
    // and the position is never approximated from a whole-book percentage.
    // Seeding [_lastPanelIndex] BEFORE the chapter's pager is first built
    // means its controller is created at the right page directly; the jump
    // below covers the rare case where the pager already exists.
    if (_restorePending && _pageCache[_resumeChapterIndex] != null) {
      final resumePage = _restoreLocalPage(_resumeChapterIndex);
      if (resumePage != null) {
        _restorePending = false;
        final panel = isWideDesktop ? resumePage ~/ 2 : resumePage;
        _lastPanelIndex[_resumeChapterIndex] = panel;
        final controller = _innerControllers[_resumeChapterIndex];
        if (controller != null && controller.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (!controller.hasClients) return;
            if ((controller.page ?? 0) != panel) {
              controller.jumpToPage(panel);
            }
          });
        }
        _updateProgress();
        _reportPositionFromCurrentPage();
      }
    }

    // Display-only refresh of the progress notifier; parent notifications
    // flow exclusively through the page-change handlers below.
    _progress.value = _computedProgress;

    if (!_contentCache.containsKey(currentIndex)) {
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
                onChapterIndexTap: _useSidePanels
                    ? toggleRightPanel
                    : () => _showChapterIndex(context),
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
                onListenTap: _useSidePanels ? toggleNarrationPanel : null,
              ),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth != _layoutWidth ||
              constraints.maxHeight != _layoutHeight) {
            _layoutWidth = constraints.maxWidth;
            _layoutHeight = constraints.maxHeight;
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
                    if (!isDesktop || isWideDesktop) {
                      _onMobileTapUp(details, constraints);
                    } else {
                      toggleChrome(
                        isDarkTheme:
                            Theme.of(context).colorScheme.brightness ==
                            Brightness.dark,
                      );
                    }
                  },
                  child: PageView.builder(
                    controller: _outerController,
                    itemCount: chapters.length,
                    onPageChanged: _onOuterPageChanged,
                    itemBuilder: (context, chapterIdx) => _buildChapterItem(
                      chapterIdx,
                      vt,
                      chapters,
                      colorScheme: colorScheme,
                    ),
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
                    onExpand: _useSidePanels ? toggleNarrationPanel : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Wraps a panel of [chapterIdx] in the reader's page-turn animation,
  /// interpolated off that chapter's INNER controller position. The float is
  /// strictly local to the chapter, so all four effects behave exactly as
  /// they did in the flat model — chapter seams themselves always slide.
  Widget _wrapPanelPage(Widget page, int chapterIdx, int panel) {
    final animation = widget.settings.pageTurnAnimation;
    if (animation == PageTurnAnimation.slide) return page;
    final controller = _innerControllers[chapterIdx];
    if (controller == null) return page;

    return ClipRect(
      key: ValueKey('panel_${chapterIdx}_$panel'),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          final pagePos = controller.hasClients
              ? (controller.page ?? panel.toDouble())
              : panel.toDouble();
          final offset = pagePos - panel;
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

  /// Forwards an explicit chapter selection to the parent; the navigation
  /// itself happens when the parent echoes the new index back through
  /// [didUpdateWidget], which sees it as an external request.
  void _selectChapterExplicitly(int idx) {
    _ensureChapterLoaded(idx);
    widget.onChapterSelected(idx);
  }

  /// When the user prefers side panels on desktop, panel-capable sheets
  /// (Chapters / Listen) dock into the right panel instead of opening a
  /// floating dialog.
  bool get _useSidePanels =>
      isDesktop &&
      AppSheet.desktopPresentation == DesktopSheetPresentation.sidePanel;

  void _showChapterIndex(BuildContext context) {
    ChapterIndexSheet.show(
      context,
      sheetId: 'paged_chapter_index',
      chapters: widget.chapters,
      currentChapterIndex: _chapterIndex,
      onChapterTap: (idx) {
        _selectChapterExplicitly(idx);
      },
    );
  }

  /// The outer pager's item for [chIdx]: a loading/error state while the
  /// chapter has no pages, otherwise its inner [ChapterPager].
  Widget _buildChapterItem(
    int chIdx,
    ReadingViewTheme vt,
    List<ChapterEntity> chapters, {
    required ColorScheme colorScheme,
  }) {
    final pages = _pageCache[chIdx];
    if (pages == null || pages.isEmpty) {
      _ensureChapterLoaded(chIdx);
      return _buildChapterLoadingState(
        chIdx,
        vt,
        showHeaders: true,
        colorScheme: colorScheme,
      );
    }
    return ChapterPager(
      key: ValueKey('chapter_pager_$chIdx'),
      controller: _innerControllerFor(chIdx),
      itemCount: _panelCountFor(chIdx),
      turnLocked: _chapterTurnLocked,
      onPageChanged: (panel) => _onInnerPageChanged(chIdx, panel),
      onBoundaryTurn: (forward) {
        if (chIdx == _chapterIndex && !_chapterTurnLocked) {
          _turnChapter(forward);
        }
      },
      itemBuilder: (context, panel) =>
          _buildPanel(chIdx, panel, vt, chapters, colorScheme: colorScheme),
    );
  }

  /// One panel of chapter [chIdx]: a single page on handset, or a two-page
  /// spread on wide desktop. Panels are strictly local — the seam between
  /// chapters is handled by [_turnChapter], never by page arithmetic.
  Widget _buildPanel(
    int chIdx,
    int panel,
    ReadingViewTheme vt,
    List<ChapterEntity> chapters, {
    required ColorScheme colorScheme,
  }) {
    if (!isWideDesktop) {
      return _wrapPanelPage(
        _buildSinglePanel(
          chIdx,
          panel,
          vt,
          chapters,
          showHeaders: true,
          colorScheme: colorScheme,
        ),
        chIdx,
        panel,
      );
    }
    final pages = _pageCache[chIdx];
    final left = panel * 2;
    final right = left + 1;
    final hasPages = pages != null && pages.isNotEmpty;
    Widget side(int localPage) {
      if (!hasPages || localPage >= pages.length) {
        return Container(color: vt.resolve(colorScheme).background);
      }
      return _buildSinglePanel(
        chIdx,
        localPage,
        vt,
        chapters,
        showHeaders: false,
        colorScheme: colorScheme,
      );
    }

    return _wrapPanelPage(
      Row(
        children: [
          Expanded(child: side(left)),
          Container(
            width: 1,
            color: vt.resolve(colorScheme).text.withValues(alpha: 0.1),
          ),
          Expanded(child: side(right)),
        ],
      ),
      chIdx,
      panel,
    );
  }

  Widget _buildSinglePanel(
    int chIdx,
    int localPage,
    ReadingViewTheme vt,
    List<ChapterEntity> chapters, {
    required bool showHeaders,
    required ColorScheme colorScheme,
  }) {
    final pages = _pageCache[chIdx]!;
    final clampedPage = localPage.clamp(0, pages.length - 1);
    final content = pages[clampedPage];
    final isFirstOfChapter = clampedPage == 0;
    final isLastOfChapter = clampedPage == pages.length - 1;
    final chapter = chapters[chIdx];

    return PagedPageView(
      content: content,
      chapterTitle: chapter.title,
      chapterIndex: chIdx,
      bookId: chapter.bookId,
      chapterId: chapter.id,
      pageStartOffset: _pageStartOffset(chIdx, clampedPage),
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
      showHeaders: showHeaders,
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

  void _openGlossaryTerm(String bookId, String term) {
    AppSheet.show(
      context: context,
      id: 'glossary_term',
      initialHeight: 0.6,
      child: GlossaryTermSheet(bookId: bookId, term: term),
    );
  }
}
