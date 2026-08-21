import 'package:flutter/material.dart';

import 'package:atlas_app/core/theme/font_downloader.dart';

/// Drop-in replacement for `GoogleFonts.getFont(...)`.
///
/// Bundled families are resolved natively by Flutter (declared in
/// `pubspec.yaml` under `flutter.fonts`), so all this does is attach the
/// family name to the given [textStyle]. Downloaded families are registered
/// with the font engine by [FontDownloader], so they resolve the same way.
abstract final class LocalFonts {
  static const bundledFamilies = {'Inter', 'Open Sans', 'Playfair Display'};

  /// Attaches [family] to [textStyle] (or a default style when null).
  static TextStyle getFont(String family, {TextStyle? textStyle}) {
    final base = textStyle ?? const TextStyle();
    return base.copyWith(fontFamily: family);
  }

  /// Re-registers any previously downloaded fonts after a restart. Call once
  /// at startup (see `main.dart`).
  static Future<void> initialize() => FontDownloader.loadDownloaded();
}