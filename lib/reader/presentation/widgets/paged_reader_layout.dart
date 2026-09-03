import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/molecules/app_error_state.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/providers/annotations_provider.dart';
import 'package:atlas_app/reader/presentation/providers/atlas_glossary_providers.dart';
import 'package:atlas_app/reader/presentation/providers/reader_chrome_provider.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/utils/chapter_position_resolver.dart';
import 'package:atlas_app/reader/presentation/utils/glossary_highlight_ranges.dart';
import 'package:atlas_app/reader/presentation/utils/pager_boundary.dart';
import 'package:atlas_app/reader/presentation/utils/reader_key_events.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_index_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_narration_coordinator.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_pager.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_shimmer.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_styles.dart';
import 'package:atlas_app/reader/presentation/widgets/glossary_term_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_mini_player.dart';
import 'package:atlas_app/reader/presentation/widgets/now_playing_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/paged_page_view.dart';
import 'package:atlas_app/reader/presentation/widgets/pager.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_annotations_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bar_surface.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bottom_nav.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_chrome_bar.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_command_palette.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_edge_regions.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_right_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';

class PagedReaderLayout extends HookConsumerWidget {
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
    this.onSearchTap,
    required this.isBookmarked,
    required this.onBookmarkToggle,
    this.bookTitle,
    this.coverPath,
    this.onOpenAnnotations,
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
  final VoidCallback? onSearchTap;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;
  final String? bookTitle;
  final String? coverPath;
  final VoidCallback? onOpenAnnotations;
  final int? restorePosition;
  final void Function(int sentenceIndex, int totalSentences)? onPositionChanged;

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

  static const int _chunkedMaxPagesPerFrame = 5;
  static const ChapterPositionResolver _resolver = ChapterPositionResolver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chromeState = ref.watch(readerChromeProvider);
    final chromeNotifier = ref.read(readerChromeProvider.notifier);

    final outerController = usePageController(initialPage: currentChapterIndex);
    final innerControllers = useRef<Map<int, PageController>>({});
    final pageCache = useRef<Map<int, List<String>>>({});
    final contentCache = useRef<Map<int, String>>({});
    final loadedChapters = useRef<Set<int>>({});
    final failedChapters = useState<Set<int>>({});
    final progressNotifier = useValueNotifier(0.0);
    final cacheKey = useRef<String>('');
    final layoutWidth = useRef(0.0);
    final layoutHeight = useRef(0.0);
    final neighborPrefetchScheduledFor = useRef<int?>(null);
    final chapterIndex = useState(currentChapterIndex);
    final lastPanelIndex = useRef<Map<int, int>>({});
    final chapterTurnLocked = useState(false);
    final resumeChapterIndex = currentChapterIndex;
    final restorePending = useState(
      restorePosition != null && restorePosition! > 0,
    );

    final paginationInFlight = useRef<Set<int>>({});
    final paginationEpoch = useRef(0);
    final chunkedOffset = useRef<Map<int, int>>({});
    final chunkedAccumulator = useRef<Map<int, List<String>>>({});

    final updateTrigger = useState(0);
    void triggerUiUpdate() {
      updateTrigger.value++;
    }

    final isDesktop = MediaQuery.sizeOf(context).width >= 840;
    final isWideDesktop = isDesktop && MediaQuery.sizeOf(context).width >= 1200;
    final isDarkTheme =
        Theme.of(context).colorScheme.brightness == Brightness.dark;
    // Whether to render a two-page book spread (requires wide desktop AND user preference)
    final useSpread = isWideDesktop && settings.useBookSpread;

    double pageWidthForCurrentMode() {
      final rawWidth = layoutWidth.value > 0 ? layoutWidth.value : 800.0;
      if (useSpread) {
        final maxSpreadWidth =
            rawWidth -
            ((chromeState.rightPanelVisible ||
                    chromeState.narrationPanelVisible)
                ? 280.0
                : 0);
        final pageArea = maxSpreadWidth * 0.9;
        return (pageArea / 2).clamp(280.0, 520.0);
      }
      // Single-page mode: use responsive max width
      final windowWidth = MediaQuery.sizeOf(context).width;
      final maxWidth = AppBreakpoints.readerResponsiveMaxWidth(windowWidth);
      return rawWidth > maxWidth ? maxWidth : rawWidth;
    }

    String computeCacheKey() {
      final s = settings;
      final w = layoutWidth.value.round();
      final h = layoutHeight.value.round();
      return '${s.fontSize}_${s.fontFamily}_${s.fontWeight}_${s.lineHeight}_${s.marginPreset.name}_${s.horizontalPadding}_${s.useBookSpread}_${s.textAlignment.name}_${w}x$h';
    }

    bool needsRepagination() {
      final newKey = computeCacheKey();
      if (newKey != cacheKey.value) {
        cacheKey.value = newKey;
        return true;
      }
      return false;
    }

    int pageStartOffset(int chIdx, int localPage) {
      final cache = pageCache.value[chIdx];
      if (cache == null || localPage <= 0) return 0;
      var offset = 0;
      final upto = math.min(localPage, cache.length);
      for (var i = 0; i < upto; i++) {
        offset += cache[i].length;
      }
      return offset;
    }

    int localPageForCharOffset(int chIdx, int charOffset) {
      final cache = pageCache.value[chIdx];
      if (cache == null || cache.isEmpty) return 0;
      var start = 0;
      for (var i = 0; i < cache.length; i++) {
        final end = start + cache[i].length;
        if (charOffset < end) return i;
        start = end;
      }
      return cache.length - 1;
    }

    int? restoreLocalPage(int chIdx) {
      final pos = restorePosition;
      if (pos == null || pos <= 0) return null;
      final content = contentCache.value[chIdx];
      if (content == null || content.isEmpty) return null;
      final cache = pageCache.value[chIdx];
      if (cache == null || cache.isEmpty) return null;
      final charOffset = _resolver.charOffsetForSentenceIndex(content, pos);
      if (charOffset == null) return null;
      return localPageForCharOffset(chIdx, charOffset);
    }

    int currentLocalPage(int chIdx) {
      final pages = pageCache.value[chIdx];
      if (pages == null || pages.isEmpty) return 0;
      final panel = lastPanelIndex.value[chIdx] ?? 0;
      final base = useSpread ? panel * 2 : panel;
      return base.clamp(0, pages.length - 1);
    }

    void reportPositionFromCurrentPage() {
      final onPos = onPositionChanged;
      if (onPos == null) return;
      final content = contentCache.value[chapterIndex.value];
      if (content == null || content.isEmpty) return;
      final localPage = currentLocalPage(chapterIndex.value);
      final startOffset = pageStartOffset(chapterIndex.value, localPage);
      final pageLength =
          pageCache.value[chapterIndex.value]?[localPage].length ?? 0;
      final endOffset = startOffset + pageLength;
      final resolved = _resolver.resolveFirstWithinRange(
        content,
        startOffset,
        endOffset,
      );
      onPos(resolved.index, resolved.total);
    }

    PageController innerControllerFor(int chapterIdx) {
      return innerControllers.value.putIfAbsent(chapterIdx, () {
        return PageController(
          initialPage: lastPanelIndex.value[chapterIdx] ?? 0,
        );
      });
    }

    int panelCountFor(int chIdx) {
      final pages = pageCache.value[chIdx]?.length ?? 0;
      return useSpread ? spreadCount(pages) : pages;
    }

    double computedProgress() => chapterFraction(
      chapterIndex: chapterIndex.value,
      chapterCount: chapters.length,
      localIndex: lastPanelIndex.value[chapterIndex.value] ?? 0,
      localCount: math.max(1, panelCountFor(chapterIndex.value)),
    );

    void updateProgress() {
      final value = computedProgress();
      progressNotifier.value = value;
      onProgressChanged(value);
    }

    void turnChapter(bool forward) {
      if (chapterTurnLocked.value) return;
      final target = chapterIndex.value + (forward ? 1 : -1);
      if (target < 0 || target >= chapters.length) return;
      chapterTurnLocked.value = true;
      outerController
          .animateToPage(
            target,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          )
          .whenComplete(() {
            if (context.mounted) chapterTurnLocked.value = false;
          });
    }

    void turnPanel({required bool forward}) {
      if (chapterTurnLocked.value) return;
      final controller = innerControllers.value[chapterIndex.value];
      final count = panelCountFor(chapterIndex.value);
      if (controller == null || !controller.hasClients || count <= 0) {
        turnChapter(forward);
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
      turnChapter(forward);
    }

    void turnForward() => turnPanel(forward: true);
    void turnBack() => turnPanel(forward: false);

    void toggleChrome() {
      if (chromeState.rightPanelVisible || chromeState.narrationPanelVisible) {
        chromeNotifier.hideRightPanel();
        return;
      }
      chromeNotifier.toggleChrome(isDarkTheme: isDarkTheme);
    }

    void onMobileTapUp(TapUpDetails details, BoxConstraints constraints) {
      final width = constraints.maxWidth;
      final x = details.localPosition.dx;
      if (x < width / 3) {
        turnBack();
      } else if (x > width * 2 / 3) {
        turnForward();
      } else {
        toggleChrome();
      }
    }

    void applyBrightness(double newBrightness) {
      final notifier = ref.read(readingSettingsProvider.notifier);
      notifier.setBrightness(newBrightness);
      final svc = ref.read(platformServiceProvider);
      svc.setBrightness(newBrightness, smooth: true);
    }

    void clampInnerAfterRepagination(int chapterIdx) {
      final controller = innerControllers.value[chapterIdx];
      if (controller == null || !controller.hasClients) return;
      final count = panelCountFor(chapterIdx);
      if (count <= 0) return;
      final page = controller.page ?? 0;
      if (page > count - 1) {
        controller.jumpToPage(count - 1);
        lastPanelIndex.value[chapterIdx] = count - 1;
      }
    }

    void evictDistantCaches() {
      if (pageCache.value.length <= 15) return;
      final distantKeys =
          pageCache.value.keys
              .where((k) => (k - chapterIndex.value).abs() > 5)
              .toList()
            ..sort(
              (a, b) => (b - chapterIndex.value).abs().compareTo(
                (a - chapterIndex.value).abs(),
              ),
            );

      for (final key in distantKeys) {
        if (pageCache.value.length <= 12) break;
        pageCache.value.remove(key);
        contentCache.value.remove(key);
        loadedChapters.value.remove(key);
        final ctrl = innerControllers.value.remove(key);
        ctrl?.dispose();
      }
    }

    void paginateChapterIncremental(int index, String content, int epoch) {
      if (epoch != paginationEpoch.value || !context.mounted) {
        paginationInFlight.value.remove(index);
        return;
      }
      final colorScheme = Theme.of(context).colorScheme;
      final s = settings;
      final horizontalMargin = s.horizontalPadding;
      final verticalMargin = switch (s.marginPreset) {
        MarginPreset.narrow => AppSpacing.sm,
        MarginPreset.normal => AppSpacing.md,
        MarginPreset.wide => AppSpacing.lg,
      };
      final rawHeight = layoutHeight.value > 0
          ? layoutHeight.value
          : MediaQuery.sizeOf(context).height;
      final width = pageWidthForCurrentMode();
      final pWidth = width - horizontalMargin * 2;
      final pHeight = rawHeight - verticalMargin * 2;

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

      final startOffset = chunkedOffset.value[index] ?? 0;
      final result = Pager.paginateChunked(
        text: content,
        textStyle: textStyle,
        pageWidth: pWidth,
        pageHeight: pHeight,
        startIndex: startOffset,
        maxPages: _chunkedMaxPagesPerFrame,
      );

      chunkedAccumulator.value
          .putIfAbsent(index, () => [])
          .addAll(result.pages);

      if (result.complete) {
        paginationInFlight.value.remove(index);
        pageCache.value[index] = chunkedAccumulator.value.remove(index) ?? [''];
        chunkedOffset.value.remove(index);
        evictDistantCaches();
        ref.read(chapterLoadPhaseProvider(chapters[index]).notifier).state =
            ChapterLoadPhase.done;
        if (context.mounted) {
          clampInnerAfterRepagination(index);
          if (index == chapterIndex.value) {
            updateProgress();
            if (!restorePending.value) {
              reportPositionFromCurrentPage();
            }
          }
          triggerUiUpdate();
        }
      } else {
        chunkedOffset.value[index] = result.endIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted || epoch != paginationEpoch.value) {
            paginationInFlight.value.remove(index);
            return;
          }
          paginateChapterIncremental(index, content, epoch);
        });
      }
    }

    void schedulePagination(int index, String content) {
      if (paginationInFlight.value.contains(index)) return;
      paginationInFlight.value.add(index);
      final epoch = paginationEpoch.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || epoch != paginationEpoch.value) {
          paginationInFlight.value.remove(index);
          return;
        }
        paginateChapterIncremental(index, content, epoch);
      });
    }

    void onContentLoaded(int index, String content) {
      contentCache.value[index] = content;
      if (needsRepagination() || pageCache.value[index] == null) {
        schedulePagination(index, content);
      } else {
        ref.read(chapterLoadPhaseProvider(chapters[index]).notifier).state =
            ChapterLoadPhase.done;
      }
      if (context.mounted) triggerUiUpdate();
    }

    void markChapterFailed(int index) {
      loadedChapters.value.remove(index);
      if (!context.mounted) return;
      failedChapters.value = {...failedChapters.value, index};
    }

    Future<void> loadContent(int index, ChapterEntity chapter) async {
      try {
        final content = await ref.read(
          readerChapterContentProvider(chapter).future,
        );
        if (!context.mounted) return;
        if (failedChapters.value.contains(index)) {
          final next = Set<int>.from(failedChapters.value)..remove(index);
          failedChapters.value = next;
        }
        onContentLoaded(index, content);
        prefetchNeighboringChapters(ref, chapter);
      } on Object {
        markChapterFailed(index);
      }
    }

    void ensureChapterLoaded(int index) {
      if (loadedChapters.value.contains(index) ||
          failedChapters.value.contains(index)) {
        return;
      }
      loadedChapters.value.add(index);
      final chapter = chapters[index];
      final cached = ref.read(readerChapterContentProvider(chapter));
      cached.whenOrNull(
        data: (content) => WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) onContentLoaded(index, content);
        }),
      );
      if (cached is! AsyncData) {
        loadContent(index, chapter);
      }
    }

    void retryChapter(int index) {
      final next = Set<int>.from(failedChapters.value)..remove(index);
      failedChapters.value = next;
      ref.invalidate(readerChapterContentProvider(chapters[index]));
      ensureChapterLoaded(index);
    }

    void scheduleNeighborPrefetch(int currentIndex, int chapterCount) {
      if (neighborPrefetchScheduledFor.value == currentIndex) return;
      neighborPrefetchScheduledFor.value = currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (currentIndex > 0) ensureChapterLoaded(currentIndex - 1);
        if (currentIndex < chapterCount - 1) {
          ensureChapterLoaded(currentIndex + 1);
        }
      });
    }

    void onOuterPageChanged(int chapterIdx) {
      if (chapterIdx == chapterIndex.value) return;
      chapterIndex.value = chapterIdx;
      ensureChapterLoaded(chapterIdx);
      if (chapterIdx + 1 < chapters.length) {
        ensureChapterLoaded(chapterIdx + 1);
      }
      if (chapterIdx > 0) {
        ensureChapterLoaded(chapterIdx - 1);
      }
      reportPositionFromCurrentPage();
      onPageChanged(chapterIdx);
      updateProgress();
      chromeNotifier.resetChromeTimer(isDarkTheme: isDarkTheme);
    }

    void onInnerPageChanged(int chapterIdx, int panel) {
      lastPanelIndex.value[chapterIdx] = panel;
      if (chapterIdx != chapterIndex.value) return;
      reportPositionFromCurrentPage();
      onPageChanged(chapterIdx);
      updateProgress();
    }

    void navigateToChapter(int target, {required bool startAtTop}) {
      ensureChapterLoaded(target);
      if (startAtTop) {
        lastPanelIndex.value[target] = 0;
        final controller = innerControllers.value[target];
        if (controller != null && controller.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted &&
                controller.hasClients &&
                (controller.page ?? 0) != 0) {
              controller.jumpToPage(0);
            }
          });
        }
      }
      if (!outerController.hasClients) {
        chapterIndex.value = target;
        return;
      }
      chapterTurnLocked.value = true;
      outerController
          .animateToPage(
            target,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          )
          .whenComplete(() {
            if (context.mounted) chapterTurnLocked.value = false;
          });
    }

    void selectChapterExplicitly(int idx) {
      ensureChapterLoaded(idx);
      onChapterSelected(idx);
    }

    useEffect(() {
      chromeNotifier.initReaderChrome(isDarkTheme: isDarkTheme);
      cacheKey.value = computeCacheKey();
      return () {
        for (final c in innerControllers.value.values) {
          c.dispose();
        }
      };
    }, const []);

    final prevTarget = useRef(currentChapterIndex);
    useEffect(() {
      if (currentChapterIndex != chapterIndex.value &&
          currentChapterIndex != prevTarget.value) {
        navigateToChapter(currentChapterIndex, startAtTop: true);
      }
      prevTarget.value = currentChapterIndex;
      return null;
    }, [currentChapterIndex]);

    final currentIndex = chapterIndex.value;
    ensureChapterLoaded(currentIndex);
    scheduleNeighborPrefetch(currentIndex, chapters.length);

    final needsRepaginate = needsRepagination();
    if (needsRepaginate) {
      paginationEpoch.value++;
      paginationInFlight.value.clear();
      chunkedOffset.value.clear();
      chunkedAccumulator.value.clear();
    }
    for (final index in List<int>.from(loadedChapters.value)) {
      if (pageCache.value[index] == null || needsRepaginate) {
        final content = contentCache.value[index];
        if (content != null) {
          schedulePagination(index, content);
        }
      }
    }

    for (final index in List<int>.from(loadedChapters.value)) {
      final content = ref
          .watch(readerChapterContentProvider(chapters[index]))
          .valueOrNull;
      if (content != null && contentCache.value[index] != content) {
        contentCache.value[index] = content;
        paginationEpoch.value++;
        paginationInFlight.value.remove(index);
        chunkedOffset.value.remove(index);
        chunkedAccumulator.value.remove(index);
        schedulePagination(index, content);
      }
    }

    if (restorePending.value && pageCache.value[resumeChapterIndex] != null) {
      final resumePage = restoreLocalPage(resumeChapterIndex);
      if (resumePage != null) {
        restorePending.value = false;
        final panel = useSpread ? resumePage ~/ 2 : resumePage;
        lastPanelIndex.value[resumeChapterIndex] = panel;
        final controller = innerControllers.value[resumeChapterIndex];
        if (controller != null && controller.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            if (!controller.hasClients) return;
            if ((controller.page ?? 0) != panel) {
              controller.jumpToPage(panel);
            }
          });
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          updateProgress();
          reportPositionFromCurrentPage();
        });
      }
    }

    final activeItem = ref.watch(activeSpeechItemProvider);
    if (activeItem != null &&
        currentIndex >= 0 &&
        currentIndex < chapters.length &&
        activeItem.chapterId == chapters[currentIndex].id) {
      final currentContent = contentCache.value[currentIndex];
      if (currentContent != null && currentContent.isNotEmpty) {
        final charOffset = const ChapterNarrationCoordinator()
            .resolveActiveSpeechOffset(
              item: activeItem,
              content: currentContent,
            );
        if (charOffset != null) {
          final targetLocalPage = localPageForCharOffset(
            currentIndex,
            charOffset,
          );
          final targetPanel = useSpread
              ? targetLocalPage ~/ 2
              : targetLocalPage;
          final controller = innerControllers.value[currentIndex];
          if (controller != null &&
              controller.hasClients &&
              (controller.page?.round() ??
                      lastPanelIndex.value[currentIndex] ??
                      0) !=
                  targetPanel) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted &&
                  controller.hasClients &&
                  (controller.page?.round() ??
                          lastPanelIndex.value[currentIndex] ??
                          0) !=
                      targetPanel) {
                controller.animateToPage(
                  targetPanel,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                );
              }
            });
          }
        }
      }
    }

    final nextProgress = computedProgress();
    if (progressNotifier.value != nextProgress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          progressNotifier.value = nextProgress;
        }
      });
    }

    final vt = settings.theme;
    final colorScheme = Theme.of(context).colorScheme;

    Widget buildChapterLoadingState(
      int chIdx,
      ReadingViewTheme rvt, {
      required bool showHeaders,
      required ColorScheme cs,
    }) {
      if (failedChapters.value.contains(chIdx)) {
        return Container(
          color: rvt.resolve(cs).background,
          child: AppErrorState(
            message:
                'Could not load this chapter. Check your connection and try again.',
            onRetry: () => retryChapter(chIdx),
          ),
        );
      }
      return Stack(
        children: [
          const Positioned.fill(child: SizedBox.expand()),
          ChapterShimmer(
            vt: rvt,
            showHeaders: showHeaders,
            fontSize: settings.fontSize,
            lineHeight: settings.lineHeight,
          ),
          ReaderLoadingOverlay(chapter: chapters[chIdx], vt: rvt),
        ],
      );
    }

    List<HighlightEntry> highlightsFor(ChapterEntity chapter, String content) {
      final userHighlights =
          ref
              .watch(annotationsProvider(chapter.bookId))
              .highlights[chapter.id] ??
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

    void handlePageTextTap() {
      if (chromeState.rightPanelVisible || chromeState.narrationPanelVisible) {
        chromeNotifier.hideRightPanel();
        return;
      }
      chromeNotifier.toggleChrome(isDarkTheme: isDarkTheme);
    }

    void openGlossaryTerm(String bookId, String term) {
      AppSheet.show(
        context: context,
        id: 'glossary_term',
        initialHeight: 0.6,
        child: GlossaryTermSheet(bookId: bookId, term: term),
      );
    }

    Widget buildSinglePanel(
      int chIdx,
      int localPage,
      ReadingViewTheme rvt,
      List<ChapterEntity> chList, {
      required bool showHeaders,
      required ColorScheme cs,
    }) {
      final pages = pageCache.value[chIdx]!;
      final clampedPage = localPage.clamp(0, pages.length - 1);
      final content = pages[clampedPage];
      final isFirstOfChapter = clampedPage == 0;
      final isLastOfChapter = clampedPage == pages.length - 1;
      final chapter = chList[chIdx];

      return PagedPageView(
        content: content,
        chapterTitle: chapter.title,
        chapterIndex: chIdx,
        bookId: chapter.bookId,
        chapterId: chapter.id,
        pageStartOffset: pageStartOffset(chIdx, clampedPage),
        highlights: highlightsFor(chapter, contentCache.value[chIdx] ?? ''),
        activeSpeechItem:
            activeItem != null && activeItem.chapterId == chapter.id
            ? activeItem
            : null,
        fullChapterContent: contentCache.value[chIdx],
        isFirstPageOfChapter: isFirstOfChapter,
        isLastPageOfChapter: isLastOfChapter,
        textStyle: TextStyle(
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          letterSpacing: settings.letterSpacing,
          color: rvt.resolve(cs).text,
          fontWeight: settings.fontWeight != null
              ? FontWeight(settings.fontWeight!)
              : null,
        ),
        fontFamily: settings.fontFamily,
        textAlignment: settings.textAlignment,
        marginPreset: settings.marginPreset,
        horizontalPadding: settings.horizontalPadding,
        vt: rvt,
        showHeaders: showHeaders,
        chapterStyle: ChapterStyle.forChapter(chIdx, cs),
        onHighlight: onHighlight,
        onAddNote: onAddNote,
        onShare: onShare,
        onSearchWeb: onSearchWeb,
        onListen: onListen,
        onErase: onErase,
        onSetGlossaryTerm: (term) => openGlossaryTerm(chapter.bookId, term),
        onTap: handlePageTextTap,
      );
    }

    Widget wrapPanelPage(Widget page, int chIdx, int panel) {
      final animation = settings.pageTurnAnimation;
      if (animation == PageTurnAnimation.slide) return page;
      final controller = innerControllers.value[chIdx];
      if (controller == null) return page;

      return ClipRect(
        key: ValueKey('panel_${chIdx}_$panel'),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, child) {
            final pagePos = controller.hasClients
                ? (controller.page ?? panel.toDouble())
                : panel.toDouble();
            final offset = pagePos - panel;
            final absOffset = offset.abs().clamp(0.0, 1.0);
            final viewportWidth = layoutWidth.value > 0
                ? layoutWidth.value
                : 360.0;
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

              case PageTurnAnimation.realFlip:
                // High-fidelity physical paper flip / curl animation:
                // - Uses perspective projection Matrix4 with depth.
                // - Rotates around the spine (left/right edge).
                // - Projects a progressive spine shadow gradient as page turns.
                if (isLeaving) {
                  // The page turning forward / lifting up:
                  final turnAngle = (-offset * (math.pi / 1.8)).clamp(
                    0.0,
                    math.pi * 0.95,
                  );
                  final shadowIntensity = (absOffset * 0.45).clamp(0.0, 0.45);
                  final curlScale = 1.0 - absOffset * 0.04;
                  return Transform(
                    alignment: Alignment.centerLeft,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateY(-turnAngle)
                      ..scaleByDouble(curlScale, curlScale, 1.0, 1.0),
                    child: Stack(
                      fit: StackFit.passthrough,
                      children: [
                        child!,
                        // Dynamic page curvature spine shadow
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.black.withValues(
                                      alpha: shadowIntensity * 1.2,
                                    ),
                                    Colors.black.withValues(
                                      alpha: shadowIntensity * 0.5,
                                    ),
                                    Colors.black.withValues(
                                      alpha: shadowIntensity * 0.1,
                                    ),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.25, 0.6, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  // The underlying page being revealed:
                  final revealShadow = ((1.0 - absOffset) * 0.35).clamp(
                    0.0,
                    0.35,
                  );
                  final slideOffset = offset.clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(slideOffset * viewportWidth * 0.1, 0),
                    child: Stack(
                      fit: StackFit.passthrough,
                      children: [
                        child!,
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.black.withValues(
                                      alpha: revealShadow,
                                    ),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.4],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

              default:
                return child!;
            }
          },
          child: page,
        ),
      );
    }

    Widget buildPanel(
      int chIdx,
      int panel,
      ReadingViewTheme rvt,
      List<ChapterEntity> chList, {
      required ColorScheme cs,
    }) {
      if (!useSpread) {
        return wrapPanelPage(
          buildSinglePanel(
            chIdx,
            panel,
            rvt,
            chList,
            showHeaders: true,
            cs: cs,
          ),
          chIdx,
          panel,
        );
      }
      final pages = pageCache.value[chIdx];
      final left = panel * 2;
      final right = left + 1;
      final hasPages = pages != null && pages.isNotEmpty;
      Widget side(int localPage) {
        if (!hasPages || localPage >= pages.length) {
          return Container(color: rvt.resolve(cs).background);
        }
        return buildSinglePanel(
          chIdx,
          localPage,
          rvt,
          chList,
          showHeaders: false,
          cs: cs,
        );
      }

      final animation = settings.pageTurnAnimation;
      final controller = innerControllers.value[chIdx];

      // Sequential page-by-page flip for two-page desktop spread:
      if (animation == PageTurnAnimation.realFlip && controller != null) {
        return ClipRect(
          key: ValueKey('spread_flip_${chIdx}_$panel'),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, child) {
              final pagePos = controller.hasClients
                  ? (controller.page ?? panel.toDouble())
                  : panel.toDouble();
              final offset = pagePos - panel; // -1 to +1
              final isLeaving =
                  offset < 0; // moving to next spread (dragging left)
              final absOffset = offset.abs().clamp(0.0, 1.0);

              // Left page: turns during the second half of transition (0.5 -> 1.0)
              // Right page: turns during the first half of transition (0.0 -> 0.5)
              Widget buildLeftPage() {
                final leftWidget = side(left);
                if (isLeaving) {
                  // Leaving left page remains flat until late, then subtle shadow
                  final shadow = (absOffset * 0.3).clamp(0.0, 0.3);
                  return Stack(
                    fit: StackFit.passthrough,
                    children: [
                      leftWidget,
                      if (shadow > 0)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: shadow),
                            ),
                          ),
                        ),
                    ],
                  );
                } else {
                  // Arriving left page flips in from spine during second phase
                  final progress = ((1.0 - absOffset) * 2 - 1.0).clamp(
                    0.0,
                    1.0,
                  );
                  final angle = ((1.0 - progress) * (math.pi / 2)).clamp(
                    0.0,
                    math.pi / 2,
                  );
                  final shadow = ((1.0 - progress) * 0.4).clamp(0.0, 0.4);
                  return Transform(
                    alignment:
                        Alignment.centerRight, // spine is on right of left page
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),
                    child: Stack(
                      fit: StackFit.passthrough,
                      children: [
                        leftWidget,
                        if (shadow > 0)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: ColoredBox(
                                color: Colors.black.withValues(alpha: shadow),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }
              }

              Widget buildRightPage() {
                final rightWidget = side(right);
                if (isLeaving) {
                  // Leaving right page flips over spine during first phase (0.0 -> 0.5)
                  final phase1Progress = (absOffset * 2).clamp(0.0, 1.0);
                  final angle = (phase1Progress * (math.pi / 2)).clamp(
                    0.0,
                    math.pi / 2,
                  );
                  final shadow = (phase1Progress * 0.45).clamp(0.0, 0.45);
                  return Transform(
                    alignment:
                        Alignment.centerLeft, // spine is on left of right page
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(-angle),
                    child: Stack(
                      fit: StackFit.passthrough,
                      children: [
                        rightWidget,
                        if (shadow > 0)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: ColoredBox(
                                color: Colors.black.withValues(alpha: shadow),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                } else {
                  // Arriving right page is revealed from underneath
                  final shadow = (absOffset * 0.25).clamp(0.0, 0.25);
                  return Stack(
                    fit: StackFit.passthrough,
                    children: [
                      rightWidget,
                      if (shadow > 0)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: shadow),
                            ),
                          ),
                        ),
                    ],
                  );
                }
              }

              return Row(
                children: [
                  Expanded(child: buildLeftPage()),
                  Container(
                    width: 1,
                    color: rvt.resolve(cs).text.withValues(alpha: 0.1),
                  ),
                  Expanded(child: buildRightPage()),
                ],
              );
            },
          ),
        );
      }

      return wrapPanelPage(
        Row(
          children: [
            Expanded(child: side(left)),
            Container(
              width: 1,
              color: rvt.resolve(cs).text.withValues(alpha: 0.1),
            ),
            Expanded(child: side(right)),
          ],
        ),
        chIdx,
        panel,
      );
    }

    Widget buildChapterItem(
      int chIdx,
      ReadingViewTheme rvt,
      List<ChapterEntity> chList, {
      required ColorScheme cs,
    }) {
      final pages = pageCache.value[chIdx];
      if (pages == null || pages.isEmpty) {
        ensureChapterLoaded(chIdx);
        return buildChapterLoadingState(chIdx, rvt, showHeaders: true, cs: cs);
      }
      return ChapterPager(
        key: ValueKey('chapter_pager_$chIdx'),
        controller: innerControllerFor(chIdx),
        itemCount: panelCountFor(chIdx),
        animation: settings.pageTurnAnimation,
        enablePageFlipSound: settings.enablePageFlipSound,
        enablePageFlipHaptics: settings.enablePageFlipHaptics,
        turnLocked: chapterTurnLocked.value,
        onPageChanged: (panel) => onInnerPageChanged(chIdx, panel),
        onBoundaryTurn: (forward) {
          if (chIdx == chapterIndex.value && !chapterTurnLocked.value) {
            turnChapter(forward);
          }
        },
        itemBuilder: (context, panel) =>
            buildPanel(chIdx, panel, rvt, chList, cs: cs),
      );
    }

    void showChapterIndex(BuildContext ctx) {
      ChapterIndexSheet.show(
        ctx,
        sheetId: 'paged_chapter_index',
        chapters: chapters,
        currentChapterIndex: chapterIndex.value,
        onChapterTap: (idx) {
          selectChapterExplicitly(idx);
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

      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        chromeNotifier.resetChromeTimer(isDarkTheme: isDarkTheme);
        turnBack();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        chromeNotifier.resetChromeTimer(isDarkTheme: isDarkTheme);
        turnForward();
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    }

    if (!contentCache.value.containsKey(currentIndex)) {
      return Scaffold(
        backgroundColor: vt.resolve(colorScheme).background,
        extendBodyBehindAppBar: true,
        appBar: ReaderBarSurface(
          style: settings.chromeStyle,
          color: colorScheme.surfaceContainerHigh,
          child: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            foregroundColor: colorScheme.onSurface,
            title: Text(
              chapters[currentChapterIndex].title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.text_fields,
                  color: vt.resolve(colorScheme).text,
                ),
                onPressed: onSettingsTap,
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
              fontSize: settings.fontSize,
              lineHeight: settings.lineHeight,
            ),
            ReaderLoadingOverlay(chapter: chapters[currentIndex], vt: vt),
          ],
        ),
      );
    }

    final useSidePanels =
        isDesktop &&
        AppSheet.desktopPresentation == DesktopSheetPresentation.sidePanel;

    return Scaffold(
      backgroundColor: vt.resolve(colorScheme).background,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth != layoutWidth.value ||
              constraints.maxHeight != layoutHeight.value) {
            layoutWidth.value = constraints.maxWidth;
            layoutHeight.value = constraints.maxHeight;
          }
          return Stack(
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
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (details) {
                      if (chromeState.rightPanelVisible ||
                          chromeState.narrationPanelVisible) {
                        chromeNotifier.hideRightPanel();
                        return;
                      }
                      if (!isDesktop || useSpread) {
                        onMobileTapUp(details, constraints);
                      } else {
                        toggleChrome();
                      }
                    },
                    child: PageView.builder(
                      controller: outerController,
                      itemCount: chapters.length,
                      onPageChanged: onOuterPageChanged,
                      itemBuilder: (context, chapterIdx) => buildChapterItem(
                        chapterIdx,
                        vt,
                        chapters,
                        cs: colorScheme,
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
                  onVerticalDragUpdate: (details) =>
                      chromeNotifier.onEdgeBrightnessUpdate(
                        details,
                        onChanged: applyBrightness,
                      ),
                  onVerticalDragEnd: chromeNotifier.onEdgeBrightnessEnd,
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
                          chapterTitle: chapters[currentIndex].title,
                          accent: settings.theme.resolve(colorScheme).accent,
                          onClose: chromeNotifier.closeNarrationPanel,
                        )
                      : ReaderRightPanel(
                          chapters: chapters,
                          currentChapterIndex: currentIndex,
                          bookmarkedChapterIds: bookmarkedChapterIds,
                          onChapterSelected: (idx) {
                            selectChapterExplicitly(idx);
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
                  currentChapterIndex: currentIndex,
                  onChapterSelected: (idx) {
                    selectChapterExplicitly(idx);
                  },
                  onToggleBookmark: onBookmarkToggle,
                  isBookmarked: isBookmarked,
                  onToggleSettings: onSettingsTap,
                  onOpenAnnotations: () {
                    ReaderAnnotationsSheet.show(
                      context,
                      bookId: chapters.first.bookId,
                      chapters: chapters,
                      currentChapterId: chapters[currentIndex].id,
                      bookTitle: bookTitle,
                      coverPath: coverPath,
                      onJumpToChapter: (chId, _) {
                        final idx = chapters.indexWhere((c) => c.id == chId);
                        if (idx >= 0) {
                          selectChapterExplicitly(idx);
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
                    chapterTitle: chapters[currentIndex].title,
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
                      title: chapters[currentIndex].title,
                      textColor: colorScheme.onSurface,
                      onSettingsTap: onSettingsTap,
                      onSearchTap: onSearchTap,
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
                          currentChapterId: chapters[currentIndex].id,
                          bookTitle: bookTitle,
                          coverPath: coverPath,
                          onJumpToChapter: (chId, _) {
                            final idx = chapters.indexWhere(
                              (c) => c.id == chId,
                            );
                            if (idx >= 0) {
                              selectChapterExplicitly(idx);
                            }
                          },
                        );
                      },
                      currentChapterTitle: chapters[currentIndex].title,
                      currentChapterNumber: currentIndex,
                      totalChapters: chapters.length,
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
          );
        },
      ),
    );
  }
}
