import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:real_page_flip/real_page_flip.dart';

import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/molecules/app_error_state.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/providers/reader_system_provider.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/providers/annotations_provider.dart';
import 'package:atlas_app/reader/presentation/providers/atlas_glossary_providers.dart';
import 'package:atlas_app/reader/presentation/providers/reader_chrome_provider.dart';
import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/utils/chapter_position_resolver.dart';
import 'package:atlas_app/reader/presentation/widgets/block_card_widget.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_chrome_pieces.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_background.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';
import 'package:atlas_app/reader/presentation/utils/glossary_highlight_ranges.dart';
import 'package:atlas_app/reader/presentation/utils/reader_key_events.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_contents_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_shimmer.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_styles.dart';
import 'package:atlas_app/reader/presentation/widgets/glossary_term_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_mini_player.dart';
import 'package:atlas_app/reader/presentation/widgets/now_playing_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/paged_page_view.dart';
import 'package:atlas_app/reader/presentation/widgets/pager.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bottom_nav.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_chrome_bar.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_edge_regions.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_right_panel.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

/// Dedicated 3D physical page flip reader layout for eBooks using [PageFlipWidget]
/// from the [real_page_flip] engine.
class RealFlipReaderLayout extends HookConsumerWidget {
  const RealFlipReaderLayout({
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
    this.onIntelligenceTap,
    this.onSearchTap,
    this.onRedownload,
    this.isRedownloading = false,
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
  final VoidCallback? onIntelligenceTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onRedownload;
  final bool isRedownloading;
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

    // Debounce for on-demand download attempts of chapters whose file is
    // missing on disk; prevents an every-build retry loop while offline.
    final remoteAttemptAtRef = useRef<Map<int, DateTime>>({});
    bool mayRetryRemoteChapter(int index) {
      final last = remoteAttemptAtRef.value[index];
      return last == null ||
          DateTime.now().difference(last) > const Duration(seconds: 30);
    }

    void markRemoteAttempt(int index) =>
        remoteAttemptAtRef.value[index] = DateTime.now();


    final flipController = useMemoized(() => PageFlipController());
    final pageCache = useRef<Map<int, List<String>>>({});
    final contentCache = useRef<Map<int, String>>({});
    final loadedChapters = useRef<Set<int>>({});
    final failedChapters = useState<Set<int>>({});
    final progressNotifier = useValueNotifier(0.0);
    final cacheKey = useRef<String>('');
    final layoutWidth = useRef(0.0);
    final layoutHeight = useRef(0.0);
    final chapterIndex = useState(currentChapterIndex);
    final currentLocalPageIndex = useState(0);
    final restorePending = useState(
      restorePosition != null && restorePosition! > 0,
    );

    final paginationInFlight = useRef<Set<int>>({});
    final paginationEpoch = useRef(0);
    final chunkedOffset = useRef<Map<int, int>>({});
    final chunkedAccumulator = useRef<Map<int, List<String>>>({});
    final cardPageMap = useRef<Map<int, Map<int, BlockCard>>>({});

    final updateTrigger = useState(0);
    void triggerUiUpdate() {
      updateTrigger.value++;
    }

    final isDesktop = MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;
    final useSpread = isDesktop && settings.useBookSpread;
    final isDarkTheme =
        Theme.of(context).colorScheme.brightness == Brightness.dark;
    final activeItem = ref.watch(activeSpeechItemProvider);

    int spreadCount(int pageCount) => (pageCount / 2).ceil();

    double effectiveContentWidth(double rawWidth) {
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

    void reportPositionFromCurrentPage() {
      final onPos = onPositionChanged;
      if (onPos == null) return;
      final content = contentCache.value[chapterIndex.value];
      if (content == null || content.isEmpty) return;
      final localPage = currentLocalPageIndex.value;
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

    void applyBrightness(double newBrightness) {
      final notifier = ref.read(readingSettingsProvider.notifier);
      notifier.setBrightness(newBrightness);
      ref
          .read(readerSystemControllerProvider)
          .applyBrightnessDebounced(newBrightness);
    }

    void toggleChrome() {
      if (chromeState.rightPanelVisible || chromeState.narrationPanelVisible) {
        chromeNotifier.hideRightPanel();
        return;
      }
      chromeNotifier.toggleChrome(isDarkTheme: isDarkTheme);
    }

    void paginateChapterIncremental(int index, String content, int epoch) {
      if (epoch != paginationEpoch.value || !context.mounted) {
        paginationInFlight.value.remove(index);
        return;
      }
      final enableCards =
          ref.read(readingSettingsProvider).valueOrNull?.enableBlockCards ??
          true;
      if (enableCards) {
        final spans = ref.read(chapterBlockCardSpansProvider(chapters[index]));
        final hasCards = spans.any((s) => s.isCard);
        if (hasCards) {
          final colorScheme2 = Theme.of(context).colorScheme;
          final s2 = settings;
          final horizontalMargin2 = s2.horizontalPadding;
          final verticalMargin2 = switch (s2.marginPreset) {
            MarginPreset.narrow => AppSpacing.sm,
            MarginPreset.normal => AppSpacing.md,
            MarginPreset.wide => AppSpacing.lg,
          };
          final rawHeight2 = layoutHeight.value > 0
              ? layoutHeight.value
              : MediaQuery.sizeOf(context).height;
          final rawWidth2 = layoutWidth.value > 0
              ? layoutWidth.value
              : MediaQuery.sizeOf(context).width;
          final contentWidth2 = effectiveContentWidth(rawWidth2);
          final pWidth2 = contentWidth2 - horizontalMargin2 * 2;
          final pHeight2 = rawHeight2 - verticalMargin2 * 2;
          final baseStyle2 = TextStyle(
            fontSize: s2.fontSize,
            height: s2.lineHeight,
            letterSpacing: s2.letterSpacing,
            color: s2.theme.resolve(colorScheme2).text,
            fontWeight: s2.fontWeight != null
                ? FontWeight(s2.fontWeight!)
                : null,
          );
          final textStyle2 = s2.fontFamily != null
              ? baseStyle2.copyWith(fontFamily: s2.fontFamily)
              : baseStyle2;
          final List<String> pages = [];
          final Map<int, BlockCard> map = {};
          String proseBuffer = '';
          void flushProseBuffer() {
            if (proseBuffer.trim().isEmpty) {
              proseBuffer = '';
              return;
            }
            final chunkPages = Pager.paginate(
              text: proseBuffer,
              textStyle: textStyle2,
              pageWidth: pWidth2,
              pageHeight: pHeight2,
            );
            pages.addAll(chunkPages);
            proseBuffer = '';
          }

          for (final span in spans) {
            if (!span.isCard) {
              final prose = span.prose ?? '';
              if (prose.trim().isEmpty) continue;
              if (proseBuffer.isNotEmpty) proseBuffer += '\n\n';
              proseBuffer += prose;
            } else {
              flushProseBuffer();
              final card = span.card!;
              final marker = '\uE000BLOCKCARD:${card.hashCode}\uE001';
              map[pages.length] = card;
              pages.add(marker);
            }
          }
          flushProseBuffer();
          if (pages.isEmpty) pages.add('');
          pageCache.value[index] = List.unmodifiable(pages);
          cardPageMap.value[index] = map;
          paginationInFlight.value.remove(index);
          chunkedOffset.value.remove(index);
          chunkedAccumulator.value.remove(index);
          triggerUiUpdate();
          return;
        }
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
      final rawWidth = layoutWidth.value > 0
          ? layoutWidth.value
          : MediaQuery.sizeOf(context).width;
      final contentWidth = effectiveContentWidth(rawWidth);
      final pWidth = contentWidth - horizontalMargin * 2;
      final pHeight = rawHeight - verticalMargin * 2;

      final style = TextStyle(
        fontSize: s.fontSize,
        height: s.lineHeight,
        letterSpacing: s.letterSpacing,
        fontFamily: s.fontFamily,
        color: s.theme.resolve(colorScheme).text,
        fontWeight: s.fontWeight != null ? FontWeight(s.fontWeight!) : null,
      );

      final startOffset = chunkedOffset.value[index] ?? 0;
      final result = Pager.paginateChunked(
        text: content,
        textStyle: style,
        pageWidth: pWidth,
        pageHeight: pHeight,
        startIndex: startOffset,
        maxPages: _chunkedMaxPagesPerFrame,
      );

      final acc = chunkedAccumulator.value.putIfAbsent(index, () => []);
      acc.addAll(result.pages);
      chunkedOffset.value[index] = result.endIndex;

      if (!result.complete) {
        pageCache.value[index] = List.unmodifiable(acc);
        triggerUiUpdate();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          paginateChapterIncremental(index, content, epoch);
        });
      } else {
        pageCache.value[index] = List.unmodifiable(acc);
        paginationInFlight.value.remove(index);
        chunkedOffset.value.remove(index);
        chunkedAccumulator.value.remove(index);
        triggerUiUpdate();
      }
    }

    void schedulePagination(int index, String content) {
      if (paginationInFlight.value.contains(index)) return;
      paginationInFlight.value.add(index);
      chunkedOffset.value[index] = 0;
      chunkedAccumulator.value[index] = [];
      final epoch = paginationEpoch.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        paginateChapterIncremental(index, content, epoch);
      });
    }

    void ensureChapterLoaded(int index, {bool allowRemoteFetch = false}) {
      if (index < 0 || index >= chapters.length) return;
      if (loadedChapters.value.contains(index)) return;
      final ch = chapters[index];
      // Heal a stale failure: an earlier attempt could not find the chapter
      // file on disk, but a background fetch may have written it since —
      // the flag must not block later loads forever.
      if (failedChapters.value.contains(index)) {
        if (File(ch.contentPath).existsSync()) {
          failedChapters.value = Set<int>.from(failedChapters.value)
            ..remove(index);
        } else if (!allowRemoteFetch) {
          return;
        } else if (!mayRetryRemoteChapter(index)) {
          return;
        } else {
          markRemoteAttempt(index);
        }
      } else if (!File(ch.contentPath).existsSync()) {
        if (!allowRemoteFetch) {
          // Offline-safe: neighbors never trigger network for a chapter not
          // cached on disk.
          failedChapters.value = {...failedChapters.value, index};
          return;
        }
        markRemoteAttempt(index);
      }
      if (File(ch.contentPath).existsSync()) {
        loadedChapters.value.add(index);
        final contentAsync = ref.read(readerChapterContentProvider(ch));
        contentAsync.when(
          data: (content) {
            if (content.isNotEmpty) {
              contentCache.value[index] = content;
              schedulePagination(index, content);
            }
          },
          loading: () {},
          error: (err, stack) {
            loadedChapters.value.remove(index);
            failedChapters.value = {...failedChapters.value, index};
          },
        );
        return;
      }
      // Missing file, on-demand fetch for the chapter being displayed: route
      // through the provider (it owns network + fallbacks) and feed the
      // result into the normal pagination flow when it lands.
      unawaited(
        ref.read(readerChapterContentProvider(ch).future).then((content) {
          if (content.isNotEmpty && contentCache.value[index] != content) {
            contentCache.value[index] = content;
            schedulePagination(index, content);
          }
        }, onError: (Object _) {
          failedChapters.value = {...failedChapters.value, index};
        }),
      );
    }

    void retryChapter(int index) {
      if (index < 0 || index >= chapters.length) {
        return;
      }
      final ch = chapters[index];
      failedChapters.value = Set<int>.from(failedChapters.value)..remove(index);
      ref.invalidate(readerChapterContentProvider(ch));
      ensureChapterLoaded(index, allowRemoteFetch: true);
    }

    void updateProgress(int currentLocalPage, int totalPages) {
      final totalChapters = chapters.length;
      if (totalChapters == 0) return;
      final ch = chapterIndex.value;
      final chapterFraction = totalPages > 0
          ? currentLocalPage / totalPages
          : 0.0;
      final overall = ((ch + chapterFraction) / totalChapters).clamp(0.0, 1.0);
      progressNotifier.value = overall;
      onProgressChanged(overall);
    }

    void navigateToChapter(int targetIdx, {bool startAtTop = true}) {
      final clamped = targetIdx.clamp(0, chapters.length - 1);
      chapterIndex.value = clamped;
      currentLocalPageIndex.value = startAtTop
          ? 0
          : (pageCache.value[clamped]?.length ?? 1) - 1;
      ensureChapterLoaded(clamped, allowRemoteFetch: true);
      onPageChanged(clamped);
      if (pageCache.value[clamped] != null) {
        final panel = useSpread
            ? currentLocalPageIndex.value ~/ 2
            : currentLocalPageIndex.value;
        flipController.goToPage(panel);
        updateProgress(
          currentLocalPageIndex.value,
          pageCache.value[clamped]?.length ?? 1,
        );
      }
    }

    useEffect(() {
      chromeNotifier.initReaderChrome(isDarkTheme: isDarkTheme);
      cacheKey.value = computeCacheKey();
      return null;
    }, const []);

    final currentIndex = chapterIndex.value;
    ensureChapterLoaded(currentIndex, allowRemoteFetch: true);
    if (currentIndex + 1 < chapters.length) {
      ensureChapterLoaded(currentIndex + 1);
    }
    if (currentIndex - 1 >= 0) ensureChapterLoaded(currentIndex - 1);

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

    if (restorePending.value && pageCache.value[currentIndex] != null) {
      final resumePage = restoreLocalPage(currentIndex);
      if (resumePage != null) {
        restorePending.value = false;
        currentLocalPageIndex.value = resumePage;
        final panel = useSpread ? resumePage ~/ 2 : resumePage;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          flipController.goToPage(panel);
        });
      }
    }

    final colorScheme = Theme.of(context).colorScheme;
    final rvt = settings.theme;
    final vt = rvt;
    final pages = pageCache.value[currentIndex];
    final totalChapterPages = pages?.length ?? 0;
    final totalPanels = useSpread
        ? spreadCount(totalChapterPages)
        : totalChapterPages;

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

    void openGlossaryTerm(String bookId, String term) {
      AppSheet.show(
        context: context,
        id: 'glossary_term',
        initialHeight: 0.6,
        child: GlossaryTermSheet(bookId: bookId, term: term),
      );
    }

    Widget buildSinglePanel(int localPage) {
      if (pages == null || pages.isEmpty) return const SizedBox();
      final clampedPage = localPage.clamp(0, pages.length - 1);
      final content = pages[clampedPage];
      final isFirstOfChapter = clampedPage == 0;
      final isLastOfChapter = clampedPage == pages.length - 1;
      final chapter = chapters[currentIndex];
      final card = cardPageMap.value[currentIndex]?[clampedPage];
      if (card != null) {
        final readingColors = settings.theme.resolve(
          Theme.of(context).colorScheme,
        );
        final vPad = switch (settings.marginPreset) {
          MarginPreset.narrow => AppSpacing.sm,
          MarginPreset.normal => AppSpacing.md,
          MarginPreset.wide => AppSpacing.lg,
        };
        final hPad = settings.horizontalPadding;
        return ReaderBackground(
          colors: readingColors,
          customColor: settings.customBackgroundColor,
          pattern: settings.pattern,
          patternOpacity: settings.patternOpacity,
          child: Column(
            children: [
              if (isFirstOfChapter)
                ChapterHeaderBanner(
                  chapterNumber: currentIndex + 1,
                  title: chapter.title,
                  style: ChapterStyle.forChapter(
                    currentIndex,
                    Theme.of(context).colorScheme,
                  ),
                ),
              if (isFirstOfChapter)
                ChapterOrnamentalDivider(
                  accentColor: ChapterStyle.forChapter(
                    currentIndex,
                    Theme.of(context).colorScheme,
                  ).accentColor,
                  verticalPadding: 4,
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: hPad,
                    vertical: vPad,
                  ),
                  child: BlockCardWidget(
                    card: card,
                    colors: readingColors,
                    fontSize: settings.fontSize,
                    bookId: chapter.bookId,
                  ),
                ),
              ),
              if (isLastOfChapter)
                ChapterOrnamentalDivider(
                  accentColor: ChapterStyle.forChapter(
                    currentIndex,
                    Theme.of(context).colorScheme,
                  ).accentColor,
                ),
              if (isLastOfChapter)
                ChapterEndFooter(
                  chapterNumber: currentIndex + 1,
                  textColor: readingColors.text,
                  baseFontSize: settings.fontSize,
                ),
            ],
          ),
        );
      }

      return PagedPageView(
        content: content,
        chapterTitle: chapter.title,
        chapterIndex: currentIndex,
        bookId: chapter.bookId,
        chapterId: chapter.id,
        pageStartOffset: pageStartOffset(currentIndex, clampedPage),
        highlights: highlightsFor(
          chapter,
          contentCache.value[currentIndex] ?? '',
        ),
        activeSpeechItem:
            activeItem != null && activeItem.chapterId == chapter.id
            ? activeItem
            : null,
        fullChapterContent: contentCache.value[currentIndex],
        isFirstPageOfChapter: isFirstOfChapter,
        isLastPageOfChapter: isLastOfChapter,
        textStyle: TextStyle(
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          letterSpacing: settings.letterSpacing,
          color: vt.resolve(colorScheme).text,
          fontWeight: settings.fontWeight != null
              ? FontWeight(settings.fontWeight!)
              : null,
        ),
        fontFamily: settings.fontFamily,
        textAlignment: settings.textAlignment,
        marginPreset: settings.marginPreset,
        horizontalPadding: settings.horizontalPadding,
        vt: vt,
        showHeaders: true,
        chapterStyle: ChapterStyle.forChapter(currentIndex, colorScheme),
        customBackgroundColor: settings.customBackgroundColor,
        pattern: settings.pattern,
        patternOpacity: settings.patternOpacity,
        onHighlight: onHighlight,
        onAddNote: onAddNote,
        onShare: onShare,
        onSearchWeb: onSearchWeb,
        onListen: onListen,
        onErase: onErase,
        onSetGlossaryTerm: (term) => openGlossaryTerm(chapter.bookId, term),
        onTap: toggleChrome,
      );
    }

    Widget buildPanel(int panel) {
      if (!useSpread) {
        return buildSinglePanel(panel);
      }
      final left = panel * 2;
      final right = left + 1;
      return Row(
        children: [
          Expanded(
            child: left < totalChapterPages
                ? buildSinglePanel(left)
                : const SizedBox(),
          ),
          Container(
            width: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
          Expanded(
            child: right < totalChapterPages
                ? buildSinglePanel(right)
                : const SizedBox(),
          ),
        ],
      );
    }

    void showChapterIndex(BuildContext ctx, {int initialTab = 0}) {
      ReaderContentsSheet.show(
        ctx,
        bookId: chapters.first.bookId,
        bookTitle: bookTitle,
        coverPath: coverPath,
        bookmarkedChapterIds: bookmarkedChapterIds,
        onBookmarkToggle: onBookmarkToggle,
        isBookmarked: isBookmarked,
        initialTab: initialTab,
        sheetId: 'real_flip_chapter_index',
        chapters: chapters,
        currentChapterIndex: currentIndex,
        onChapterTap: (idx) {
          navigateToChapter(idx, startAtTop: true);
        },
      );
    }

    void goToPrevious() {
      if (useSpread) {
        final currentPanel = currentLocalPageIndex.value ~/ 2;
        if (currentPanel > 0) {
          flipController.previousPage();
        } else if (currentIndex > 0) {
          navigateToChapter(currentIndex - 1, startAtTop: false);
        }
      } else {
        if (currentLocalPageIndex.value > 0) {
          flipController.previousPage();
        } else if (currentIndex > 0) {
          navigateToChapter(currentIndex - 1, startAtTop: false);
        }
      }
    }

    void goToNext() {
      if (useSpread) {
        final maxPanel = spreadCount(totalChapterPages) - 1;
        final currentPanel = currentLocalPageIndex.value ~/ 2;
        if (currentPanel < maxPanel) {
          flipController.nextPage();
        } else if (currentIndex < chapters.length - 1) {
          navigateToChapter(currentIndex + 1, startAtTop: true);
        }
      } else {
        if (currentLocalPageIndex.value < totalChapterPages - 1) {
          flipController.nextPage();
        } else if (currentIndex < chapters.length - 1) {
          navigateToChapter(currentIndex + 1, startAtTop: true);
        }
      }
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
        goToPrevious();
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        chromeNotifier.resetChromeTimer(isDarkTheme: isDarkTheme);
        goToNext();
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    }

    final useSidePanels =
        isDesktop &&
        AppSheet.desktopPresentation == DesktopSheetPresentation.sidePanel;

    return Scaffold(
      backgroundColor:
          settings.customBackgroundColor ?? vt.resolve(colorScheme).background,
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
                  child: totalPanels <= 0
                      ? (failedChapters.value.contains(currentIndex)
                          ? AppErrorState(
                              message:
                                  'Could not load this chapter. Check your connection and try again.',
                              onRetry: () => retryChapter(currentIndex),
                            )
                          : Stack(
                              children: [
                                Positioned.fill(
                                  child: ChapterShimmer(
                                    vt: vt,
                                    showHeaders: true,
                                    fontSize: settings.fontSize,
                                    lineHeight: settings.lineHeight,
                                  ),
                                ),
                                ReaderLoadingOverlay(
                                  chapter: chapters[currentIndex],
                                  vt: vt,
                                ),
                              ],
                            ))
                      : Builder(
                          builder: (context) {
                            final rawIndex = useSpread
                                ? (currentLocalPageIndex.value ~/ 2)
                                : currentLocalPageIndex.value;
                            final safeInitialIndex = rawIndex.clamp(
                              0,
                              math.max<int>(0, totalPanels - 1),
                            );
                            final supportsSound =
                                !kIsWeb && !Platform.isWindows;

                            final isEdgesOnly =
                                settings.pageFlipGestureZone ==
                                PageFlipGestureZone.edgesOnly;
                            final edgeRatio = isEdgesOnly ? 0.20 : 0.08;
                            final sensitivity = isEdgesOnly ? 0.30 : 0.50;

                            final isAtLastPanel =
                                safeInitialIndex >= totalPanels - 1;
                            final isAtFirstPanel = safeInitialIndex <= 0;

                            var accumulatedDx = 0.0;
                            var accumulatedDy = 0.0;

                            return Listener(
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: (_) {
                                accumulatedDx = 0.0;
                                accumulatedDy = 0.0;
                              },
                              onPointerMove: (event) {
                                accumulatedDx += event.delta.dx;
                                accumulatedDy += event.delta.dy;

                                // If dragging past boundary with predominantly horizontal drag
                                if (accumulatedDx.abs() > 40 &&
                                    accumulatedDx.abs() >
                                        accumulatedDy.abs() * 1.5) {
                                  if (accumulatedDx < 0 &&
                                      isAtLastPanel &&
                                      currentIndex < chapters.length - 1) {
                                    accumulatedDx = 0.0;
                                    goToNext();
                                  } else if (accumulatedDx > 0 &&
                                      isAtFirstPanel &&
                                      currentIndex > 0) {
                                    accumulatedDx = 0.0;
                                    goToPrevious();
                                  }
                                }
                              },
                              child: PageFlipWidget(
                                key: ValueKey(
                                  'real_flip_pager_${currentIndex}_${useSpread ? "spread" : "single"}_$totalPanels',
                                ),
                                controller: flipController,
                                itemCount: totalPanels,
                                initialIndex: safeInitialIndex,
                                spreadMode: useSpread
                                    ? PageFlipSpreadMode.doubleSpread
                                    : PageFlipSpreadMode.single,
                                config: PageFlipConfig(
                                  enableSound:
                                      supportsSound &&
                                      settings.enablePageFlipSound,
                                  enableHaptics: settings.enablePageFlipHaptics,
                                  edgeTapWidthRatio: edgeRatio,
                                  sensitivity: sensitivity,
                                  snapshotRefreshPolicy:
                                      PageFlipSnapshotRefreshPolicy.always,
                                  performanceProfile:
                                      DevicePerformanceProfile.high,
                                  snapshotPerformanceProfile:
                                      DevicePerformanceProfile.high,
                                  maxSnapshotPixelRatio: 3.0,
                                  cutoffForward: 0.35,
                                  cutoffPrevious: 0.35,
                                ),
                                onPageChanged: (panelIdx) {
                                  final localPage = useSpread
                                      ? (panelIdx * 2)
                                      : panelIdx;
                                  currentLocalPageIndex.value = localPage.clamp(
                                    0,
                                    totalChapterPages - 1,
                                  );
                                  updateProgress(
                                    currentLocalPageIndex.value,
                                    totalChapterPages,
                                  );
                                  reportPositionFromCurrentPage();
                                },
                                itemBuilder: (context, panelIdx) =>
                                    buildPanel(panelIdx),
                              ),
                            );
                          },
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
                            navigateToChapter(idx, startAtTop: true);
                            chromeNotifier.hideRightPanel();
                          },
                          onBookmarkToggle: onBookmarkToggle,
                          isBookmarked: isBookmarked,
                          onClose: chromeNotifier.hideRightPanel,
                          settings: settings,
                        ),
                ),
              if (!chromeState.narrationPanelVisible && !chromeState.chromeVisible)
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
                  child: ReaderChromeBar(
                    title: chapters[currentIndex].title,
                    textColor: colorScheme.onSurface,
                    onSettingsTap: onSettingsTap,
                    onBack: () => Navigator.of(context).maybePop(),
                    onIntelligenceTap: onIntelligenceTap,
                    onSearchTap: onSearchTap,
                    onRedownload: onRedownload,
                    isRedownloading: isRedownloading,
                    slim: true,
                    onTitleTap: () => showChapterIndex(context),
                    onBookmarkTap: onBookmarkToggle,
                    isBookmarked: isBookmarked,
                    chromeStyle: settings.chromeStyle,
                  ),
                ),
              if (chromeState.chromeVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ReaderBottomNav(
                    textColor: colorScheme.onSurface,
                    onSettingsTap: onSettingsTap,
                    onChapterIndexTap: () => showChapterIndex(context),
                    onBookmarkTap: onBookmarkToggle,
                    isBookmarked: isBookmarked,
                    chromeStyle: settings.chromeStyle,
                    onAnnotationsTap: () => showChapterIndex(context, initialTab: 2),
                    currentChapterTitle: chapters[currentIndex].title,
                    currentChapterNumber: currentIndex,
                    totalChapters: chapters.length,
                    bookTitle: bookTitle,
                    coverPath: coverPath,
                    progress: progressNotifier,
                    progressColor: settings.theme.resolve(colorScheme).accent,
                    onSearchTap: onSearchTap,
                    onIntelligenceTap: onIntelligenceTap,
                    onRedownload: onRedownload,
                    isRedownloading: isRedownloading,
                    onScrubToChapter: (idx) => navigateToChapter(idx, startAtTop: true),
                    onPrevChapter: currentIndex > 0
                        ? () =>
                              navigateToChapter(currentIndex - 1, startAtTop: true)
                        : null,
                    onNextChapter: currentIndex < chapters.length - 1
                        ? () =>
                              navigateToChapter(currentIndex + 1, startAtTop: true)
                        : null,
                    onListenTap: useSidePanels
                        ? chromeNotifier.toggleNarrationPanel
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
