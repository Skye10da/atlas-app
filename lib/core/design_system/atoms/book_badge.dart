import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';

enum BookBadgeVariant {
  primary,
  secondary,
  tertiary,
  error,
  neutral,
}

/// A unified, responsive badge atom for displaying book metadata, novel formats,
/// update counts, reading states, or source origins.
class BookBadge extends StatelessWidget {
  const BookBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = BookBadgeVariant.neutral,
    this.isCompact = false,
  });

  const BookBadge.primary({
    super.key,
    required this.label,
    this.icon,
    this.isCompact = false,
  }) : variant = BookBadgeVariant.primary;

  const BookBadge.tertiary({
    super.key,
    required this.label,
    this.icon,
    this.isCompact = false,
  }) : variant = BookBadgeVariant.tertiary;

  const BookBadge.error({
    super.key,
    required this.label,
    this.icon,
    this.isCompact = false,
  }) : variant = BookBadgeVariant.error;

  final String label;
  final IconData? icon;
  final BookBadgeVariant variant;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (bgColor, fgColor) = switch (variant) {
      BookBadgeVariant.primary => (
        cs.primaryContainer,
        cs.onPrimaryContainer,
      ),
      BookBadgeVariant.secondary => (
        cs.secondaryContainer,
        cs.onSecondaryContainer,
      ),
      BookBadgeVariant.tertiary => (
        cs.tertiaryContainer,
        cs.onTertiaryContainer,
      ),
      BookBadgeVariant.error => (
        cs.errorContainer,
        cs.onErrorContainer,
      ),
      BookBadgeVariant.neutral => (
        cs.surfaceContainerHighest.withValues(alpha: 0.7),
        cs.onSurfaceVariant,
      ),
    };

    final padding = isCompact
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 3);

    final fontSize = isCompact ? 10.0 : 11.0;
    final iconSize = isCompact ? 11.0 : 13.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: fgColor),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: fgColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

