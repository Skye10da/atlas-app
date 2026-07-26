import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/molecules/app_error_state.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/services/platform_service.dart';
import 'package:atlas_app/reader/domain/entities/bookmark_entity.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/reader_repository_interface.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(readerRepositoryProvider);
    final settingsAsync = ref.watch(readingSettingsProvider);

    return settingsAsync.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (_, _) => const Scaffold(body: AppLoading()),
      data: (settings) => _ReaderContent(
        repo: repo,
        bookId: widget.bookId,
        settings: settings,
        onFontSizeChanged: (size) =>
            ref.read(readingSettingsProvider.notifier).setFontSize(size),
        onFontFamilyChanged: (f) =>
            ref.read(readingSettingsProvider.notifier).setFontFamily(f),
        onLineHeightChanged: (h) =>
            ref.read(readingSettingsProvider.notifier).setLineHeight(h),
        onLetterSpacingChanged: (s) =>
            ref.read(readingSettingsProvider.notifier).setLetterSpacing(s),
        onKeepScreenAwakeChanged: (v) =>
            ref.read(readingSettingsProvider.notifier).setKeepScreenAwake(v),
        onBrightnessChanged: (v) =>
            ref.read(readingSettingsProvider.notifier).setBrightness(v),
        onThemeChanged: (t) =>
            ref.read(readingSettingsProvider.notifier).setTheme(t),
        onReadingModeChanged: (m) =>
            ref.read(readingSettingsProvider.notifier).setReadingMode(m),
        onTextAlignmentChanged: (a) =>
            ref.read(readingSettingsProvider.notifier).setTextAlignment(a),
        onMarginPresetChanged: (p) =>
            ref.read(readingSettingsProvider.notifier).setMarginPreset(p),
      ),
    );
  }
}

class _ReaderContent extends ConsumerStatefulWidget {
  const _ReaderContent({
    required this.repo,
    required this.bookId,
    required this.settings,
    required this.onFontSizeChanged,
    required this.onFontFamilyChanged,
    required this.onLineHeightChanged,
    required this.onLetterSpacingChanged,
    required this.onKeepScreenAwakeChanged,
    required this.onBrightnessChanged,
    required this.onThemeChanged,
    required this.onReadingModeChanged,
    required this.onTextAlignmentChanged,
    required this.onMarginPresetChanged,
  });

  final ReaderRepositoryInterface repo;
  final String bookId;
  final ReadingSettingsEntity settings;
  final void Function(double) onFontSizeChanged;
  final void Function(String?) onFontFamilyChanged;
  final void Function(double) onLineHeightChanged;
  final void Function(double) onLetterSpacingChanged;
  final void Function(bool) onKeepScreenAwakeChanged;
  final void Function(double) onBrightnessChanged;
  final void Function(ReadingViewTheme) onThemeChanged;
  final void Function(ReadingMode) onReadingModeChanged;
  final void Function(TextAlignment) onTextAlignmentChanged;
  final void Function(MarginPreset) onMarginPresetChanged;

  @override
  ConsumerState<_ReaderContent> createState() => _ReaderContentState();
}

class _ReaderContentState extends ConsumerState<_ReaderContent> {
  ChapterEntity? _currentChapter;
  List<ChapterEntity> _chapters = [];
  double _scrollProgress = 0.0;
  int? _initialChapterIndex;
  double? _initialScrollProgress;
  bool _readQueryParam = false;
  bool _loading = true;
  String? _errorMessage;
  Set<String> _bookmarkedChapterIds = {};
  late final PlatformService _platformService;
  Timer? _saveDebounceTimer;

  @override
  void initState() {
    super.initState();
    _platformService = createPlatformService();
    _loadChapters();
  }

  @override
  void didUpdateWidget(_ReaderContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.brightness != widget.settings.brightness ||
        oldWidget.settings.keepScreenAwake != widget.settings.keepScreenAwake) {
      _applySystemSettings();
    }
  }

  void _applySystemSettings() {
    if (widget.settings.keepScreenAwake) {
      _platformService.enableWakeLock();
    } else {
      _platformService.disableWakeLock();
    }
    _platformService.setBrightness(widget.settings.brightness);
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
      final targetIndex = _initialChapterIndex != null
          ? _initialChapterIndex!.clamp(0, _chapters.length - 1)
          : 0;
      _currentChapter ??= _chapters[targetIndex];
      _initialChapterIndex = null;
    });
    await _loadBookmarks();
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
      final chapterParam = params['chapter'];
      _initialChapterIndex =
          chapterParam != null ? int.tryParse(chapterParam) : null;
      final progressParam = params['progress'];
      _initialScrollProgress =
          progressParam != null ? double.tryParse(progressParam) : null;
      _readQueryParam = true;
    }
    _applySystemSettings();
  }

  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
    if (_currentChapter != null) {
      _saveProgress(_currentChapter!);
    }
    _platformService.disableWakeLock();
    _platformService.resetBrightness();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: AppLoading());
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

    final isBookmarked = _currentChapter != null &&
        _bookmarkedChapterIds.contains(_currentChapter!.id);

    if (settings.readingMode == ReadingMode.continuous) {
      return _ContinuousReaderLayout(
        chapters: chapters,
        settings: settings,
        currentChapterIndex: _currentChapter != null
            ? chapters.indexOf(_currentChapter!)
            : 0,
        initialScrollProgress: _initialScrollProgress,
        onScrollProgress: _onContinuousScrollProgress,
        onCurrentChapterChanged: _onContinuousChapterChanged,
        onScrollDirectionChanged: _onScrollDirectionChanged,
        onSettingsTap: _showSettingsDrawer,
        onChapterSelected: (idx) {
          setState(() => _currentChapter = _chapters[idx]);
        },
        isBookmarked: isBookmarked,
        onBookmarkToggle: _toggleBookmark,
      );
    }

    return _PagedReaderLayout(
      chapters: chapters,
      settings: settings,
      currentChapterIndex: chapters.indexOf(_currentChapter!),
      onPageChanged: _onPagedPageChanged,
      onChapterSelected: _goToPagedChapter,
      onSettingsTap: _showSettingsDrawer,
      isBookmarked: isBookmarked,
      onBookmarkToggle: _toggleBookmark,
    );
  }

  void _onContinuousScrollProgress(double progress) {
    _scrollProgress = progress;
  }

  void _onContinuousChapterChanged(int index) {
    if (_currentChapter?.id != _chapters[index].id) {
      setState(() => _currentChapter = _chapters[index]);
      _saveProgress(_chapters[index]);
    }
  }

  void _onScrollDirectionChanged(ScrollDirection direction) {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_currentChapter != null) _saveProgress(_currentChapter!);
    });
  }

  void _saveProgress(ChapterEntity chapter) async {
    await widget.repo.saveProgress(
      userId: 'local',
      bookId: widget.bookId,
      chapterId: chapter.id,
      percentage: _scrollProgress * 100,
      position: 0,
      totalPositions: 0,
    );
  }

  void _onPagedPageChanged(int chapterIndex) {
    setState(() => _currentChapter = _chapters[chapterIndex]);
    _saveProgress(_chapters[chapterIndex]);
  }

  void _goToPagedChapter(int index) {}

  void _showSettingsDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ReaderSettings(
        fontSize: widget.settings.fontSize,
        fontFamily: widget.settings.fontFamily,
        lineHeight: widget.settings.lineHeight,
        letterSpacing: widget.settings.letterSpacing,
        keepScreenAwake: widget.settings.keepScreenAwake,
        brightness: widget.settings.brightness,
        theme: widget.settings.theme,
        readingMode: widget.settings.readingMode,
        textAlignment: widget.settings.textAlignment,
        marginPreset: widget.settings.marginPreset,
        onFontSizeChanged: widget.onFontSizeChanged,
        onFontFamilyChanged: widget.onFontFamilyChanged,
        onLineHeightChanged: widget.onLineHeightChanged,
        onLetterSpacingChanged: widget.onLetterSpacingChanged,
        onKeepScreenAwakeChanged: widget.onKeepScreenAwakeChanged,
        onBrightnessChanged: widget.onBrightnessChanged,
        onThemeChanged: widget.onThemeChanged,
        onReadingModeChanged: widget.onReadingModeChanged,
        onTextAlignmentChanged: widget.onTextAlignmentChanged,
        onMarginPresetChanged: widget.onMarginPresetChanged,
      ),
    );
  }
}

class _Pager {
  static List<String> paginate({
    required String text,
    required TextStyle textStyle,
    required double pageWidth,
    required double pageHeight,
  }) {
    if (text.isEmpty) return [''];
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ');
    final words = normalized.split(' ');
    final pages = <String>[];
    final painter = TextPainter(textDirection: TextDirection.ltr);

    int start = 0;
    while (start < words.length) {
      int low = start;
      int high = words.length;
      while (low < high) {
        final mid = (low + high + 1) ~/ 2;
        painter.text = TextSpan(
          text: words.sublist(start, mid).join(' '),
          style: textStyle,
        );
        painter.layout(maxWidth: pageWidth);
        if (painter.height <= pageHeight) {
          low = mid;
        } else {
          high = mid - 1;
        }
      }
      pages.add(words.sublist(start, low).join(' '));
      start = low;
    }

    return pages;
  }
}

class _PagedReaderLayout extends ConsumerStatefulWidget {
  const _PagedReaderLayout({
    required this.chapters,
    required this.settings,
    required this.currentChapterIndex,
    required this.onPageChanged,
    required this.onChapterSelected,
    required this.onSettingsTap,
    required this.isBookmarked,
    required this.onBookmarkToggle,
  });

  final List<ChapterEntity> chapters;
  final ReadingSettingsEntity settings;
  final int currentChapterIndex;
  final void Function(int chapterIndex) onPageChanged;
  final void Function(int chapterIndex) onChapterSelected;
  final VoidCallback onSettingsTap;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;

  @override
  ConsumerState<_PagedReaderLayout> createState() =>
      _PagedReaderLayoutState();
}

class _PagedReaderLayoutState extends ConsumerState<_PagedReaderLayout> {
  final _pageController = PageController();
  final Map<int, List<String>> _pageCache = {};
  final Map<int, String> _contentCache = {};
  int _totalPages = 0;
  int _currentGlobalPage = 0;
  String _cacheKey = '';
  bool _chromeVisible = true;
  bool _pendingChapterJump = true;
  Timer? _chromeTimer;

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

  void _resetChromeTimer() {
    _chromeTimer?.cancel();
    _chromeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _chromeVisible = false);
        _setFullscreen(true);
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isDesktop = MediaQuery.of(context).size.width >= 840;
    if (!isDesktop) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _resetChromeTimer();
      if (_currentGlobalPage > 0) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _resetChromeTimer();
      if (_currentGlobalPage < _totalPages - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _toggleChrome();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  String _computeCacheKey() {
    final s = widget.settings;
    return '${s.fontSize}_${s.fontFamily}_${s.lineHeight}_${s.marginPreset.name}_${s.textAlignment.name}';
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
      final pages = _pageCache[i];
      final len = pages != null ? pages.length : 1;
      if (remaining < len) return (i, remaining);
      remaining -= len;
    }
    final last = widget.chapters.length - 1;
    final lastPages = _pageCache[last];
    return (last, lastPages != null ? lastPages.length - 1 : 0);
  }

  int _localToGlobal(int chapterIndex, int pageInChapter) {
    int offset = 0;
    for (int i = 0; i < chapterIndex; i++) {
      offset += _pageCache[i]?.length ?? 1;
    }
    return offset + pageInChapter;
  }

  void _paginateChapter(int index, String content) {
    final s = widget.settings;
    final isDesktop = MediaQuery.of(context).size.width >= 840;
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
    final height = MediaQuery.of(context).size.height;
    final width = isDesktop ? 720.0 : MediaQuery.of(context).size.width;
    final pageWidth = width - horizontalMargin * 2;
    final pageHeight = height - kToolbarHeight - 120 - verticalMargin * 2;

    final baseStyle = TextStyle(
      fontSize: s.fontSize,
      height: s.lineHeight,
      letterSpacing: s.letterSpacing,
      color: s.theme.text,
    );
    final textStyle = s.fontFamily != null
        ? GoogleFonts.getFont(s.fontFamily!, textStyle: baseStyle)
        : baseStyle;

    _pageCache[index] = _Pager.paginate(
      text: content,
      textStyle: textStyle,
      pageWidth: pageWidth,
      pageHeight: pageHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vt = widget.settings.theme;
    final chapters = widget.chapters;
    bool contentLoaded = true;

    for (final chapter in chapters) {
      final contentAsync =
          ref.watch(readerChapterContentProvider(chapter.contentPath));
      contentAsync.when(
        loading: () => contentLoaded = false,
        error: (_, _) => contentLoaded = false,
        data: (content) {
          _contentCache[chapter.index] = content;
        },
      );
    }

    final needsRepaginate = _needsRepagination();
    for (final chapter in chapters) {
      if (_pageCache[chapter.index] == null || needsRepaginate) {
        final content = _contentCache[chapter.index];
        if (content != null) {
          _paginateChapter(chapter.index, content);
        }
      }
    }

    _totalPages = 0;
    for (final chapter in chapters) {
      _totalPages += _pageCache[chapter.index]?.length ?? 0;
    }
    if (needsRepaginate && _currentGlobalPage >= _totalPages) {
      _currentGlobalPage = 0;
    }

    if (_pendingChapterJump && _totalPages > 0) {
      _pendingChapterJump = false;
      int target = 0;
      for (int i = 0; i < widget.currentChapterIndex && i < widget.chapters.length; i++) {
        target += _pageCache[i]?.length ?? 0;
      }
      target = target.clamp(0, _totalPages - 1);
      _currentGlobalPage = target;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(target);
        }
      });
    }

    if (!contentLoaded || _totalPages == 0) {
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

    final currentIndex = widget.currentChapterIndex;

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
                IconButton(
                  icon: Icon(Icons.text_fields, size: 18, color: vt.text),
                  onPressed: widget.onSettingsTap,
                ),
              ],
            )
          : null,
      bottomNavigationBar: _chromeVisible
          ? _ReaderBottomNav(
              onSettingsTap: widget.onSettingsTap,
              onChapterIndexTap: () => _showChapterIndex(context),
              onBookmarkTap: widget.onBookmarkToggle,
              isBookmarked: widget.isBookmarked,
              currentChapterTitle: chapters[currentIndex].title,
              currentChapterNumber: currentIndex,
              totalChapters: chapters.length,
            )
          : null,
      body: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
        onTap: _toggleChrome,
        child: PageView.builder(
        controller: _pageController,
        onPageChanged: (globalPage) {
          _currentGlobalPage = globalPage;
          final (chIdx, _) = _globalToLocal(globalPage);
          widget.onPageChanged(chIdx);
          _resetChromeTimer();
        },
        itemCount: _totalPages,
        itemBuilder: (context, globalPage) {
          final (chIdx, pageInChapter) = _globalToLocal(globalPage);
          final pages = _pageCache[chIdx]!;
          final content = pages[pageInChapter];
          final isFirstOfChapter = pageInChapter == 0;
          final isLastOfChapter = pageInChapter == pages.length - 1;

            return _PagedPageView(
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
          );
        },
      ),
      ),
    ));
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
                    _pageController.animateToPage(target,
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

    return Container(
      color: vt.background,
      child: Column(
        children: [
          if (isFirstPageOfChapter && showHeaders)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: vt.text.withValues(alpha: 0.08))),
              ),
              child: Text(
                chapterTitle,
                style: TextStyle(
                  fontSize: textStyle.fontSize! * 1.2,
                  fontWeight: FontWeight.bold,
                  color: vt.text,
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: _padding,
              child: SelectableText(
                content,
                style: resolvedStyle,
                textAlign: textAlignment.flutterTextAlign,
              ),
            ),
          ),
          if (isLastPageOfChapter && showHeaders)
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
      ),
    );
  }
}

class _ContinuousReaderLayout extends StatefulWidget {
  const _ContinuousReaderLayout({
    required this.chapters,
    required this.settings,
    required this.currentChapterIndex,
    this.initialScrollProgress,
    required this.onScrollProgress,
    required this.onCurrentChapterChanged,
    required this.onScrollDirectionChanged,
    required this.onSettingsTap,
    required this.onChapterSelected,
    required this.isBookmarked,
    required this.onBookmarkToggle,
  });

  final List<ChapterEntity> chapters;
  final ReadingSettingsEntity settings;
  final int currentChapterIndex;
  final double? initialScrollProgress;
  final void Function(double) onScrollProgress;
  final void Function(int) onCurrentChapterChanged;
  final void Function(ScrollDirection) onScrollDirectionChanged;
  final VoidCallback onSettingsTap;
  final void Function(int) onChapterSelected;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;

  @override
  State<_ContinuousReaderLayout> createState() =>
      _ContinuousReaderLayoutState();
}

class _ContinuousReaderLayoutState extends State<_ContinuousReaderLayout> {
  final _scrollController = ScrollController();
  double _lastScrollPos = 0;
  bool _chromeVisible = true;
  Timer? _chromeTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialScrollProgress != null) {
        _restoreScrollProgress(widget.initialScrollProgress!);
      } else {
        _scrollToChapter(widget.currentChapterIndex);
      }
    });
    _resetChromeTimer();
  }

  @override
  void didUpdateWidget(_ContinuousReaderLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentChapterIndex != oldWidget.currentChapterIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToChapter(widget.currentChapterIndex));
    }
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

  void _resetChromeTimer() {
    _chromeTimer?.cancel();
    _chromeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _chromeVisible = false);
        _setFullscreen(true);
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isDesktop = MediaQuery.of(context).size.width >= 840;
    if (!isDesktop) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (!_scrollController.hasClients) return KeyEventResult.handled;
      _resetChromeTimer();
      final offset = _scrollController.offset -
          MediaQuery.of(context).size.height * 0.4;
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (!_scrollController.hasClients) return KeyEventResult.handled;
      _resetChromeTimer();
      final offset = _scrollController.offset +
          MediaQuery.of(context).size.height * 0.4;
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      if (!_scrollController.hasClients) return KeyEventResult.handled;
      _resetChromeTimer();
      final offset = _scrollController.offset -
          MediaQuery.of(context).size.height * 0.85;
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      if (!_scrollController.hasClients) return KeyEventResult.handled;
      _resetChromeTimer();
      final offset = _scrollController.offset +
          MediaQuery.of(context).size.height * 0.85;
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _toggleChrome();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _scrollToChapter(int index) {
    if (!_scrollController.hasClients) return;
    if (index < 0 || index >= widget.chapters.length) return;
    final total = _scrollController.position.maxScrollExtent;
    if (total <= 0) return;
    final target = (index / widget.chapters.length) * total;
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _restoreScrollProgress(double progress) {
    if (!_scrollController.hasClients) return;
    final total = _scrollController.position.maxScrollExtent;
    if (total <= 0) return;
    _scrollController.jumpTo((progress * total).clamp(0.0, total));
  }

  int _currentChapterAtOffset(double scrollOffset) {
    final total = _scrollController.position.maxScrollExtent;
    final progress = total > 0 ? scrollOffset / total : 0.0;
    return (progress * widget.chapters.length).floor().clamp(0, widget.chapters.length - 1);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _resetChromeTimer();
    final pos = _scrollController.position;
    final progress = pos.maxScrollExtent > 0 ? pos.pixels / pos.maxScrollExtent : 0.0;
    widget.onScrollProgress(progress);

    final current = _currentChapterAtOffset(pos.pixels);
    widget.onCurrentChapterChanged(current);

    final delta = pos.pixels - _lastScrollPos;
    if (delta.abs() > 4) {
      final direction = delta > 0 ? ScrollDirection.down : ScrollDirection.up;
      widget.onScrollDirectionChanged(direction);
      setState(() {
        if (direction == ScrollDirection.up) {
          _chromeVisible = true;
          _setFullscreen(false);
        }
      });
    }
    _lastScrollPos = pos.pixels;
  }

  Widget _buildChapterBlock(ChapterEntity chapter, int index, {bool showHeaders = true}) {
    final vt = widget.settings.theme;
    final textStyle = TextStyle(
      fontSize: widget.settings.fontSize,
      height: widget.settings.lineHeight,
      letterSpacing: widget.settings.letterSpacing,
      color: vt.text,
    );
    final resolvedTitleStyle = widget.settings.fontFamily != null
        ? GoogleFonts.getFont(widget.settings.fontFamily!,
            textStyle: textStyle.copyWith(
              fontSize: textStyle.fontSize! * 1.2,
              fontWeight: FontWeight.bold,
            ))
        : textStyle.copyWith(
            fontSize: textStyle.fontSize! * 1.2,
            fontWeight: FontWeight.bold,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeaders)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              border: Border(
                  bottom:
                      BorderSide(color: vt.text.withValues(alpha: 0.08))),
            ),
            child: Text(
              chapter.title,
              style: resolvedTitleStyle,
            ),
          ),
        _ChapterContent(
          chapter: chapter,
          fontSize: widget.settings.fontSize,
          fontFamily: widget.settings.fontFamily,
          lineHeight: widget.settings.lineHeight,
          letterSpacing: widget.settings.letterSpacing,
          vt: vt,
          textAlignment: widget.settings.textAlignment,
          marginPreset: widget.settings.marginPreset,
          scrollable: false,
        ),
        if (showHeaders)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Column(
              children: [
                Divider(color: vt.text.withValues(alpha: 0.15)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '— End of Chapter ${index + 1} —',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final vt = widget.settings.theme;
    final chapters = widget.chapters;
    final index = widget.currentChapterIndex;

    return Scaffold(
      backgroundColor: vt.background,
      appBar: _chromeVisible
          ? AppBar(
              backgroundColor: vt.surface,
              foregroundColor: vt.text,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: 40,
              title: Text(chapters[index].title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14)),
              actions: [
                IconButton(
                  icon: Icon(Icons.text_fields, size: 18, color: vt.text),
                  onPressed: widget.onSettingsTap,
                ),
              ],
            )
          : null,
      body: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
        onTap: _toggleChrome,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: chapters.length,
          itemBuilder: (context, index) => _buildChapterBlock(chapters[index], index, showHeaders: _chromeVisible),
        ),
      ),
      ),
      bottomNavigationBar: _chromeVisible
          ? _ReaderBottomNav(
              onSettingsTap: widget.onSettingsTap,
              onChapterIndexTap: () => _showChapterIndex(context),
              onBookmarkTap: widget.onBookmarkToggle,
              isBookmarked: widget.isBookmarked,
              currentChapterTitle: chapters[index].title,
              currentChapterNumber: index,
              totalChapters: chapters.length,
            )
          : null,
    );
  }

  void _showChapterIndex(BuildContext context) {
    final currentIndex = widget.currentChapterIndex;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Chapters', style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: ListView.separated(
              itemCount: widget.chapters.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
              itemBuilder: (_, idx) {
                final ch = widget.chapters[idx];
                final isCurrent = idx == currentIndex;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCurrent ? Theme.of(context).colorScheme.onPrimary : null,
                      ),
                    ),
                  ),
                  title: Text(
                    ch.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: isCurrent ? FontWeight.w600 : null),
                  ),
                  trailing: isCurrent
                      ? Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    _scrollToChapter(idx);
                    Navigator.of(ctx).pop();
                    widget.onChapterSelected(idx);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterContent extends ConsumerWidget {
  const _ChapterContent({
    required this.chapter,
    required this.fontSize,
    this.fontFamily,
    required this.lineHeight,
    required this.letterSpacing,
    required this.vt,
    this.textAlignment = TextAlignment.left,
    this.marginPreset = MarginPreset.normal,
    this.scrollable = true,
  });

  final ChapterEntity chapter;
  final double fontSize;
  final String? fontFamily;
  final double lineHeight;
  final double letterSpacing;
  final ReadingViewTheme vt;
  final TextAlignment textAlignment;
  final MarginPreset marginPreset;
  final bool scrollable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync =
        ref.watch(readerChapterContentProvider(chapter.contentPath));

    return contentAsync.when(
      loading: () => const AppLoading(),
      error: (err, _) => Center(
        child: Text('Could not load chapter.',
            style: TextStyle(color: vt.text)),
      ),
      data: (content) => Container(
        color: vt.background,
        child: ChapterView(
          content: content,
          fontSize: fontSize,
          fontFamily: fontFamily,
          lineHeight: lineHeight,
          letterSpacing: letterSpacing,
          theme: vt,
          textAlignment: textAlignment,
          marginPreset: marginPreset,
          scrollable: scrollable,
        ),
      ),
    );
  }
}

class _ReaderSettings extends StatefulWidget {
  const _ReaderSettings({
    required this.fontSize,
    this.fontFamily,
    required this.lineHeight,
    required this.letterSpacing,
    required this.keepScreenAwake,
    required this.brightness,
    required this.theme,
    required this.readingMode,
    required this.textAlignment,
    required this.marginPreset,
    required this.onFontSizeChanged,
    required this.onFontFamilyChanged,
    required this.onLineHeightChanged,
    required this.onLetterSpacingChanged,
    required this.onKeepScreenAwakeChanged,
    required this.onBrightnessChanged,
    required this.onThemeChanged,
    required this.onReadingModeChanged,
    required this.onTextAlignmentChanged,
    required this.onMarginPresetChanged,
  });

  final double fontSize;
  final String? fontFamily;
  final double lineHeight;
  final double letterSpacing;
  final bool keepScreenAwake;
  final double brightness;
  final ReadingViewTheme theme;
  final ReadingMode readingMode;
  final TextAlignment textAlignment;
  final MarginPreset marginPreset;
  final void Function(double) onFontSizeChanged;
  final void Function(String?) onFontFamilyChanged;
  final void Function(double) onLineHeightChanged;
  final void Function(double) onLetterSpacingChanged;
  final void Function(bool) onKeepScreenAwakeChanged;
  final void Function(double) onBrightnessChanged;
  final void Function(ReadingViewTheme) onThemeChanged;
  final void Function(ReadingMode) onReadingModeChanged;
  final void Function(TextAlignment) onTextAlignmentChanged;
  final void Function(MarginPreset) onMarginPresetChanged;

  @override
  State<_ReaderSettings> createState() => _ReaderSettingsState();
}

class _ReaderSettingsState extends State<_ReaderSettings>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late double _fontSize;
  late String? _fontFamily;
  late double _lineHeight;
  late double _letterSpacing;
  late ReadingViewTheme _theme;
  late ReadingMode _readingMode;
  late TextAlignment _textAlignment;
  late MarginPreset _marginPreset;
  late bool _keepScreenAwake;
  late double _brightness;

  static const _fontOptions = <String?>[
    null,
    'Merriweather',
    'Lora',
    'Inter',
    'Noto Serif',
    'Playfair Display',
    'Roboto Slab',
    'Open Sans',
    'EB Garamond',
    'JetBrains Mono',
  ];
  static const _fontLabels = [
    'System',
    'Merriweather',
    'Lora',
    'Inter',
    'Noto Serif',
    'Playfair',
    'Roboto Slab',
    'Open Sans',
    'Garamond',
    'JetBrains',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fontSize = widget.fontSize;
    _fontFamily = widget.fontFamily;
    _lineHeight = widget.lineHeight;
    _letterSpacing = widget.letterSpacing;
    _theme = widget.theme;
    _readingMode = widget.readingMode;
    _textAlignment = widget.textAlignment;
    _marginPreset = widget.marginPreset;
    _keepScreenAwake = widget.keepScreenAwake;
    _brightness = widget.brightness;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Reading Settings',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TabBar(
            controller: _tabController,
            labelColor: colors.primary,
            unselectedLabelColor: colors.onSurface.withValues(alpha: 0.6),
            indicatorColor: colors.primary,
            tabs: const [
              Tab(icon: Icon(Icons.palette, size: 20), text: 'Theme'),
              Tab(icon: Icon(Icons.text_fields, size: 20), text: 'Text'),
              Tab(icon: Icon(Icons.view_quilt, size: 20), text: 'Layout'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 320,
            child: TabBarView(
              controller: _tabController,
              children: [
                _ThemeTab(
                  theme: _theme,
                  marginPreset: _marginPreset,
                  onThemeChanged: (t) {
                    setState(() => _theme = t);
                    widget.onThemeChanged(t);
                  },
                  onMarginPresetChanged: (p) {
                    setState(() => _marginPreset = p);
                    widget.onMarginPresetChanged(p);
                  },
                ),
                _TextTab(
                  fontSize: _fontSize,
                  fontFamily: _fontFamily,
                  textAlignment: _textAlignment,
                  lineHeight: _lineHeight,
                  letterSpacing: _letterSpacing,
                  onFontSizeChanged: (v) {
                    setState(() => _fontSize = v);
                    widget.onFontSizeChanged(v);
                  },
                  onFontFamilyChanged: (v) {
                    setState(() => _fontFamily = v);
                    widget.onFontFamilyChanged(v);
                  },
                  onTextAlignmentChanged: (v) {
                    setState(() => _textAlignment = v);
                    widget.onTextAlignmentChanged(v);
                  },
                  onLineHeightChanged: (v) {
                    setState(() => _lineHeight = v);
                    widget.onLineHeightChanged(v);
                  },
                  onLetterSpacingChanged: (v) {
                    setState(() => _letterSpacing = v);
                    widget.onLetterSpacingChanged(v);
                  },
                ),
                _LayoutTab(
                  readingMode: _readingMode,
                  keepScreenAwake: _keepScreenAwake,
                  brightness: _brightness,
                  onReadingModeChanged: (m) {
                    setState(() => _readingMode = m);
                    widget.onReadingModeChanged(m);
                  },
                  onKeepScreenAwakeChanged: (v) {
                    setState(() => _keepScreenAwake = v);
                    widget.onKeepScreenAwakeChanged(v);
                  },
                  onBrightnessChanged: (v) {
                    setState(() => _brightness = v);
                    widget.onBrightnessChanged(v);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeTab extends StatelessWidget {
  const _ThemeTab({
    required this.theme,
    required this.marginPreset,
    required this.onThemeChanged,
    required this.onMarginPresetChanged,
  });

  final ReadingViewTheme theme;
  final MarginPreset marginPreset;
  final ValueChanged<ReadingViewTheme> onThemeChanged;
  final ValueChanged<MarginPreset> onMarginPresetChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Color Theme', style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 100,
            child: GridView.count(
              crossAxisCount: 9,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.8,
              children: ReadingViewTheme.values.map((t) => _ThemeTile(
                    selectedTheme: t,
                    isSelected: theme == t,
                    onTap: () => onThemeChanged(t),
                  )).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Margins', style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            children: MarginPreset.values.map((p) {
              final isSelected = marginPreset == p;
              return ChoiceChip(
                label: Text(p.label),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  onMarginPresetChanged(p);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TextTab extends StatelessWidget {
  const _TextTab({
    required this.fontSize,
    required this.fontFamily,
    required this.textAlignment,
    required this.lineHeight,
    required this.letterSpacing,
    required this.onFontSizeChanged,
    required this.onFontFamilyChanged,
    required this.onTextAlignmentChanged,
    required this.onLineHeightChanged,
    required this.onLetterSpacingChanged,
  });

  final double fontSize;
  final String? fontFamily;
  final TextAlignment textAlignment;
  final double lineHeight;
  final double letterSpacing;
  final void Function(double) onFontSizeChanged;
  final void Function(String?) onFontFamilyChanged;
  final void Function(TextAlignment) onTextAlignmentChanged;
  final void Function(double) onLineHeightChanged;
  final void Function(double) onLetterSpacingChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Font Size', style: textTheme.labelLarge),
          Row(
            children: [
              const Icon(Icons.text_fields, size: 16),
              Expanded(
                child: Slider(
                  value: fontSize,
                  min: 12,
                  max: 32,
                  divisions: 10,
                  label: '${fontSize.round()}',
                  onChanged: onFontSizeChanged,
                ),
              ),
              SizedBox(
                width: 32,
                child: Text('${fontSize.round()}',
                    style: textTheme.bodySmall),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Letter Spacing', style: textTheme.labelLarge),
          Row(
            children: [
              const Text('0'),
              Expanded(
                child: Slider(
                  value: letterSpacing,
                  min: 0.0,
                  max: 5.0,
                  divisions: 10,
                  label: letterSpacing.toStringAsFixed(1),
                  onChanged: onLetterSpacingChanged,
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(letterSpacing.toStringAsFixed(1),
                    style: textTheme.bodySmall),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Font Family', style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: List.generate(_ReaderSettingsState._fontOptions.length, (i) {
              final isSelected =
                  fontFamily == _ReaderSettingsState._fontOptions[i];
              return ChoiceChip(
                label: Text(
                  _ReaderSettingsState._fontLabels[i],
                  style: TextStyle(
                    fontFamily: _ReaderSettingsState._fontOptions[i],
                  ),
                ),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  onFontFamilyChanged(
                      _ReaderSettingsState._fontOptions[i]);
                },
              );
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Line Height', style: textTheme.labelLarge),
          Row(
            children: [
              const Text('1.2'),
              Expanded(
                child: Slider(
                  value: lineHeight,
                  min: 1.2,
                  max: 3.0,
                  divisions: 9,
                  label: lineHeight.toStringAsFixed(1),
                  onChanged: onLineHeightChanged,
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(lineHeight.toStringAsFixed(1),
                    style: textTheme.bodySmall),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Text Alignment', style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            children: TextAlignment.values.map((a) {
              final isSelected = textAlignment == a;
              return ChoiceChip(
                label: Text(a.label),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  onTextAlignmentChanged(a);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _LayoutTab extends StatelessWidget {
  const _LayoutTab({
    required this.readingMode,
    required this.keepScreenAwake,
    required this.brightness,
    required this.onReadingModeChanged,
    required this.onKeepScreenAwakeChanged,
    required this.onBrightnessChanged,
  });

  final ReadingMode readingMode;
  final bool keepScreenAwake;
  final double brightness;
  final ValueChanged<ReadingMode> onReadingModeChanged;
  final ValueChanged<bool> onKeepScreenAwakeChanged;
  final ValueChanged<double> onBrightnessChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reading Mode', style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            children: ReadingMode.values.map((m) {
              final isSelected = readingMode == m;
              return ChoiceChip(
                label: Text(m.label),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  onReadingModeChanged(m);
                },
              );
            }).toList(),
          ),
          if (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS) ...[
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Keep Screen Awake', style: textTheme.labelLarge),
              subtitle: Text('Prevent device from sleeping while reading',
                  style: textTheme.bodySmall),
              value: keepScreenAwake,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onKeepScreenAwakeChanged(v);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Brightness', style: textTheme.labelLarge),
            Row(
              children: [
                const Icon(Icons.brightness_low, size: 16),
                Expanded(
                  child: Slider(
                    value: brightness,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    label: brightness.toStringAsFixed(2),
                    onChanged: onBrightnessChanged,
                  ),
                ),
                const Icon(Icons.brightness_high, size: 16),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReaderBottomNav extends StatelessWidget {
  const _ReaderBottomNav({
    required this.onSettingsTap,
    required this.onChapterIndexTap,
    required this.onBookmarkTap,
    this.isBookmarked = false,
    this.currentChapterTitle,
    this.currentChapterNumber,
    this.totalChapters,
  });

  final VoidCallback onSettingsTap;
  final VoidCallback onChapterIndexTap;
  final VoidCallback onBookmarkTap;
  final bool isBookmarked;
  final String? currentChapterTitle;
  final int? currentChapterNumber;
  final int? totalChapters;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.onSurface.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              _NavIconButton(
                icon: Icons.text_fields,
                label: 'Settings',
                onTap: onSettingsTap,
                color: colors.onSurface,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: onChapterIndexTap,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (currentChapterTitle != null)
                        Text(
                          currentChapterTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      if (currentChapterNumber != null &&
                          totalChapters != null)
                        Text(
                          '${currentChapterNumber! + 1} / $totalChapters',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _NavIconButton(
                icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                label: 'Bookmark',
                onTap: onBookmarkTap,
                color: isBookmarked ? colors.primary : colors.onSurface,
              ),
              _NavIconButton(
                icon: Icons.headphones,
                label: 'Listen',
                onTap: () {
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Listen coming soon'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                color: colors.onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.selectedTheme,
    required this.isSelected,
    required this.onTap,
  });

  final ReadingViewTheme selectedTheme;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = selectedTheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: t.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? t.accent
                : t.text.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(t.icon, color: t.text, size: 18),
            const SizedBox(height: 2),
            Text(
              t.label,
              style: TextStyle(
                fontSize: 10,
                color: t.text,
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
