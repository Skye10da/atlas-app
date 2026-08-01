import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';

/// Paints the background for the reader's floating chrome bars.
///
/// The background layer is wrapped in [IgnorePointer] and the interactive
/// content sits in a transparent [Material], so taps on the bar's empty
/// space fall through to the page underneath instead of being swallowed.
class ReaderBarSurface extends StatelessWidget implements PreferredSizeWidget {
  const ReaderBarSurface({
    super.key,
    required this.style,
    required this.color,
    required this.child,
  });

  final ReaderChromeStyle style;
  final Color color;
  final Widget child;

  @override
  Size get preferredSize {
    final c = child;
    return c is PreferredSizeWidget ? c.preferredSize : Size.zero;
  }

  @override
  Widget build(BuildContext context) {
    final background = switch (style) {
      ReaderChromeStyle.frosted => ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ColoredBox(color: color.withValues(alpha: 0.5)),
          ),
        ),
      ReaderChromeStyle.translucent =>
        ColoredBox(color: color.withValues(alpha: 0.9)),
    };

    return Stack(
      children: [
        Positioned.fill(child: IgnorePointer(child: background)),
        Material(type: MaterialType.transparency, child: child),
      ],
    );
  }
}
