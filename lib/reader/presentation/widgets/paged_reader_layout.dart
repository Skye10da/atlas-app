import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_styles.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/pager.dart';
import 'package:atlas_app/reader/presentation/widgets/word_lookup_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bottom_nav.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';

class PagedReaderLayout extends ConsumerStatefulWidget {
  const PagedReaderLayout({
    super.key,
    required this.chapters,
    required this.settings,
    required this.currentChapterIndex,
    this.initialProgress,
    required this.onPageChanged,
    required this.onProgressChanged,
    required this.onChapterSelected,
    required this.onSettingsTap,
    required this.isBookmarked,
    required this.onBookmarkToggle,
  });

  final List<ChapterEntity> chapters;
  final ReadingSettingsEntity settings;
  final int currentChapterIndex;
  final double? initialProgress;
  final void Function(int chapterIndex) onPageChanged;
  final void Function(double progress) onProgressChanged;
  final void Function(int chapterIndex) onChapterSelected;
  final VoidCallback onSettingsTap;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;

  @override
  ConsumerState<PagedReaderLayout> createState() => _PagedReaderLayoutState();
}

class _PagedReaderLayoutState extends ConsumerState<PagedReaderLayout> {
  final _pageController = PageController();
  final Map<int, List<String>> _pageCache = {};
  final Map<int, String> _contentCache = {};
  int _totalPages = 0;
  int _currentGlobalPage = 0;
  String _cacheKey = '';
  bool _chromeVisible = true;
  bool _pendingChapterJump = true;
  Timer? _chromeTimer;
  double _layoutWidth = 0;
  double _layoutHeight = 0;
  static const double _maxReadingWidth = 720.0;

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
    return '${s.fontSize}_${s.fontFamily}_${s.lineHeight}_${s.marginPreset.name}_${s.textAlignment.name}_$_layoutWidth.$_layoutHeight';
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
    final rawWidth = _layoutWidth > 0
        ? _layoutWidth
        : MediaQuery.of(context).size.width;
    final rawHeight = _layoutHeight > 0
        ? _layoutHeight
        : MediaQuery.of(context).size.height;
    final width = rawWidth > _maxReadingWidth ? _maxReadingWidth : rawWidth;
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
          return Focus(
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
              widget.onProgressChanged(
                  _totalPages > 0 ? globalPage / _totalPages : 0.0);
              _resetChromeTimer();
            },
            itemCount: _totalPages,
            itemBuilder: (context, globalPage) {
              final (chIdx, pageInChapter) = _globalToLocal(globalPage);
              final pages = _pageCache[chIdx]!;
              final content = pages[pageInChapter];
              final isFirstOfChapter = pageInChapter == 0;
              final isLastOfChapter = pageInChapter == pages.length - 1;

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
              );
              return _wrapWithPageAnimation(pageWidget, globalPage);
            },
          ),
          ),
          );
        },
      ));
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
    this.chapterStyle,
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
    // ignore: prefer_function_declarations_over_variables
    final EditableTextContextMenuBuilder contextMenu = (ctx, editable) =>
        _textContextMenu(ctx, editable, c);

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

  Widget _textContextMenu(
      BuildContext ctx, EditableTextState editable, String fullText) {
    final sel = editable.textEditingValue.selection;
    final buttonItems = <ContextMenuButtonItem>[
      ContextMenuButtonItem(
        label: 'Copy',
        onPressed: () {
          final data = editable.textEditingValue.selection.textInside(
            editable.textEditingValue.text,
          );
          Clipboard.setData(ClipboardData(text: data));
        },
      ),
      ContextMenuButtonItem(
        label: 'Select all',
        onPressed: () => editable.selectAll(SelectionChangedCause.toolbar),
      ),
    ];

    if (sel.isValid && !sel.isCollapsed) {
      final word = fullText.substring(sel.start, sel.end).trim();
      if (word.isNotEmpty) {
        buttonItems.insert(
          0,
          ContextMenuButtonItem(
            label: 'Define "$word"',
            onPressed: () => _showPagedDefine(ctx, word),
          ),
        );
      }
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editable.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  void _showPagedDefine(BuildContext ctx, String word) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (c) => WordLookupSheet(word: word),
    );
  }
}
