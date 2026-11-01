import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/account/presentation/providers/local_account_providers.dart';
import 'package:atlas_app/core/design_system/atoms/app_button.dart';
import 'package:atlas_app/core/design_system/tokens/animation.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/discover/presentation/providers/reading_analytics_providers.dart';
import 'package:atlas_app/onboarding/domain/entities/onboarding_draft.dart';
import 'package:atlas_app/onboarding/domain/entities/onboarding_step.dart';
import 'package:atlas_app/onboarding/presentation/content/onboarding_content.dart';
import 'package:atlas_app/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:atlas_app/onboarding/presentation/widgets/onboarding_appearance_step.dart';
import 'package:atlas_app/onboarding/presentation/widgets/onboarding_intro_page.dart';
import 'package:atlas_app/onboarding/presentation/widgets/onboarding_navigation.dart';
import 'package:atlas_app/onboarding/presentation/widgets/onboarding_page_frame.dart';
import 'package:atlas_app/onboarding/presentation/widgets/onboarding_preferences_step.dart';
import 'package:atlas_app/onboarding/presentation/widgets/onboarding_profile_step.dart';
import 'package:atlas_app/onboarding/presentation/widgets/onboarding_progress.dart';
import 'package:atlas_app/onboarding/presentation/widgets/onboarding_ready_step.dart';

/// First-run welcome flow: a short introduction, then optional setup
/// (local profile, appearance, reading goals). Also reused, with
/// [replay] set, from Settings.
class OnboardingScreen extends HookConsumerWidget {
  const OnboardingScreen({super.key, this.replay = false});

  final bool replay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(kOnboardingSlides.length == OnboardingStep.profile.index);
    final pageController = usePageController();
    final index = useState(0);
    final finishing = useState(false);
    final seededReplay = useRef(false);
    final step = OnboardingStep.values[index.value];
    final account = ref.watch(localAccountProvider);

    useEffect(() {
      if (replay && account.hasValue && !seededReplay.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted || seededReplay.value) return;
          seededReplay.value = true;
          final savedAccount = account.requireValue;
          final notifier = ref.read(onboardingDraftProvider.notifier);
          notifier.seed(
            displayName: savedAccount.displayName == 'Reader'
                ? ''
                : savedAccount.displayName,
            avatarColorIndex: savedAccount.avatarColorIndex,
          );
          unawaited(() async {
            try {
              final goal = await ref.read(readingGoalProvider.future);
              if (!context.mounted) return;
              notifier.seed(
                weeklyChapterTarget: goal.weeklyChapterTarget,
                dailyMinuteTarget: goal.dailyMinuteTarget,
              );
            } catch (e, st) {
              AppLogger.error(
                'Could not load the reading goal for replay',
                e,
                st,
              );
            }
          }());
        });
      }
      return null;
    }, [replay, account]);

    void goTo(int page) {
      FocusManager.instance.primaryFocus?.unfocus();
      if (MediaQuery.of(context).disableAnimations) {
        pageController.jumpToPage(page);
      } else {
        unawaited(
          pageController.animateToPage(
            page,
            duration: AppAnimation.medium,
            curve: Curves.easeOutCubic,
          ),
        );
      }
    }

    Future<void> finish(OnboardingDestination destination) async {
      if (finishing.value) return;
      finishing.value = true;
      await ref
          .read(onboardingFinisherProvider)
          .finish(ref.read(onboardingDraftProvider));
      if (!context.mounted) return;
      if (replay) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(OnboardingRoutes.library);
        }
      } else {
        openOnboardingDestination(context, destination);
      }
    }

    void next() {
      if (index.value < OnboardingStep.count - 1) {
        goTo(index.value + 1);
      } else {
        unawaited(finish(OnboardingDestination.library));
      }
    }

    void back() {
      if (index.value > 0) goTo(index.value - 1);
    }

    void skip() {
      if (step.isIntro) {
        goTo(OnboardingStep.profile.index);
      } else {
        unawaited(finish(OnboardingDestination.library));
      }
    }

    final primaryLabel = switch (step) {
      OnboardingStep.welcome => 'Get started',
      OnboardingStep.ready => replay ? 'Save changes' : 'Open my library',
      OnboardingStep.profile ||
      OnboardingStep.appearance ||
      OnboardingStep.preferences => 'Continue',
      _ => 'Next',
    };

    // Keeps the autoDispose draft alive for the whole flow without rebuilding
    // this screen on every keystroke.
    ref.listen<OnboardingDraft>(onboardingDraftProvider, (_, _) {});

    return PopScope(
      canPop: index.value == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                showBack: index.value > 0,
                skipLabel: step.isIntro ? 'Skip intro' : 'Skip setup',
                showSkip: step != OnboardingStep.ready,
                enabled: !finishing.value,
                onBack: back,
                onSkip: skip,
              ),
              Expanded(
                child: PageView(
                  controller: pageController,
                  onPageChanged: (page) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    index.value = page;
                  },
                  children: [
                    for (final slide in kOnboardingSlides)
                      OnboardingIntroPage(slide: slide),
                    const OnboardingProfileStep(),
                    const OnboardingAppearanceStep(),
                    const OnboardingPreferencesStep(),
                    OnboardingReadyStep(
                      showStarters: replay,
                      enabled: !finishing.value,
                      onStart: (destination) => unawaited(finish(destination)),
                    ),
                  ],
                ),
              ),
              _BottomBar(
                index: index.value,
                label: primaryLabel,
                loading: finishing.value,
                onPressed: finishing.value ? null : next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.showBack,
    required this.showSkip,
    required this.skipLabel,
    required this.enabled,
    required this.onBack,
    required this.onSkip,
  });

  final bool showBack;
  final bool showSkip;
  final String skipLabel;
  final bool enabled;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.touchTarget + AppSpacing.sm,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: AppSpacing.touchTarget,
              child: showBack
                  ? IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: enabled ? onBack : null,
                    )
                  : null,
            ),
            const Spacer(),
            if (showSkip)
              TextButton(
                onPressed: enabled ? onSkip : null,
                child: Text(skipLabel),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final int index;
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kOnboardingMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OnboardingProgress(current: index, total: OnboardingStep.count),
              const SizedBox(height: AppSpacing.md),
              AppButton.primary(
                label: label,
                onPressed: onPressed,
                expanded: true,
                loading: loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
