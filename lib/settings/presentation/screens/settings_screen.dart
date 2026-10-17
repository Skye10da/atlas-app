import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/account/presentation/providers/local_account_providers.dart';
import 'package:atlas_app/core/account/presentation/widgets/profile_edit_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/notifications/presentation/screens/update_check_settings_screen.dart';
import 'package:atlas_app/intelligence/presentation/settings/ai_provider_settings_screen.dart';
import 'package:atlas_app/settings/presentation/screens/ai_translation_settings_screen.dart';
import 'package:atlas_app/settings/presentation/screens/appearance_settings_screen.dart';
import 'package:atlas_app/settings/presentation/screens/backup_restore_screen.dart';
import 'package:atlas_app/settings/presentation/screens/danger_zone_screen.dart';
import 'package:atlas_app/settings/presentation/screens/reading_settings_screen.dart';
import 'package:atlas_app/settings/presentation/screens/search_engine_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final account = ref.watch(localAccountSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'Fraunces',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.formContentMaxWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            children: [
              // Section 1: Personalization
              _SectionHeader(label: 'PERSONALIZATION', colors: colors),
              Card(
                elevation: 0,
                color: colors.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusLg,
                  ),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.person_outline_rounded,
                      iconColor: colors.primary,
                      title: 'Profile',
                      subtitle:
                          'Display name & avatar colour — ${account.greetingName}',
                      onTap: () => showProfileEditSheet(context),
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: colors.outlineVariant.withValues(alpha: 0.3),
                    ),
                    _MenuTile(
                      icon: Icons.palette_outlined,
                      title: 'Appearance',
                      subtitle: 'Brand theme, font catalog, theme mode',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AppearanceSettingsScreen(),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: colors.outlineVariant.withValues(alpha: 0.3),
                    ),
                    _MenuTile(
                      icon: Icons.chrome_reader_mode_outlined,
                      title: 'Reading',
                      subtitle: 'Font, typography, themes, brightness',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReadingSettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Section: Search & Lookup
              _SectionHeader(label: 'SEARCH & LOOKUP', colors: colors),
              Card(
                elevation: 0,
                color: colors.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusLg,
                  ),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.travel_explore_rounded,
                      title: 'Search Engine',
                      subtitle: 'Google, Bing, DuckDuckGo, Brave — for lookup & address bar',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SearchEngineSettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Section 2: Content & AI
              _SectionHeader(label: 'CONTENT & AI', colors: colors),
              Card(
                elevation: 0,
                color: colors.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusLg,
                  ),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.auto_awesome_rounded,
                      iconColor: colors.primary,
                      title: 'AI Translation',
                      subtitle: 'AI+ provider, API key, and model',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AiTranslationSettingsScreen(),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: colors.outlineVariant.withValues(alpha: 0.3),
                    ),
                    _MenuTile(
                      icon: Icons.psychology_outlined,
                      iconColor: colors.primary,
                      title: 'Story Intelligence & AI (BYOK)',
                      subtitle: 'Ollama, llama.cpp, Gemini, OpenAI, Claude',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AiProviderSettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Section 2b: Notifications (top-level)
              _SectionHeader(label: 'NOTIFICATIONS', colors: colors),
              Card(
                elevation: 0,
                color: colors.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusLg,
                  ),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.notifications_active_outlined,
                      iconColor: colors.primary,
                      title: 'Notifications',
                      subtitle:
                          'Chapter updates, grouping, quiet hours & sound',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const UpdateCheckSettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Section 3: Data Management
              _SectionHeader(label: 'DATA MANAGEMENT', colors: colors),
              Card(
                elevation: 0,
                color: colors.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusLg,
                  ),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.backup_rounded,
                      iconColor: colors.primary,
                      title: 'Library Backup & Restore',
                      subtitle:
                          'Export or import your books, progress, and vocabulary',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BackupRestoreScreen(),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: colors.outlineVariant.withValues(alpha: 0.3),
                    ),
                    _MenuTile(
                      icon: Icons.warning_amber_rounded,
                      title: 'Danger Zone',
                      subtitle: 'Delete books, reading history, and data',
                      iconColor: colors.error,
                      titleColor: colors.error,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DangerZoneScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Brand footer
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
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Version 1.2.0 • Offline-first sanctuary for readers',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.colors});

  final String label;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSurfaceVariant,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: iconColor ?? colors.onSurfaceVariant),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: titleColor ?? colors.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colors.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
