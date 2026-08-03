import 'package:flutter/material.dart';

/// Presents content in a bottom sheet the user can drag vertically by its
/// handle. The height it is dragged to is remembered per [id] for the rest
/// of the session, so the sheet "stops" where the user put it instead of
/// snapping back to the default on the next open.
class DraggableBottomSheet {
  DraggableBottomSheet._();

  static final Map<String, double> _remembered = {};

  static Future<T?> show<T>({
    required BuildContext context,
    required String id,
    required Widget child,
    double initialHeight = 0.5,
    double minHeight = 120,
    double maxHeightFactor = 0.92,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (context, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
      pageBuilder: (context, _, _) => _DraggableSheet(
        id: id,
        initialHeight: initialHeight,
        minHeight: minHeight,
        maxHeightFactor: maxHeightFactor,
        remembered: _remembered,
        child: child,
      ),
    );
  }
}

class _DraggableSheet extends StatefulWidget {
  const _DraggableSheet({
    required this.id,
    required this.child,
    required this.initialHeight,
    required this.minHeight,
    required this.maxHeightFactor,
    required this.remembered,
  });

  final String id;
  final Widget child;
  final double initialHeight;
  final double minHeight;
  final double maxHeightFactor;
  final Map<String, double> remembered;

  @override
  State<_DraggableSheet> createState() => _DraggableSheetState();
}

class _DraggableSheetState extends State<_DraggableSheet> {
  static const _handleHeight = 36.0;

  late double _height;
  double _maxHeight = 0;
  bool _initialized = false;
  double? _dragStartHeight;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final screen = MediaQuery.of(context).size.height;
    _maxHeight = screen * widget.maxHeightFactor;
    _height = (widget.remembered[widget.id] ?? widget.initialHeight * screen)
        .clamp(widget.minHeight, _maxHeight);
  }

  void _onDragStart(DragStartDetails _) => _dragStartHeight = _height;

  void _onDragUpdate(DragUpdateDetails details) {
    final start = _dragStartHeight ?? _height;
    final next = (start - details.delta.dy).clamp(widget.minHeight, _maxHeight);
    setState(() => _height = next);
  }

  void _onDragEnd(DragEndDetails _) {
    widget.remembered[widget.id] = _height;
    _dragStartHeight = null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: colorScheme.surfaceContainerLow,
        elevation: 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: _height,
          width: double.infinity,
          child: Column(
            children: [
              _SheetHandle(
                onVerticalDragStart: _onDragStart,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
              ),
              Flexible(
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
  });

  final GestureDragStartCallback onVerticalDragStart;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: onVerticalDragStart,
      onVerticalDragUpdate: onVerticalDragUpdate,
      onVerticalDragEnd: onVerticalDragEnd,
      child: SizedBox(
        height: _DraggableSheetState._handleHeight,
        width: double.infinity,
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
