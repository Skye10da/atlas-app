import 'package:flutter/material.dart';

enum ReadingViewTheme {
  paper,
  parchment,
  ivory,
  sepia,
  wood,
  book,
  blueLight,
  warmGray,
  mint,
  forest,
  ocean,
  midnight,
  charcoal,
  nord,
  dracula,
  amoled,
}

extension ReadingViewThemeX on ReadingViewTheme {
  String get label => switch (this) {
    ReadingViewTheme.paper => 'Paper',
    ReadingViewTheme.parchment => 'Parchment',
    ReadingViewTheme.ivory => 'Ivory',
    ReadingViewTheme.sepia => 'Sepia',
    ReadingViewTheme.wood => 'Wood',
    ReadingViewTheme.book => 'Book',
    ReadingViewTheme.blueLight => 'Blue Light',
    ReadingViewTheme.warmGray => 'Warm Gray',
    ReadingViewTheme.mint => 'Mint',
    ReadingViewTheme.forest => 'Forest',
    ReadingViewTheme.ocean => 'Ocean',
    ReadingViewTheme.midnight => 'Midnight',
    ReadingViewTheme.charcoal => 'Charcoal',
    ReadingViewTheme.nord => 'Nord',
    ReadingViewTheme.dracula => 'Dracula',
    ReadingViewTheme.amoled => 'AMOLED',
  };

  IconData get icon => switch (this) {
    ReadingViewTheme.paper => Icons.description,
    ReadingViewTheme.parchment => Icons.wb_sunny,
    ReadingViewTheme.ivory => Icons.wb_sunny,
    ReadingViewTheme.sepia => Icons.wb_sunny,
    ReadingViewTheme.wood => Icons.table_restaurant,
    ReadingViewTheme.book => Icons.import_contacts,
    ReadingViewTheme.blueLight => Icons.water_drop,
    ReadingViewTheme.warmGray => Icons.blur_on,
    ReadingViewTheme.mint => Icons.nature,
    ReadingViewTheme.forest => Icons.nature,
    ReadingViewTheme.ocean => Icons.water_drop,
    ReadingViewTheme.midnight => Icons.dark_mode,
    ReadingViewTheme.charcoal => Icons.dark_mode,
    ReadingViewTheme.nord => Icons.ac_unit,
    ReadingViewTheme.dracula => Icons.nightlight_round,
    ReadingViewTheme.amoled => Icons.nightlight_round,
  };
}

enum ScrollDirection { up, down }

enum ReadingMode { page, continuous, realFlip }

extension ReadingModeX on ReadingMode {
  String get label => switch (this) {
    ReadingMode.page => 'Page Mode',
    ReadingMode.continuous => 'Continuous',
    ReadingMode.realFlip => 'Real Page Flip',
  };

  IconData get icon => switch (this) {
    ReadingMode.page => Icons.auto_stories,
    ReadingMode.continuous => Icons.view_day,
    ReadingMode.realFlip => Icons.menu_book,
  };
}

enum PageTurnAnimation { realFlip, slide, fade, reveal, cube }

extension PageTurnAnimationX on PageTurnAnimation {
  String get label => switch (this) {
    PageTurnAnimation.realFlip => 'Page Flip',
    PageTurnAnimation.slide => 'Slide',
    PageTurnAnimation.fade => 'Fade',
    PageTurnAnimation.reveal => 'Reveal',
    PageTurnAnimation.cube => 'Cube',
  };

  IconData get icon => switch (this) {
    PageTurnAnimation.realFlip => Icons.auto_stories,
    PageTurnAnimation.slide => Icons.arrow_forward,
    PageTurnAnimation.fade => Icons.blur_on,
    PageTurnAnimation.reveal => Icons.swap_horiz,
    PageTurnAnimation.cube => Icons.view_in_ar,
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

enum ReaderChromeStyle { translucent, frosted }

extension ReaderChromeStyleX on ReaderChromeStyle {
  String get label => switch (this) {
    ReaderChromeStyle.translucent => 'Translucent',
    ReaderChromeStyle.frosted => 'Frosted Glass',
  };

  IconData get icon => switch (this) {
    ReaderChromeStyle.translucent => Icons.blur_on,
    ReaderChromeStyle.frosted => Icons.grain,
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

/// Drag gesture active zones for turning pages in page flip mode.
enum PageFlipGestureZone {
  /// Turn from anywhere on the page (swipe across entire screen).
  fullScreen,

  /// Turn only by dragging from the outer edges (leaves center free for effortless text selection).
  edgesOnly,
}

extension PageFlipGestureZoneX on PageFlipGestureZone {
  String get label => switch (this) {
    PageFlipGestureZone.fullScreen => 'Full Screen',
    PageFlipGestureZone.edgesOnly => 'Edges Only (Selection Friendly)',
  };

  String get description => switch (this) {
    PageFlipGestureZone.fullScreen => 'Swipe anywhere to turn page',
    PageFlipGestureZone.edgesOnly => 'Swipe from edges to turn, center is for text selection',
  };

  IconData get icon => switch (this) {
    PageFlipGestureZone.fullScreen => Icons.fullscreen,
    PageFlipGestureZone.edgesOnly => Icons.border_vertical,
  };
}

