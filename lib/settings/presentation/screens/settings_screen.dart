import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/settings/presentation/screens/appearance_settings_screen.dart';
import 'package:atlas_app/settings/presentation/screens/danger_zone_screen.dart';
import 'package:atlas_app/settings/presentation/screens/reading_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          _MenuTile(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Brand theme, system font, theme mode',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AppearanceSettingsScreen()),
            ),
          ),
          _MenuTile(
            icon: Icons.chrome_reader_mode_outlined,
            title: 'Reading',
            subtitle: 'Font, layout, theme, brightness',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReadingSettingsScreen()),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'DATA MANAGEMENT',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
          ),
          _MenuTile(
            icon: Icons.dangerous_outlined,
            title: 'Danger Zone',
            subtitle: 'Delete all books, novels, and data',
            iconColor: colors.error,
            titleColor: colors.error,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DangerZoneScreen()),
            ),
          ),
        ],
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
      title: Text(title, style: titleColor != null ? TextStyle(color: titleColor) : null),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
