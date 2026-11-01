import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/account/domain/entities/local_account_entity.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:atlas_app/onboarding/presentation/widgets/onboarding_page_frame.dart';

/// Creates the on-device account: a display name and an avatar colour.
/// There is nothing to sign in to; the profile only personalises Atlas.
class OnboardingProfileStep extends HookConsumerWidget {
  const OnboardingProfileStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final draft = ref.watch(onboardingDraftProvider);
    final notifier = ref.read(onboardingDraftProvider.notifier);
    final nameController = useTextEditingController(
      text: ref.read(onboardingDraftProvider).displayName,
    );
    final colorIndex = kAvatarColors.isEmpty
        ? 0
        : draft.avatarColorIndex % kAvatarColors.length;

    // A replayed tour seeds the draft after this page is built; keep the text
    // field in step without fighting the user's own typing.
    ref.listen<String>(onboardingDraftProvider.select((d) => d.displayName), (
      _,
      next,
    ) {
      if (nameController.text != next) nameController.text = next;
    });

    return OnboardingPageFrame(
      hero: Semantics(
        label: 'Avatar preview for ${draft.greetingName}',
        child: CircleAvatar(
          radius: 48,
          backgroundColor: Color(kAvatarColors[colorIndex]),
          child: Text(
            draft.avatarInitial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      title: 'Create your profile',
      subtitle: 'Stored on this device only. No email, no password, no cloud.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What should we call you?', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            maxLength: 40,
            onChanged: notifier.setDisplayName,
            decoration: const InputDecoration(
              hintText: 'Reader',
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Pick a colour', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < kAvatarColors.length; i++)
                _ColorChoice(
                  color: Color(kAvatarColors[i]),
                  selected: i == colorIndex,
                  onTap: () => notifier.setAvatarColorIndex(i),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'You can change this any time in Settings.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: 'Avatar colour',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: AppSpacing.touchTarget - 4,
          height: AppSpacing.touchTarget - 4,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: selected
                ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 3,
                  )
                : null,
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}
