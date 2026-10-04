import 'package:flutter/material.dart';

import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

/// Reader-only background helpers: resolve effective background color
/// (custom override vs theme) and paint subtle pattern overlays via
/// CustomPainter so reader themes stay distinct without assets.
Color resolveReaderBackground({
  required ReadingColors colors,
  required Color? customColor,
}) {
  return customColor ?? colors.background;
}

class ReaderPatternPainter extends CustomPainter {
  const ReaderPatternPainter({
    required this.pattern,
    required this.color,
    required this.opacity,
  });

  final ReaderPattern pattern;
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (pattern == ReaderPattern.none || opacity <= 0) return;
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = color.withValues(alpha: opacity * 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    switch (pattern) {
      case ReaderPattern.none:
        break;
      case ReaderPattern.dots:
        const step = 18.0;
        const r = 1.1;
        for (var y = 0.0; y < size.height; y += step) {
          for (var x = 0.0; x < size.width; x += step) {
            canvas.drawCircle(Offset(x, y), r, paint);
          }
        }
        break;
      case ReaderPattern.grid:
        const step = 22.0;
        for (var x = 0.0; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), stroke);
        }
        for (var y = 0.0; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), stroke);
        }
        break;
      case ReaderPattern.ruled:
        const step = 28.0;
        for (var y = step; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), stroke);
        }
        break;
      case ReaderPattern.linen:
        const step = 14.0;
        final p = Paint()
          ..color = color.withValues(alpha: opacity * 0.5)
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke;
        for (var y = 0.0; y < size.height; y += step) {
          canvas.drawLine(
            Offset(0, y + (y % 28 == 0 ? 4 : 0)),
            Offset(size.width, y),
            p,
          );
        }
        for (var x = 0.0; x < size.width; x += step * 1.2) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
        break;
      case ReaderPattern.paperGrain:
        // Diagonal grain lines.
        const step = 16.0;
        final p = Paint()
          ..color = color.withValues(alpha: opacity * 0.6)
          ..strokeWidth = 0.7
          ..style = PaintingStyle.stroke;
        for (var y = -size.width; y < size.height; y += step) {
          canvas.drawLine(
            Offset(0, y),
            Offset(size.width, y + size.width * 0.18),
            p,
          );
        }
        break;
      case ReaderPattern.noise:
        // Sparse speckles.
        final rnd = _NoiseRandom(999);
        final count = (size.width * size.height / 900).round().clamp(80, 700);
        for (var i = 0; i < count; i++) {
          final x = rnd.nextDouble() * size.width;
          final y = rnd.nextDouble() * size.height;
          final rr = rnd.nextDouble() * 0.9 + 0.3;
          canvas.drawCircle(Offset(x, y), rr, paint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant ReaderPatternPainter old) =>
      old.pattern != pattern || old.color != color || old.opacity != opacity;
}

class _NoiseRandom {
  _NoiseRandom(this.seed);
  int seed;
  double nextDouble() {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed / 0x7fffffff;
  }
}

class ReaderBackground extends StatelessWidget {
  const ReaderBackground({
    super.key,
    required this.colors,
    required this.customColor,
    required this.pattern,
    required this.patternOpacity,
    required this.child,
  });

  final ReadingColors colors;
  final Color? customColor;
  final ReaderPattern pattern;
  final double patternOpacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bg = resolveReaderBackground(
      colors: colors,
      customColor: customColor,
    );
    final isDark = bg.computeLuminance() < 0.5;
    final patternColor = (isDark ? Colors.white : Colors.black);
    // Pattern must cover the *entire* background, not just the child's
    // intrinsic size. Using a Stack with Positioned.fill ensures the
    // CustomPaint fills the ColoredBox bounds even when child is a
    // centered ConstrainedBox (e.g. continuous chapter blocks). Previously
    // `CustomPaint(child: child)` sized itself to the child, leaving
    // gutters unpatterned, and the inner ChapterContentLoader's opaque
    // Container hid the pattern behind text.
    if (pattern == ReaderPattern.none) {
      return ColoredBox(color: bg, child: child);
    }
    return ColoredBox(
      color: bg,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: ReaderPatternPainter(
                pattern: pattern,
                color: patternColor,
                opacity: patternOpacity.clamp(0.0, 0.20),
              ),
              // Ensure painter gets full constraints even before layout.
              size: Size.infinite,
            ),
          ),
          child,
        ],
      ),
    );
  }
}
