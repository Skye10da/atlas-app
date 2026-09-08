import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/providers/reader_chrome_provider.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/utils/chapter_position_resolver.dart';
import 'package:atlas_app/reader/presentation/utils/reader_key_events.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_chrome_pieces.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_content_loader.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_index_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_styles.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_mini_player.dart';
import 'package:atlas_app/reader/presentation/widgets/now_playing_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_annotations_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bar_surface.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bottom_nav.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_chrome_bar.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_command_palette.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_edge_regions.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_right_panel.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';

class ContinuousReaderLayout extends HookConsumerWidget {
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
    this.onSearchTap,
    this.onRedownload,
    this.isRedownloading = false,
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
    required void Function() onOpenAnnotations,
  });

  final List<ChapterEntity> chapters;
  final ReadingSettingsEntity settings;
  final int currentChapterIndex;
  final Set<String> bookmarkedChapterIds;
  final double? initialScrollProgress;
  final int? restorePosition;
  final void Function(int sentenceIndex, int totalSentences)? onPositionChanged;
  final void Function(double) onScrollProgress;
  final void Function(int) onCurrentChapterChanged;
  final void Function(ScrollDirection) onScrollDirectionChanged;
  final VoidCallback onSettingsTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onRedownload;
  final bool isRedownloading;
  final void Function(int) onChapterSelected;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;
  final String? bookTitle;
  final String? coverPath;

  final void Function(
    String text,
    Color color,
    int start,
    int end, {
    HighlightStyleType styleType,
  })?
  onHighlight;
  final void Function(String text, String? sentence)? onAddNote;
  final void Function(String text)? onShare;
  final void Function(String text)? onSearchWeb;
  final void Function(String text, String? sentence, int start, int end)?
  onListen;
  final void Function(int start, int end)? onErase;

  static const _snapScrollDuration = Duration(milliseconds: 300);
  static const _resolver = ChapterPositionResolver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chromeState = ref.watch(readerChromeProvider);
    final chromeNotifier = ref.read(readerChromeProvider.notifier);

    final itemScrollController = useMemoized(() => ItemScrollController());
    final scrollOffsetController = useMemoized(() => ScrollOffsetController());
    final itemPositionsListener = useMemoized(
      () => ItemPositionsListener.create(),
    );
    final scrollOffsetListener = useMemoized(
      () => ScrollOffsetListener.create(),
    );

    final scrollOffset = useRef(0.0);
    final accumulatedOffset = useRef(0.0);
    final autoScrollTimer = useRef<Timer?>(null);
    final autoScrollSpeed = useState(2.0);
    final autoScrollActive = useState(false);
    final jumpInFlight = useRef(false);
    final snapInFlight = useRef(false);
    final applyingGate = useRef(false);
    final lastReportedChapterIndex = useRef(currentChapterIndex);
    final narrationOutOfSync = useState(false);
    final narrationReveals = useRef<Map<int, void Function()>>({});
    final progressNotifier = useValueNotifier(0.0);

    final resumeChapterIndex = currentChapterIndex;
    final pendingRestoreCharOffset = useState<int?>(null);
    final restoreApplied = useState(false);
    final lastReportedPosition = useRef<({int index, int total})?>(null);

    final isDesktop = MediaQuery.sizeOf(context).width >= 840;
    final isDarkTheme =
        Theme.of(context).colorScheme.brightness == Brightness.dark;

    bool isNearCurrentViewport(int index) {
      final positions = itemPositionsListener.itemPositions.value;
      if (positions.isEmpty) return false;
      var min = chapters.length;
      var max = -1;
      for (final p in positions) {
        if (p.index < min) min = p.index;
        if (p.index > max) max = p.index;
      }
      return index >= min - 1 && index <= max + 1;
    }

    int? currentChapterFromPositions(Iterable<ItemPosition> positions) {
      final visible = positions.where(
        (p) => p.itemLeadingEdge < 1 && p.itemTrailingEdge > 0,
      );
      if (visible.isEmpty) return null;
      return visible
          .reduce((a, b) => a.itemLeadingEdge < b.itemLeadingEdge ? a : b)
          .index;
    }

    void syncCurrentChapter() {
      if (!context.mounted || jumpInFlight.value) return;
      final current = currentChapterFromPositions(
        itemPositionsListener.itemPositions.value,
      );
      if (current == null) return;
      lastReportedChapterIndex.value = current;
      onCurrentChapterChanged(current);
    }

    Future<void> scrollToChapter(int index, {bool animate = true}) async {
      if (index < 0 || index >= chapters.length) return;
      if (!itemScrollController.isAttached) return;
      jumpInFlight.value = true;
      final canAnimate = animate && isNearCurrentViewport(index);
      if (canAnimate) {
        await itemScrollController.scrollTo(
          index: index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        itemScrollController.jumpTo(index: index);
      }
      jumpInFlight.value = false;
      if (context.mounted) syncCurrentChapter();
    }

    void restoreScrollProgress(double progress, {int retries = 5}) {
      if (!itemScrollController.isAttached) {
        if (retries > 0) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => restoreScrollProgress(progress, retries: retries - 1),
          );
        }
        return;
      }
      final index = (progress * chapters.length).floor().clamp(
        0,
        chapters.length - 1,
      );
      scrollToChapter(index, animate: false);
    }

    void stopAutoScroll() {
      autoScrollTimer.value?.cancel();
      autoScrollTimer.value = null;
      autoScrollActive.value = false;
    }

    void startAutoScroll() {
      autoScrollTimer.value?.cancel();
      autoScrollActive.value = true;
      chromeNotifier.setFullscreen(true, isDarkTheme: isDarkTheme);
      autoScrollTimer.value = Timer.periodic(const Duration(milliseconds: 50), (
        _,
      ) {
        if (!context.mounted || !itemScrollController.isAttached) return;
        if (progressNotifier.value >= 0.99) {
          stopAutoScroll();
          return;
        }
        unawaited(
          scrollOffsetController.animateScroll(
            offset: autoScrollSpeed.value,
            duration: const Duration(milliseconds: 50),
            curve: Curves.linear,
          ),
        );
      });
    }

    void toggleAutoScroll() {
      if (autoScrollActive.value) {
        stopAutoScroll();
      } else {
        startAutoScroll();
      }
    }

    bool isChapterLoading(int index) {
      if (index < 0 || index >= chapters.length) return false;
      final state = ref.read(readerChapterContentProvider(chapters[index]));
      return state is AsyncLoading || state is AsyncError;
    }

    void applyScrollGateIfNeeded(Iterable<ItemPosition> positions) {
      if (applyingGate.value) return;
      for (final p in positions) {
        if (isChapterLoading(p.index) && p.itemLeadingEdge < 0) {
          applyingGate.value = true;
          if (itemScrollController.isAttached) {
            itemScrollController.jumpTo(index: p.index, alignment: 0);
          }
          applyingGate.value = false;
          return;
        }
      }
    }

    double progressFromPositions(Iterable<ItemPosition> positions) {
      final total = chapters.length;
      if (total == 0) return 0.0;
      final visible = positions.where(
        (p) => p.itemLeadingEdge < 1 && p.itemTrailingEdge > 0,
      );
      if (visible.isEmpty) return progressNotifier.value;
      final top = visible.reduce(
        (a, b) => a.itemLeadingEdge < b.itemLeadingEdge ? a : b,
      );
      final withinItem = (-top.itemLeadingEdge).clamp(0.0, 1.0);
      return ((top.index + withinItem) / total).clamp(0.0, 1.0);
    }

    void reportPosition(Iterable<ItemPosition> positions) {
      final onPosition = onPositionChanged;
      if (onPosition == null) return;
      if (!restoreApplied.value &&
          restorePosition != null &&
          restorePosition! > 0) {
        return;
      }
      final total = chapters.length;
      if (total == 0) return;
      final visible = positions.where(
        (p) => p.itemLeadingEdge < 1 && p.itemTrailingEdge > 0,
      );
      if (visible.isEmpty) return;
      final top = visible.reduce(
        (a, b) => a.itemLeadingEdge < b.itemLeadingEdge ? a : b,
      );
      final content = ref
          .read(readerChapterContentProvider(chapters[top.index]))
          .valueOrNull;
      if (content == null || content.isEmpty) return;
      final extent = top.itemTrailingEdge - top.itemLeadingEdge;
      if (extent <= 0) return;
      final viewportHeight = MediaQuery.sizeOf(context).height;
      final totalHeightPx = extent * viewportHeight;
      const headerHeightPx = 130.0;
      const footerHeightPx = 110.0;
      final contentHeightPx = math.max(1.0, totalHeightPx - headerHeightPx - footerHeightPx);

      final scrolledPx = (-top.itemLeadingEdge) * viewportHeight;
      final contentScrolledPx = (scrolledPx - headerHeightPx).clamp(0.0, contentHeightPx);
      final within = (contentScrolledPx / contentHeightPx).clamp(0.0, 1.0);
      final charOffset = (within * content.length).round().clamp(
        0,
        content.length,
      );
      final resolved = _resolver.resolveFirstWithinRange(
        content,
        charOffset,
        content.length,
      );
      final last = lastReportedPosition.value;
      if (last != null &&
          last.index == resolved.index &&
          last.total == resolved.total) {
        return;
      }
      lastReportedPosition.value = (
        index: resolved.index,
        total: resolved.total,
      );
      onPosition(resolved.index, resolved.total);
    }

    void onPositionsChanged() {
      final positions = itemPositionsListener.itemPositions.value;
      if (positions.isEmpty) return;

      final progress = progressFromPositions(positions);
      progressNotifier.value = progress;
      onScrollProgress(progress);
      reportPosition(positions);

      if (jumpInFlight.value) return;

      final current = currentChapterFromPositions(positions);
      if (current != null && current != lastReportedChapterIndex.value) {
        lastReportedChapterIndex.value = current;
        onCurrentChapterChanged(current);
      }
      applyScrollGateIfNeeded(positions);
    }

    void onScrollOffsetChange(double delta) {
      if (!context.mounted) return;
      accumulatedOffset.value += delta;
      scrollOffset.value = accumulatedOffset.value;
      chromeNotifier.resetChromeTimer(isDarkTheme: isDarkTheme);
      if (jumpInFlight.value) return;
      if (delta.abs() > 4) {
        final direction = delta > 0 ? ScrollDirection.down : ScrollDirection.up;
        onScrollDirectionChanged(direction);
        if (direction == ScrollDirection.up) {
          chromeNotifier.setFullscreen(false, isDarkTheme: isDarkTheme);
        }
      }
    }

    int? resolveRestoreCharOffset() {
      final pos = restorePosition;
      if (pos == null ||
          pos <= 0 ||
          resumeChapterIndex < 0 ||
          resumeChapterIndex >= chapters.length) {
        return null;
      }
      final content = ref
          .read(readerChapterContentProvider(chapters[resumeChapterIndex]))
          .valueOrNull;
      if (content == null || content.isEmpty) return null;
      return _resolver.charOffsetForSentenceIndex(content, pos);
    }

    useEffect(() {
      chromeNotifier.initReaderChrome(isDarkTheme: isDarkTheme);
      itemPositionsListener.itemPositions.addListener(onPositionsChanged);
      final sub = scrollOffsetListener.changes.listen(onScrollOffsetChange);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (currentChapterIndex >= 0 && currentChapterIndex < chapters.length) {
          scrollToChapter(currentChapterIndex);
        } else if (initialScrollProgress != null) {
          restoreScrollProgress(initialScrollProgress!);
        } else {
          scrollToChapter(0);
        }
      });

      return () {
        autoScrollTimer.value?.cancel();
        itemPositionsListener.itemPositions.removeListener(onPositionsChanged);
        sub.cancel();
      };
    }, const []);

    final prevChapterTarget = useRef(currentChapterIndex);
    useEffect(() {
      if (currentChapterIndex != lastReportedChapterIndex.value &&
          currentChapterIndex != prevChapterTarget.value) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => scrollToChapter(currentChapterIndex),
        );
      }
      prevChapterTarget.value = currentChapterIndex;
      return null;
    }, [currentChapterIndex]);

    int? narratingChapterIndex() {
      final item = ref.read(activeSpeechItemProvider);
      if (item == null) return null;
      for (var i = 0; i < chapters.length; i++) {
        if (chapters[i].id == item.chapterId) return i;
      }
      return null;
    }

    void acquireNarrationReveal(int index, {required int attempts}) {
      if (attempts <= 0) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final handle = narrationReveals.value[index];
        if (handle != null) {
          handle();
          return;
        }
        acquireNarrationReveal(index, attempts: attempts - 1);
      });
    }

    void revealNarration() {
      final index = narratingChapterIndex();
      if (index == null || !itemScrollController.isAttached) return;
      final handle = narrationReveals.value[index];
      if (handle != null) {
        handle();
        return;
      }
      scrollToChapter(index);
      acquireNarrationReveal(index, attempts: 20);
    }

    void applyBrightness(double newBrightness) {
      final notifier = ref.read(readingSettingsProvider.notifier);
      notifier.setBrightness(newBrightness);
      final svc = ref.read(platformServiceProvider);
      svc.setBrightness(newBrightness, smooth: true);
    }

    bool onScrollEnd(ScrollEndNotification notification) {
      if (settings.scrollAnimation != ScrollAnimation.snap) return false;
      if (notification.depth != 0) return false;
      if (notification.dragDetails == null) return false;
      if (snapInFlight.value) return false;
      if (!itemScrollController.isAttached) return false;
      final viewport = MediaQuery.sizeOf(context).height;
      final page = (scrollOffset.value / viewport).round();
      final correction = page * viewport - scrollOffset.value;
      if (correction.abs() < 0.5) return false;
      snapInFlight.value = true;
      unawaited(
        scrollOffsetController
            .animateScroll(
              offset: correction,
              duration: _snapScrollDuration,
              curve: Curves.easeOut,
            )
            .whenComplete(() => snapInFlight.value = false),
      );
      return true;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final vt = settings.theme;

    Widget wrapWithAnimation(Widget listView) {
      return switch (settings.scrollAnimation) {
        ScrollAnimation.smooth => listView,
        ScrollAnimation.snap => NotificationListener<ScrollEndNotification>(
          onNotification: onScrollEnd,
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
                  valueListenable: progressNotifier,
                  builder: (context, progress, _) => SizedBox(
                    width: 8,
                    child: CustomPaint(
                      painter: _GlowScrollbarPainter(
                        progress: progress,
                        color: settings.theme.resolve(colorScheme).accent,
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

    Widget wrapHeaderWithParallax(Widget header, int index) {
      if (settings.scrollAnimation != ScrollAnimation.parallax) return header;
      final offset =
          math.sin((index * math.pi * 0.3) + (scrollOffset.value * 0.003)) * 6;
      return Transform.translate(offset: Offset(0, offset), child: header);
    }

    void toggleChrome() {
      if (chromeState.rightPanelVisible || chromeState.narrationPanelVisible) {
        chromeNotifier.hideRightPanel();
        return;
      }
      chromeNotifier.toggleChrome(isDarkTheme: isDarkTheme);
    }

    Widget buildChapterBlock(
      ChapterEntity chapter,
      int index, {
      bool showHeaders = true,
      int? restoreCharOffset,
      void Function()? onRestoreRevealed,
    }) {
      final cs = ChapterStyle.forChapter(index, colorScheme);

      final block = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeaders) ...[
            wrapHeaderWithParallax(
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
            fontSize: settings.fontSize,
            fontFamily: settings.fontFamily,
            fontWeight: settings.fontWeight,
            lineHeight: settings.lineHeight,
            letterSpacing: settings.letterSpacing,
            vt: vt,
            textAlignment: settings.textAlignment,
            marginPreset: settings.marginPreset,
            horizontalPadding: settings.horizontalPadding,
            scrollable: false,
            chapterStyle: cs,
            restoreCharOffset: restoreCharOffset,
            onRestoreRevealed: onRestoreRevealed,
            onNarrationOutOfSyncChanged: (outOfSync) {
              if (context.mounted && narrationOutOfSync.value != outOfSync) {
                narrationOutOfSync.value = outOfSync;
              }
            },
            onRegisterNarrationReveal: (reveal) {
              narrationReveals.value[index] = reveal;
            },
            onHighlight: onHighlight,
            onAddNote: onAddNote,
            onShare: onShare,
            onSearchWeb: onSearchWeb,
            onListen: onListen,
            onErase: onErase,
            onTap: toggleChrome,
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
              baseFontSize: settings.fontSize,
            ),
        ],
      );

      final windowWidth = MediaQuery.sizeOf(context).width;
      final maxWidth = AppBreakpoints.readerResponsiveMaxWidth(windowWidth);
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: block,
        ),
      );
    }

    void showChapterIndex(BuildContext ctx) {
      ChapterIndexSheet.show(
        ctx,
        sheetId: 'continuous_chapter_index',
        chapters: chapters,
        currentChapterIndex: currentChapterIndex,
        onChapterTap: (idx) {
          onChapterSelected(idx);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => scrollToChapter(idx),
          );
        },
      );
    }

    KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (!isDesktop) return KeyEventResult.ignored;

      final common = handleCommonReaderKeys(
        event,
        commandPaletteVisible: chromeState.commandPaletteVisible,
        onClosePalette: () => chromeNotifier.setCommandPaletteVisible(false),
        onToggleChrome: () =>
            chromeNotifier.toggleChrome(isDarkTheme: isDarkTheme),
        onOpenPalette: () => chromeNotifier.setCommandPaletteVisible(true),
      );
      if (common != KeyEventResult.ignored) return common;

      final screenHeight = MediaQuery.sizeOf(context).height;
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (!itemScrollController.isAttached) return KeyEventResult.handled;
        chromeNotifier.resetChromeTimer(isDarkTheme: isDarkTheme);
        unawaited(
          scrollOffsetController.animateScroll(
            offset: -screenHeight * 0.4,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          ),
        );
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (!itemScrollController.isAttached) return KeyEventResult.handled;
        chromeNotifier.resetChromeTimer(isDarkTheme: isDarkTheme);
        unawaited(
          scrollOffsetController.animateScroll(
            offset: screenHeight * 0.4,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          ),
        );
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.pageUp) {
        if (!itemScrollController.isAttached) return KeyEventResult.handled;
        chromeNotifier.resetChromeTimer(isDarkTheme: isDarkTheme);
        unawaited(
          scrollOffsetController.animateScroll(
            offset: -screenHeight * 0.85,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          ),
        );
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.pageDown) {
        if (!itemScrollController.isAttached) return KeyEventResult.handled;
        chromeNotifier.resetChromeTimer(isDarkTheme: isDarkTheme);
        unawaited(
          scrollOffsetController.animateScroll(
            offset: screenHeight * 0.85,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          ),
        );
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    }

    if (!restoreApplied.value && pendingRestoreCharOffset.value == null) {
      pendingRestoreCharOffset.value = resolveRestoreCharOffset();
    }

    final platform = Theme.of(context).platform;
    final scrollPhysics =
        (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS)
        ? const BouncingScrollPhysics()
        : const ClampingScrollPhysics();

    final useSidePanels =
        isDesktop &&
        AppSheet.desktopPresentation == DesktopSheetPresentation.sidePanel;

    return Scaffold(
      backgroundColor: vt.resolve(colorScheme).background,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: [
          Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                if (chromeState.rightPanelVisible ||
                    chromeState.narrationPanelVisible) {
                  chromeNotifier.hideRightPanel();
                  return KeyEventResult.handled;
                }
              }
              return handleKeyEvent(node, event);
            },
            child: SafeArea(
              bottom: false,
              left: false,
              right: false,
              child: GestureDetector(
                onTap: toggleChrome,
                child: wrapWithAnimation(
                  ScrollablePositionedList.builder(
                    itemScrollController: itemScrollController,
                    scrollOffsetController: scrollOffsetController,
                    itemPositionsListener: itemPositionsListener,
                    scrollOffsetListener: scrollOffsetListener,
                    physics: scrollPhysics,
                    itemCount: chapters.length,
                    initialScrollIndex: currentChapterIndex.clamp(
                      0,
                      math.max(0, chapters.length - 1),
                    ),
                    itemBuilder: (context, index) => buildChapterBlock(
                      chapters[index],
                      index,
                      showHeaders: true,
                      restoreCharOffset: index == resumeChapterIndex
                          ? pendingRestoreCharOffset.value
                          : null,
                      onRestoreRevealed: () {
                        pendingRestoreCharOffset.value = null;
                        restoreApplied.value = true;
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!isDesktop)
            BrightnessEdgeGestureRegion(
              onVerticalDragStart: (details) =>
                  chromeNotifier.onEdgeBrightnessStart(
                    details,
                    followSystemBrightness: settings.followSystemBrightness,
                    currentBrightness: settings.brightness,
                  ),
              onVerticalDragUpdate: (details) => chromeNotifier
                  .onEdgeBrightnessUpdate(details, onChanged: applyBrightness),
              onVerticalDragEnd: chromeNotifier.onEdgeBrightnessEnd,
            ),
          if (autoScrollActive.value)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: _AutoScrollControl(
                  speed: autoScrollSpeed.value,
                  onSpeedChanged: (s) =>
                      autoScrollSpeed.value = s.clamp(1.0, 6.0),
                  onStop: stopAutoScroll,
                  accent: settings.theme.resolve(colorScheme).accent,
                ),
              ),
            ),
          if (narrationOutOfSync.value && narratingChapterIndex() != null)
            Positioned(
              right: 16,
              bottom: isDesktop ? 24 : 88,
              child: _NarrationSyncButton(
                accent: settings.theme.resolve(colorScheme).accent,
                onPressed: revealNarration,
              ),
            ),
          if (isDesktop &&
              (chromeState.rightPanelVisible ||
                  chromeState.narrationPanelVisible))
            DesktopRightPanelRegion(
              visible:
                  chromeState.rightPanelVisible ||
                  chromeState.narrationPanelVisible,
              chromeVisible: chromeState.chromeVisible,
              panelWidth: 280.0,
              panel: chromeState.narrationPanelVisible
                  ? NowPlayingPanel(
                      bookTitle: bookTitle,
                      coverPath: coverPath,
                      chapterTitle: chapters[currentChapterIndex].title,
                      accent: settings.theme.resolve(colorScheme).accent,
                      onClose: chromeNotifier.closeNarrationPanel,
                    )
                  : ReaderRightPanel(
                      chapters: chapters,
                      currentChapterIndex: currentChapterIndex,
                      bookmarkedChapterIds: bookmarkedChapterIds,
                      onChapterSelected: (idx) {
                        onChapterSelected(idx);
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => scrollToChapter(idx),
                        );
                      },
                      onBookmarkToggle: onBookmarkToggle,
                      isBookmarked: isBookmarked,
                      onClose: chromeNotifier.hideRightPanel,
                      settings: settings,
                    ),
            ),
          if (chromeState.commandPaletteVisible)
            ReaderCommandPalette(
              chapters: chapters,
              currentChapterIndex: currentChapterIndex,
              onChapterSelected: (idx) {
                onChapterSelected(idx);
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => scrollToChapter(idx),
                );
              },
              onToggleBookmark: onBookmarkToggle,
              isBookmarked: isBookmarked,
              onToggleSettings: onSettingsTap,
              onOpenAnnotations: () {
                ReaderAnnotationsSheet.show(
                  context,
                  bookId: chapters.first.bookId,
                  chapters: chapters,
                  currentChapterId: chapters[currentChapterIndex].id,
                  bookTitle: bookTitle,
                  coverPath: coverPath,
                  onJumpToChapter: (chId, _) {
                    final idx = chapters.indexWhere((c) => c.id == chId);
                    if (idx >= 0) {
                      onChapterSelected(idx);
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => scrollToChapter(idx),
                      );
                    }
                  },
                );
              },
              onClose: () => chromeNotifier.setCommandPaletteVisible(false),
            ),
          if (!chromeState.narrationPanelVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: NarrationMiniPlayer(
                bookTitle: bookTitle,
                coverPath: coverPath,
                chapterTitle: chapters[currentChapterIndex].title,
                accent: settings.theme.resolve(colorScheme).accent,
                onExpand: useSidePanels
                    ? chromeNotifier.toggleNarrationPanel
                    : null,
              ),
            ),
          if (chromeState.chromeVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ReaderBarSurface(
                style: settings.chromeStyle,
                color: colorScheme.surfaceContainerHigh,
                child: ReaderChromeBar(
                  title: chapters[currentChapterIndex].title,
                  textColor: colorScheme.onSurface,
                  onSettingsTap: onSettingsTap,
                  onSearchTap: onSearchTap,
                  onRedownload: onRedownload,
                  isRedownloading: isRedownloading,
                ),
              ),
            ),
          if (chromeState.chromeVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ReaderBarSurface(
                style: settings.chromeStyle,
                color: colorScheme.surfaceContainerHigh,
                child: ReaderBottomNav(
                  textColor: colorScheme.onSurface,
                  onSettingsTap: onSettingsTap,
                  onChapterIndexTap: () => showChapterIndex(context),
                  onBookmarkTap: onBookmarkToggle,
                  isBookmarked: isBookmarked,
                  onAnnotationsTap: () {
                    ReaderAnnotationsSheet.show(
                      context,
                      bookId: chapters.first.bookId,
                      chapters: chapters,
                      currentChapterId: chapters[currentChapterIndex].id,
                      bookTitle: bookTitle,
                      coverPath: coverPath,
                      onJumpToChapter: (chId, _) {
                        final idx = chapters.indexWhere((c) => c.id == chId);
                        if (idx >= 0) {
                          onChapterSelected(idx);
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => scrollToChapter(idx),
                          );
                        }
                      },
                    );
                  },
                  currentChapterTitle: chapters[currentChapterIndex].title,
                  currentChapterNumber: currentChapterIndex,
                  totalChapters: chapters.length,
                  autoScrollActive: autoScrollActive.value,
                  onAutoScrollToggle: toggleAutoScroll,
                  bookTitle: bookTitle,
                  coverPath: coverPath,
                  progress: progressNotifier,
                  progressColor: settings.theme.resolve(colorScheme).accent,
                  onListenTap: useSidePanels
                      ? chromeNotifier.toggleNarrationPanel
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlowScrollbarPainter extends CustomPainter {
  const _GlowScrollbarPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()..color = color.withValues(alpha: 0.15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4)),
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

class _NarrationSyncButton extends StatelessWidget {
  const _NarrationSyncButton({required this.accent, required this.onPressed});

  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark =
        ThemeData.estimateBrightnessForColor(scheme.surface) == Brightness.dark;
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
