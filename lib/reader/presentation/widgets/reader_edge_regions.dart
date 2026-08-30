import 'package:flutter/material.dart';

/// The left-edge vertical-drag strip used on mobile to adjust brightness.
/// Identical in both layouts — only the callbacks passed in differ, and in
/// practice both call straight through to [ReaderChromeController]'s
/// brightness handlers.
class BrightnessEdgeGestureRegion extends StatelessWidget {
  const BrightnessEdgeGestureRegion({
    super.key,
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
    this.width = 40,
  });

  final GestureDragStartCallback onVerticalDragStart;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: width,
      child: GestureDetector(
        onVerticalDragStart: onVerticalDragStart,
        onVerticalDragUpdate: onVerticalDragUpdate,
        onVerticalDragEnd: onVerticalDragEnd,
        behavior: HitTestBehavior.translucent,
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

/// The positioned right-docked panel used on desktop.
class DesktopRightPanelRegion extends StatelessWidget {
  const DesktopRightPanelRegion({
    super.key,
    required this.visible,
    required this.chromeVisible,
    required this.panelWidth,
    required this.panel,
  });

  final bool visible;
  final bool chromeVisible;
  final double panelWidth;
  final Widget panel;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Positioned(
      right: 0,
      top: chromeVisible ? MediaQuery.paddingOf(context).top : 0,
      bottom: chromeVisible ? MediaQuery.paddingOf(context).bottom : 0,
      width: panelWidth,
      child: panel,
    );
  }
}
