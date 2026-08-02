import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/organisms/draggable_bottom_sheet.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/controllers/reader_chrome_controller.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/utils/reader_key_events.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_chrome_pieces.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_index_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_styles.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/pager.dart';
import 'package:atlas_app/core/design_system/widgets/app_context_menu.dart';
import 'package:atlas_app/reader/presentation/widgets/word_lookup_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bar_surface.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bottom_nav.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_chrome_bar.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_command_palette.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_edge_regions.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_progress_bar.dart';
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
    this.onHighlight,
    this.onAddNote,
    this.onShare,
    this.onSearchWeb,
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

  /// Called with the selected text and chosen color when the reader taps a
  /// highlight swatch in the context menu. Omit to hide highlighting.
  final void Function(String text, Color color)? onHighlight;

  /// Called with the selected text (and surrounding sentence, if available)
  /// when the reader taps "Note". Omit to hide the note action.
  final void Function(String text, String? sentence)? onAddNote;

  /// Called with the selected text when the reader taps "Share". Omit to
  /// hide the share action.
  final void Function(String text)? onShare;

  /// Called with the selected text when the reader taps "Search the web".
  /// Omit to hide the search action.
  final void Function(String text)? onSearchWeb;

  @override
  ConsumerState<PagedReaderLayout> createState() => _PagedReaderLayoutState();
}

class _PagedReaderLayoutState extends ConsumerState<PagedReaderLayout>
    with ReaderChromeController {
  final _pageController = PageController();
  final Map<int, List<String>> _pageCache = {};
  final Map<int, String> _contentCache = {};
  final Set<int> _loadedChapters = {};
  int _totalPages = 0;
  int _currentGlobalPage = 0;
  String _cacheKey = '';
  bool _pendingChapterJump = true;
  double _layoutWidth = 0;
  double _layoutHeight = 0;
  int? _neighborPrefetchScheduledFor;
  static const double _maxReadingWidth = 720.0;

  @override
  void initState() {
    super.initState();
    _cacheKey = _computeCacheKey();
    initReaderChrome(isDarkTheme: widget.settings.theme.isDark);
  }

  @override
  void dispose() {
    disposeReaderChrome();
    _pageController.dispose();
    super.dispose();
  }

  void _onDesktopSpreadTapUp(TapUpDetails details, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final x = details.localPosition.dx;
    final spreadBefore = _currentGlobalPage ~/ 2;
    if (x < width / 3) {
      if (spreadBefore > 0) {
        final target = (spreadBefore - 1) * 2;
        _pageController.animateToPage(target ~/ 2,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut);
      }
    } else if (x > width * 2 / 3) {
      if (_currentGlobalPage < _totalPages - 1) {
        final target = (spreadBefore + 1) * 2;
        _pageController.animateToPage(target ~/ 2,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut);
      }
    } else {
      toggleChrome(isDarkTheme: widget.settings.theme.isDark);
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
      if (_currentGlobalPage < _totalPages - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    } else {
      toggleChrome(isDarkTheme: widget.settings.theme.isDark);
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
          rawWidth - (rightPanelVisible ? ReaderChromeController.rightPanelWidth : 0);
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
      onToggleChrome: () =>
          toggleChrome(isDarkTheme: widget.settings.theme.isDark),
      onOpenPalette: () => setState(() => commandPaletteVisible = true),
    );
    if (common != KeyEventResult.ignored) return common;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      resetChromeTimer(isDarkTheme: widget.settings.theme.isDark);
      if (_currentGlobalPage > 0) {
        final step = isWideDesktop ? 2 : 1;
        final target = _currentGlobalPage - step;
        if (isWideDesktop) {
          _pageController.animateToPage(target ~/ 2,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut);
        } else {
          _pageController.previousPage(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut);
        }
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      resetChromeTimer(isDarkTheme: widget.settings.theme.isDark);
      if (_currentGlobalPage < _totalPages - 1) {
        if (isWideDesktop) {
          final target = _currentGlobalPage + 2;
          _pageController.animateToPage(target ~/ 2,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut);
        } else {
          _pageController.nextPage(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut);
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
    return '${s.fontSize}_${s.fontFamily}_${s.lineHeight}_${s.marginPreset.name}_${s.textAlignment.name}_${w}x$h';
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

  void _paginateChapter(int index, String content) {
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
      color: s.theme.text,
    );
    final textStyle = s.fontFamily != null
        ? GoogleFonts.getFont(s.fontFamily!, textStyle: baseStyle)
        : baseStyle;

    _pageCache[index] = Pager.paginate(
      text: content,
      textStyle: textStyle,
      pageWidth: pageWidth,
      pageHeight: pageHeight,
    );
  }

  int _pagesFor(int index) {
    final cached = _pageCache[index];
    if (cached != null) return cached.length;
    return widget.chapters[index].pageCount;
  }

  void _ensureChapterLoaded(int index) {
    if (_loadedChapters.contains(index)) return;
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
    if (!File(chapter.contentPath).existsSync()) {
      final downloadService = ref.read(chapterDownloadServiceProvider);
      await downloadService.downloadChapter(chapter.bookId, chapter.index);
      if (!mounted) return;
    }
    final repo = ref.read(readerRepositoryProvider);
    final result = await repo.getChapterContent(chapter.contentPath);
    if (!mounted) return;
    if (result case Success(value: final content)) {
      _onContentLoaded(index, content);
    }
  }

  void _recomputeTotalPages() {
    _totalPages = 0;
    for (int i = 0; i < widget.chapters.length; i++) {
      _totalPages += _pagesFor(i);
    }
  }

  final Set<int> _paginationInFlight = {};

  /// Runs pagination for [index] after the current frame has been painted,
  /// so any in-progress build can show a loading spinner first instead of
  /// the UI thread blocking silently on the previous frame.
  void _schedulePagination(int index, String content) {
    if (_paginationInFlight.contains(index)) return;
    _paginationInFlight.add(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paginationInFlight.remove(index);
      if (!mounted) return;
      _paginateChapter(index, content);
      _recomputeTotalPages();
      setState(() {});
    });
  }

  void _onContentLoaded(int index, String content) {
    _contentCache[index] = content;
    if (_needsRepagination() || _pageCache[index] == null) {
      _schedulePagination(index, content);
    } else {
      _recomputeTotalPages();
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
      if (currentIndex < chapterCount - 1) _ensureChapterLoaded(currentIndex + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vt = widget.settings.theme;
    final chapters = widget.chapters;
    final currentIndex = widget.currentChapterIndex;

    _ensureChapterLoaded(currentIndex);
    _scheduleNeighborPrefetch(currentIndex, chapters.length);

    final needsRepaginate = _needsRepagination();
    for (final index in List<int>.from(_loadedChapters)) {
      if (_pageCache[index] == null || needsRepaginate) {
        final content = _contentCache[index];
        if (content != null) {
          _schedulePagination(index, content);
        }
      }
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
      final newGlobalPage =
          _localToGlobal(anchorChapter, anchorLocalPage!).clamp(0, _totalPages - 1);
      if (newGlobalPage != _currentGlobalPage) {
        _currentGlobalPage = newGlobalPage;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(
                isWideDesktop ? newGlobalPage ~/ 2 : newGlobalPage);
          }
        });
      }
    } else if (needsRepaginate && _currentGlobalPage >= _totalPages) {
      _currentGlobalPage = 0;
    }

    if (_pendingChapterJump && _totalPages > 0) {
      _pendingChapterJump = false;
      int target;
      if (widget.initialProgress != null) {
        target = (widget.initialProgress! * _totalPages).round().clamp(0, _totalPages - 1);
      } else {
        target = 0;
        for (int i = 0; i < widget.currentChapterIndex && i < widget.chapters.length; i++) {
          target += _pagesFor(i);
        }
        target = target.clamp(0, _totalPages - 1);
      }
      _currentGlobalPage = target;
      widget.onProgressChanged(_totalPages > 0 ? _currentGlobalPage / _totalPages : 0.0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(isWideDesktop ? target ~/ 2 : target);
        }
      });
    }

    if (!_contentCache.containsKey(currentIndex) || _totalPages == 0) {
      return Scaffold(
        backgroundColor: vt.background,
        extendBodyBehindAppBar: true,
        appBar: ReaderBarSurface(
          style: widget.settings.chromeStyle,
          color: vt.surface,
          child: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            foregroundColor: vt.text,
            title: Text(chapters[widget.currentChapterIndex].title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                icon: Icon(Icons.text_fields, color: vt.text),
                onPressed: widget.onSettingsTap,
              ),
            ],
          ),
        ),
        body: const Center(child: AppLoading()),
      );
    }

    return Scaffold(
      backgroundColor: vt.background,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: chromeVisible
          ? ReaderBarSurface(
              style: widget.settings.chromeStyle,
              color: vt.surface,
              child: ReaderChromeBar(
                title: chapters[currentIndex].title,
                textColor: vt.text,
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
              color: vt.surface,
              child: ReaderBottomNav(
                onSettingsTap: widget.onSettingsTap,
                onChapterIndexTap: () => _showChapterIndex(context),
                onBookmarkTap: widget.onBookmarkToggle,
                isBookmarked: widget.isBookmarked,
                currentChapterTitle: chapters[currentIndex].title,
                currentChapterNumber: currentIndex,
                totalChapters: chapters.length,
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
                    if (rightPanelVisible) {
                      hideRightPanel();
                      return KeyEventResult.handled;
                    }
                  }
                  return _handleKeyEvent(node, event);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (details) {
                    if (rightPanelVisible) {
                      hideRightPanel();
                      return;
                    }
                    if (!isDesktop) {
                      _onMobileTapUp(details, constraints);
                    } else if (isWideDesktop) {
                      _onDesktopSpreadTapUp(details, constraints);
                    } else {
                      toggleChrome(isDarkTheme: widget.settings.theme.isDark);
                    }
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (pageIndex) {
                      _currentGlobalPage = isWideDesktop ? pageIndex * 2 : pageIndex;
                      final (chIdx, _) = _globalToLocal(_currentGlobalPage);
                      _ensureChapterLoaded(chIdx);
                      if (chIdx + 1 < chapters.length) {
                        _ensureChapterLoaded(chIdx + 1);
                      }
                      widget.onPageChanged(chIdx);
                      widget.onProgressChanged(
                          _totalPages > 0 ? _currentGlobalPage / _totalPages : 0.0);
                      resetChromeTimer(isDarkTheme: widget.settings.theme.isDark);
                    },
                    itemCount: isWideDesktop ? _totalSpreads : _totalPages,
                    itemBuilder: (context, index) {
                      if (isWideDesktop) {
                        return _buildSpread(index, vt, chapters);
                      }
                      return _buildSinglePage(index, vt, chapters);
                    },
                  ),
                ),
              ),
              if (!isDesktop && chromeVisible)
                Positioned(
                  top: MediaQuery.of(context).padding.top,
                  left: 0,
                  right: 0,
                  child: ReaderProgressBar(
                    progress: _totalPages > 0 ? _currentGlobalPage / _totalPages : 0.0,
                    color: widget.settings.theme.accent,
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
              if (isDesktop)
                DesktopRightPanelRegion(
                  visible: rightPanelVisible,
                  chromeVisible: chromeVisible,
                  panelWidth: ReaderChromeController.rightPanelWidth,
                  onHoverReveal: showRightPanelOnHover,
                  panel: ReaderRightPanel(
                    chapters: chapters,
                    currentChapterIndex: currentIndex,
                    bookmarkedChapterIds: widget.bookmarkedChapterIds,
                    onChapterSelected: (idx) {
                      widget.onChapterSelected(idx);
                      final target = _localToGlobal(idx, 0);
                      _pageController.animateToPage(target,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut);
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
                    widget.onChapterSelected(idx);
                    final target = _localToGlobal(idx, 0);
                    _pageController.animateToPage(target ~/ 2,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut);
                  },
                  onToggleBookmark: widget.onBookmarkToggle,
                  isBookmarked: widget.isBookmarked,
                  onToggleSettings: widget.onSettingsTap,
                  onTogglePanel: toggleRightPanel,
                  onClose: () => setState(() => commandPaletteVisible = false),
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

  void _showChapterIndex(BuildContext context) {
    final (curChIdx, _) = _globalToLocal(_currentGlobalPage);
    ChapterIndexSheet.show(
      context,
      sheetId: 'paged_chapter_index',
      chapters: widget.chapters,
      currentChapterIndex: curChIdx,
      onChapterTap: (idx) {
        final target = _localToGlobal(idx, 0);
        final pageToJump = isWideDesktop ? target ~/ 2 : target;
        _pageController.animateToPage(pageToJump,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut);
      },
    );
  }

  Widget _buildSinglePage(int globalPage, ReadingViewTheme vt, List<ChapterEntity> chapters) {
    final (chIdx, pageInChapter) = _globalToLocal(globalPage);
    final pages = _pageCache[chIdx];
    if (pages == null) {
      if (_loadedChapters.add(chIdx)) {
        _ensureChapterLoaded(chIdx);
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: CircularProgressIndicator(color: vt.accent),
        ),
      );
    }
    final clampedPage = pageInChapter.clamp(0, pages.length - 1);
    final content = pages[clampedPage];
    final isFirstOfChapter = clampedPage == 0;
    final isLastOfChapter = clampedPage == pages.length - 1;

    final pageWidget = _PagedPageView(
      content: content,
      chapterTitle: chapters[chIdx].title,
      chapterIndex: chIdx,
      isFirstPageOfChapter: isFirstOfChapter,
      isLastPageOfChapter: isLastOfChapter,
      textStyle: TextStyle(
        fontSize: widget.settings.fontSize,
        height: widget.settings.lineHeight,
        letterSpacing: widget.settings.letterSpacing,
        color: vt.text,
      ),
      fontFamily: widget.settings.fontFamily,
      textAlignment: widget.settings.textAlignment,
      marginPreset: widget.settings.marginPreset,
      vt: vt,
      showHeaders: true,
      chapterStyle: ChapterStyle.forChapter(chIdx),
      onHighlight: widget.onHighlight,
      onAddNote: widget.onAddNote,
      onShare: widget.onShare,
      onSearchWeb: widget.onSearchWeb,
    );
    return _wrapWithPageAnimation(pageWidget, globalPage);
  }

  Widget _buildSpread(int spreadIndex, ReadingViewTheme vt, List<ChapterEntity> chapters) {
    final leftGlobalPage = spreadIndex * 2;
    final rightGlobalPage = spreadIndex * 2 + 1;
    final (leftChIdx, _) = _globalToLocal(leftGlobalPage);
    final (rightChIdx, _) = _globalToLocal(rightGlobalPage);

    Widget side(int globalPage, int chIdx) {
      if (_pageCache[chIdx] == null) {
        _ensureChapterLoaded(chIdx);
        return Center(
          child: CircularProgressIndicator(color: vt.accent),
        );
      }
      return _PagedPageView(
        content: _pageContentAt(globalPage),
        chapterTitle: chapters[chIdx].title,
        chapterIndex: chIdx,
        isFirstPageOfChapter: _isFirstPageOfChapter(globalPage),
        isLastPageOfChapter: _isLastPageOfChapter(globalPage),
        textStyle: TextStyle(
          fontSize: widget.settings.fontSize,
          height: widget.settings.lineHeight,
          letterSpacing: widget.settings.letterSpacing,
          color: vt.text,
        ),
        fontFamily: widget.settings.fontFamily,
        textAlignment: widget.settings.textAlignment,
        marginPreset: widget.settings.marginPreset,
        vt: vt,
        showHeaders: false,
        chapterStyle: ChapterStyle.forChapter(chIdx),
        onHighlight: widget.onHighlight,
        onAddNote: widget.onAddNote,
        onShare: widget.onShare,
        onSearchWeb: widget.onSearchWeb,
      );
    }

    return Row(
      children: [
        Expanded(child: rightGlobalPage <= _totalPages ? side(leftGlobalPage, leftChIdx) : Container(color: vt.background)),
        Container(width: 1, color: vt.text.withValues(alpha: 0.1)),
        Expanded(child: rightGlobalPage < _totalPages ? side(rightGlobalPage, rightChIdx) : Container(color: vt.background)),
      ],
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
    return pages != null && pageInChapter.clamp(0, pages.length - 1) == pages.length - 1;
  }
}

class _PagedPageView extends StatelessWidget {
  const _PagedPageView({
    required this.content,
    required this.chapterTitle,
    required this.chapterIndex,
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
  });

  final String content;
  final String chapterTitle;
  final int chapterIndex;
  final bool isFirstPageOfChapter;
  final bool isLastPageOfChapter;
  final TextStyle textStyle;
  final String? fontFamily;
  final TextAlignment textAlignment;
  final MarginPreset marginPreset;
  final ReadingViewTheme vt;
  final bool showHeaders;
  final ChapterStyle? chapterStyle;
  final void Function(String text, Color color)? onHighlight;
  final void Function(String text, String? sentence)? onAddNote;
  final void Function(String text)? onShare;
  final void Function(String text)? onSearchWeb;

  EdgeInsets get _padding => switch (marginPreset) {
    MarginPreset.narrow => const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: AppSpacing.sm,
      ),
    MarginPreset.normal => const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.md,
      ),
    MarginPreset.wide => const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl, vertical: AppSpacing.lg,
      ),
  };

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = fontFamily != null
        ? GoogleFonts.getFont(fontFamily!, textStyle: textStyle)
        : textStyle;
    final cs = chapterStyle;

    return Container(
      color: vt.background,
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
              textColor: vt.text,
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

    if (cs != null && isFirstPageOfChapter && c.isNotEmpty) {
      final ds = cs.dropCapStyle;
      return SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(text: c.substring(0, 1), style: ds),
            TextSpan(text: c.substring(1), style: resolvedStyle),
          ],
        ),
        textAlign: textAlignment.flutterTextAlign,
        contextMenuBuilder: contextMenu,
      );
    }
    return SelectableText(
      c,
      style: resolvedStyle,
      textAlign: textAlignment.flutterTextAlign,
      contextMenuBuilder: contextMenu,
    );
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
        final sentence =
            hasSelection && word.isNotEmpty ? _sentenceAround(fullText, sel) : null;
        final showSelectionActions = hasSelection && word.isNotEmpty;
        final srcTitle = chapterTitle;

        return AppContextMenu(
          anchor: anchor,
          highlightColors: showSelectionActions ? _highlightPalette : const [],
          onHighlightSelected: showSelectionActions && onHighlight != null
              ? (color) => onHighlight!(word, color)
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
                label: 'Define "$word"',
                icon: Icons.translate_rounded,
                onPressed: () => _showDefine(ctx, word, sentence: sentence, sourceTitle: srcTitle),
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
              onPressed: () => editable.selectAll(SelectionChangedCause.toolbar),
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

  void _showDefine(BuildContext ctx, String word, {String? sentence, String? sourceTitle}) {
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
