import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/word_lookup_sheet.dart';

enum ReadingViewTheme {
  light,
  dark,
  sepia,
  forest,
  ocean,
  dracula,
  amoled,
  cream,
  gray,
}

extension ReadingViewThemeX on ReadingViewTheme {
  Color get background => switch (this) {
    ReadingViewTheme.light => const Color(0xFFFFFBFE),
    ReadingViewTheme.dark => const Color(0xFF1A1A1A),
    ReadingViewTheme.sepia => const Color(0xFFF5F0E8),
    ReadingViewTheme.forest => const Color(0xFFE8F0E8),
    ReadingViewTheme.ocean => const Color(0xFFE8F0F5),
    ReadingViewTheme.dracula => const Color(0xFF282A36),
    ReadingViewTheme.amoled => const Color(0xFF000000),
    ReadingViewTheme.cream => const Color(0xFFFFF9E3),
    ReadingViewTheme.gray => const Color(0xFF2C2C2C),
  };

  Color get text => switch (this) {
    ReadingViewTheme.light => const Color(0xFF1C1B1F),
    ReadingViewTheme.dark => const Color(0xFFE3E3E3),
    ReadingViewTheme.sepia => const Color(0xFF3B2F2F),
    ReadingViewTheme.forest => const Color(0xFF2D3D2D),
    ReadingViewTheme.ocean => const Color(0xFF1C3D5E),
    ReadingViewTheme.dracula => const Color(0xFFF8F8F2),
    ReadingViewTheme.amoled => const Color(0xFFFFFFFF),
    ReadingViewTheme.cream => const Color(0xFF3E2723),
    ReadingViewTheme.gray => const Color(0xFFBDBDBD),
  };

  Color get surface => switch (this) {
    ReadingViewTheme.light => const Color(0xFFF0F0F0),
    ReadingViewTheme.dark => const Color(0xFF2A2A2A),
    ReadingViewTheme.sepia => const Color(0xFFE8E0D0),
    ReadingViewTheme.forest => const Color(0xFFD8E8D8),
    ReadingViewTheme.ocean => const Color(0xFFD0E0F0),
    ReadingViewTheme.dracula => const Color(0xFF44475A),
    ReadingViewTheme.amoled => const Color(0xFF1A1A1A),
    ReadingViewTheme.cream => const Color(0xFFF5EDD0),
    ReadingViewTheme.gray => const Color(0xFF3A3A3A),
  };

  Color get accent => switch (this) {
    ReadingViewTheme.light => const Color(0xFF1A73E8),
    ReadingViewTheme.dark => const Color(0xFF8AB4F8),
    ReadingViewTheme.sepia => const Color(0xFF8B6B4A),
    ReadingViewTheme.forest => const Color(0xFF4A7C4A),
    ReadingViewTheme.ocean => const Color(0xFF2D7DBF),
    ReadingViewTheme.dracula => const Color(0xFFBD93F9),
    ReadingViewTheme.amoled => const Color(0xFFBB86FC),
    ReadingViewTheme.cream => const Color(0xFF795548),
    ReadingViewTheme.gray => const Color(0xFF90A4AE),
  };

  String get label => switch (this) {
    ReadingViewTheme.light => 'Light',
    ReadingViewTheme.dark => 'Dark',
    ReadingViewTheme.sepia => 'Sepia',
    ReadingViewTheme.forest => 'Forest',
    ReadingViewTheme.ocean => 'Ocean',
    ReadingViewTheme.dracula => 'Dracula',
    ReadingViewTheme.amoled => 'AMOLED',
    ReadingViewTheme.cream => 'Cream',
    ReadingViewTheme.gray => 'Gray',
  };

  bool get isDark =>
      this == ReadingViewTheme.dark || this == ReadingViewTheme.dracula || this == ReadingViewTheme.amoled || this == ReadingViewTheme.gray;

  IconData get icon => switch (this) {
    ReadingViewTheme.light => Icons.light_mode,
    ReadingViewTheme.dark => Icons.dark_mode,
    ReadingViewTheme.sepia => Icons.wb_sunny,
    ReadingViewTheme.forest => Icons.nature,
    ReadingViewTheme.ocean => Icons.water_drop,
    ReadingViewTheme.dracula => Icons.nightlight_round,
    ReadingViewTheme.amoled => Icons.nightlight_round,
    ReadingViewTheme.cream => Icons.wb_sunny,
    ReadingViewTheme.gray => Icons.blur_on,
  };
}

class ChapterView extends ConsumerStatefulWidget {
  const ChapterView({
    super.key,
    required this.content,
    this.fontSize = 18.0,
    this.fontFamily,
    this.lineHeight = 1.8,
    this.letterSpacing = 0.0,
    this.theme = ReadingViewTheme.light,
    this.textAlignment = TextAlignment.left,
    this.marginPreset = MarginPreset.normal,
    this.scrollable = true,
    this.onScroll,
    this.onScrollDirectionChanged,
    this.dropCapStyle,
  });

  final String content;
  final double fontSize;
  final String? fontFamily;
  final double lineHeight;
  final double letterSpacing;
  final ReadingViewTheme theme;
  final TextAlignment textAlignment;
  final MarginPreset marginPreset;
  final bool scrollable;
  final void Function(double scrollOffset)? onScroll;
  final void Function(ScrollDirection direction)? onScrollDirectionChanged;
  final TextStyle? dropCapStyle;

  @override
  ConsumerState<ChapterView> createState() => _ChapterViewState();
}

class _ChapterViewState extends ConsumerState<ChapterView> {
  final _scrollController = ScrollController();
  double _lastScrollPos = 0;

  EdgeInsets get _padding => switch (widget.marginPreset) {
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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.maxScrollExtent > 0) {
      widget.onScroll?.call(metrics.pixels / metrics.maxScrollExtent);
    }
    if (notification is ScrollUpdateNotification) {
      final delta = metrics.pixels - _lastScrollPos;
      if (delta.abs() > 4) {
        widget.onScrollDirectionChanged?.call(
          delta > 0 ? ScrollDirection.down : ScrollDirection.up,
        );
      }
      _lastScrollPos = metrics.pixels;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: widget.fontSize,
      height: widget.lineHeight,
      letterSpacing: widget.letterSpacing,
      color: widget.theme.text,
    );

    final content = _buildText(baseStyle);
    if (!widget.scrollable) {
      return Padding(padding: _padding, child: content);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _handleScroll(notification);
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: _padding,
        child: content,
      ),
    );
  }

  Widget _buildText(TextStyle baseStyle) {
    final textStyle = widget.fontFamily != null
        ? GoogleFonts.getFont(widget.fontFamily!, textStyle: baseStyle)
        : baseStyle;

    final ds = widget.dropCapStyle;
    final c = widget.content;

    if (ds != null && c.isNotEmpty) {
      return SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(text: c.substring(0, 1), style: ds),
            TextSpan(text: c.substring(1), style: textStyle),
          ],
        ),
        textAlign: widget.textAlignment.flutterTextAlign,
        contextMenuBuilder: (ctx, editable) =>
            _contextMenu(ctx, editable, c),
      );
    }

    return SelectableText(
      c,
      style: textStyle,
      textAlign: widget.textAlignment.flutterTextAlign,
      contextMenuBuilder: (ctx, editable) =>
          _contextMenu(ctx, editable, c),
    );
  }

  Widget _contextMenu(
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
            onPressed: () => _showDefine(word),
          ),
        );
      }
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editable.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  void _showDefine(String word) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => WordLookupSheet(word: word),
    );
  }
}

enum ScrollDirection { up, down }

enum ReadingMode { page, continuous }

enum PageTurnAnimation { slide, fade, reveal, cube, depth }

extension PageTurnAnimationX on PageTurnAnimation {
  String get label => switch (this) {
    PageTurnAnimation.slide => 'Slide',
    PageTurnAnimation.fade => 'Fade',
    PageTurnAnimation.reveal => 'Reveal',
    PageTurnAnimation.cube => 'Cube',
    PageTurnAnimation.depth => 'Depth',
  };

  IconData get icon => switch (this) {
    PageTurnAnimation.slide => Icons.arrow_forward,
    PageTurnAnimation.fade => Icons.blur_on,
    PageTurnAnimation.reveal => Icons.swap_horiz,
    PageTurnAnimation.cube => Icons.view_in_ar,
    PageTurnAnimation.depth => Icons.layers,
  };
}

enum ScrollAnimation { smooth, snap, fadeEdges, parallax, glow }

extension ScrollAnimationX on ScrollAnimation {
  String get label => switch (this) {
    ScrollAnimation.smooth => 'Smooth',
    ScrollAnimation.snap => 'Snap',
    ScrollAnimation.fadeEdges => 'Fade Edges',
    ScrollAnimation.parallax => 'Parallax',
    ScrollAnimation.glow => 'Scroll Glow',
  };

  IconData get icon => switch (this) {
    ScrollAnimation.smooth => Icons.swap_vert,
    ScrollAnimation.snap => Icons.first_page,
    ScrollAnimation.fadeEdges => Icons.blur_linear,
    ScrollAnimation.parallax => Icons.view_carousel,
    ScrollAnimation.glow => Icons.touch_app,
  };
}

extension ReadingModeX on ReadingMode {
  String get label => switch (this) {
    ReadingMode.page => 'Page Mode',
    ReadingMode.continuous => 'Continuous',
  };
}

enum TextAlignment { left, justify, center, right }

extension TextAlignmentX on TextAlignment {
  String get label => switch (this) {
    TextAlignment.left => 'Left',
    TextAlignment.justify => 'Justify',
    TextAlignment.center => 'Center',
    TextAlignment.right => 'Right',
  };

  TextAlign get flutterTextAlign => switch (this) {
    TextAlignment.left => TextAlign.left,
    TextAlignment.justify => TextAlign.justify,
    TextAlignment.center => TextAlign.center,
    TextAlignment.right => TextAlign.right,
  };
}

enum MarginPreset { narrow, normal, wide }

extension MarginPresetX on MarginPreset {
  String get label => switch (this) {
    MarginPreset.narrow => 'Narrow',
    MarginPreset.normal => 'Normal',
    MarginPreset.wide => 'Wide',
  };
}
