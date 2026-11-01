import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:atlas_app/onboarding/presentation/widgets/onboarding_page_frame.dart';

const List<int> _kWeeklyChapterOptions = [5, 10, 20, 35];
const List<int> _kDailyMinuteOptions = [15, 30, 45, 60];

/// Mirrors the defaults used by the reading-goal service, so an untouched
/// page shows the value that is already in effect.
const int _kDefaultWeeklyChapters = 20;
const int _kDefaultDailyMinutes = 30;

/// Reading goals and optional update notifications.
class OnboardingPreferencesStep extends ConsumerWidget {
  const OnboardingPreferencesStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final draft = ref.watch(onboardingDraftProvider);
    final notifier = ref.read(onboardingDraftProvider.notifier);

    final weekly = draft.weeklyChapterTarget ?? _kDefaultWeeklyChapters;
    final daily = draft.dailyMinuteTarget ?? _kDefaultDailyMinutes;

    return OnboardingPageFrame(
      hero: const OnboardingHeroBadge(icon: Icons.flag_outlined),
      title: 'Set a reading rhythm',
      subtitle: 'Pick goals that feel easy. You can change them later.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chapters per week', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in _kWeeklyChapterOptions)
                ChoiceChip(
                  label: Text('$value'),
                  selected: weekly == value,
                  onSelected: (_) => notifier.setWeeklyChapterTarget(value),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Minutes per day', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in _kDailyMinuteOptions)
                ChoiceChip(
                  label: Text('$value min'),
                  selected: daily == value,
                  onSelected: (_) => notifier.setDailyMinuteTarget(value),
                ),
            ],
          ),
          if (!kIsWeb) ...[
            const SizedBox(height: AppSpacing.lg),
            Material(
              color: cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
                side: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
                value: draft.enableUpdateNotifications,
                onChanged: notifier.setUpdateNotifications,
                title: const Text('New chapter alerts'),
                subtitle: const Text(
                  'Atlas checks for updates in the background and asks '
                  'permission to notify you.',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
