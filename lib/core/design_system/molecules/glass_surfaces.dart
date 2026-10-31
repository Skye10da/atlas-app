// Atlas liquid-glass surfaces: shared frosted-glass primitives.
//
// Lifted from the navigation organism (atlas_glass_nav_bar.dart) so non-nav
// chrome — floating reader pills, sheets, popovers — can speak the same
// "Liquid Glass" language without depending on nav widgets. The organism file
// re-exports [GlassCapsule] and [GlassLens], so existing imports keep working
// (see docs/plans/reader_glass_pills_plan.md).
//
// From glassmorphism: backdrop blur + translucent fill (cheap, works on every
// Flutter target incl. Web/Windows/Linux).
// From Liquid Glass: vibrancy boost, specular edge light, clipped shadows.

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Raw frosted-glass panel: backdrop blur + saturation boost (vibrancy),
/// translucent gradient fill, specular gradient rim, outer drop shadow.
///
/// [pill] is the convenience mode for floating pills over live text: it
/// clamps the radius to a full pill (999) and caps the blur at 20 sigma.
/// [interactive] false is for pointer-transparent chrome (the reader's
/// tap-falls-through contract): the glass layer ignores pointer events while
/// [child] stays fully interactive.
class GlassCapsule extends StatelessWidget {
  const GlassCapsule({
    super.key,
    this.borderRadius = 999,
    this.pill = false,
    this.blur = 28,
    this.vibrancy = 1.6,
    this.strong = false,
    this.skipDropShadow = false,
    this.interactive = true,
    this.shadow,
    this.fill,
    this.child,
  });

  /// Geometric corner radius; defaults to and clamped to a full pill when
  /// [pill] is true.
  final double borderRadius;

  /// Convenience pill mode: radius → 999 and blur capped at 20 sigma, so
  /// pills over scrolling text stay cheap and perfectly rounded.
  final bool pill;
  final double blur;
  final double vibrancy;
  final bool strong;

  /// True when the caller paints its own outer shadow or already sits inside
  /// another capsule (saves one saveLayer per stacked glass).
  final bool skipDropShadow;

  /// When false, the glass background (blur, fill, rim, shadow) is wrapped in
  /// [IgnorePointer] so empty areas never hit-test; [child] is re-hosted in a
  /// transparency [Material] above it and stays interactive. Defaults to
  /// true (the capsule behaves like any opaque decorative surface).
  final bool interactive;

  /// Overrides the built-in soft drop shadow (color, offset, blur, spread).
  /// Used by migrated reader pills to keep their legacy visual weight.
  final BoxShadow? shadow;

  /// Overrides the default white-alpha tint with a single translucent color,
  /// whose gradient fades to 72% of its opacity toward the far corner. The
  /// blur + saturation still run underneath, so the vibrancy effect is not
  /// reduced — only the fill's own glance-through.
  final Color? fill;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = pill ? 999.0 : borderRadius;
    final sigma = pill ? blur.clamp(0.0, 20.0).toDouble() : blur;

    Widget surface(Widget? inner) => ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            // Blur + saturation boost = the "vibrant" glass look.
            filter: ImageFilter.compose(
              outer: ColorFilter.matrix(glassSaturation(vibrancy)),
              inner: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            ),
            child: CustomPaint(
              foregroundPainter: GlassSpecularBorderPainter(
                radius: radius,
                isDark: isDark,
                width: strong ? 1.4 : 1.2,
                strong: strong,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: fill != null
                        ? [
                            fill!,
                            fill!.withValues(alpha: fill!.a * 0.72),
                          ]
                        : isDark
                            ? const [
                                Color.fromRGBO(255, 255, 255, 0.12),
                                Color.fromRGBO(255, 255, 255, 0.04),
                              ]
                            : const [
                                Color.fromRGBO(255, 255, 255, 0.60),
                                Color.fromRGBO(255, 255, 255, 0.30),
                              ],
                  ),
                ),
                child: inner,
              ),
            ),
          ),
        );

    if (interactive || child == null) {
      return CustomPaint(
        painter: GlassDropShadowPainter(radius: radius, isDark: isDark, boxShadow: shadow),
        child: surface(child),
      );
    }

    // Pointer-transparent glass: the decorative layer ignores pointer events,
    // while a transparency Material hosts [child] on top so its buttons stay
    // live and empty glass areas fall through to the page underneath. The
    // Stack hugs the child; the background layer (a childless proxy chain,
    // hence the SizedBox.expand) tracks the Stack's bounded size.
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: skipDropShadow
                ? SizedBox.expand(child: surface(null))
                : CustomPaint(
                    painter: GlassDropShadowPainter(
                      radius: radius,
                      isDark: isDark,
                      boxShadow: shadow,
                    ),
                    child: SizedBox.expand(child: surface(null)),
                  ),
          ),
        ),
        Material(type: MaterialType.transparency, child: child!),
      ],
    );
  }
}

/// The accent "glass droplet" indicator — pure decoration that sizes to its
/// parent box. Reused by the nav bar lens, the glass desktop sidebar and the
/// reader's selected-value highlights.
class GlassLens extends StatelessWidget {
  const GlassLens({
    super.key,
    required this.accent,
    required this.isDark,
    required this.radius,
  });

  final Color accent;
  final bool isDark;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: GlassSpecularBorderPainter(
        radius: radius,
        isDark: isDark,
        width: 1.4,
        strong: true,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                accent.withValues(alpha: isDark ? 0.20 : 0.14),
                Color.fromRGBO(255, 255, 255, isDark ? 0.22 : 0.70),
              ),
              Color.alphaBlend(
                accent.withValues(alpha: isDark ? 0.10 : 0.06),
                Color.fromRGBO(255, 255, 255, isDark ? 0.08 : 0.30),
              ),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.35 : 0.22),
              blurRadius: 18,
              spreadRadius: -4,
            ),
          ],
        ),
      ),
    );
  }
}

/// Gradient hairline: bright top-left + faint bottom-right rim, like light
/// catching the edge of real glass. Public so the shells can reuse or test
/// the exact rim the capsules paint.
class GlassSpecularBorderPainter extends CustomPainter {
  const GlassSpecularBorderPainter({
    required this.radius,
    required this.isDark,
    required this.width,
    this.strong = false,
  });

  final double radius;
  final bool isDark;
  final double width;
  final bool strong;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(width / 2),
      Radius.circular(radius),
    );
    final hi = strong ? 0.95 : (isDark ? 0.55 : 0.90);
    final rim = strong ? 0.45 : (isDark ? 0.22 : 0.45);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.fromRGBO(255, 255, 255, hi),
          const Color.fromRGBO(255, 255, 255, 0.04),
          const Color.fromRGBO(255, 255, 255, 0.04),
          Color.fromRGBO(255, 255, 255, rim),
        ],
        stops: const [0, 0.38, 0.62, 1],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(GlassSpecularBorderPainter o) =>
      o.radius != radius ||
      o.isDark != isDark ||
      o.width != width ||
      o.strong != strong;
}

/// Soft drop shadow drawn only OUTSIDE the capsule so it doesn't muddy the
/// glass. When [boxShadow] is set, its color/offset/blur/spread replace the
/// built-in shadow — migrated reader pills use this to keep their legacy
/// visual weight while moving onto the shared glass painter.
class GlassDropShadowPainter extends CustomPainter {
  const GlassDropShadowPainter({
    required this.radius,
    required this.isDark,
    this.boxShadow,
  });

  final double radius;
  final bool isDark;
  final BoxShadow? boxShadow;

  @override
  void paint(Canvas canvas, Size size) {
    final base = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final override = boxShadow;
    final rrect = override == null
        ? base.shift(const Offset(0, 10))
        : base.inflate(override.spreadRadius).shift(override.offset);
    final sigma = override == null ? 16.0 : override.blurRadius / 2;
    final color = override == null
        ? Color.fromRGBO(0, 0, 0, isDark ? 0.45 : 0.18)
        : override.color;
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(
        Rect.fromLTRB(-120, -120, size.width + 120, size.height + 120),
      ),
      Path()..addRRect(base),
    );
    canvas.save();
    canvas.clipPath(outside);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(GlassDropShadowPainter o) =>
      o.radius != radius ||
      o.isDark != isDark ||
      o.boxShadow != boxShadow;
}

/// Saturation-boost color matrix ("vibrancy") shared by everything that
/// composes the glass look by hand — currently the nav bar's inline capsule.
List<double> glassSaturation(double s) {
  final sr = (1 - s) * _satBase[0];
  final sg = (1 - s) * _satBase[1];
  final sb = (1 - s) * _satBase[2];
  return [
    sr + s, sg, sb, 0, 0, //
    sr, sg + s, sb, 0, 0,
    sr, sg, sb + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

const List<double> _satBase = [
  0.2126, 0.7152, 0.0722, //
];
