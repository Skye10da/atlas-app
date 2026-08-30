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
