import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.onPressed,
    this.onDeleted,
    this.selected = false,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onDeleted;
  final bool selected;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      onSelected: onPressed != null ? (_) => onPressed!() : null,
      selected: selected,
      avatar: leading,
      deleteIcon: onDeleted != null ? const Icon(Icons.close, size: 18) : null,
      onDeleted: onDeleted,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    );
  }
}
