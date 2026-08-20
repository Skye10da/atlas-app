import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared chrome/shell state for reader layouts (continuous scroll, paged,
/// and any future layout). Mix this into a `State<T>` (or `ConsumerState<T>`,
/// since it extends `State<T>`) to get fullscreen toggling, the chrome
/// auto-hide timer, right-panel visibility, edge-swipe brightness dragging,
/// and the desktop breakpoints — all previously duplicated verbatim between
/// ContinuousReaderLayout and PagedReaderLayout.
///
/// The consuming State stays in charge of anything mode-specific (page vs.
/// scroll navigation, pagination) and calls into this mixin for the rest.
mixin ReaderChromeController<T extends StatefulWidget> on State<T> {
  static const double rightPanelWidth = 280.0;

  bool chromeVisible = true;
  bool rightPanelVisible = false;
  bool commandPaletteVisible = false;

  /// When true, the right side panel shows the Now Playing narration UI
  /// (desktop) instead of the reader chapters/bookmarks/settings panel.
  bool narrationPanelVisible = false;

  Timer? _chromeTimer;
  double? _brightnessDragStartY;
  double? _brightnessDragStartValue;

  bool get isDesktop => MediaQuery.of(context).size.width >= 840;
  bool get isWideDesktop =>
      isDesktop && MediaQuery.of(context).size.width >= 1200;

  /// Call from initState.
  void initReaderChrome({required bool isDarkTheme}) {
    setFullscreen(false, isDarkTheme: isDarkTheme);
    resetChromeTimer(isDarkTheme: isDarkTheme);
  }

  /// Call from dispose.
  void disposeReaderChrome() {
    _chromeTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void setFullscreen(bool fullscreen, {required bool isDarkTheme}) {
    SystemChrome.setEnabledSystemUIMode(
      fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkTheme
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDarkTheme
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }

  void toggleChrome({required bool isDarkTheme}) {
    HapticFeedback.lightImpact();
    setState(() => chromeVisible = !chromeVisible);
    if (chromeVisible) {
      setFullscreen(false, isDarkTheme: isDarkTheme);
      resetChromeTimer(isDarkTheme: isDarkTheme);
    } else {
      setFullscreen(true, isDarkTheme: isDarkTheme);
      _chromeTimer?.cancel();
    }
  }

  void resetChromeTimer({required bool isDarkTheme}) {
    _chromeTimer?.cancel();
    _chromeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => chromeVisible = false);
        setFullscreen(true, isDarkTheme: isDarkTheme);
      }
    });
  }

  void toggleRightPanel() => setState(() {
    rightPanelVisible = !rightPanelVisible;
    if (rightPanelVisible) narrationPanelVisible = false;
  });

  /// Shows the Now Playing UI in the right side panel (desktop), replacing
  /// any reader panel already open.
  void openNarrationPanel() => setState(() {
    narrationPanelVisible = true;
    rightPanelVisible = false;
  });

  /// Toggles the Now Playing panel, mirroring how Listen behaves on mobile
  /// (tapping again closes it).
  void toggleNarrationPanel() {
    if (narrationPanelVisible) {
      setState(() => narrationPanelVisible = false);
    } else {
      openNarrationPanel();
    }
  }

  void closeNarrationPanel() {
    if (narrationPanelVisible) {
      setState(() => narrationPanelVisible = false);
    }
  }

  /// Closes whichever side panel is open (reader or Now Playing). Used by
  /// click-outside-to-dismiss on desktop and the Escape key.
  void hideRightPanel() {
    if (rightPanelVisible || narrationPanelVisible) {
      setState(() {
        rightPanelVisible = false;
        narrationPanelVisible = false;
      });
    }
  }

  void showRightPanelOnHover() {
    if (!rightPanelVisible && !narrationPanelVisible) {
      setState(() => rightPanelVisible = true);
    }
  }

  void onEdgeBrightnessStart(
    DragStartDetails details, {
    required bool followSystemBrightness,
    required double currentBrightness,
  }) {
    if (followSystemBrightness) {
      _brightnessDragStartY = null;
      _brightnessDragStartValue = null;
      return;
    }
    _brightnessDragStartY = details.localPosition.dy;
    _brightnessDragStartValue = currentBrightness;
  }

  /// [onChanged] receives the new clamped 0..1 brightness value; the caller
  /// decides how to apply it (settings provider + platform service).
  void onEdgeBrightnessUpdate(
    DragUpdateDetails details, {
    required void Function(double newBrightness) onChanged,
  }) {
    if (_brightnessDragStartY == null || _brightnessDragStartValue == null) {
      return;
    }
    final delta = (details.localPosition.dy - _brightnessDragStartY!) / 300;
    final newBrightness = (_brightnessDragStartValue! - delta).clamp(0.0, 1.0);
    onChanged(newBrightness);
  }

  void onEdgeBrightnessEnd(DragEndDetails details) {
    _brightnessDragStartY = null;
    _brightnessDragStartValue = null;
  }
}
