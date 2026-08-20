import 'dart:io';

import 'package:flutter/services.dart';

/// Sends the app's current theme state to the native Windows runner so it can
/// tint the title bar accordingly.
///
/// - On Windows 11+ the title bar background and text color are set via
///   `DWMWA_CAPTION_COLOR` / `DWMWA_TEXT_COLOR`.
/// - On Windows 10 the dark/light toggle is updated via
///   `DWMWA_USE_IMMERSIVE_DARK_MODE`.
/// - On non-Windows platforms this is a silent no-op.
class WindowThemeChannel {
  static const _channel = MethodChannel('com.atlasapp/window_theme');

  /// Pushes the current [brightness] and [brandSeed] color to the native
  /// window so the title bar matches the app.
  ///
  /// [brightness] determines whether dark or light mode is used for the
  /// native title bar chrome.  [brandSeed] is the brand's primary color
  /// used as the caption background on Windows 11+.
  void syncTheme({required Brightness brightness, required Color brandSeed}) {
    if (!Platform.isWindows) return;

    final isDark = brightness == Brightness.dark;

    // Caption background: use the brand seed directly.
    // Convert to COLORREF (0x00BBGGRR – note reversed channel order from ARGB).
    final int bgRef = _colorToColorref(brandSeed);

    // Caption text: white on dark backgrounds, dark on light backgrounds.
    // Use a simple luminance check on the seed color.
    final int fgRef = _isLight(brandSeed) ? 0x00333333 : 0x00FFFFFF;

    _channel
        .invokeMethod<void>('setTheme', {
          'dark': isDark,
          'captionBg': bgRef,
          'captionFg': fgRef,
        })
        .catchError((_) {});
  }

  /// Converts a Flutter [Color] (ARGB) to a Windows COLORREF (0x00BBGGRR).
  static int _colorToColorref(Color c) {
    final int r = (c.r * 255).round();
    final int g = (c.g * 255).round();
    final int b = (c.b * 255).round();
    // COLORREF = 0x00BBGGRR (alpha is ignored by DWM, drop it to stay in int32).
    return (b << 16) | (g << 8) | r;
  }

  /// Returns true if the color is perceived as "light" (needs dark text).
  static bool _isLight(Color c) {
    // Relative luminance per ITU-R BT.709.
    final double luminance = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    return luminance > 0.5;
  }
}
