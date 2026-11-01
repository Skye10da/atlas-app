import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';

/// Widest the content column grows on tablets and desktop windows.
const double kOnboardingMaxWidth = 520;

/// Shared layout for every onboarding page: a hero, a heading, supporting
/// text and an optional body. Scrolls when the keyboard or a large text scale
/// leaves too little room.
class OnboardingPageFrame extends StatelessWidget {
  const OnboardingPageFrame({
    super.key,
    required this.hero,
    required this.title,
    this.subtitle,
    this.child,
  });

  final Widget hero;
  final String title;
  final String? subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: kOnboardingMaxWidth,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    hero,
                    const SizedBox(height: AppSpacing.lg),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontFamily: 'Fraunces',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.smMd),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (child != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      child!,
                    ],
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Round tinted badge holding an icon; the hero of most pages.
class OnboardingHeroBadge extends StatelessWidget {
  const OnboardingHeroBadge({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 44, color: cs.onPrimaryContainer),
      ),
    );
  }
}
