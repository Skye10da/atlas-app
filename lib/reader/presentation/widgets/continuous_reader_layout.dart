import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_content_loader.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_styles.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bottom_nav.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';

class ContinuousReaderLayout extends StatefulWidget {
  const ContinuousReaderLayout({
    super.key,
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
  State<ContinuousReaderLayout> createState() =>
      _ContinuousReaderLayoutState();
}

class _ContinuousReaderLayoutState extends State<ContinuousReaderLayout> {
  static const _snapScrollDuration = Duration(milliseconds: 300);

  final _scrollController = ScrollController();
  double _lastScrollPos = 0;
  double _scrollOffset = 0;
  bool _chromeVisible = true;
  Timer? _chromeTimer;
  ScrollAnimation _animation = ScrollAnimation.smooth;

  @override
  void initState() {
    super.initState();
    _animation = widget.settings.scrollAnimation;
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
  void didUpdateWidget(ContinuousReaderLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings.scrollAnimation != oldWidget.settings.scrollAnimation) {
      setState(() => _animation = widget.settings.scrollAnimation);
    }
    final diff = (widget.currentChapterIndex - oldWidget.currentChapterIndex).abs();
    if (diff > 1) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToChapter(widget.currentChapterIndex));
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

  void _scrollToChapter(int index, {int retries = 3}) {
    if (!_scrollController.hasClients) {
      if (retries > 0) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToChapter(index, retries: retries - 1));
      }
      return;
    }
    if (index < 0 || index >= widget.chapters.length) return;
    final total = _scrollController.position.maxScrollExtent;
    if (total <= 0) {
      if (retries > 0) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToChapter(index, retries: retries - 1));
      }
      return;
    }
    final target = (index / widget.chapters.length) * total;
    _scrollController.jumpTo(target.clamp(0.0, total));
  }

  void _restoreScrollProgress(double progress, {int retries = 3}) {
    if (!_scrollController.hasClients) {
      if (retries > 0) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _restoreScrollProgress(progress, retries: retries - 1));
      }
      return;
    }
    final total = _scrollController.position.maxScrollExtent;
    if (total <= 0) {
      if (retries > 0) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _restoreScrollProgress(progress, retries: retries - 1));
      }
      return;
    }
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
    _scrollOffset = pos.pixels;
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

  bool _onScrollEnd(ScrollEndNotification notification) {
    if (_animation != ScrollAnimation.snap) return false;
    if (notification.dragDetails == null) return false;
    if (!_scrollController.hasClients) return false;
    final page = (_scrollController.offset /
        _scrollController.position.viewportDimension).round();
    final target = page * _scrollController.position.viewportDimension;
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: _snapScrollDuration,
      curve: Curves.easeOut,
    );
    return true;
  }

  Widget _wrapWithAnimation(Widget listView) {
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
            colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
            stops: [0, 0.06, 0.94, 1],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: listView,
        ),
      ScrollAnimation.parallax => listView,
      ScrollAnimation.glow => Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          thickness: 8,
          radius: const Radius.circular(4),
          child: Theme(
            data: ThemeData(
              scrollbarTheme: ScrollbarThemeData(
                thumbColor: WidgetStateProperty.all(
                  widget.settings.theme.accent.withValues(alpha: 0.8),
                ),
                radius: const Radius.circular(4),
                thickness: WidgetStateProperty.all(8),
                trackVisibility: WidgetStateProperty.all(true),
                trackColor: WidgetStateProperty.all(
                  widget.settings.theme.accent.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: listView,
          ),
        ),
    };
  }

  Widget _wrapHeaderWithParallax(Widget header, int index) {
    if (_animation != ScrollAnimation.parallax) return header;
    final offset = math.sin((index * math.pi * 0.3) + (_scrollOffset * 0.003)) * 6;
    return Transform.translate(
      offset: Offset(0, offset),
      child: header,
    );
  }

  Widget _buildChapterBlock(ChapterEntity chapter, int index, {bool showHeaders = true}) {
    final vt = widget.settings.theme;
    final cs = ChapterStyle.forChapter(index);
    final textStyle = TextStyle(
      fontSize: widget.settings.fontSize,
      height: widget.settings.lineHeight,
      letterSpacing: widget.settings.letterSpacing,
      color: vt.text,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeaders) ...[
          _wrapHeaderWithParallax(_buildChapterHeader(chapter, index, cs), index),
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
        ],
        ChapterContentLoader(
          chapter: chapter,
          fontSize: widget.settings.fontSize,
          fontFamily: widget.settings.fontFamily,
          lineHeight: widget.settings.lineHeight,
          letterSpacing: widget.settings.letterSpacing,
          vt: vt,
          textAlignment: widget.settings.textAlignment,
          marginPreset: widget.settings.marginPreset,
          scrollable: false,
          chapterStyle: cs,
        ),
        if (showHeaders)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
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

  Widget _buildChapterHeader(ChapterEntity chapter, int index, ChapterStyle cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.bannerBackground.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: cs.accentColor.withValues(alpha: 0.2)),
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
                '${index + 1}',
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
            child: Text(chapter.title, style: cs.titleStyle),
          ),
        ],
      ),
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
        child: _wrapWithAnimation(
          ListView.builder(
            controller: _scrollController,
            itemCount: chapters.length,
            itemBuilder: (context, index) => _buildChapterBlock(chapters[index], index, showHeaders: _chromeVisible),
          ),
        ),
      ),
      ),
      bottomNavigationBar: _chromeVisible
          ? ReaderBottomNav(
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
