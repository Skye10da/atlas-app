import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/account/domain/entities/local_account_entity.dart';
import 'package:atlas_app/core/account/presentation/providers/local_account_providers.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';

/// Opens the local-account editor (display name + avatar colour).
Future<void> showProfileEditSheet(BuildContext context) {
  return AppSheet.show<void>(
    context: context,
    id: 'profile_edit',
    title: 'Your Profile',
    subtitle: 'Stored on this device only — no account, no cloud.',
    fitToContent: true,
    child: const ProfileEditSheet(),
  );
}

class ProfileEditSheet extends ConsumerStatefulWidget {
  const ProfileEditSheet({super.key});

  @override
  ConsumerState<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<ProfileEditSheet> {
  late final TextEditingController _nameController;
  late int _colorIndex;

  @override
  void initState() {
    super.initState();
    final account = ref.read(localAccountSummaryProvider);
    _nameController = TextEditingController(text: account.displayName);
    _colorIndex = account.avatarColorIndex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _nameController.text.trim();
    final initial = name.isEmpty ? 'R' : name.substring(0, 1).toUpperCase();
    final color = Color(kAvatarColors[_colorIndex % kAvatarColors.length]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: color,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Display name', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Reader',
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Avatar colour', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < kAvatarColors.length; i++)
                _ColorDot(
                  color: Color(kAvatarColors[i]),
                  selected: i == _colorIndex,
                  onTap: () => setState(() => _colorIndex = i),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final notifier = ref.read(localAccountProvider.notifier);
                await notifier.setDisplayName(_nameController.text);
                await notifier.setAvatarColorIndex(_colorIndex);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
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
          width: 40,
          height: 40,
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
