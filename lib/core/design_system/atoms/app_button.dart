import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';

enum AppButtonVariant { primary, secondary, text, icon }

class AppButton extends StatelessWidget {
  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = false,
    this.loading = false,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = false,
    this.loading = false,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.text({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = false,
    this.loading = false,
  }) : variant = AppButtonVariant.text;

  const AppButton.icon({
    super.key,
    required this.icon,
    this.onPressed,
    this.label,
    this.loading = false,
  })  : variant = AppButtonVariant.icon,
        expanded = false;

  final AppButtonVariant variant;
  final String? label;
  final Widget? icon;
  final VoidCallback? onPressed;
  final bool expanded;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      AppButtonVariant.primary => _buildElevated(context),
      AppButtonVariant.secondary => _buildOutlined(context),
      AppButtonVariant.text => _buildText(context),
      AppButtonVariant.icon => _buildIcon(context),
    };
  }

  Widget _buildElevated(BuildContext context) {
    return SizedBox(
      width: expanded ? double.infinity : null,
      height: AppSpacing.touchTarget,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildOutlined(BuildContext context) {
    return SizedBox(
      width: expanded ? double.infinity : null,
      height: AppSpacing.touchTarget,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildText(BuildContext context) {
    return SizedBox(
      height: AppSpacing.touchTarget,
      child: TextButton(
        onPressed: loading ? null : onPressed,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    return IconButton(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : icon!,
      tooltip: label,
    );
  }

  Widget _buildContent() {
    if (loading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (label != null && icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon!,
          const SizedBox(width: AppSpacing.sm),
          Text(label!),
        ],
      );
    }

    if (icon != null) return icon!;

    return Text(label!);
  }
}
