import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';

/// One field for everything: search novels or paste a link. Placeholder:
/// "Search novels or paste a link". URL handling lives in the screen's
/// submit logic (a link skips search and opens the import confirm sheet),
/// so this header carries no action icon — just the text field.
/// Autofocus is desktop-only: on mobile the keyboard would cover the
/// dashboard content.
class HeroSearchHeader extends StatelessWidget {
  const HeroSearchHeader({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onCleared,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCleared;

  static bool get autofocusOnDesktop {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasText = controller.text.isNotEmpty;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocusOnDesktop,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search novels or paste a link',
        prefixIcon: const Icon(Icons.travel_explore_rounded, size: 22),
        suffixIcon: hasText
            ? IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () {
                  controller.clear();
                  onCleared();
                },
              )
            : null,
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
      ),
      style: theme.textTheme.bodyLarge,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
