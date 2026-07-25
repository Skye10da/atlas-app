import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';

class AppDivider extends StatelessWidget {
  const AppDivider({
    super.key,
    this.height = 1,
    this.indent = AppSpacing.md,
    this.endIndent = AppSpacing.md,
    this.color,
  });

  final double height;
  final double indent;
  final double endIndent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: height,
      indent: indent,
      endIndent: endIndent,
      color: color ?? Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class AppVerticalDivider extends StatelessWidget {
  const AppVerticalDivider({
    super.key,
    this.width = 1,
    this.indent,
    this.endIndent,
    this.color,
  });

  final double width;
  final double? indent;
  final double? endIndent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: width,
      indent: indent,
      endIndent: endIndent,
      color: color ?? Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
