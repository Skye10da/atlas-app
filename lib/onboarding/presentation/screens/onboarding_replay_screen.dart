import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/atoms/app_button.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';

/// Settings entry for re-running the welcome tour (profile, appearance and
/// goals start from what is already saved).
class OnboardingReplayScreen extends StatelessWidget {
  const OnboardingReplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Welcome tour')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.shellContentMaxWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replay the introduction and revisit your profile, '
                  'appearance and reading goals. Nothing is reset: each step '
                  'starts from what you have saved.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton.primary(
                  label: 'Start the tour',
                  icon: const Icon(Icons.waving_hand_outlined),
                  onPressed: () => context.push('/onboarding?replay=1'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
