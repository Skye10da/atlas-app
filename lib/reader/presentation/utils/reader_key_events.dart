import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Handles the Escape (close palette / toggle chrome) and Ctrl/Cmd+K (open
/// palette) key events that both reader layouts implement identically
/// inside their own `_handleKeyEvent`. Call this first from each layout's
/// key handler; if it returns `KeyEventResult.ignored`, fall through to
/// mode-specific arrow-key / page-turn handling.
KeyEventResult handleCommonReaderKeys(
  KeyEvent event, {
  required bool commandPaletteVisible,
  required VoidCallback onClosePalette,
  required VoidCallback onToggleChrome,
  required VoidCallback onOpenPalette,
}) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;

  if (event.logicalKey == LogicalKeyboardKey.escape) {
    if (commandPaletteVisible) {
      onClosePalette();
      return KeyEventResult.handled;
    }
    onToggleChrome();
    return KeyEventResult.handled;
  }

  final isCtrlOrCmd =
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;
  if (isCtrlOrCmd && event.logicalKey == LogicalKeyboardKey.keyK) {
    if (!commandPaletteVisible) onOpenPalette();
    return KeyEventResult.handled;
  }

  return KeyEventResult.ignored;
}
