import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/account/domain/entities/local_account_entity.dart';
import 'package:atlas_app/core/account/presentation/providers/local_account_providers.dart';
import 'package:atlas_app/core/account/presentation/widgets/profile_edit_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/intelligence/presentation/settings/ai_provider_settings_screen.dart';
import 'package:atlas_app/notifications/presentation/screens/update_check_settings_screen.dart';
import 'package:atlas_app/settings/presentation/screens/ai_translation_settings_screen.dart';
import 'package:atlas_app/settings/presentation/screens/appearance_settings_screen.dart';
import 'package:atlas_app/settings/presentation/screens/backup_restore_screen.dart';
import 'package:atlas_app/settings/presentation/screens/danger_zone_screen.dart';
import 'package:atlas_app/settings/presentation/screens/reading_settings_screen.dart';
import 'package:atlas_app/settings/presentation/screens/search_engine_settings_screen.dart';

/// Content width at which Settings becomes master-detail: the section list on
/// the left and the chosen section filling the rest of the window.
const double _masterDetailMinWidth = 840;
const double _listPaneWidth = 340;

class _Section {
  const _Section({
    required this.group,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
    this.danger = false,
  });

  final String group;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget Function() builder;
  final bool danger;
}

final List<_Section> _sections = [
  _Section(
    group: 'Personalization',
    icon: Icons.palette_outlined,
    title: 'Appearance',
    subtitle: 'Brand theme, font catalog, theme mode',
    builder: () => const AppearanceSettingsScreen(),
  ),
  _Section(
    group: 'Personalization',
    icon: Icons.chrome_reader_mode_outlined,
    title: 'Reading',
    subtitle: 'Font, typography, themes, brightness',
    builder: () => const ReadingSettingsScreen(),
  ),
  _Section(
    group: 'Search & lookup',
    icon: Icons.travel_explore_rounded,
    title: 'Search Engine',
    subtitle: 'Google, Bing, DuckDuckGo, Brave — for lookup & address bar',
    builder: () => const SearchEngineSettingsScreen(),
  ),
  _Section(
    group: 'Content & AI',
    icon: Icons.auto_awesome_rounded,
    title: 'AI Translation',
    subtitle: 'AI+ provider, API key, and model',
    builder: () => const AiTranslationSettingsScreen(),
  ),
  _Section(
    group: 'Content & AI',
    icon: Icons.psychology_outlined,
    title: 'Story Intelligence & AI (BYOK)',
    subtitle: 'Ollama, llama.cpp, Gemini, OpenAI, Claude',
    builder: () => const AiProviderSettingsScreen(),
  ),
  _Section(
    group: 'Notifications',
    icon: Icons.notifications_active_outlined,
    title: 'Notifications',
    subtitle: 'Chapter updates, grouping, quiet hours & sound',
    builder: () => const UpdateCheckSettingsScreen(),
  ),
  _Section(
    group: 'Data management',
    icon: Icons.backup_rounded,
    title: 'Library Backup & Restore',
    subtitle: 'Export or import your books, progress, and vocabulary',
    builder: () => const BackupRestoreScreen(),
  ),
  _Section(
    group: 'Data management',
    icon: Icons.warning_amber_rounded,
    title: 'Danger Zone',
    subtitle: 'Delete books, reading history, and data',
    builder: () => const DangerZoneScreen(),
    danger: true,
  ),
];

/// Settings.
///
/// Compact windows show the grouped section list and push each section as its
/// own page. Wide windows (>= 840dp of content) show the same list as a left
/// pane and open the selected section in the remaining space, so no page is
/// ever a narrow column floating in a wide window.
class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = useState(0);
    final account = ref.watch(localAccountSummaryProvider);
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _masterDetailMinWidth;

        if (!wide) {
          return Scaffold(
            body: SafeArea(
              bottom: false,
              child: _SettingsList(
                account: account,
                selectedIndex: null,
                onSelect: (i) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _sections[i].builder(),
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: _listPaneWidth,
                child: SafeArea(
                  bottom: false,
                  child: _SettingsList(
                    account: account,
                    selectedIndex: selected.value,
                    onSelect: (i) => selected.value = i,
                  ),
                ),
              ),
              VerticalDivider(
                width: 1,
                color: cs.outlineVariant.withValues(alpha: 0.6),
              ),
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey<int>(selected.value),
                  child: _sections[selected.value].builder(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsList extends StatelessWidget {
  const _SettingsList({
    required this.account,
    required this.selectedIndex,
    required this.onSelect,
  });

  final LocalAccountEntity account;

  /// Highlighted section in master-detail mode; null when pushing pages.
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Group consecutive sections that share a label.
    final groups = <(String, List<int>)>[];
    for (var i = 0; i < _sections.length; i++) {
      final label = _sections[i].group;
      if (groups.isEmpty || groups.last.$1 != label) {
        groups.add((label, <int>[i]));
      } else {
        groups.last.$2.add(i);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [
        Text(
          'Settings',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontFamily: 'Fraunces',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _AccountCard(account: account),
        for (final group in groups) ...[
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              group.$1,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Material(
            color: cs.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final index in group.$2)
                  _SettingsTile(
                    section: _sections[index],
                    selected: selectedIndex == index,
                    showChevron: selectedIndex == null,
                    onTap: () => onSelect(index),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/icon.png', width: 30, height: 30),
                  const SizedBox(width: 6),
                  Text(
                    'Atlas',
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Version 1.2.0 • Offline-first sanctuary for readers',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(color: cs.outline),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});

  final LocalAccountEntity account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final avatar = Color(
      kAvatarColors[account.avatarColorIndex % kAvatarColors.length],
    );

    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showProfileEditSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: avatar,
                child: Text(
                  account.avatarInitial,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.smMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.greetingName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'Fraunces',
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Display name & avatar colour',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.section,
    required this.selected,
    required this.showChevron,
    required this.onTap,
  });

  final _Section section;
  final bool selected;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final danger = section.danger;
    final chipColor = danger ? cs.errorContainer : cs.secondaryContainer;
    final chipIcon = danger ? cs.onErrorContainer : cs.onSecondaryContainer;
    final titleColor = danger ? cs.error : cs.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? cs.secondaryContainer.withValues(alpha: 0.55) : null,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(section.icon, size: 22, color: chipIcon),
                ),
                const SizedBox(width: AppSpacing.smMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        section.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (showChevron)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
