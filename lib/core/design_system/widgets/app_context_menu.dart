import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';

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
///   1. Formatting style selector (Solid, Underline, Wavy, Strikethrough, Bold, Italic)
///   2. Highlight color swatches
///   3. Icon-only quick actions (e.g. Copy, Note, Share)
///   4. Full-width labeled list actions (e.g. Define, Search, Select all)
class AppContextMenu extends HookWidget {
  const AppContextMenu({
    super.key,
    required this.anchor,
    this.highlightColors = const [],
    this.onHighlightSelected,
    this.onHighlightWithStyle,
    this.initialStyle = HighlightStyleType.solid,
    this.quickActions = const [],
    this.listActions = const [],
    this.onDismiss,
    this.externallyPositioned = false,
    this.useBackdropFilter = true,
  });

  /// Overlay-space point the menu should anchor near — pass
  /// `editable.contextMenuAnchors.primaryAnchor` from your builder.
  final Offset anchor;

  /// Leave empty to hide the highlight row entirely.
  final List<AppContextMenuHighlightOption> highlightColors;
  final void Function(Color color)? onHighlightSelected;
  final void Function(Color color, HighlightStyleType style)? onHighlightWithStyle;
  final HighlightStyleType initialStyle;

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

  /// Backdrop blur behind the panel. Blur forces the panel onto its own
  /// compositing layer that must be re-sampled every frame; callers that stack
  /// this menu above a live platform view (the browser's WebView2) should pass
  /// `false` to avoid per-frame compositing over the platform view.
  final bool useBackdropFilter;

  /// Builds an [EditableTextContextMenuBuilder] and hands you the resolved
  /// anchor point so you don't have to compute it yourself at each call site.
  static EditableTextContextMenuBuilder builder({
    required AppContextMenu Function(
      BuildContext context,
      EditableTextState editable,
      Offset anchor,
    )
    build,
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
    final selectedStyle = useState(initialStyle);
    final colors = Theme.of(context).colorScheme;

    final hasHighlights = highlightColors.isNotEmpty;
    final hasQuickActions = quickActions.isNotEmpty;
    final hasListActions = listActions.isNotEmpty;

    final divider = Divider(
      height: 1,
      thickness: 1,
      color: colors.outlineVariant.withValues(alpha: 0.3),
    );

    final menuSurface = Container(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
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
          if (hasHighlights) ...[
            _StyleSelectorRow(
              selectedStyle: selectedStyle.value,
              onStyleSelected: (style) {
                selectedStyle.value = style;
              },
            ),
            _HighlightRow(
              options: highlightColors,
              selectedStyle: selectedStyle.value,
              onSelected: (color) {
                if (onHighlightWithStyle != null) {
                  onHighlightWithStyle!(color, selectedStyle.value);
                } else {
                  onHighlightSelected?.call(color);
                }
                _dismiss();
              },
            ),
          ],
          if (hasHighlights && hasQuickActions) divider,
          if (hasQuickActions)
            _QuickActionRow(
              actions: quickActions,
              onTapAction: (action) {
                action.onPressed();
                _dismiss();
              },
            ),
          if ((hasHighlights || hasQuickActions) && hasListActions) divider,
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
    );

    final decoratedSurface = useBackdropFilter
        ? BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: menuSurface,
          )
        : menuSurface;

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
        child: decoratedSurface,
      ),
    );

    if (externallyPositioned) return panel;
    return CustomSingleChildLayout(
      delegate: _MenuPositionDelegate(
        anchor: anchor,
        safePadding:
            MediaQuery.paddingOf(context) + const EdgeInsets.all(8),
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
    final maxDx = (size.width - childSize.width - safePadding.right).clamp(
      safePadding.left,
      size.width,
    );
    final maxDy = (size.height - childSize.height - safePadding.bottom).clamp(
      safePadding.top,
      size.height,
    );

    final dx = (anchor.dx - childSize.width / 2).clamp(safePadding.left, maxDx);
    final dy = (anchor.dy + 12).clamp(safePadding.top, maxDy);

    return Offset(dx, dy);
  }

  @override
  bool shouldRelayout(covariant _MenuPositionDelegate oldDelegate) =>
      anchor != oldDelegate.anchor;
}

class _StyleSelectorRow extends StatelessWidget {
  const _StyleSelectorRow({
    required this.selectedStyle,
    required this.onStyleSelected,
  });

  final HighlightStyleType selectedStyle;
  final ValueChanged<HighlightStyleType> onStyleSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final style in HighlightStyleType.values)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onStyleSelected(style),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: selectedStyle == style
                        ? colors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selectedStyle == style
                          ? colors.primary.withValues(alpha: 0.5)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    style.icon,
                    size: 16,
                    color: selectedStyle == style
                        ? colors.primary
                        : colors.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.options,
    required this.selectedStyle,
    required this.onSelected,
  });

  final List<AppContextMenuHighlightOption> options;
  final HighlightStyleType selectedStyle;
  final void Function(Color color) onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _HighlightSwatch(
                  option: option,
                  style: selectedStyle,
                  onTap: () => onSelected(option.color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HighlightSwatch extends HookWidget {
  const _HighlightSwatch({
    required this.option,
    required this.style,
    required this.onTap,
  });

  final AppContextMenuHighlightOption option;
  final HighlightStyleType style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pressed = useState(false);

    return Semantics(
      button: true,
      label: '${style.label} ${option.label ?? 'Highlight'}',
      child: GestureDetector(
        onTapDown: (_) => pressed.value = true,
        onTapCancel: () => pressed.value = false,
        onTapUp: (_) => pressed.value = false,
        onTap: onTap,
        child: AnimatedScale(
          scale: pressed.value ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: option.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: option.color.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: switch (style) {
              HighlightStyleType.solid => null,
              HighlightStyleType.underline => Center(
                  child: Container(
                    width: 12,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              HighlightStyleType.wavy => const Center(
                  child: Icon(
                    Icons.waves_rounded,
                    size: 13,
                    color: Colors.black54,
                  ),
                ),
              HighlightStyleType.strikethrough => Center(
                  child: Container(
                    width: 14,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              HighlightStyleType.bold => const Center(
                  child: Text(
                    'B',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.black54,
                    ),
                  ),
                ),
              HighlightStyleType.italic => const Center(
                  child: Text(
                    'I',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ),
            },
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

class _QuickActionButton extends HookWidget {
  const _QuickActionButton({required this.action, required this.onTap});

  final AppContextMenuAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pressed = useState(false);
    final colors = Theme.of(context).colorScheme;
    final iconColor = action.destructive
        ? colors.error
        : colors.onSurface.withValues(alpha: 0.85);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => pressed.value = true,
      onTapCancel: () => pressed.value = false,
      onTapUp: (_) => pressed.value = false,
      onTap: onTap,
      child: AnimatedScale(
        scale: pressed.value ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 20, color: iconColor),
              const SizedBox(height: 3),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppContextMenuListItem extends HookWidget {
  const _AppContextMenuListItem({required this.action, required this.onTap});

  final AppContextMenuAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hovered = useState(false);
    final colors = Theme.of(context).colorScheme;
    final itemColor = action.destructive
        ? colors.error
        : colors.onSurface;

    return MouseRegion(
      onEnter: (_) => hovered.value = true,
      onExit: (_) => hovered.value = false,
      child: Material(
        color: hovered.value
            ? colors.surfaceContainerHighest.withValues(alpha: 0.6)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(action.icon, size: 18, color: itemColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: itemColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
