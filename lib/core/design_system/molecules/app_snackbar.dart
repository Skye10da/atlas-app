// Deprecated SnackBar-compat facade over [AppToast].
//
// Everything the app says out loud now renders as the glass droplet pill
// (see app_toast.dart). Callers still using [AppSnackBar] get the pill for
// free; migrate to [AppToast] directly for tone-specific emoticons.

import 'package:flutter/material.dart' show SnackBarAction;

import 'package:atlas_app/core/design_system/molecules/app_toast.dart';

class AppSnackBar {
  const AppSnackBar._();

  static void show(
    String message, {
    Duration duration = const Duration(seconds: 4),
    Object? backgroundColor, // ignored — glass pill tones carry the color
    SnackBarAction? action,
  }) {
    AppToast.show(
      message,
      duration: duration,
      action: action == null
          ? null
          : AppToastAction(action.label, () => action.onPressed()),
    );
  }

  static void showError(
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    AppToast.showError(message, duration: duration);
  }
}
