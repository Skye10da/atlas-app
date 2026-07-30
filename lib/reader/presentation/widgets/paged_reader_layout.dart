import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_styles.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/pager.dart';
import 'package:atlas_app/core/design_system/widgets/app_context_menu.dart';
import 'package:atlas_app/reader/presentation/widgets/word_lookup_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bottom_nav.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_command_palette.dart';
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

class _PagedReaderLayoutState extends ConsumerState<PagedReaderLayout> {
  final _pageController = PageController();
  final Map<int, List<String>> _pageCache = {};
  final Map<int, String> _contentCache = {};
  final Set<int> _loadedChapters = {};
  int _totalPages = 0;
  int _currentGlobalPage = 0;
  String _cacheKey = '';
  bool _chromeVisible = true;
  bool _rightPanelVisible = false;
  bool _commandPaletteVisible = false;
  bool _pendingChapterJump = true;
  Timer? _chromeTimer;
  double _layoutWidth = 0;
  double _layoutHeight = 0;
  int? _neighborPrefetchScheduledFor;
  static const double _maxReadingWidth = 720.0;
  static const double _rightPanelWidth = 280.0;

  @override
  void initState() {
    super.initState();
    _cacheKey = _computeCacheKey();
    _resetChromeTimer();
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }

  void _setFullscreen(bool fullscreen) {
    SystemChrome.setEnabledSystemUIMode(
      fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          widget.settings.theme.isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: widget.settings.theme.background,
      systemNavigationBarIconBrightness:
          widget.settings.theme.isDark ? Brightness.light : Brightness.dark,
    ));
  }

  void _toggleChrome() {
    HapticFeedback.lightImpact();
    setState(() {
      _chromeVisible = !_chromeVisible;
    });
    if (_chromeVisible) {
      _setFullscreen(false);
      _resetChromeTimer();
    } else {
      _setFullscreen(true);
      _chromeTimer?.cancel();
    }
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
      _toggleChrome();
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
      _toggleChrome();
    }
  }

  double? _brightnessDragStartY;
  double? _brightnessDragStartValue;

  void _onEdgeBrightnessStart(DragStartDetails details) {
    _brightnessDragStartY = details.localPosition.dy;
    _brightnessDragStartValue = widget.settings.brightness;
  }

  void _onEdgeBrightnessUpdate(DragUpdateDetails details) {
    if (_brightnessDragStartY == null || _brightnessDragStartValue == null) return;
    final delta = (details.localPosition.dy - _brightnessDragStartY!) / 300;
    final newBrightness = (_brightnessDragStartValue! - delta).clamp(0.0, 1.0);
    final notifier = ref.read(readingSettingsProvider.notifier);
    notifier.setBrightness(newBrightness);
    final svc = ref.read(platformServiceProvider);
    svc.setBrightness(newBrightness, smooth: true);
  }

  void _onEdgeBrightnessEnd(DragEndDetails details) {
    _brightnessDragStartY = null;
    _brightnessDragStartValue = null;
  }

  void _resetChromeTimer() {
    _chromeTimer?.cancel();
    _chromeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _chromeVisible = false);
        _setFullscreen(true);
      }
    });
  }

  bool get _isDesktop => MediaQuery.of(context).size.width >= 840;
  bool get _isWideDesktop => _isDesktop && MediaQuery.of(context).size.width >= 1200;

  int get _totalSpreads => (_totalPages + 1) ~/ 2;

  double _pageWidthForCurrentMode() {
    final rawWidth = _layoutWidth > 0 ? _layoutWidth : 800.0;
    if (_isWideDesktop) {
      final maxSpreadWidth = rawWidth - (_rightPanelVisible ? _rightPanelWidth : 0);
      final pageArea = maxSpreadWidth * 0.9;
      return (pageArea / 2).clamp(280.0, 520.0);
    }
    return rawWidth > _maxReadingWidth ? _maxReadingWidth : rawWidth;
  }

  void _toggleRightPanel() {
    setState(() => _rightPanelVisible = !_rightPanelVisible);
  }

  void _hideRightPanel() {
    if (_rightPanelVisible) setState(() => _rightPanelVisible = false);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isDesktop = MediaQuery.of(context).size.width >= 840;
    if (!isDesktop) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _resetChromeTimer();
      if (_currentGlobalPage > 0) {
        final step = _isWideDesktop ? 2 : 1;
        final target = _currentGlobalPage - step;
        if (_isWideDesktop) {
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
      _resetChromeTimer();
      if (_currentGlobalPage < _totalPages - 1) {
        if (_isWideDesktop) {
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
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_commandPaletteVisible) {
        setState(() => _commandPaletteVisible = false);
        return KeyEventResult.handled;
      }
      _toggleChrome();
      return KeyEventResult.handled;
    }

    final isCtrlOrCmd = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (isCtrlOrCmd && event.logicalKey == LogicalKeyboardKey.keyK) {
      if (!_commandPaletteVisible) {
        setState(() => _commandPaletteVisible = true);
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

    _totalPages = 0;
    for (int i = 0; i < chapters.length; i++) {
      _totalPages += _pagesFor(i);
    }
    if (needsRepaginate && _currentGlobalPage >= _totalPages) {
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
          target += _pageCache[i]?.length ?? 0;
        }
        target = target.clamp(0, _totalPages - 1);
      }
      _currentGlobalPage = target;
      widget.onProgressChanged(_totalPages > 0 ? _currentGlobalPage / _totalPages : 0.0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_isWideDesktop ? target ~/ 2 : target);
        }
      });
    }

    if (!_contentCache.containsKey(currentIndex) || _totalPages == 0) {
      return Scaffold(
        backgroundColor: vt.background,
        appBar: AppBar(
          backgroundColor: vt.surface,
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
        body: const Center(child: AppLoading()),
      );
    }

    return Scaffold(
      backgroundColor: vt.background,
      appBar: _chromeVisible
          ? AppBar(
              backgroundColor: vt.surface,
              foregroundColor: vt.text,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: 40,
              title: Text(chapters[currentIndex].title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14)),
              actions: [
                if (_isDesktop) ...[
                  IconButton(
                    icon: Icon(
                      _rightPanelVisible ? Icons.view_sidebar : Icons.view_sidebar_outlined,
                      size: 18,
                      color: vt.text,
                    ),
                    tooltip: 'Toggle panel',
                    onPressed: _toggleRightPanel,
                  ),
                  const SizedBox(width: 4),
                ],
                IconButton(
                  icon: Icon(Icons.text_fields, size: 18, color: vt.text),
                  onPressed: widget.onSettingsTap,
                ),
              ],
            )
          : null,
      bottomNavigationBar: _chromeVisible
          ? ReaderBottomNav(
              onSettingsTap: widget.onSettingsTap,
              onChapterIndexTap: () => _showChapterIndex(context),
              onBookmarkTap: widget.onBookmarkToggle,
              isBookmarked: widget.isBookmarked,
              currentChapterTitle: chapters[currentIndex].title,
              currentChapterNumber: currentIndex,
              totalChapters: chapters.length,
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
                    if (_rightPanelVisible) {
                      _hideRightPanel();
                      return KeyEventResult.handled;
                    }
                  }
                  return _handleKeyEvent(node, event);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (details) {
                    if (_rightPanelVisible) {
                      _hideRightPanel();
                      return;
                    }
                    if (!_isDesktop) {
                      _onMobileTapUp(details, constraints);
                    } else if (_isWideDesktop) {
                      _onDesktopSpreadTapUp(details, constraints);
                    } else {
                      _toggleChrome();
                    }
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (pageIndex) {
                      _currentGlobalPage = _isWideDesktop ? pageIndex * 2 : pageIndex;
                      final (chIdx, _) = _globalToLocal(_currentGlobalPage);
                      _ensureChapterLoaded(chIdx);
                      if (chIdx + 1 < chapters.length) {
                        _ensureChapterLoaded(chIdx + 1);
                      }
                      widget.onPageChanged(chIdx);
                      widget.onProgressChanged(
                          _totalPages > 0 ? _currentGlobalPage / _totalPages : 0.0);
                      _resetChromeTimer();
                    },
                    itemCount: _isWideDesktop ? _totalSpreads : _totalPages,
                    itemBuilder: (context, index) {
                      if (_isWideDesktop) {
                        return _buildSpread(index, vt, chapters);
                      }
                      return _buildSinglePage(index, vt, chapters);
                    },
                  ),
                ),
              ),
              if (!_isDesktop && _chromeVisible)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ReaderProgressBar(
                    progress: _totalPages > 0 ? _currentGlobalPage / _totalPages : 0.0,
                    color: widget.settings.theme.accent,
                  ),
                ),
              if (!_isDesktop)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 40,
                  child: GestureDetector(
                    onVerticalDragStart: _onEdgeBrightnessStart,
                    onVerticalDragUpdate: _onEdgeBrightnessUpdate,
                    onVerticalDragEnd: _onEdgeBrightnessEnd,
                    behavior: HitTestBehavior.translucent,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              if (_isDesktop) ...[
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 8,
                  child: MouseRegion(
                    onEnter: (_) {
                      if (!_rightPanelVisible) {
                        setState(() => _rightPanelVisible = true);
                      }
                    },
                    cursor: _rightPanelVisible ? SystemMouseCursors.basic : SystemMouseCursors.click,
                    child: Container(color: Colors.transparent),
                  ),
                ),
                if (_rightPanelVisible)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: _rightPanelWidth,
                    child: ReaderRightPanel(
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
                      onClose: _hideRightPanel,
                      settings: widget.settings,
                    ),
                  ),
              ],
              if (_commandPaletteVisible)
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
                  onTogglePanel: _toggleRightPanel,
                  onClose: () => setState(() => _commandPaletteVisible = false),
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
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Chapters',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: ListView.separated(
              itemCount: widget.chapters.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 16),
              itemBuilder: (_, idx) {
                final ch = widget.chapters[idx];
                final (curChIdx, _) = _globalToLocal(_currentGlobalPage);
                final isCurrent = idx == curChIdx;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCurrent
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                      ),
                    ),
                  ),
                  title: Text(
                    ch.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.w600 : null),
                  ),
                  trailing: isCurrent
                      ? Icon(Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    final target = _localToGlobal(idx, 0);
                    final pageToJump = _isWideDesktop ? target ~/ 2 : target;
                    _pageController.animateToPage(pageToJump,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut);
                  },
                );
              },
            ),
          ),
        ],
      ),
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
      showHeaders: _chromeVisible,
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.bannerBackground.withValues(alpha: 0.3),
                border: Border(
                  bottom: BorderSide(
                      color: cs.accentColor.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${chapterIndex + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(chapterTitle, style: cs.titleStyle),
                  ),
                ],
              ),
            ),
          if (isFirstPageOfChapter && showHeaders && cs != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: Text(
                  ChapterStyle.ornamentalDivider,
                  style: TextStyle(
                    color: cs.accentColor.withValues(alpha: 0.4),
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: _padding,
              child: _buildText(resolvedStyle, cs),
            ),
          ),
          if (isLastPageOfChapter && showHeaders) ...[
            if (cs != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    ChapterStyle.ornamentalDivider,
                    style: TextStyle(
                      color: cs.accentColor.withValues(alpha: 0.4),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Column(
                children: [
                  Divider(color: vt.text.withValues(alpha: 0.15)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '— End of Chapter ${chapterIndex + 1} —',
                    style: TextStyle(
                      fontSize: textStyle.fontSize! * 0.85,
                      color: vt.text.withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
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
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (c) => WordLookupSheet(
        word: word,
        sourceSentence: sentence,
        sourceTitle: sourceTitle,
      ),
    );
  }
}
