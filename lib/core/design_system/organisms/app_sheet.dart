import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// How sheets are presented on desktop-sized windows.
enum DesktopSheetPresentation { dialog, sidePanel }

/// Modern adaptive modal sheet.
///
/// - `< 840px`: bottom sheet with spring physics, velocity-based fling
///   dismissal and snap points; full-width below 600, capped to 640 above.
/// - `>= 840px`: floating centered dialog (rounded on all corners).
///
/// Panel-capable sheets (Listen / Chapters) can additionally be routed into
/// the reader's right side panel by callers that check
/// [desktopPresentation] before calling [AppSheet.show].
///
/// The height a sheet was dragged to is remembered per [id] for the rest of
/// the session, so it "stops" where the user put it instead of snapping back
/// to the default on the next open.
class AppSheet {
  AppSheet._();

  /// Width at or above which sheets become floating dialogs instead of
  /// bottom-anchored sheets. Matches the reader's own desktop breakpoint.
  static const double desktopBreakpoint = 840;

  /// Maximum content width for tablet/desktop presentations.
  static const double maxSheetWidth = 640;

  /// Whether the frosted-glass backdrop is rendered behind open sheets.
  /// Costs a GPU blur pass per frame while a sheet is visible; disabled on
  /// web where the canvas backend is much slower at it.
  static bool enableBackdropBlur = !kIsWeb;

  /// Desktop presentation preference, synced from user settings by the
  /// settings layer. Callers route panel-capable sheets accordingly.
  static DesktopSheetPresentation desktopPresentation =
      DesktopSheetPresentation.dialog;

  /// Session-scoped memory of each sheet's last height, keyed by [id].
  /// Exposed so tests can reset state between cases.
  static final Map<String, double> rememberedHeights = {};

  /// Presents [child] in an adaptive modal sheet.
  ///
  /// [id] keys the remembered-height store. Heights are expressed as
  /// fractions of screen height: [initialHeight] is where the sheet opens,
  /// [snapPoints] are the positions it settles between (defaults to just
  /// [initialHeight]), clamped to `[minHeightPx, maxHeightFactor * screen]`.
  static Future<T?> show<T>({
    required BuildContext context,
    required String id,
    required Widget child,
    String? title,
    double initialHeight = 0.5,
    List<double> snapPoints = const [],
    double minHeight = 120,
    double maxHeightFactor = 0.92,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final presentation = width >= desktopBreakpoint
        ? _SurfacePresentation.dialog
        : _SurfacePresentation.bottomSheet;

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      // The scrim (dim + optional blur) is drawn inside the transition so it
      // fades as one unit with the surface.
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 340),
      pageBuilder: (_, _, _) => _AppSheetSurface(
        id: id,
        title: title,
        presentation: presentation,
        rememberedHeights: rememberedHeights,
        initialHeight: initialHeight,
        snapPoints: snapPoints,
        minHeight: minHeight,
        maxHeightFactor: maxHeightFactor,
        child: child,
      ),
      transitionBuilder: (context, animation, _, child) => _Backdrop(
        animation: animation,
        dialogMode: presentation == _SurfacePresentation.dialog,
        child: child,
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({
    required this.animation,
    required this.dialogMode,
    required this.child,
  });

  final Animation<double> animation;
  final bool dialogMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ).value;
        Widget scrim = GestureDetector(
          onTap: () => Navigator.maybeOf(context)?.maybePop(),
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.42 * t)),
        );
        if (AppSheet.enableBackdropBlur && t > 0) {
          final sigma = 12.0 * t;
          scrim = ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: scrim,
            ),
          );
        }
        return Stack(
          children: [
            Positioned.fill(child: scrim),
            if (dialogMode)
              Align(
                alignment: Alignment.center,
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.94, end: 1).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: child,
                  ),
                ),
              )
            else
              Align(
                alignment: Alignment.bottomCenter,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                          reverseCurve: Curves.easeInToLinear,
                        ),
                      ),
                  child: child,
                ),
              ),
          ],
        );
      },
    );
  }
}

enum _SurfacePresentation { bottomSheet, dialog }

class _AppSheetSurface extends StatefulWidget {
  const _AppSheetSurface({
    required this.id,
    required this.title,
    required this.child,
    required this.presentation,
    required this.rememberedHeights,
    required this.initialHeight,
    required this.snapPoints,
    required this.minHeight,
    required this.maxHeightFactor,
  });

  final String id;
  final String? title;
  final Widget child;
  final _SurfacePresentation presentation;
  final Map<String, double> rememberedHeights;
  final double initialHeight;
  final List<double> snapPoints;
  final double minHeight;
  final double maxHeightFactor;

  @override
  State<_AppSheetSurface> createState() => _AppSheetSurfaceState();
}

class _AppSheetSurfaceState extends State<_AppSheetSurface>
    with SingleTickerProviderStateMixin {
  static const _handleHeight = 28.0;
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 380,
    damping: 34,
  );

  late final AnimationController _position;
  late List<double> _snapsPx;
  late double _maxExtent;
  double _screenHeight = 0;

  @override
  void initState() {
    super.initState();
    _position = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screen = MediaQuery.sizeOf(context).height;
    if (screen == _screenHeight) return;
    final firstInit = _screenHeight == 0;
    _screenHeight = screen;
    _maxExtent = screen * widget.maxHeightFactor;
    final minPx = math.max(
      widget.minHeight,
      _handleHeight + kMinInteractiveDimension,
    );

    _snapsPx =
        (widget.snapPoints.isEmpty ? [widget.initialHeight] : widget.snapPoints)
            .map((f) => f.clamp(widget.minHeight / screen, 1.0) * screen)
            .toList()
          ..sort();

    if (!firstInit) return;
    final remembered = widget.rememberedHeights[widget.id];
    final startPx = (remembered != null)
        ? remembered * screen
        : _nearestSnap(_maxExtent * widget.initialHeight);
    _position.value = (startPx.clamp(minPx, _maxExtent)) / _maxExtent;
  }

  double get _heightPx => _position.value * _maxExtent;

  double _nearestSnap(double px) {
    var best = _snapsPx.first;
    for (final s in _snapsPx) {
      if ((s - px).abs() < (best - px).abs()) best = s;
    }
    return best.clamp(0, _maxExtent);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _position.stop();
    final minPx = math.min(_snapsPx.first * 0.55, widget.minHeight.toDouble());
    setState(() {
      _position.value =
          ((_heightPx - details.delta.dy).clamp(minPx, _maxExtent)) /
          _maxExtent;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final vy = -details.velocity.pixelsPerSecond.dy;
    final projected = _heightPx + vy * 0.12;

    // Hard downward fling dismisses outright.
    if (vy < -1400 && _heightPx < _snapsPx.first * 1.15) {
      _dismiss();
      return;
    }
    // Momentum carrying toward dismissal.
    if (projected < _snapsPx.first * 0.5) {
      _dismiss();
      return;
    }
    _settleTo(_nearestSnap(projected), velocityPxPerFraction: vy / _maxExtent);
  }

  void _settleTo(double px, {double velocityPxPerFraction = 0}) {
    _position
        .animateWith(
          SpringSimulation(
            _spring,
            _position.value,
            px / _maxExtent,
            velocityPxPerFraction,
          ),
        )
        .whenComplete(() {
          if (!mounted) return;
          widget.rememberedHeights[widget.id] =
              (_position.value * _maxExtent) / _screenHeight;
          HapticFeedback.selectionClick();
        });
  }

  void _dismiss() {
    Navigator.maybeOf(context)?.maybePop();
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final keyboard = viewInsets.bottom;
    final isDialog = widget.presentation == _SurfacePresentation.dialog;

    final EdgeInsets outerPadding;
    final BorderRadius radius;
    final Alignment alignment;
    if (isDialog) {
      // Keyboard insets shrink the centered area so the dialog floats above
      // the keyboard instead of behind it.
      outerPadding = EdgeInsets.fromLTRB(
        48,
        40,
        48,
        keyboard > 0 ? keyboard + 24 : 40,
      );
      radius = BorderRadius.circular(28);
      alignment = Alignment.center;
    } else {
      // Keyboard insets lift the sheet above the keyboard; otherwise it sits
      // flush with the safe area.
      outerPadding = EdgeInsets.only(
        bottom: keyboard > 0 ? keyboard : MediaQuery.paddingOf(context).bottom,
      );
      radius = const BorderRadius.vertical(top: Radius.circular(28));
      alignment = Alignment.bottomCenter;
    }

    return AnimatedBuilder(
      animation: _position,
      builder: (context, _) {
        final hPx = math.max(widget.minHeight, _heightPx);
        Widget sheet = SizedBox(
          height: hPx,
          child: Material(
            color: colorScheme.surfaceContainerLow,
            elevation: 16,
            shadowColor: Colors.black45,
            shape: RoundedRectangleBorder(borderRadius: radius),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                if (!isDialog)
                  _SheetHandle(
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                  ),
                if (widget.title != null)
                  SheetHeader(title: widget.title!, onClose: _dismiss),
                Flexible(child: widget.child),
              ],
            ),
          ),
        );

        // Cap width once there's room to breathe (large phones landscape /
        // tablets / desktop dialogs); center horizontally.
        if ((isDialog || width >= 600) && width > AppSheet.maxSheetWidth) {
          sheet = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSheet.maxSheetWidth),
            child: sheet,
          );
        }

        return Padding(
          padding: outerPadding,
          child: Align(alignment: alignment, child: sheet),
        );
      },
    );
  }
}

/// Drag handle shown at the top of bottom-sheet presentations. Extends the
/// drag gesture across its full row plus generous vertical hit slop.
class _SheetHandle extends StatelessWidget {
  const _SheetHandle({
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
  });

  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: onVerticalDragUpdate,
      onVerticalDragEnd: onVerticalDragEnd,
      child: SizedBox(
        height: _AppSheetSurfaceState._handleHeight,
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

/// Standard sheet header: title on the left, close button on the right.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
        ],
      ),
    );
  }
}
