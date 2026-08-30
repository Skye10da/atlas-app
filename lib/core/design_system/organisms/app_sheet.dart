import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:atlas_app/settings/domain/value_objects/desktop_sheet_presentation.dart';
export 'package:atlas_app/settings/domain/value_objects/desktop_sheet_presentation.dart';

/// Presentation mode preference for adaptive sheets.
enum AppSheetMode {
  /// Intelligently resolves presentation based on device width and orientation.
  auto,

  /// Anchored to the bottom of the viewport with drag-to-dismiss and snap points.
  bottomSheet,

  /// Anchored to the right side of the viewport (ideal for widescreen/desktop).
  sideSheet,

  /// Floating centered modal card.
  dialog,
}

/// Internal resolved surface presentation.
enum _SurfacePresentation {
  bottomSheet,
  sideSheet,
  dialog,
  splitLandscape,
}

/// Modern adaptive modal sheet and side panel system (AppSheet 2.0).
///
/// Features:
/// - Adaptive layout: Mobile portrait bottom sheet, mobile landscape split-sheet,
///   tablet floating card, and desktop modal or right-docked side sheet.
/// - Dynamic auto-sizing (`fitToContent: true`) for compact popups/footnotes.
/// - Fluid nested-scroll coordination (overscroll at list top pulls the sheet).
/// - Zero-allocation drag pipeline with critically-damped spring physics.
/// - Smooth IME/virtual keyboard tracking.
/// - In-sheet multi-step navigation (`SheetNavigator`).
/// - GPU-optimized backdrop blur pipeline with performance fallbacks.
class AppSheet {
  AppSheet._();

  /// Width at or above which sheets become floating dialogs or side sheets.
  static const double desktopBreakpoint = 840;

  /// Maximum content width for tablet/desktop presentations.
  static const double maxSheetWidth = 640;

  /// Maximum content width for landscape split-sheet presentations.
  static const double maxLandscapeSheetWidth = 420;

  /// Whether frosted-glass backdrop is rendered behind open sheets.
  static bool enableBackdropBlur = !kIsWeb;

  /// Desktop presentation preference, synced from user settings.
  static DesktopSheetPresentation desktopPresentation =
      DesktopSheetPresentation.dialog;

  /// Session-scoped memory of each sheet's last height, keyed by [id].
  static final Map<String, double> rememberedHeights = {};

  /// Session-scoped memory of each sheet's last dock state on desktop (docked vs centered), keyed by [id].
  static final Map<String, bool> rememberedDockStates = {};

  /// Presents [child] in an adaptive modal sheet or side panel.
  static Future<T?> show<T>({
    required BuildContext context,
    required String id,
    required Widget child,
    String? title,
    String? subtitle,
    Widget? leadingAction,
    List<Widget> trailingActions = const [],
    AppSheetMode mode = AppSheetMode.auto,
    bool fitToContent = false,
    double initialHeight = 0.5,
    List<double> snapPoints = const [],
    double minHeight = 120,
    double maxHeightFactor = 0.92,
    double maxWidth = maxSheetWidth,
    bool enableNestedScroll = true,
    bool dismissible = true,
    VoidCallback? onDismissed,
    void Function(double snapFraction)? onSnapChanged,
  }) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final height = size.height;
    final isLandscape = width > height && height < 540;

    final _SurfacePresentation presentation;
    switch (mode) {
      case AppSheetMode.dialog:
        presentation = _SurfacePresentation.dialog;
        break;
      case AppSheetMode.sideSheet:
        presentation = _SurfacePresentation.sideSheet;
        break;
      case AppSheetMode.bottomSheet:
        presentation = _SurfacePresentation.bottomSheet;
        break;
      case AppSheetMode.auto:
        if (width >= desktopBreakpoint) {
          presentation = desktopPresentation == DesktopSheetPresentation.sidePanel
              ? _SurfacePresentation.sideSheet
              : _SurfacePresentation.dialog;
        } else if (isLandscape) {
          presentation = _SurfacePresentation.splitLandscape;
        } else {
          presentation = _SurfacePresentation.bottomSheet;
        }
        break;
    }

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => _AppSheetSurface(
        id: id,
        title: title,
        subtitle: subtitle,
        leadingAction: leadingAction,
        trailingActions: trailingActions,
        presentation: presentation,
        rememberedHeights: rememberedHeights,
        rememberedDockStates: rememberedDockStates,
        fitToContent: fitToContent,
        initialHeight: initialHeight,
        snapPoints: snapPoints,
        minHeight: minHeight,
        maxHeightFactor: maxHeightFactor,
        maxWidth: maxWidth,
        enableNestedScroll: enableNestedScroll,
        dismissible: dismissible,
        onDismissed: onDismissed,
        onSnapChanged: onSnapChanged,
        child: child,
      ),
      transitionBuilder: (context, animation, _, child) => _Backdrop(
        animation: animation,
        presentation: presentation,
        dismissible: dismissible,
        child: child,
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({
    required this.animation,
    required this.presentation,
    required this.dismissible,
    required this.child,
  });

  final Animation<double> animation;
  final _SurfacePresentation presentation;
  final bool dismissible;
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
          onTap: dismissible ? () => Navigator.maybeOf(context)?.maybePop() : null,
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.42 * t)),
        );

        if (AppSheet.enableBackdropBlur && t > 0.05) {
          final sigma = 0.1 * t;
          scrim = RepaintBoundary(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: scrim,
              ),
            ),
          );
        }

        final Widget transitionedChild;
        switch (presentation) {
          case _SurfacePresentation.dialog:
            transitionedChild = FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                ),
                child: child,
              ),
            );
            break;

          case _SurfacePresentation.sideSheet:
          case _SurfacePresentation.splitLandscape:
            transitionedChild = Align(
              alignment: Alignment.centerRight,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
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
            );
            break;

          case _SurfacePresentation.bottomSheet:
            transitionedChild = Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: Tween<Offset>(
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
            );
            break;
        }

        return Stack(
          children: [
            Positioned.fill(child: scrim),
            transitionedChild,
          ],
        );
      },
    );
  }
}

class _AppSheetSurface extends StatefulWidget {
  const _AppSheetSurface({
    required this.id,
    required this.title,
    this.subtitle,
    this.leadingAction,
    this.trailingActions = const [],
    required this.child,
    required this.presentation,
    required this.rememberedHeights,
    required this.rememberedDockStates,
    required this.fitToContent,
    required this.initialHeight,
    required this.snapPoints,
    required this.minHeight,
    required this.maxHeightFactor,
    required this.maxWidth,
    required this.enableNestedScroll,
    required this.dismissible,
    this.onDismissed,
    this.onSnapChanged,
  });

  final String id;
  final String? title;
  final String? subtitle;
  final Widget? leadingAction;
  final List<Widget> trailingActions;
  final Widget child;
  final _SurfacePresentation presentation;
  final Map<String, double> rememberedHeights;
  final Map<String, bool> rememberedDockStates;
  final bool fitToContent;
  final double initialHeight;
  final List<double> snapPoints;
  final double minHeight;
  final double maxHeightFactor;
  final double maxWidth;
  final bool enableNestedScroll;
  final bool dismissible;
  final VoidCallback? onDismissed;
  final void Function(double snapFraction)? onSnapChanged;

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
  bool _isDragging = false;
  bool _isDockedAtBottom = false;
  double _dragAccumulator = 0;

  @override
  void initState() {
    super.initState();
    _position = AnimationController(vsync: this);
    _isDockedAtBottom = widget.rememberedDockStates[widget.id] ?? false;
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

  void _onDragStart() {
    _isDragging = true;
    _dragAccumulator = 0;
    _position.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) _onDragStart();
    _dragAccumulator += details.delta.dy;

    if (widget.presentation == _SurfacePresentation.dialog) {
      // In desktop dialog mode, dragging down docks at bottom; dragging up floats to center
      if (!_isDockedAtBottom && _dragAccumulator > 60) {
        setState(() {
          _isDockedAtBottom = true;
          widget.rememberedDockStates[widget.id] = true;
          _dragAccumulator = 0;
          _isDragging = false;
        });
        HapticFeedback.selectionClick();
        return;
      } else if (_isDockedAtBottom && _dragAccumulator < -60) {
        setState(() {
          _isDockedAtBottom = false;
          widget.rememberedDockStates[widget.id] = false;
          _dragAccumulator = 0;
          _isDragging = false;
        });
        HapticFeedback.selectionClick();
        return;
      }
    }

    final minPx = math.min(_snapsPx.first * 0.55, widget.minHeight);
    _position.value =
        ((_heightPx - details.delta.dy).clamp(minPx, _maxExtent)) / _maxExtent;
  }

  void _onDragEnd(DragEndDetails details) {
    _isDragging = false;
    final vy = -details.velocity.pixelsPerSecond.dy;

    if (widget.presentation == _SurfacePresentation.dialog) {
      if (!_isDockedAtBottom && (vy < -350 || _dragAccumulator > 30)) {
        setState(() {
          _isDockedAtBottom = true;
          widget.rememberedDockStates[widget.id] = true;
        });
        HapticFeedback.selectionClick();
        return;
      } else if (_isDockedAtBottom && (vy > 350 || _dragAccumulator < -30)) {
        setState(() {
          _isDockedAtBottom = false;
          widget.rememberedDockStates[widget.id] = false;
        });
        HapticFeedback.selectionClick();
        return;
      }
    }

    final projected = _heightPx + vy * 0.12;

    if (widget.dismissible) {
      // Hard downward fling dismisses outright
      if (vy < -1400 && _heightPx < _snapsPx.first * 1.15) {
        _dismiss();
        return;
      }
      // Momentum carrying toward dismissal
      if (projected < _snapsPx.first * 0.5) {
        _dismiss();
        return;
      }
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
          final fraction = (_position.value * _maxExtent) / _screenHeight;
          widget.rememberedHeights[widget.id] = fraction;
          widget.onSnapChanged?.call(fraction);
          HapticFeedback.selectionClick();
        });
  }

  void _dismiss() {
    widget.onDismissed?.call();
    Navigator.maybeOf(context)?.maybePop();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!widget.enableNestedScroll ||
        widget.presentation != _SurfacePresentation.bottomSheet) {
      return false;
    }

    if (notification is OverscrollNotification && notification.overscroll < 0) {
      // Pulling down at top of list
      _onDragStart();
      final minPx = math.min(_snapsPx.first * 0.55, widget.minHeight);
      _position.value =
          ((_heightPx - notification.overscroll * 0.6).clamp(minPx, _maxExtent)) /
          _maxExtent;
      return true;
    } else if (notification is ScrollEndNotification && _isDragging) {
      _onDragEnd(
        DragEndDetails(
          velocity: Velocity(
            pixelsPerSecond: Offset(
              0,
              notification.dragDetails?.primaryVelocity ?? 0,
            ),
          ),
        ),
      );
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final height = size.height;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final keyboard = viewInsets.bottom;
    final isDialog = widget.presentation == _SurfacePresentation.dialog;
    final isSide = widget.presentation == _SurfacePresentation.sideSheet ||
        widget.presentation == _SurfacePresentation.splitLandscape;

    final EdgeInsets outerPadding;
    final BorderRadius radius;
    final Alignment alignment;

    if (isDialog) {
      if (_isDockedAtBottom) {
        outerPadding = EdgeInsets.only(
          bottom: keyboard > 0 ? keyboard : MediaQuery.paddingOf(context).bottom,
        );
        radius = const BorderRadius.vertical(top: Radius.circular(28));
        alignment = Alignment.bottomCenter;
      } else {
        outerPadding = EdgeInsets.fromLTRB(
          32,
          32,
          32,
          keyboard > 0 ? keyboard + 20 : 32,
        );
        radius = BorderRadius.circular(28);
        alignment = Alignment.center;
      }
    } else if (isSide) {
      outerPadding = EdgeInsets.only(
        right: 0,
        top: MediaQuery.paddingOf(context).top,
        bottom: keyboard > 0 ? keyboard : MediaQuery.paddingOf(context).bottom,
      );
      radius = const BorderRadius.horizontal(left: Radius.circular(24));
      alignment = Alignment.centerRight;
    } else {
      outerPadding = EdgeInsets.only(
        bottom: keyboard > 0 ? keyboard : MediaQuery.paddingOf(context).bottom,
      );
      radius = const BorderRadius.vertical(top: Radius.circular(28));
      alignment = Alignment.bottomCenter;
    }

    final double effectiveMaxWidth;
    if (widget.presentation == _SurfacePresentation.splitLandscape) {
      effectiveMaxWidth = math.min(widget.maxWidth, AppSheet.maxLandscapeSheetWidth);
    } else if (isSide) {
      effectiveMaxWidth = math.min(widget.maxWidth, 460);
    } else {
      effectiveMaxWidth = widget.maxWidth;
    }

    final effectiveTrailing = [
      ...widget.trailingActions,
      if (isDialog)
        IconButton(
          icon: Icon(
            _isDockedAtBottom
                ? Icons.open_in_full_rounded
                : Icons.vertical_align_bottom_rounded,
            size: 18,
          ),
          tooltip: _isDockedAtBottom ? 'Float to center' : 'Dock at bottom',
          onPressed: () {
            setState(() {
              _isDockedAtBottom = !_isDockedAtBottom;
              widget.rememberedDockStates[widget.id] = _isDockedAtBottom;
            });
          },
          visualDensity: VisualDensity.compact,
        ),
    ];

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            widget.dismissible) {
          _dismiss();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedBuilder(
        animation: _position,
        builder: (context, _) {
          final double hPx;
          if (widget.fitToContent) {
            hPx = double.infinity;
          } else if (isSide) {
            hPx = height;
          } else if (isDialog) {
            hPx = math.min(_maxExtent, _screenHeight * widget.initialHeight);
          } else {
            hPx = math.max(widget.minHeight, _heightPx);
          }

          Widget contentBody = Column(
            mainAxisSize: widget.fitToContent
                ? MainAxisSize.min
                : MainAxisSize.max,
            children: [
              if (!isSide)
                _SheetHandle(
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                ),
              if (widget.title != null ||
                  widget.leadingAction != null ||
                  effectiveTrailing.isNotEmpty)
                SheetHeader(
                  title: widget.title ?? '',
                  subtitle: widget.subtitle,
                  leading: widget.leadingAction,
                  trailing: effectiveTrailing,
                  onClose: widget.dismissible ? _dismiss : () {},
                ),
              if (widget.fitToContent)
                Flexible(fit: FlexFit.loose, child: widget.child)
              else
                Expanded(child: widget.child),
            ],
          );

          if (widget.enableNestedScroll && !isDialog) {
            contentBody = NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: contentBody,
            );
          }

          Widget sheet = Material(
            color: colorScheme.surfaceContainerLow,
            elevation: 16,
            shadowColor: Colors.black45,
            shape: RoundedRectangleBorder(borderRadius: radius),
            clipBehavior: Clip.antiAlias,
            child: contentBody,
          );

          if (widget.fitToContent) {
            sheet = ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: _maxExtent,
                minHeight: widget.minHeight,
              ),
              child: sheet,
            );
          } else {
            sheet = SizedBox(height: hPx, child: sheet);
          }

          if ((isDialog || width >= 600 || isSide) && width > effectiveMaxWidth) {
            sheet = ConstrainedBox(
              constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
              child: sheet,
            );
          }

          return SizedBox.expand(
            child: RepaintBoundary(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: outerPadding,
                child: Align(alignment: alignment, child: sheet),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Drag handle shown at the top of bottom-sheet presentations.
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

/// Standard sheet header with leading slot, title, optional subtitle,
/// trailing action controls, and close button.
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing = const [],
    required this.onClose,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> trailing;
  final VoidCallback onClose;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 4),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: onBack,
              visualDensity: VisualDensity.compact,
            )
          else if (leading != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: leading!,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          ...trailing,
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// In-sheet navigation container allowing multi-step sub-flows
/// with smooth sliding transitions within a single sheet.
class SheetNavigator extends StatefulWidget {
  const SheetNavigator({
    super.key,
    required this.initialPage,
    this.onPageChanged,
  });

  final Widget initialPage;
  final void Function(int depth)? onPageChanged;

  static SheetNavigatorState of(BuildContext context) {
    final state = context.findAncestorStateOfType<SheetNavigatorState>();
    assert(state != null, 'No SheetNavigator found in context');
    return state!;
  }

  @override
  State<SheetNavigator> createState() => SheetNavigatorState();
}

class SheetNavigatorState extends State<SheetNavigator> {
  final List<Widget> _stack = [];

  @override
  void initState() {
    super.initState();
    _stack.add(widget.initialPage);
  }

  int get depth => _stack.length;
  bool get canPop => _stack.length > 1;

  void push(Widget page) {
    setState(() {
      _stack.add(page);
    });
    widget.onPageChanged?.call(_stack.length);
  }

  bool pop() {
    if (!canPop) return false;
    setState(() {
      _stack.removeLast();
    });
    widget.onPageChanged?.call(_stack.length);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, animation) {
        final inAnimation = Tween<Offset>(
          begin: const Offset(0.2, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return SlideTransition(
          position: inAnimation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_stack.length),
        child: _stack.last,
      ),
    );
  }
}
