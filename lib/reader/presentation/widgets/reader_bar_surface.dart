import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

/// The floating-pill shell shared by the reader's pills (dock capsule and the
/// slim top bar). Two looks:
///
/// * [glass] true (default) — the "Liquid Glass" look: the shell is a
///   [GlassCapsule] in pill mode (vibrancy backdrop + specular rim) while
///   keeping the reader's tap contract: the glass layer is pointer
///   transparent, so taps on empty pill space fall through to the page
///   underneath.
/// * [glass] false — the classic translucent shell (surface fill + blur +
///   hairline border), the pre-glass look kept for the
///   [ReaderChromeStyle.translucent] and [ReaderChromeStyle.frosted]
///   settings.
class ReaderPillSurface extends StatelessWidget {
  const ReaderPillSurface({
    super.key,
    required this.colorScheme,
    required this.child,
    this.glass = true,
  });

  final ColorScheme colorScheme;
  final Widget child;

  /// Liquid-glass styling via [GlassCapsule]. False renders the legacy
  /// translucent shell.
  final bool glass;

  @override
  Widget build(BuildContext context) {
    if (!glass) return _legacyShell();
    final dark = colorScheme.brightness == Brightness.dark;
    return GlassCapsule(
      pill: true,
      blur: 20,
      vibrancy: 1.6,
      strong: false,
      // Reader contract: empty pill area must not swallow taps.
      interactive: false,
      // Surface-tinted fill keeps pill content legible over live text in
      // both themes; the nav-white gradient is too faint in dark mode here.
      fill: colorScheme.surface.withValues(alpha: dark ? 0.55 : 0.70),
      // Legacy shadow weight, migrated into the capsule painter.
      shadow: BoxShadow(
        color: dark ? const Color(0x66000000) : const Color(0x48232019),
        offset: const Offset(0, 18),
        blurRadius: 40,
        spreadRadius: -12,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );
  }

  Widget _legacyShell() {
    final dark = colorScheme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: dark
                ? const Color(0x66000000)
                : const Color(0x48232019),
            offset: const Offset(0, 18),
            blurRadius: 40,
            spreadRadius: -12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: colorScheme.onSurface.withValues(alpha: 0.10),
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

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
      // Full-width frosted bars are a separate compositional problem (the
      // liquid-glass pills plan keeps them out of phase 1); the glass chrome
      // value reuses the frosted bar treatment there.
      ReaderChromeStyle.frosted || ReaderChromeStyle.glass => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ColoredBox(color: color.withValues(alpha: 0.5)),
        ),
      ),
      ReaderChromeStyle.translucent => ColoredBox(
        color: color.withValues(alpha: 0.80),
      ),
    };

    return Stack(
      children: [
        Positioned.fill(child: IgnorePointer(child: background)),
        Material(type: MaterialType.transparency, child: child),
      ],
    );
  }
}
