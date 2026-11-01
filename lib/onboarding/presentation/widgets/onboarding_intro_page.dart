import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/onboarding/domain/entities/onboarding_step.dart';
import 'package:atlas_app/onboarding/presentation/content/onboarding_content.dart';
import 'package:atlas_app/onboarding/presentation/widgets/onboarding_page_frame.dart';

class OnboardingIntroPage extends StatelessWidget {
  const OnboardingIntroPage({super.key, required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWelcome = slide.step == OnboardingStep.welcome;

    return OnboardingPageFrame(
      hero: isWelcome
          ? ExcludeSemantics(
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primaryContainer,
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Image.asset('assets/icon.png'),
                ),
              ),
            )
          : OnboardingHeroBadge(icon: slide.icon),
      title: slide.title,
      subtitle: slide.body,
      child: Column(
        children: [
          for (final bullet in slide.bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.smMd),
              child: _BulletRow(bullet: bullet),
            ),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.bullet});

  final OnboardingBullet bullet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(bullet.icon, size: 20, color: cs.onSecondaryContainer),
          ),
        ),
        const SizedBox(width: AppSpacing.smMd),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(bullet.text, style: theme.textTheme.bodyMedium),
          ),
        ),
      ],
    );
  }
}
