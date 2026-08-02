import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/controllers/reader_chrome_controller.dart';
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
import 'package:atlas_app/reader/presentation/widgets/reader_progress_bar.dart';
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
  final Set<String> bookmarkedChapterIds;
  final double? initialScrollProgress;
  final void Function(double) onScrollProgress;
  final void Function(int) onCurrentChapterChanged;
  final void Function(ScrollDirection) onScrollDirectionChanged;
  final VoidCallback onSettingsTap;
  final void Function(int) onChapterSelected;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;

  @override
  ConsumerState<ContinuousReaderLayout> createState() =>
      _ContinuousReaderLayoutState();
}

class _ContinuousReaderLayoutState
    extends ConsumerState<ContinuousReaderLayout> with ReaderChromeController {
  static const _snapScrollDuration = Duration(milliseconds: 300);

  final _scrollController = ScrollController();
  final List<GlobalKey> _chapterKeys = [];
  double _lastScrollPos = 0;
  double _scrollOffset = 0;
  Timer? _autoScrollTimer;
  double _autoScrollSpeed = 2.0;
  bool _autoScrollActive = false;
  ScrollAnimation _animation = ScrollAnimation.smooth;
  bool _jumpInFlight = false;
  int _lastReportedChapterIndex = 0;

  void _initChapterKeys() {
    _chapterKeys
      ..clear()
      ..addAll(List.generate(widget.chapters.length, (_) => GlobalKey()));
  }

  @override
  void initState() {
    super.initState();
    _animation = widget.settings.scrollAnimation;
    _initChapterKeys();
    _lastReportedChapterIndex = widget.currentChapterIndex;
    _scrollController.addListener(_onScroll);
    initReaderChrome(isDarkTheme: widget.settings.theme.isDark);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialScrollProgress != null) {
        _restoreScrollProgress(widget.initialScrollProgress!);
      } else {
        _scrollToChapter(widget.currentChapterIndex);
      }
    });
  }

  @override
  void didUpdateWidget(ContinuousReaderLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings.scrollAnimation != oldWidget.settings.scrollAnimation) {
      setState(() => _animation = widget.settings.scrollAnimation);
    }
    if (widget.chapters.length != oldWidget.chapters.length) {
      _initChapterKeys();
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
          toggleChrome(isDarkTheme: widget.settings.theme.isDark),
      onOpenPalette: () => setState(() => commandPaletteVisible = true),
    );
    if (common != KeyEventResult.ignored) return common;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (!_scrollController.hasClients) return KeyEventResult.handled;
      resetChromeTimer(isDarkTheme: widget.settings.theme.isDark);
      final offset =
          _scrollController.offset - MediaQuery.of(context).size.height * 0.4;
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (!_scrollController.hasClients) return KeyEventResult.handled;
      resetChromeTimer(isDarkTheme: widget.settings.theme.isDark);
      final offset =
          _scrollController.offset + MediaQuery.of(context).size.height * 0.4;
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      if (!_scrollController.hasClients) return KeyEventResult.handled;
      resetChromeTimer(isDarkTheme: widget.settings.theme.isDark);
      final offset =
          _scrollController.offset - MediaQuery.of(context).size.height * 0.85;
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      if (!_scrollController.hasClients) return KeyEventResult.handled;
      resetChromeTimer(isDarkTheme: widget.settings.theme.isDark);
      final offset =
          _scrollController.offset + MediaQuery.of(context).size.height * 0.85;
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _scrollToChapter(int index, {int retries = 3}) {
    if (!_scrollController.hasClients) {
      if (retries > 0) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToChapter(index, retries: retries - 1),
        );
      }
      return;
    }
    if (index < 0 || index >= widget.chapters.length) return;
    final total = _scrollController.position.maxScrollExtent;
    if (total <= 0) {
      if (retries > 0) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToChapter(index, retries: retries - 1),
        );
      }
      return;
    }

    _jumpInFlight = true;

    // Prefer the chapter's real position when it has been laid out, so
    // jumps land exactly at the chapter start regardless of how much
    // content the earlier chapters hold.
    final exact = _chapterRevealOffset(index);
    if (exact != null) {
      _jumpAndSync(exact);
      _finishJump();
      return;
    }

    // Chapter is far away and not built yet: jump to a proportional
    // estimate, then refine once the list realizes the target block.
    final estimate = (index / widget.chapters.length) * total;
    _jumpAndSync(estimate);
    _refineChapterJump(index, attempts: 8);
  }

  /// Ends a programmatic jump: re-enables chapter reporting and syncs the
  /// settled chapter once the frame after the jump has laid out the blocks.
  void _finishJump() {
    _jumpInFlight = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _syncCurrentChapter();
      }
    });
  }

  /// Returns the scroll offset that would align [index]'s chapter block with
  /// the top of the viewport, or `null` if the block isn't laid out yet.
  double? _chapterRevealOffset(int index) {
    final ctx = _chapterKeys[index].currentContext;
    if (ctx == null) return null;
    final blockBox = ctx.findRenderObject();
    final viewportBox = _scrollController.hasClients
        ? _scrollController.position.context.storageContext.findRenderObject()
        : null;
    if (blockBox is! RenderBox || viewportBox is! RenderBox) return null;
    final blockTop = blockBox.localToGlobal(Offset.zero).dy;
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    return _scrollController.position.pixels + (blockTop - viewportTop);
  }

  void _refineChapterJump(int index, {required int attempts}) {
    if (attempts <= 0) {
      _finishJump();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        _finishJump();
        return;
      }
      final exact = _chapterRevealOffset(index);
      if (exact == null) {
        // The target chapter's block still hasn't been built by the
        // sliver, which means our last jump landed too far away for it
        // to come into range. Re-estimate against the *current*
        // maxScrollExtent (which gets more accurate as more chapters are
        // laid out) and jump again, instead of re-polling a guess that
        // will never resolve on its own.
        final total = _scrollController.position.maxScrollExtent;
        if (total > 0) {
          final reestimate = (index / widget.chapters.length) * total;
          _jumpAndSync(reestimate);
        }
        _refineChapterJump(index, attempts: attempts - 1);
        return;
      }
      _jumpAndSync(exact);
      _finishJump();
    });
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
    setFullscreen(true, isDarkTheme: widget.settings.theme.isDark);
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent) {
        _stopAutoScroll();
        return;
      }
      _scrollController.jumpTo(
        (pos.pixels + _autoScrollSpeed).clamp(0.0, pos.maxScrollExtent),
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

  void _restoreScrollProgress(double progress, {int retries = 3}) {
    if (!_scrollController.hasClients) {
      if (retries > 0) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _restoreScrollProgress(progress, retries: retries - 1),
        );
      }
      return;
    }
    final total = _scrollController.position.maxScrollExtent;
    if (total <= 0) {
      if (retries > 0) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _restoreScrollProgress(progress, retries: retries - 1),
        );
      }
      return;
    }
    _jumpInFlight = true;
    _jumpAndSync(progress * total);
    _finishJump();
  }

  /// Finds the chapter whose block currently sits at the top of the
  /// viewport by measuring the real layout offsets of the blocks that have
  /// been built — not by assuming every chapter has the same height.
  int _currentChapterAtOffset(double scrollOffset) {
    int current = 0;
    for (int i = 0; i < _chapterKeys.length; i++) {
      final reveal = _chapterRevealOffset(i);
      if (reveal != null && reveal <= scrollOffset + 1) {
        current = i;
      }
    }
    return current;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    resetChromeTimer(isDarkTheme: widget.settings.theme.isDark);
    final pos = _scrollController.position;
    _scrollOffset = pos.pixels;
    final progress = pos.maxScrollExtent > 0
        ? pos.pixels / pos.maxScrollExtent
        : 0.0;
    widget.onScrollProgress(progress);

    // Only report the current chapter once blocks are laid out — during a
    // programmatic jump the viewport has no measured blocks yet, and a
    // fallback of 0 would clobber the restored chapter in the parent.
    // While a jump is in flight we also suppress reporting entirely so the
    // provisional (wrong) index never propagates up and triggers a
    // `didUpdateWidget` re-jump in the opposite direction.
    if (_jumpInFlight) {
      _lastScrollPos = pos.pixels;
      return;
    }
    final hasMeasuredBlocks = _chapterKeys.any((k) => k.currentContext != null);
    if (hasMeasuredBlocks) {
      final current = _currentChapterAtOffset(pos.pixels);
      _lastReportedChapterIndex = current;
      widget.onCurrentChapterChanged(current);
    }

    final delta = pos.pixels - _lastScrollPos;
    if (delta.abs() > 4) {
      final direction = delta > 0 ? ScrollDirection.down : ScrollDirection.up;
      widget.onScrollDirectionChanged(direction);
      setState(() {
        if (direction == ScrollDirection.up) {
          chromeVisible = true;
          setFullscreen(false, isDarkTheme: widget.settings.theme.isDark);
        }
      });
    }
    _lastScrollPos = pos.pixels;
  }

  void _jumpAndSync(double target) {
    final total = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(target.clamp(0.0, total));
    _syncCurrentChapter();
  }

  /// Reports the chapter actually at the top of the viewport once its block
  /// has been laid out, so programmatic jumps/restores don't leave the
  /// parent's chapter state stale (or wrong).
  void _syncCurrentChapter({int attempts = 3}) {
    if (!mounted || !_scrollController.hasClients) return;
    if (_jumpInFlight) return;
    final hasMeasuredBlocks = _chapterKeys.any((k) => k.currentContext != null);
    if (!hasMeasuredBlocks) {
      if (attempts > 0) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _syncCurrentChapter(attempts: attempts - 1),
        );
      }
      return;
    }
    final current = _currentChapterAtOffset(_scrollController.position.pixels);
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
    if (!_scrollController.hasClients) return false;
    final page =
        (_scrollController.offset /
                _scrollController.position.viewportDimension)
            .round();
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
    final offset =
        math.sin((index * math.pi * 0.3) + (_scrollOffset * 0.003)) * 6;
    return Transform.translate(offset: Offset(0, offset), child: header);
  }

  Widget _buildChapterBlock(
    ChapterEntity chapter,
    int index, {
    bool showHeaders = true,
  }) {
    final vt = widget.settings.theme;
    final cs = ChapterStyle.forChapter(index);

    return Column(
      key: _chapterKeys[index],
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
          lineHeight: widget.settings.lineHeight,
          letterSpacing: widget.settings.letterSpacing,
          vt: vt,
          textAlignment: widget.settings.textAlignment,
          marginPreset: widget.settings.marginPreset,
          scrollable: false,
          chapterStyle: cs,
        ),
        if (showHeaders)
          ChapterOrnamentalDivider(
            accentColor: cs.accentColor,
            verticalPadding: 24,
          ),
        if (showHeaders)
          ChapterEndFooter(
            chapterNumber: index + 1,
            textColor: vt.text,
            baseFontSize: widget.settings.fontSize,
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
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: chromeVisible
          ? ReaderBarSurface(
              style: widget.settings.chromeStyle,
              color: vt.surface,
              child: ReaderChromeBar(
                title: chapters[index].title,
                textColor: vt.text,
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
                if (rightPanelVisible) {
                  hideRightPanel();
                  return KeyEventResult.handled;
                }
              }
              return _handleKeyEvent(node, event);
            },
            child: GestureDetector(
              onTap: () {
                if (rightPanelVisible) {
                  hideRightPanel();
                }
                toggleChrome(isDarkTheme: widget.settings.theme.isDark);
              },
              child: _wrapWithAnimation(
                ListView.builder(
                  controller: _scrollController,
                  physics: _scrollPhysics,
                  itemCount: chapters.length,
                  itemBuilder: (context, index) => _buildChapterBlock(
                    chapters[index],
                    index,
                    showHeaders: true,
                  ),
                ),
              ),
            ),
          ),
          if (!isDesktop && (chromeVisible || _autoScrollActive))
            Positioned(
              top: chromeVisible ? MediaQuery.of(context).padding.top : 0,
              left: 0,
              right: 0,
              child: ReaderProgressBar(
                progress:
                    _scrollController.hasClients &&
                        _scrollController.position.maxScrollExtent > 0
                    ? _scrollController.offset /
                          _scrollController.position.maxScrollExtent
                    : 0.0,
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
                  accent: widget.settings.theme.accent,
                ),
              ),
            ),
          if (isDesktop)
            DesktopRightPanelRegion(
              visible: rightPanelVisible,
              chromeVisible: chromeVisible,
              panelWidth: ReaderChromeController.rightPanelWidth,
              onHoverReveal: showRightPanelOnHover,
              panel: ReaderRightPanel(
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
        ],
      ),
      bottomNavigationBar: chromeVisible
          ? ReaderBarSurface(
              style: widget.settings.chromeStyle,
              color: vt.surface,
              child: ReaderBottomNav(
                onSettingsTap: widget.onSettingsTap,
                onChapterIndexTap: () => _showChapterIndex(context),
                onBookmarkTap: widget.onBookmarkToggle,
                isBookmarked: widget.isBookmarked,
                currentChapterTitle: chapters[index].title,
                currentChapterNumber: index,
                totalChapters: chapters.length,
                autoScrollActive: _autoScrollActive,
                onAutoScrollToggle: _toggleAutoScroll,
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
