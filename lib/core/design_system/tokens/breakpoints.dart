import 'package:flutter/material.dart';

/// Responsive window size breakpoints adhering to Material Design 3 and
/// Flutter adaptive layout guidelines.
abstract final class AppBreakpoints {
  /// Window width threshold for compact / mobile screens (< 600dp).
  static const double mobile = 600;

  /// Window width threshold for medium / tablet screens (600dp - 899dp).
  static const double tablet = 900;

  /// Window width threshold for expanded / desktop screens (>= 900dp).
  static const double desktop = 900;

  /// Window width threshold for large / ultrawide desktop screens (>= 1200dp).
  static const double largeDesktop = 1200;

  /// Optimal maximum width for prose readability (65-85 characters per line).
  static const double readerContentMaxWidth = 840.0;

  /// Returns a responsive max-width for reader content based on the current
  /// window width.
  ///
  /// - **Mobile / Tablet** (< 900dp): returns [double.infinity] so content
  ///   fills the full available width (only [MarginPreset] padding applies).
  /// - **Desktop** (900–1199dp): returns 90% of the window width, floored at
  ///   840dp so it's never narrower than the legacy constant.
  /// - **Large desktop** (≥ 1200dp): returns 90% of the window width, capped
  ///   at 1100dp to keep line lengths readable.
  static double readerResponsiveMaxWidth(double windowWidth) {
    if (windowWidth < desktop) return double.infinity;
    if (windowWidth < largeDesktop) {
      return (windowWidth * 0.9).clamp(840.0, windowWidth);
    }
    return (windowWidth * 0.9).clamp(840.0, 1100.0);
  }

  /// Optimal maximum width for settings forms and dialog cards.
  static const double formContentMaxWidth = 760.0;

  /// Optimal maximum width for modal sheets and flyout dialogs.
  static const double sheetMaxWidth = 640.0;

  /// True when the current window width is compact (< 600dp).
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  /// True when the current window width is medium (600dp - 899dp).
  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobile && width < tablet;
  }

  /// True when the current window width is expanded (900dp - 1199dp).
  static bool isExpanded(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= tablet && width < largeDesktop;
  }

  /// True when the current window width is large (>= 1200dp).
  static bool isLarge(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= largeDesktop;

  // Backward-compatible aliases:
  static bool isMobile(BuildContext context) => isCompact(context);
  static bool isTablet(BuildContext context) => isMedium(context);
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
  static bool isWide(BuildContext context) => isDesktop(context);
}
