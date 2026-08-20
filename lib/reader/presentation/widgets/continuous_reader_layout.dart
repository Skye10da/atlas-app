import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/controllers/reader_chrome_controller.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/utils/chapter_position_resolver.dart';
import 'package:atlas_app/reader/presentation/utils/reader_key_events.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_chrome_pieces.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_content_loader.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_index_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_styles.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bar_surface.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bottom_nav.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_chrome_bar.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_command_palette.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_edge_regions.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_mini_player.dart';
import 'package:atlas_app/reader/presentation/widgets/now_playing_panel.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_right_panel.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';

class ContinuousReaderLayout extends ConsumerStatefulWidget {
  const ContinuousReaderLayout({
    super.key,
    required this.chapters,
    required this.settings,
    required this.currentChapterIndex,
    required this.bookmarkedChapterIds,
    this.initialScrollProgress,
    this.restorePosition,
    this.onPositionChanged,
    required this.onScrollProgress,
    required this.onCurrentChapterChanged,
    required this.onScrollDirectionChanged,
    required this.onSettingsTap,
    required this.onChapterSelected,
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
  });

  final List<ChapterEntity> chapters;
  final ReadingSettingsEntity settings;
  final int currentChapterIndex;
  final Set<String> bookmarkedChapterIds;
  final double? initialScrollProgress;

  /// A flat sentence index (from [onPositionChanged]) to resume at on open.
  /// `null` or `0` means "resume at the top of the current chapter".
  final int? restorePosition;

  /// Reports the current reading position as a flat sentence index into the
  /// chapter's rebuildable sentence sequence (plus the total), for persisting
  /// exact-position resume. Omit to disable position reporting.
  final void Function(int sentenceIndex, int totalSentences)? onPositionChanged;
  final void Function(double) onScrollProgress;
  final void Function(int) onCurrentChapterChanged;
  final void Function(ScrollDirection) onScrollDirectionChanged;
  final VoidCallback onSettingsTap;
  final void Function(int) onChapterSelected;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;
  final String? bookTitle;
  final String? coverPath;

  /// Context-menu callbacks forwarded to every chapter view.
  final void Function(String text, Color color, int start, int end)? onHighlight;
  final void Function(String text, String? sentence)? onAddNote;
  final void Function(String text)? onShare;
  final void Function(String text)? onSearchWeb;
  final void Function(String text, String? sentence, int start, int end)? onListen;
  final void Function(int start, int end)? onErase;

  @override
  ConsumerState<ContinuousReaderLayout> createState() =>
      _ContinuousReaderLayoutState();
}

class _ContinuousReaderLayoutState
    extends ConsumerState<ContinuousReaderLayout> with ReaderChromeController {
  static const _snapScrollDuration = Duration(milliseconds: 300);

  final _itemScrollController = ItemScrollController();
  final _scrollOffsetController = ScrollOffsetController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final ScrollOffsetListener _scrollOffsetListener =
      ScrollOffsetListener.create();
  StreamSubscription<double>? _scrollOffsetSubscription;
  double _scrollOffset = 0;
  double _accumulatedOffset = 0;
  Timer? _autoScrollTimer;
  double _autoScrollSpeed = 2.0;
  bool _autoScrollActive = false;
  ScrollAnimation _animation = ScrollAnimation.smooth;
  bool _jumpInFlight = false;
  bool _applyingGate = false;
  int _lastReportedChapterIndex = 0;
  bool _narrationOutOfSync = false;
  final Map<int, void Function()> _narrationReveals = {};
  final ValueNotifier<double> _progress = ValueNotifier<double>(0.0);
  static const _resolver = ChapterPositionResolver();

  /// The chapter the exact-position resume applies to — the chapter the reader
  /// opened on, so a later navigation never re-fires the resume reveal.
  late final int _resumeChapterIndex = widget.currentChapterIndex;
  int? _pendingRestoreCharOffset;
  bool _restoreApplied = false;
  ({int index, int total})? _lastReportedPosition;

  @override
  void initState() {
    super.initState();
    _animation = widget.settings.scrollAnimation;
    _lastReportedChapterIndex = widget.currentChapterIndex;
    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
    _scrollOffsetSubscription =
        _scrollOffsetListener.changes.listen(_onScrollOffsetChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initReaderChrome(isDarkTheme: Theme.of(context).colorScheme.brightness == Brightness.dark);
      // widget.currentChapterIndex is always the reliable resume chapter
      // (reader_content.dart tracks it directly, never derived). Using
      // initialScrollProgress to pick a DIFFERENT chapter here — via
      // (progress * chapters.length).floor(), which assumes every chapter
      // is the same length — could disagree with it for any book with
      // non-uniform chapter sizes, landing the reader on the wrong chapter
      // while _pendingRestoreCharOffset sits ready to reveal a precise
      // position inside the chapter this widget was actually told to open.
      // initialScrollProgress is now only a last-resort fallback for the
      // (should be unreachable in practice) case where currentChapterIndex
      // itself is out of range.
      if (widget.currentChapterIndex >= 0 &&
          widget.currentChapterIndex < widget.chapters.length) {
        _scrollToChapter(widget.currentChapterIndex);
      } else if (widget.initialScrollProgress != null) {
        _restoreScrollProgress(widget.initialScrollProgress!);
      } else {
        _scrollToChapter(0);
      }
    });
  }

  @override
  void didUpdateWidget(ContinuousReaderLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings.scrollAnimation != oldWidget.settings.scrollAnimation) {
      setState(() => _animation = widget.settings.scrollAnimation);
    }
    // Re-jump only when the parent moved to an index we did not report
    // ourselves (e.g. the user picked a chapter from the panel/palette).
    // Echoed reports from our own scroll already match _lastReportedChapterIndex
    // and must not trigger a jump back, which would ping-pong on big books.
    final target = widget.currentChapterIndex;
    if (target != _lastReportedChapterIndex) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToChapter(target),
      );
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    _scrollOffsetSubscription?.cancel();
    _progress.dispose();
    disposeReaderChrome();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isDesktop = MediaQuery.of(context).size.width >= 840;
    if (!isDesktop) return KeyEventResult.ignored;

    final common = handleCommonReaderKeys(
      event,
      commandPaletteVisible: commandPaletteVisible,
      onClosePalette: () => setState(() => commandPaletteVisible = false),
      onToggleChrome: () =>
          toggleChrome(isDarkTheme: Theme.of(context).colorScheme.brightness == Brightness.dark),
      onOpenPalette: () => setState(() => commandPaletteVisible = true),
    );
    if (common != KeyEventResult.ignored) return common;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (!_itemScrollController.isAttached) return KeyEventResult.handled;
      resetChromeTimer(isDarkTheme: Theme.of(context).colorScheme.brightness == Brightness.dark);
      unawaited(
        _scrollOffsetController.animateScroll(
          offset: -MediaQuery.of(context).size.height * 0.4,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        ),
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (!_itemScrollController.isAttached) return KeyEventResult.handled;
      resetChromeTimer(isDarkTheme: Theme.of(context).colorScheme.brightness == Brightness.dark);
      unawaited(
        _scrollOffsetController.animateScroll(
          offset: MediaQuery.of(context).size.height * 0.4,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        ),
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      if (!_itemScrollController.isAttached) return KeyEventResult.handled;
      resetChromeTimer(isDarkTheme: Theme.of(context).colorScheme.brightness == Brightness.dark);
      unawaited(
        _scrollOffsetController.animateScroll(
          offset: -MediaQuery.of(context).size.height * 0.85,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        ),
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      if (!_itemScrollController.isAttached) return KeyEventResult.handled;
      resetChromeTimer(isDarkTheme: Theme.of(context).colorScheme.brightness == Brightness.dark);
      unawaited(
        _scrollOffsetController.animateScroll(
          offset: MediaQuery.of(context).size.height * 0.85,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        ),
      );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _scrollToChapter(int index, {bool animate = true}) async {
    if (index < 0 || index >= widget.chapters.length) return;
    if (!_itemScrollController.isAttached) return;
    _jumpInFlight = true;
    // Only animate when the target is already within the currently-tracked
    // viewport; the package then scrolls directly on its single active list.
    // For any target outside it (a far jump) the package would run its
    // primary/secondary cross-fade transition, which reads the secondary
    // list's controller before it is guaranteed to have a scroll position
    // attached — a source of ScrollController crashes. "Jump" for those.
    final canAnimate = animate && _isNearCurrentViewport(index);
    if (canAnimate) {
      await _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _itemScrollController.jumpTo(index: index);
    }
    _jumpInFlight = false;
    if (mounted) _syncCurrentChapter();
  }

  /// Whether [index] is on or adjacent to the chapters currently laid out in
  /// the viewport, i.e. a jump that never needs the package's far-distance
  /// two-list transition.
  bool _isNearCurrentViewport(int index) {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return false;
    var min = widget.chapters.length;
    var max = -1;
    for (final p in positions) {
      if (p.index < min) min = p.index;
      if (p.index > max) max = p.index;
    }
    return index >= min - 1 && index <= max + 1;
  }

  void _toggleAutoScroll() {
    if (_autoScrollActive) {
      _stopAutoScroll();
    } else {
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    setState(() {
      _autoScrollActive = true;
      chromeVisible = false;
    });
    setFullscreen(true, isDarkTheme: Theme.of(context).colorScheme.brightness == Brightness.dark);
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || !_itemScrollController.isAttached) return;
      if (_progress.value >= 0.99) {
        _stopAutoScroll();
        return;
      }
      unawaited(
        _scrollOffsetController.animateScroll(
          offset: _autoScrollSpeed,
          duration: const Duration(milliseconds: 50),
          curve: Curves.linear,
        ),
      );
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    if (mounted) setState(() => _autoScrollActive = false);
  }

  void _setAutoScrollSpeed(double speed) {
    _autoScrollSpeed = speed.clamp(1.0, 6.0);
    if (mounted) setState(() {});
  }

  ScrollPhysics get _scrollPhysics {
    final platform = Theme.of(context).platform;
    return (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS)
        ? const BouncingScrollPhysics()
        : const ClampingScrollPhysics();
  }

  void _restoreScrollProgress(double progress, {int retries = 5}) {
    if (!_itemScrollController.isAttached) {
      if (retries > 0) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _restoreScrollProgress(progress, retries: retries - 1),
        );
      }
      return;
    }
    final index = (progress * widget.chapters.length)
        .floor()
        .clamp(0, widget.chapters.length - 1);
    _scrollToChapter(index, animate: false);
  }

  /// True while [index] is still loading *or* has failed to load — either
  /// way its content isn't ready to read yet, so [_applyScrollGateIfNeeded]
  /// must hold the reader at its boundary rather than let it scroll into a
  /// blank/error chapter. A failed chapter only clears this once its error
  /// UI's Retry action succeeds (which re-resolves the same provider).
  bool _isChapterLoading(int index) {
    if (index < 0 || index >= widget.chapters.length) return false;
    final state = ref.read(readerChapterContentProvider(widget.chapters[index]));
    return state is AsyncLoading || state is AsyncError;
  }

  /// The index of the chapter whose block is currently considered "on top",
  /// matching the rule ScrollablePositionedList itself uses to track the
  /// topmost item, or `null` when nothing is laid out yet.
  int? _currentChapterFromPositions(Iterable<ItemPosition> positions) {
    final visible = positions
        .where((p) => p.itemLeadingEdge < 1 && p.itemTrailingEdge > 0);
    if (visible.isEmpty) return null;
    return visible
        .reduce((a, b) => a.itemLeadingEdge < b.itemLeadingEdge ? a : b)
        .index;
  }

  /// Approximates whole-book progress from the currently tracked item
  /// positions. Each chapter counts as a fixed 1/N slice rather than being
  /// weighted by its actual rendered height — coarser than the old
  /// pixel-accurate value, intentionally.
  double _progressFromPositions(Iterable<ItemPosition> positions) {
    final total = widget.chapters.length;
    if (total == 0) return 0.0;
    final visible = positions
        .where((p) => p.itemLeadingEdge < 1 && p.itemTrailingEdge > 0);
    if (visible.isEmpty) return _progress.value;
    final top = visible.reduce(
      (a, b) => a.itemLeadingEdge < b.itemLeadingEdge ? a : b,
    );
    final withinItem = (-top.itemLeadingEdge).clamp(0.0, 1.0);
    return ((top.index + withinItem) / total).clamp(0.0, 1.0);
  }

  /// Holds the reader at the boundary of the first not-ready (loading or
  /// failed) chapter so the reader can't scroll past a chapter whose content
  /// isn't actually there yet. Only built (tracked) chapters are considered —
  /// far-away, unbuilt chapters aren't reachable yet.
  void _applyScrollGateIfNeeded(Iterable<ItemPosition> positions) {
    if (_applyingGate) return;
    for (final p in positions) {
      if (_isChapterLoading(p.index) && p.itemLeadingEdge < 0) {
        _applyingGate = true;
        if (_itemScrollController.isAttached) {
          _itemScrollController.jumpTo(index: p.index, alignment: 0);
        }
        _applyingGate = false;
        return;
      }
    }
  }

  void _onPositionsChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final progress = _progressFromPositions(positions);
    _progress.value = progress;
    widget.onScrollProgress(progress);
    _reportPosition(positions);

    // While a programmatic jump is in flight, the provisional (intermediate)
    // positions must never propagate up and trigger a `didUpdateWidget`
    // re-jump in the opposite direction.
    if (_jumpInFlight) return;

    final current = _currentChapterFromPositions(positions);
    if (current != null && current != _lastReportedChapterIndex) {
      _lastReportedChapterIndex = current;
      widget.onCurrentChapterChanged(current);
    }
    _applyScrollGateIfNeeded(positions);
  }

  /// Reports the current reading position as a flat sentence index + total,
  /// derived from the topmost chapter's `itemLeadingEdge` fraction — an
  /// approximation (the chapter block includes its header/footer, so the
  /// viewport fraction is mapped to the content length). Cheap to compute and
  /// only forwarded upstream when the index actually changes.
  void _reportPosition(Iterable<ItemPosition> positions) {
    final onPosition = widget.onPositionChanged;
    if (onPosition == null) return;
    final total = widget.chapters.length;
    if (total == 0) return;
    final visible = positions
        .where((p) => p.itemLeadingEdge < 1 && p.itemTrailingEdge > 0);
    if (visible.isEmpty) return;
    final top = visible.reduce(
      (a, b) => a.itemLeadingEdge < b.itemLeadingEdge ? a : b,
    );
    final content = ref
        .read(readerChapterContentProvider(widget.chapters[top.index]))
        .valueOrNull;
    if (content == null || content.isEmpty) return;
    final within = (-top.itemLeadingEdge).clamp(0.0, 1.0);
    final charOffset = (within * content.length).round().clamp(0, content.length);
    final resolved = _resolver.resolve(content, charOffset);
    final last = _lastReportedPosition;
    if (last != null &&
        last.index == resolved.index &&
        last.total == resolved.total) {
      return;
    }
    _lastReportedPosition = (index: resolved.index, total: resolved.total);
    onPosition(resolved.index, resolved.total);
  }

  /// Resolves the resume sentence to a character offset once the resume
  /// chapter's content is available, so its ChapterView can reveal it.
  int? _resolveRestoreCharOffset() {
    final pos = widget.restorePosition;
    if (pos == null ||
        pos <= 0 ||
        _resumeChapterIndex < 0 ||
        _resumeChapterIndex >= widget.chapters.length) {
      return null;
    }
    final content = ref
        .read(readerChapterContentProvider(widget.chapters[_resumeChapterIndex]))
        .valueOrNull;
    if (content == null || content.isEmpty) return null;
    return _resolver.charOffsetForSentenceIndex(content, pos);
  }

  void _onScrollOffsetChange(double delta) {
    if (!mounted) return;
    _accumulatedOffset += delta;
    _scrollOffset = _accumulatedOffset;
    resetChromeTimer(isDarkTheme: Theme.of(context).colorScheme.brightness == Brightness.dark);
    if (_jumpInFlight) return;
    if (delta.abs() > 4) {
      final direction = delta > 0 ? ScrollDirection.down : ScrollDirection.up;
      widget.onScrollDirectionChanged(direction);
      setState(() {
        if (direction == ScrollDirection.up) {
          chromeVisible = true;
          setFullscreen(false, isDarkTheme: Theme.of(context).colorScheme.brightness == Brightness.dark);
        }
      });
    }
  }

  /// Reports the chapter actually on top once its block has been laid out, so
  /// programmatic jumps/restores don't leave the parent's chapter state stale
  /// (or wrong).
  void _syncCurrentChapter() {
    if (!mounted || _jumpInFlight) return;
    final current = _currentChapterFromPositions(
      _itemPositionsListener.itemPositions.value,
    );
    if (current == null) return;
    _lastReportedChapterIndex = current;
    widget.onCurrentChapterChanged(current);
  }

  void _applyBrightness(double newBrightness) {
    final notifier = ref.read(readingSettingsProvider.notifier);
    notifier.setBrightness(newBrightness);
    final svc = ref.read(platformServiceProvider);
    svc.setBrightness(newBrightness, smooth: true);
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    if (_animation != ScrollAnimation.snap) return false;
    if (notification.dragDetails == null) return false;
    if (!_itemScrollController.isAttached) return false;
    final viewport = MediaQuery.of(context).size.height;
    final page = (_scrollOffset / viewport).round();
    final target = page * viewport;
    unawaited(
      _scrollOffsetController.animateScroll(
        offset: target - _scrollOffset,
        duration: _snapScrollDuration,
        curve: Curves.easeOut,
      ),
    );
    return true;
  }

  Widget _wrapWithAnimation(Widget listView) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (_animation) {
      ScrollAnimation.smooth => listView,
      ScrollAnimation.snap => NotificationListener<ScrollEndNotification>(
        onNotification: _onScrollEnd,
        child: listView,
      ),
      ScrollAnimation.fadeEdges => ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0, 0.06, 0.94, 1],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: listView,
      ),
      ScrollAnimation.parallax => listView,
      ScrollAnimation.glow => Stack(
        children: [
          Positioned.fill(child: listView),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: _progress,
                builder: (context, progress, _) => SizedBox(
                  width: 8,
                  child: CustomPaint(
                    painter: _GlowScrollbarPainter(
                      progress: progress,
                      color: widget.settings.theme.resolve(colorScheme).accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    };
  }

  Widget _wrapHeaderWithParallax(Widget header, int index) {
    if (_animation != ScrollAnimation.parallax) return header;
    final offset =
        math.sin((index * math.pi * 0.3) + (_scrollOffset * 0.003)) * 6;
    return Transform.translate(offset: Offset(0, offset), child: header);
  }

  /// Finds the index of the chapter currently being narrated, if any.
  int? get _narratingChapterIndex {
    final item = ref.read(activeSpeechItemProvider);
    if (item == null) return null;
    for (var i = 0; i < widget.chapters.length; i++) {
      if (widget.chapters[i].id == item.chapterId) return i;
    }
    return null;
  }

  /// Scrolls the reader back to the currently narrated sentence. The reveal
  /// handle is registered by the narrating chapter's [ChapterView]; if that
  /// chapter's block has been disposed (scrolled out of the list cache) the
  /// stored handle is dead, so we first jump to the chapter and re-acquire a
  /// live handle once its view has been rebuilt.
  void _revealNarration() {
    final index = _narratingChapterIndex;
    if (index == null || !_itemScrollController.isAttached) return;
    final handle = _narrationReveals[index];
    if (handle != null) {
      handle();
      return;
    }
    _scrollToChapter(index);
    _acquireNarrationReveal(index, attempts: 20);
  }

  /// Polls across frames for the narrating chapter's view to rebuild and
  /// register its reveal handle, then scrolls to the sentence.
  void _acquireNarrationReveal(int index, {required int attempts}) {
    if (attempts <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final handle = _narrationReveals[index];
      if (handle != null) {
        handle();
        return;
      }
      _acquireNarrationReveal(index, attempts: attempts - 1);
    });
  }

  Widget _buildChapterBlock(
    ChapterEntity chapter,
    int index, {
    bool showHeaders = true,
    int? restoreCharOffset,
    void Function()? onRestoreRevealed,
  }) {
    final vt = widget.settings.theme;
    final colorScheme = Theme.of(context).colorScheme;
    final cs = ChapterStyle.forChapter(index, colorScheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeaders) ...[
          _wrapHeaderWithParallax(
            ChapterHeaderBanner(
              chapterNumber: index + 1,
              title: chapter.title,
              style: cs,
            ),
            index,
          ),
          ChapterOrnamentalDivider(accentColor: cs.accentColor),
        ],
        ChapterContentLoader(
          chapter: chapter,
          fontSize: widget.settings.fontSize,
          fontFamily: widget.settings.fontFamily,
          fontWeight: widget.settings.fontWeight,
          lineHeight: widget.settings.lineHeight,
          letterSpacing: widget.settings.letterSpacing,
          vt: vt,
          textAlignment: widget.settings.textAlignment,
          marginPreset: widget.settings.marginPreset,
          scrollable: false,
          chapterStyle: cs,
          restoreCharOffset: restoreCharOffset,
          onRestoreRevealed: onRestoreRevealed,
          onNarrationOutOfSyncChanged: (outOfSync) {
            if (mounted && _narrationOutOfSync != outOfSync) {
              setState(() => _narrationOutOfSync = outOfSync);
            }
          },
          onRegisterNarrationReveal: (reveal) {
            _narrationReveals[index] = reveal;
          },
          onHighlight: widget.onHighlight,
          onAddNote: widget.onAddNote,
          onShare: widget.onShare,
          onSearchWeb: widget.onSearchWeb,
          onListen: widget.onListen,
          onErase: widget.onErase,
        ),
        if (showHeaders)
          ChapterOrnamentalDivider(
            accentColor: cs.accentColor,
            verticalPadding: 24,
          ),
        if (showHeaders)
          ChapterEndFooter(
            chapterNumber: index + 1,
            textColor: vt.resolve(colorScheme).text,
            baseFontSize: widget.settings.fontSize,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vt = widget.settings.theme;
    final colorScheme = Theme.of(context).colorScheme;
    final chapters = widget.chapters;
    final index = widget.currentChapterIndex;

    // Resolve the resume sentence to a character offset once its chapter's
    // content is available; the target ChapterView reveals it once, then we
    // clear it so it never re-fires on a later build/navigation.
    if (!_restoreApplied && _pendingRestoreCharOffset == null) {
      _pendingRestoreCharOffset = _resolveRestoreCharOffset();
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
                title: chapters[index].title,
                textColor: colorScheme.onSurface,
                showPanelToggle: isDesktop,
                rightPanelVisible: rightPanelVisible,
                onTogglePanel: toggleRightPanel,
                onSettingsTap: widget.onSettingsTap,
              ),
            )
          : null,
      body: Stack(
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
              onTap: () {
                if (rightPanelVisible || narrationPanelVisible) {
                  hideRightPanel();
                  return;
                }
                toggleChrome(isDarkTheme: Theme.of(context).colorScheme.brightness == Brightness.dark);
              },
              child: _wrapWithAnimation(
                ScrollablePositionedList.builder(
                  itemScrollController: _itemScrollController,
                  scrollOffsetController: _scrollOffsetController,
                  itemPositionsListener: _itemPositionsListener,
                  scrollOffsetListener: _scrollOffsetListener,
                  physics: _scrollPhysics,
                  itemCount: chapters.length,
                  itemBuilder: (context, index) => _buildChapterBlock(
                    chapters[index],
                    index,
                    showHeaders: true,
                    restoreCharOffset:
                        index == _resumeChapterIndex ? _pendingRestoreCharOffset : null,
                    onRestoreRevealed: () {
                      if (mounted) {
                        setState(() {
                          _pendingRestoreCharOffset = null;
                          _restoreApplied = true;
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          if (!isDesktop)
            BrightnessEdgeGestureRegion(
              onVerticalDragStart: (details) => onEdgeBrightnessStart(
                details,
                followSystemBrightness: widget.settings.followSystemBrightness,
                currentBrightness: widget.settings.brightness,
              ),
              onVerticalDragUpdate: (details) => onEdgeBrightnessUpdate(
                details,
                onChanged: _applyBrightness,
              ),
              onVerticalDragEnd: onEdgeBrightnessEnd,
            ),
          if (_autoScrollActive)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: _AutoScrollControl(
                  speed: _autoScrollSpeed,
                  onSpeedChanged: _setAutoScrollSpeed,
                  onStop: _stopAutoScroll,
                  accent: widget.settings.theme.resolve(colorScheme).accent,
                ),
              ),
            ),
          if (_narrationOutOfSync && _narratingChapterIndex != null)
            Positioned(
              right: 16,
              bottom: isDesktop ? 24 : 88,
              child: _NarrationSyncButton(
                accent: widget.settings.theme.resolve(colorScheme).accent,
                onPressed: _revealNarration,
              ),
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
                      chapterTitle: chapters[index].title,
                      accent: widget.settings.theme.resolve(colorScheme).accent,
                      onClose: closeNarrationPanel,
                    )
                  : ReaderRightPanel(
                      chapters: chapters,
                      currentChapterIndex: index,
                      bookmarkedChapterIds: widget.bookmarkedChapterIds,
                      onChapterSelected: (idx) {
                        widget.onChapterSelected(idx);
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _scrollToChapter(idx),
                        );
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
              currentChapterIndex: index,
              onChapterSelected: (idx) {
                widget.onChapterSelected(idx);
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToChapter(idx),
                );
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
                chapterTitle: chapters[index].title,
                accent: widget.settings.theme.resolve(colorScheme).accent,
              ),
            ),
        ],
      ),
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
                currentChapterTitle: chapters[index].title,
                currentChapterNumber: index,
                totalChapters: chapters.length,
                autoScrollActive: _autoScrollActive,
                onAutoScrollToggle: _toggleAutoScroll,
                bookTitle: widget.bookTitle,
                coverPath: widget.coverPath,
                progress: _progress,
                progressColor: widget.settings.theme.resolve(colorScheme).accent,
                onListenTap: isDesktop ? toggleNarrationPanel : null,
              ),
            )
          : null,
    );
  }

  void _showChapterIndex(BuildContext context) {
    ChapterIndexSheet.show(
      context,
      sheetId: 'continuous_chapter_index',
      chapters: widget.chapters,
      currentChapterIndex: widget.currentChapterIndex,
      onChapterTap: (idx) {
        widget.onChapterSelected(idx);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToChapter(idx));
      },
    );
  }
}

/// Non-interactive progress indicator for glow scrollbar mode, driven by the
/// reader's whole-book progress. Replaces the old draggable [Scrollbar], which
/// has no controller to bind to in [ScrollablePositionedList].
class _GlowScrollbarPainter extends CustomPainter {
  const _GlowScrollbarPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()..color = color.withValues(alpha: 0.15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(4),
      ),
      track,
    );
    if (progress <= 0) return;
    final thumbHeight = (size.height * 0.15).clamp(24.0, size.height);
    final thumbTop = (size.height - thumbHeight) * progress.clamp(0.0, 1.0);
    final thumb = Paint()..color = color.withValues(alpha: 0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, thumbTop, size.width, thumbHeight),
        const Radius.circular(4),
      ),
      thumb,
    );
  }

  @override
  bool shouldRepaint(covariant _GlowScrollbarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _AutoScrollControl extends StatelessWidget {
  const _AutoScrollControl({
    required this.speed,
    required this.onSpeedChanged,
    required this.onStop,
    required this.accent,
  });

  final double speed;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onStop;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor =
        ThemeData.estimateBrightnessForColor(scheme.surface) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return Material(
      color: scheme.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              iconSize: 20,
              color: iconColor,
              tooltip: 'Slower',
              onPressed: () => onSpeedChanged(speed - 0.5),
            ),
            Text(
              '${(speed * 20).round()} px/s',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: iconColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              iconSize: 20,
              color: iconColor,
              tooltip: 'Faster',
              onPressed: () => onSpeedChanged(speed + 0.5),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close),
              iconSize: 20,
              color: accent,
              tooltip: 'Stop auto-scroll',
              onPressed: onStop,
            ),
          ],
        ),
      ),
    );
  }
}

/// A small floating pill shown while narration is active but the highlighted
/// sentence has scrolled out of view. Tapping it scrolls the reader back to
/// the current narration position.
class _NarrationSyncButton extends StatelessWidget {
  const _NarrationSyncButton({
    required this.accent,
    required this.onPressed,
  });

  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = ThemeData.estimateBrightnessForColor(scheme.surface) ==
        Brightness.dark;
    return Material(
      color: scheme.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.volume_up_rounded, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(
                'Jump to narration',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}