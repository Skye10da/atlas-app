import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/marketing/presentation/content/landing_content.dart';

/// Three-step "how it works": import → read → keep, the first narrative beat
/// after the hero.
class LandingHowItWorks extends StatelessWidget {
  const LandingHowItWorks({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          children: [
            for (
              var stepIndex = 0;
              stepIndex < landingHowItWorks.length;
              stepIndex++
            )
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: GlassCapsule(
                  borderRadius: AppSpacing.borderRadiusLg + 8,
                  blur: 18,
                  strong: true,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    accent,
                                    accent.withValues(alpha: 0.55),
                                  ],
                                ),
                              ),
                              child: Icon(
                                landingHowItWorks[stepIndex].icon,
                                size: 20,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Step ${stepIndex + 1}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          landingHowItWorks[stepIndex].title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          landingHowItWorks[stepIndex].body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
