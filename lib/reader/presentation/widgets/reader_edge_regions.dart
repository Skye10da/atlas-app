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

/// The right-edge hover strip + positioned panel used on desktop. Wraps the
/// hover-to-reveal `MouseRegion` and the panel's `Positioned` placement,
/// which were previously duplicated between the two layouts down to the
/// exact padding-based top/bottom offsets.
class DesktopRightPanelRegion extends StatelessWidget {
  const DesktopRightPanelRegion({
    super.key,
    required this.visible,
    required this.chromeVisible,
    required this.panelWidth,
    required this.onHoverReveal,
    required this.panel,
  });

  final bool visible;
  final bool chromeVisible;
  final double panelWidth;
  final VoidCallback onHoverReveal;
  final Widget panel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 8,
          child: MouseRegion(
            onEnter: (_) {
              if (!visible) onHoverReveal();
            },
            cursor: visible
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: Container(color: Colors.transparent),
          ),
        ),
        if (visible)
          Positioned(
            right: 0,
            top: chromeVisible ? MediaQuery.of(context).padding.top : 0,
            bottom: chromeVisible ? MediaQuery.of(context).padding.bottom : 0,
            width: panelWidth,
            child: panel,
          ),
      ],
    );
  }
}
