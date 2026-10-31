// Atlas glass navigation chrome: glassmorphism base + Liquid Glass behaviour.
//
// From glassmorphism: backdrop blur, translucent fill, frosted look
//   (cheap, works on every Flutter target incl. Web/Windows/Linux).
// From Liquid Glass: floating capsule, vibrancy boost, specular edge light,
//   a "lens" pill that slides on a spring, stretches with velocity,
//   swells while pressed, and can be dragged across tabs.
//
// Surfaces derived from the same core:
//   * [AtlasGlassNavBar] â€” horizontal capsule for the mobile bottom bar.
//   * [AtlasGlassRail]   â€” vertical capsule for tablet/desktop side docks.
//   * [GlassLens]        â€” the accent "droplet" pill, reused by the glass
//     desktop sidebar for its nav indicator.
//
// All nav variants support one optional ACTION slot (Atlas' centre "+"),
// which is a member of the row but never a navigation destination: the lens
// skips it and hit-testing resolves away from it.

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';

// Glass primitives ([GlassCapsule], [GlassLens]) live in molecules/
// glass_surfaces.dart; re-exported here so the existing organism import keeps
// working for shells and older call sites.
export 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart'
    show GlassCapsule, GlassLens;

class AtlasNavItem {
  const AtlasNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// A mid-nav action (Atlas' "add book"). Occupies one slot, never selected.
class AtlasNavAction {
  const AtlasNavAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;
}

/// Horizontal (bottom bar) glass navigation capsule with a centre action slot.
class AtlasGlassNavBar extends StatelessWidget {
  const AtlasGlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    this.action,
    this.actionSlot,
    this.accent,
    this.height = 68,
    this.blur = 28,
  }) : assert(items.length >= 2);

  final List<AtlasNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final AtlasNavAction? action;

  /// Insertion index of [action] among `items.length + 1` slots; defaults to
  /// the centre (ceil(items.length / 2)) splitting both halves evenly.
  final int? actionSlot;
  final Color? accent;
  final double height;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: _GlassNavCore(
          axis: Axis.horizontal,
          items: items,
          action: action,
          actionSlot: actionSlot,
          currentIndex: currentIndex,
          onChanged: onChanged,
          accent: accent,
          thickness: height,
          blur: blur,
          labelSize: 11,
        ),
      ),
    );
  }
}

/// Vertical (side dock) glass navigation capsule for tablet/desktop shells.
class AtlasGlassRail extends StatelessWidget {
  const AtlasGlassRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    this.action,
    this.actionSlot,
    this.accent,
    this.width = 76,
    this.blur = 24,
  }) : assert(items.length >= 2);

  final List<AtlasNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final AtlasNavAction? action;
  final int? actionSlot;
  final Color? accent;
  final double width;
  final double blur;

  @override
  Widget build(BuildContext context) {
    // Bound the cross axis explicitly: when placed in a Stack as a
    // Positioned(left/top/bottom) child, Stack hands this widget an
    // unconstrained width, which the internal Column then propagates.
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: width,
        child: _GlassNavCore(
          axis: Axis.vertical,
          items: items,
          action: action,
          actionSlot: actionSlot,
          currentIndex: currentIndex,
          onChanged: onChanged,
          accent: accent,
          thickness: width,
          blur: blur,
          labelSize: 10,
        ),
      ),
    );
  }
}

/// Shared spring/lens engine for both axes.
///
/// Slot space: slots are laid out uniformly ([Row]/[Column] Expanded) and the
/// destination mapping skips the action slot. The controller runs in SLOT
/// units, so a 5-slot bar with the action at slot 2 animates dest 0â†’1 across
/// slots 0â†’1 and dest 1â†’2 across slots 1â†’3 â€” the lens glides over the "+"
/// without stopping on it.
class _GlassNavCore extends StatefulWidget {
  const _GlassNavCore({
    required this.axis,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    required this.thickness,
    required this.blur,
    required this.labelSize,
    this.action,
    this.actionSlot,
    this.accent,
  });

  final Axis axis;
  final List<AtlasNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final AtlasNavAction? action;
  final int? actionSlot;
  final Color? accent;

  /// Cross-axis size of the capsule (bar height / rail width).
  final double thickness;

  final double blur;
  final double labelSize;

  @override
  State<_GlassNavCore> createState() => _GlassNavCoreState();
}

class _GlassNavCoreState extends State<_GlassNavCore>
    with SingleTickerProviderStateMixin {
  // Slightly underdamped => a small, liquid overshoot.
  static const _spring = SpringDescription(mass: 1, stiffness: 220, damping: 18);
  static const _pad = 6.0;

  late final AnimationController _ctrl;
  late double _slotExtent;
  bool _pressed = false;

  int get _slotCount => widget.items.length + (widget.action != null ? 1 : 0);

  int _effectiveActionSlot() {
    final n = widget.items.length;
    return widget.action == null
        ? -1
        : (widget.actionSlot ?? n ~/ 2).clamp(0, n);
  }

  /// Slot index of destination [destIndex].
  int _slotOf(int destIndex) =>
      _effectiveActionSlot() <= destIndex ? destIndex + 1 : destIndex;

  /// Destination index of the destination-flavoured slot nearest to raw slot
  /// index [slot]. Returns -1 for the action slot when it has no closer
  /// destination (never happens: action is never at the outer edges).
  int _destFromSlot(int slot) {
    if (slot == _effectiveActionSlot()) return -1;
    // The action slot belongs to whichever neighbouring destination the
    // rounding landed on; incoming slots never knowingly round to the action
    // slot except from a direct tap, which is handled separately above.
    return switch (_effectiveActionSlot()) {
      -1 => slot.clamp(0, widget.items.length - 1),
      final a => (slot >= a) ? slot - 1 : slot,
    };
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController.unbounded(
      vsync: this,
      value: _slotOf(widget.currentIndex).toDouble(),
    );
    _slotExtent = 0;
  }

  @override
  void didUpdateWidget(_GlassNavCore old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex && !_pressed) {
      _animateTo(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _animateTo(int destIndex) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.value = _slotOf(destIndex).toDouble();
      return;
    }
    _ctrl.animateWith(
      SpringSimulation(
        _spring,
        _ctrl.value,
        _slotOf(destIndex).toDouble(),
        _ctrl.velocity,
      ),
    );
  }

  void _select(int destIndex) {
    if (destIndex == widget.currentIndex || destIndex < 0) return;
    HapticFeedback.selectionClick();
    widget.onChanged(destIndex);
  }

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  double _axisOffset(Offset local) =>
      widget.axis == Axis.horizontal ? local.dx : local.dy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.accent ?? theme.colorScheme.primary;
    final inactive = isDark
        ? const Color.fromRGBO(255, 255, 255, 0.62)
        : const Color.fromRGBO(0, 0, 0, 0.55);
    final active = isDark ? Colors.white : accent;
    final actionSlot = _effectiveActionSlot();
    final horizontal = widget.axis == Axis.horizontal;
    final radius = widget.thickness / 2;

    return LayoutBuilder(
      builder: (context, c) {
        final track = horizontal ? c.maxWidth : c.maxHeight;
        final slotW = (track - _pad * 2) / _slotCount;
        _slotExtent = slotW;
        final lensTrack = widget.thickness - _pad * 2;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (d) {
            _setPressed(false);
            final raw = (_axisOffset(d.localPosition) - _pad) / slotW;
            final slot = raw.floor().clamp(0, _slotCount - 1);
            if (slot == actionSlot) {
              HapticFeedback.selectionClick();
              widget.action?.onTap();
              return;
            }
            final dest = _destFromSlot(slot);
            if (dest >= 0) _select(dest);
          },
          onHorizontalDragStart: horizontal ? _dragStart : null,
          onHorizontalDragUpdate: horizontal ? _dragUpdate : null,
          onHorizontalDragEnd: horizontal ? _dragEnd : null,
          onVerticalDragStart: horizontal ? null : _dragStart,
          onVerticalDragUpdate: horizontal ? null : _dragUpdate,
          onVerticalDragEnd: horizontal ? null : _dragEnd,
          child: CustomPaint(
            painter: GlassDropShadowPainter(radius: radius, isDark: isDark),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ImageFilter.compose(
                  outer: ColorFilter.matrix(glassSaturation(1.6)),
                  inner: ImageFilter.blur(
                    sigmaX: widget.blur,
                    sigmaY: widget.blur,
                  ),
                ),
                child: CustomPaint(
                  foregroundPainter: GlassSpecularBorderPainter(
                    radius: radius,
                    isDark: isDark,
                    width: 1.2,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? const [
                                Color.fromRGBO(255, 255, 255, 0.12),
                                Color.fromRGBO(255, 255, 255, 0.04),
                              ]
                            : const [
                                Color.fromRGBO(255, 255, 255, 0.60),
                                Color.fromRGBO(255, 255, 255, 0.30),
                              ],
                      ),
                    ),
                    child: AnimatedBuilder(
                      animation: _ctrl,
                      builder: (context, _) {
                        final pos = _ctrl.value;
                        // Stretch along motion, squash on the other axis.
                        final stretch =
                            (_ctrl.velocity.abs() * 0.035).clamp(0.0, 0.35);

                        final Widget lens = Positioned(
                          left: horizontal
                              ? _pad + pos * slotW
                              : _pad,
                          top: horizontal ? _pad : _pad + pos * slotW,
                          width: horizontal ? slotW : lensTrack,
                          height: horizontal ? lensTrack : slotW,
                          child: AnimatedScale(
                            scale: _pressed ? 1.12 : 1.0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutBack,
                            child: Transform.scale(
                              alignment: Alignment.center,
                              scaleX: horizontal ? 1 + stretch : 1 - stretch * 0.45,
                              scaleY: horizontal ? 1 - stretch * 0.45 : 1 + stretch,
                              child: GlassLens(
                                accent: accent,
                                isDark: isDark,
                                radius: lensTrack / 2,
                              ),
                            ),
                          ),
                        );

                        final List<Widget> slots = [
                          for (var s = 0; s < _slotCount; s++)
                            if (s == actionSlot)
                              _ActionSlot(
                                widget: widget,
                                horizontal: horizontal,
                              )
                            else
                              _NavButton(
                                item: widget.items[_destFromSlot(s)],
                                t: (1 - (pos - s).abs()).clamp(0.0, 1.0),
                                horizontal: horizontal,
                                inactive: inactive,
                                active: active,
                                selected: _destFromSlot(s) == widget.currentIndex,
                                labelSize: widget.labelSize,
                              ),
                        ];

                        return Stack(
                          children: [
                            lens,
                            Padding(
                              padding: const EdgeInsets.all(_pad),
                              child: horizontal
                                  ? Row(children: [...slots.map((w) => Expanded(child: w))])
                                  : Column(
                                      children: [...slots.map((w) => Expanded(child: w))],
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _dragStart(DragStartDetails d) {
    _ctrl.stop();
    _setPressed(true);
    _ctrl.value = (_axisOffset(d.localPosition) - _pad) / _slotExtent - 0.5;
  }

  void _dragUpdate(DragUpdateDetails d) {
    _ctrl.value = (_axisOffset(d.localPosition) - _pad) / _slotExtent - 0.5;
  }

  void _dragEnd(DragEndDetails d) {
    _setPressed(false);
    final velocity = widget.axis == Axis.horizontal
        ? d.velocity.pixelsPerSecond.dx
        : d.velocity.pixelsPerSecond.dy;
    // Project a little with the fling velocity, then snap.
    final projected = _ctrl.value + (velocity / _slotExtent) * 0.12;
    final rawSlot = projected.round().clamp(0, _slotCount - 1);
    final dest = _destFromSlot(rawSlot);
    if (dest < 0) {
      // Fell on the action slot via rounding: snap to the nearer neighbor.
      final fallback = _ctrl.value > _slotOf(widget.currentIndex).toDouble()
          ? widget.currentIndex + 1
          : widget.currentIndex - 1;
      if (fallback < 0 || fallback >= widget.items.length) {
        _animateTo(widget.currentIndex);
        return;
      }
      _animateTo(fallback);
      _select(fallback);
      return;
    }
    _animateTo(dest);
    _select(dest);
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.t,
    required this.horizontal,
    required this.inactive,
    required this.active,
    required this.selected,
    required this.labelSize,
  });

  final AtlasNavItem item;
  final double t;
  final bool horizontal;
  final Color inactive;
  final Color active;
  final bool selected;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(inactive, active, t)!;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: ExcludeSemantics(
        // Factor 1: size the cross axis to the child instead of filling it â€”
        // filling would stretch the capsule to the full bottomNavigationBar
        // height (or width in vertical mode).
        child: Center(
          heightFactor: horizontal ? 1 : null,
          widthFactor: horizontal ? null : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 1 + 0.12 * t,
                child: Icon(
                  t > 0.5 ? item.activeIcon : item.icon,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: labelSize,
                  height: 1,
                  color: color,
                  fontWeight:
                      FontWeight.lerp(FontWeight.w500, FontWeight.w700, t),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionSlot extends StatelessWidget {
  const _ActionSlot({required this.widget, required this.horizontal});

  final _GlassNavCore widget;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final action = widget.action!;
    return Semantics(
      button: true,
      label: 'Add book',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Material(
            color: cs.primary,
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: action.onTap,
              child: SizedBox(
                // Fill the slot along the nav axis, but keep the CROSS axis
                // bounded: a double.infinity here propagates an unbounded
                // extent to the slot Row/Column, which in Scaffold's
                // bottomNavigationBar slot grows the capsule to full screen.
                width: horizontal
                    ? double.infinity
                    : widget.thickness - _GlassNavCoreState._pad * 2 - 6,
                height: horizontal
                    ? widget.thickness - _GlassNavCoreState._pad * 2 - 6
                    : double.infinity,
                child: Icon(
                  action.icon,
                  size: horizontal ? 26 : 22,
                  color: cs.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
