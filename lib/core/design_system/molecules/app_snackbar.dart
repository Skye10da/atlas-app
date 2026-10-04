import 'package:flutter/material.dart';

import 'package:atlas_app/main.dart';

/// Centralized snackbar helper that uses the root [ScaffoldMessenger].
///
/// Why: `ScaffoldMessenger.of(context)` is tied to the nearest Scaffold.
/// When `LibraryScreen._checkAllUpdates` or `NovelActionsController`
/// invalidates `libraryBooksProvider` / `bookChaptersProvider`, the
/// Library/Novel widgets rebuild and their local ScaffoldMessenger is
/// replaced — any snackbar shown via the pre-await messenger ref is
/// dismissed instantly. By routing through [rootScaffoldMessengerKey]
/// (installed on `MaterialApp.router`) the snackbar survives provider
/// invalidations, navigation, and `setState` rebuilds.
///
/// Keep `snackbar only` per spec — no OS notification for manual checks.
class AppSnackBar {
  const AppSnackBar._();

  static void show(
    String message, {
    Duration duration = const Duration(seconds: 4),
    Color? backgroundColor,
    SnackBarAction? action,
  }) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    // Hide any current snackbar first so rapid successive checks queue
    // deterministically instead of stacking.
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  static void showError(
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = rootScaffoldMessengerKey.currentState;
    Color? errorColor;
    try {
      final ctx = messenger?.context;
      if (ctx != null && ctx.mounted) {
        errorColor = Theme.of(ctx).colorScheme.error;
      }
    } catch (_) {}
    show(message, duration: duration, backgroundColor: errorColor);
  }
}
