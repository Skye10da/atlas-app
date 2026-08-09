import 'dart:ui';

import 'package:flutter/material.dart';

final class AppContextMenuAction {
  const AppContextMenuAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool destructive;
}

final class AppContextMenuHighlightOption {
  const AppContextMenuHighlightOption({required this.color, this.label});

  final Color color;
  final String? label;
}

/// A modern, glass-styled context menu for text selection.
///
/// Layout (top to bottom, each section optional):
///   1. Highlight color swatches
///   2. Icon-only quick actions (e.g. Copy, Note, Share)
///   3. Full-width labeled list actions (e.g. Define, Search, Select all)
class AppContextMenu extends StatelessWidget {
  const AppContextMenu({
    super.key,
    required this.anchor,
    this.highlightColors = const [],
    this.onHighlightSelected,
    this.quickActions = const [],
    this.listActions = const [],
    this.onDismiss,
    this.externallyPositioned = false,
  });

  /// Overlay-space point the menu should anchor near — pass
  /// `editable.contextMenuAnchors.primaryAnchor` from your builder.
  final Offset anchor;

  /// Leave empty to hide the highlight row entirely.
  final List<AppContextMenuHighlightOption> highlightColors;
  final void Function(Color color)? onHighlightSelected;

  /// Icon-only quick actions shown in an equally-spaced row.
  final List<AppContextMenuAction> quickActions;

  /// Full-width labeled rows.
  final List<AppContextMenuAction> listActions;

  final VoidCallback? onDismiss;

  /// When true, the menu renders without its own [CustomSingleChildLayout]
  /// positioning wrapper, so the parent decides placement (e.g. pdfrx's
  /// built-in `Positioned` for the selection context menu). [anchor] is ignored
  /// in this mode.
  final bool externallyPositioned;

  /// Builds an [EditableTextContextMenuBuilder] and hands you the resolved
  /// anchor point so you don't have to compute it yourself at each call site.
  static EditableTextContextMenuBuilder builder({
    required AppContextMenu Function(
      BuildContext context,
      EditableTextState editable,
      Offset anchor,
    ) build,
  }) {
    return (context, editable) =>
        build(context, editable, editable.contextMenuAnchors.primaryAnchor);
  }

  void _dismiss() {
    onDismiss?.call();
    ContextMenuController.removeAny();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);

    final hasHighlights = highlightColors.isNotEmpty;
    final hasQuickActions = quickActions.isNotEmpty;
    final hasListActions = listActions.isNotEmpty;

    final divider = Divider(
      height: 1,
      thickness: 1,
      color: colors.outlineVariant.withValues(alpha: 0.3),
    );

    final panel = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.9 + (0.1 * value),
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasHighlights)
                  _HighlightRow(
                    options: highlightColors,
                    onSelected: (color) {
                      onHighlightSelected?.call(color);
                      _dismiss();
                    },
                  ),
                if (hasHighlights && hasQuickActions) divider,
                if (hasQuickActions)
                  _QuickActionRow(
                    actions: quickActions,
                    onTapAction: (action) {
                      action.onPressed();
                      _dismiss();
                    },
                  ),
                if ((hasHighlights || hasQuickActions) && hasListActions)
                  divider,
                for (final action in listActions)
                  _AppContextMenuListItem(
                    action: action,
                    onTap: () {
                      action.onPressed();
                      _dismiss();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (externallyPositioned) return panel;
    return CustomSingleChildLayout(
      delegate: _MenuPositionDelegate(
        anchor: anchor,
        safePadding: mq.padding + const EdgeInsets.all(8),
      ),
      child: panel,
    );
  }
}

/// Positions the menu near [anchor] (the selection midpoint), clamped so it
/// never spills off-screen or gets swallowed by the notch/status bar.
class _MenuPositionDelegate extends SingleChildLayoutDelegate {
  _MenuPositionDelegate({required this.anchor, required this.safePadding});

  final Offset anchor;
  final EdgeInsets safePadding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxDx = (size.width - childSize.width - safePadding.right)
        .clamp(safePadding.left, size.width);
    final maxDy = (size.height - childSize.height - safePadding.bottom)
        .clamp(safePadding.top, size.height);

    final dx = (anchor.dx - childSize.width / 2).clamp(safePadding.left, maxDx);
    final dy = (anchor.dy + 12).clamp(safePadding.top, maxDy);

    return Offset(dx, dy);
  }

  @override
  bool shouldRelayout(covariant _MenuPositionDelegate oldDelegate) =>
      anchor != oldDelegate.anchor;
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({required this.options, required this.onSelected});

  final List<AppContextMenuHighlightOption> options;
  final void Function(Color color) onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final option in options)
            _HighlightSwatch(
              option: option,
              onTap: () => onSelected(option.color),
            ),
        ],
      ),
    );
  }
}

class _HighlightSwatch extends StatefulWidget {
  const _HighlightSwatch({required this.option, required this.onTap});

  final AppContextMenuHighlightOption option;
  final VoidCallback onTap;

  @override
  State<_HighlightSwatch> createState() => _HighlightSwatchState();
}

class _HighlightSwatchState extends State<_HighlightSwatch> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.option.label ?? 'Highlight',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: widget.option.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: widget.option.color.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({required this.actions, required this.onTapAction});

  final List<AppContextMenuAction> actions;
  final void Function(AppContextMenuAction action) onTapAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final action in actions)
            Expanded(
              child: _QuickActionButton(
                action: action,
                onTap: () => onTapAction(action),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  const _QuickActionButton({required this.action, required this.onTap});

  final AppContextMenuAction action;
  final VoidCallback onTap;

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = widget.action.destructive ? colors.error : colors.onSurface;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _hovered
                      ? color.withValues(alpha: 0.1)
                      : color.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.action.icon, size: 18, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                widget.action.label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: color.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppContextMenuListItem extends StatefulWidget {
  const _AppContextMenuListItem({required this.action, required this.onTap});

  final AppContextMenuAction action;
  final VoidCallback onTap;

  @override
  State<_AppContextMenuListItem> createState() =>
      _AppContextMenuListItemState();
}

class _AppContextMenuListItemState extends State<_AppContextMenuListItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final iconColor =
        widget.action.destructive ? colors.error : colors.onSurfaceVariant;
    final textColor =
        widget.action.destructive ? colors.error : colors.onSurface;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapCancel: () => setState(() => _isPressed = false),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          color: _isPressed
              ? colors.onSurface.withValues(alpha: 0.1)
              : _isHovered
                  ? colors.onSurface.withValues(alpha: 0.06)
                  : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.action.icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.action.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
