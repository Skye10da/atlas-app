import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/onboarding/domain/entities/onboarding_step.dart';
import 'package:atlas_app/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:atlas_app/onboarding/presentation/widgets/onboarding_page_frame.dart';

class OnboardingReadyStep extends ConsumerWidget {
  const OnboardingReadyStep({
    super.key,
    required this.showStarters,
    required this.enabled,
    required this.onStart,
  });

  /// Hidden when the tour is replayed from Settings.
  final bool showStarters;
  final bool enabled;
  final ValueChanged<OnboardingDestination> onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(onboardingDraftProvider.select((d) => d.greetingName));

    return OnboardingPageFrame(
      hero: const OnboardingHeroBadge(icon: Icons.check_rounded),
      title: "You're all set, $name",
      subtitle: showStarters
          ? 'Your profile is saved on this device. A good place to begin:'
          : 'Your changes will be saved.',
      child: showStarters
          ? Column(
              children: [
                _StarterTile(
                  icon: Icons.add_circle_outline_rounded,
                  title: 'Add your first book',
                  subtitle: 'Import a file or paste a link',
                  onTap: enabled
                      ? () => onStart(OnboardingDestination.importBook)
                      : null,
                ),
                const SizedBox(height: AppSpacing.smMd),
                _StarterTile(
                  icon: Icons.travel_explore_rounded,
                  title: 'Browse sources',
                  subtitle: 'Find web novels and online libraries',
                  onTap: enabled
                      ? () => onStart(OnboardingDestination.sources)
                      : null,
                ),
              ],
            )
          : null,
    );
  }
}

class _StarterTile extends StatelessWidget {
  const _StarterTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minVerticalPadding: AppSpacing.smMd,
        leading: Icon(icon, color: cs.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
