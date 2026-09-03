import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReaderChromeState {
  const ReaderChromeState({
    this.chromeVisible = true,
    this.rightPanelVisible = false,
    this.commandPaletteVisible = false,
    this.narrationPanelVisible = false,
  });

  final bool chromeVisible;
  final bool rightPanelVisible;
  final bool commandPaletteVisible;
  final bool narrationPanelVisible;

  ReaderChromeState copyWith({
    bool? chromeVisible,
    bool? rightPanelVisible,
    bool? commandPaletteVisible,
    bool? narrationPanelVisible,
  }) {
    return ReaderChromeState(
      chromeVisible: chromeVisible ?? this.chromeVisible,
      rightPanelVisible: rightPanelVisible ?? this.rightPanelVisible,
      commandPaletteVisible: commandPaletteVisible ?? this.commandPaletteVisible,
      narrationPanelVisible: narrationPanelVisible ?? this.narrationPanelVisible,
    );
  }
}

final readerChromeProvider =
    StateNotifierProvider.autoDispose<ReaderChromeNotifier, ReaderChromeState>(
  (ref) => ReaderChromeNotifier(),
);

class ReaderChromeNotifier extends StateNotifier<ReaderChromeState> {
  ReaderChromeNotifier() : super(const ReaderChromeState());

  Timer? _chromeTimer;
  double? _brightnessDragStartY;
  double? _brightnessDragStartValue;

  void initReaderChrome({required bool isDarkTheme}) {
    setFullscreen(false, isDarkTheme: isDarkTheme);
    resetChromeTimer(isDarkTheme: isDarkTheme);
  }

  void setFullscreen(bool fullscreen, {required bool isDarkTheme}) {
    SystemChrome.setEnabledSystemUIMode(
      fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkTheme ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDarkTheme ? Brightness.light : Brightness.dark,
      ),
    );
  }

  void toggleChrome({required bool isDarkTheme}) {
    HapticFeedback.lightImpact();
    final next = !state.chromeVisible;
    state = state.copyWith(chromeVisible: next);
    if (next) {
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
        state = state.copyWith(chromeVisible: false);
        setFullscreen(true, isDarkTheme: isDarkTheme);
      }
    });
  }

  void toggleRightPanel() {
    final next = !state.rightPanelVisible;
    state = state.copyWith(
      rightPanelVisible: next,
      narrationPanelVisible: next ? false : state.narrationPanelVisible,
    );
  }

  void openNarrationPanel() {
    state = state.copyWith(
      narrationPanelVisible: true,
      rightPanelVisible: false,
    );
  }

  void toggleNarrationPanel() {
    if (state.narrationPanelVisible) {
      closeNarrationPanel();
    } else {
      openNarrationPanel();
    }
  }

  void closeNarrationPanel() {
    if (state.narrationPanelVisible) {
      state = state.copyWith(narrationPanelVisible: false);
    }
  }

  void hideRightPanel() {
    if (state.rightPanelVisible || state.narrationPanelVisible) {
      state = state.copyWith(
        rightPanelVisible: false,
        narrationPanelVisible: false,
      );
    }
  }

  void showRightPanelOnHover() {
    if (!state.rightPanelVisible && !state.narrationPanelVisible) {
      state = state.copyWith(rightPanelVisible: true);
    }
  }

  void setCommandPaletteVisible(bool visible) {
    state = state.copyWith(commandPaletteVisible: visible);
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

  @override
  void dispose() {
    _chromeTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}

