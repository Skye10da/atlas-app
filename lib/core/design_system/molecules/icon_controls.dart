// Self-explaining icon-first control primitives for reader settings.
//
// The reader settings redesign ("simplex" controls) replaces text-titled
// sliders/choice tiles with controls that show what they do: an icon or
// glyph plus a 9-10px micro-label (the same rhythm as the docked mini
// player's nav strip), a tooltip and a semantic label for each target.
// Nothing here knows about reading settings — the reader tabs compose them.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_hooks/flutter_hooks.dart';

/// One selectable option of an [IconSegment].
class IconSegmentOption<T> {
  const IconSegmentOption(
    this.value, {
    required this.label,
    this.icon,
    this.glyph,
  }) : assert(
         icon != null || glyph != null,
         'An option needs an icon or a custom glyph',
       );

  final T value;

  /// Micro-label under the glyph — doubles as the tooltip/semantics label.
  final String label;
  final IconData? icon;

  /// Custom glyph widget (e.g. [SpacedLinesGlyph]) for concepts no material
  /// icon conveys. Takes precedence over [icon].
  final Widget? glyph;
}

/// Segmented selection where every segment is a glyph + micro-label.
///
/// Self-explaining by construction: the segment state (selected fill),
/// the glyph and the micro-label together say what the control does; the
/// label is also the tooltip and the screen-reader label.
class IconSegment<T> extends StatelessWidget {
  const IconSegment({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<IconSegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final option in options)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _segment(context, option, cs),
            ),
          ),
      ],
    );
  }

  Widget _segment(
    BuildContext context,
    IconSegmentOption<T> option,
    ColorScheme cs,
  ) {
    final isSelected = option.value == selected;
    return Semantics(
      button: true,
      selected: isSelected,
      label: option.label,
      child: Tooltip(
        message: option.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            onSelected(option.value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? cs.primaryContainer : cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? cs.primary
                    : cs.outlineVariant.withValues(alpha: 0.4),
                width: isSelected ? 1.8 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.glyph != null)
                  SizedBox(height: 20, child: Center(child: option.glyph!))
                else
                  Icon(
                    option.icon,
                    size: 20,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  ),
                const SizedBox(height: 4),
                Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
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

/// Three stacked lines whose gaps visualize a line-spacing preset —
/// self-explaining glyph for tight / normal / roomy spacing.
class SpacedLinesGlyph extends StatelessWidget {
  const SpacedLinesGlyph({super.key, required this.gap, required this.color});

  /// Vertical gap between the lines (bigger = roomier spacing).
  final double gap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget line() => Container(
      width: 20,
      height: 2,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
    return SizedBox(
      width: 20,
      height: 18,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          line(),
          SizedBox(height: gap),
          line(),
          SizedBox(height: gap),
          line(),
        ],
      ),
    );
  }
}

/// `−` / `+` stepper around a live content preview — for values people
/// tweak one step at a time (text size). No slider, no numeric label: the
/// preview itself shows the effect.
class IconStepper extends StatelessWidget {
  const IconStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    required this.preview,
    required this.semanticLabel,
    this.tooltipPrefix = 'Text size',
    this.valueLabel,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;

  /// The live preview between the beads (e.g. an "Aa" at the current size).
  final Widget preview;

  /// Optional current-value caption rendered under the preview (e.g.
  /// "16 pt") so the exact setting stays readable while the preview keeps
  /// the live visual feedback.
  final String? valueLabel;

  /// Screen-reader label for the whole control ("Text size").
  final String semanticLabel;

  /// Tooltip wording: "$tooltipPrefix decrease" / "$tooltipPrefix increase".
  final String tooltipPrefix;

  @override
  Widget build(BuildContext context) {
    final canDecrease = value - step >= min - 0.001;
    final canIncrease = value + step <= max + 0.001;

    Widget bead({
      required IconData icon,
      required String verb,
      required bool enabled,
      required double delta,
    }) {
      return Semantics(
        button: true,
        label: '$semanticLabel $verb',
        child: Tooltip(
          message: '$tooltipPrefix $verb',
          child: IconButton.filledTonal(
            icon: Icon(icon, size: 18),
            onPressed: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    onChanged((value + delta).clamp(min, max));
                  }
                : null,
          ),
        ),
      );
    }

    return Row(
      children: [
        bead(
          icon: Icons.remove_rounded,
          verb: 'decrease',
          enabled: canDecrease,
          delta: -step,
        ),
        Expanded(
          child: Center(
            child: Semantics(
              label: semanticLabel,
              child: valueLabel == null
                  ? preview
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        preview,
                        const SizedBox(height: 2),
                        Text(
                          valueLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        bead(
          icon: Icons.add_rounded,
          verb: 'increase',
          enabled: canIncrease,
          delta: step,
        ),
      ],
    );
  }
}

/// Single 44px bead that toggles a boolean — the state reads from the fill
/// color, the glyph explains the feature, the label rides as tooltip and
/// screen-reader text.
class IconToggleBead extends StatelessWidget {
  const IconToggleBead({
    super.key,
    required this.active,
    required this.label,
    required this.onChanged,
    this.activeIcon = Icons.check_rounded,
    this.inactiveIcon,
  });

  final bool active;
  final String label;
  final ValueChanged<bool> onChanged;

  /// Glyph while active; falls back to [inactiveIcon] (or the same icon)
  /// when off.
  final IconData activeIcon;
  final IconData? inactiveIcon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = active ? activeIcon : (inactiveIcon ?? activeIcon);
    return Semantics(
      toggled: active,
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(!active);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active ? cs.primaryContainer : cs.surfaceContainerLow,
              shape: BoxShape.circle,
              border: Border.all(
                color: active
                    ? cs.primary
                    : cs.outlineVariant.withValues(alpha: 0.4),
                width: active ? 1.8 : 1,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: active ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Collapsible "Advanced" row for rarely-used knobs: one tap target that
/// explains itself (rotating chevron + label), everything hidden inside
/// only builds attention when expanded.
class AdvancedDisclosure extends HookWidget {
  const AdvancedDisclosure({
    super.key,
    required this.children,
    this.label = 'Advanced',
    this.hint,
    this.initiallyExpanded = false,
  });

  /// Hidden when collapsed; laid out when expanded (cross-fade).
  final List<Widget> children;
  final String label;

  /// Optional current-value hint shown right-aligned (e.g. "Serif").
  final String? hint;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final open = useState(initiallyExpanded);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            open.value = !open.value;
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: open.value ? 0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                if (hint != null) ...[
                  const Spacer(),
                  Text(
                    hint!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          alignment: Alignment.topLeft,
          // Conditionally built: collapsed content is truly absent from the
          // tree (and off the hit-test / a11y paths), not just faded out.
          child: open.value
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
