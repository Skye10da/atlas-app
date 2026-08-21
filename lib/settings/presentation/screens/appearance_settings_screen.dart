import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/theme/app_brand.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/theme_preview_screen.dart';
import 'package:atlas_app/settings/presentation/providers/font_download_provider.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';
import 'package:atlas_app/settings/presentation/screens/font_manager_screen.dart';
import 'package:atlas_app/settings/presentation/widgets/settings_widgets.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(readingSettingsProvider);
    final fontFamiliesAsync = ref.watch(availableFontFamiliesProvider);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Failed to load settings')),
        data: (settings) {
          final notifier = ref.read(readingSettingsProvider.notifier);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: [
              const SectionHeader(title: 'Brand Theme'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Brand Theme', style: textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AppBrand.values.map((brand) {
                        final isSelected = settings.brand == brand;
                        return GestureDetector(
                          onTap: () => notifier.setBrand(brand),
                          child: Container(
                            width: 64,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: brand.seed.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? brand.seed
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(brand.icon, color: brand.seed, size: 22),
                                const SizedBox(height: 4),
                                Text(
                                  brand.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : null,
                                    color: isSelected
                                        ? brand.seed
                                        : colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('System Font', style: textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Builder(
                      builder: (context) {
                        final fontFamilies =
                            fontFamiliesAsync.valueOrNull ?? [];
                        final options = [null, ...fontFamilies];
                        return Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: List.generate(options.length, (i) {
                            final f = options[i];
                            final isSelected =
                                settings.systemFontFamily == f;
                            return ChoiceChip(
                              label: Text(
                                f ?? 'System Default',
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: isSelected,
                              onSelected: (_) =>
                                  notifier.setSystemFontFamily(f),
                            );
                          }),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.font_download_outlined),
                  title: const Text(
                    'Download Fonts',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    'Manage reader fonts — bundled and downloadable',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FontManagerScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme Mode', style: textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children:
                          [
                            ('system', 'System'),
                            ('light', 'Light'),
                            ('dark', 'Dark'),
                          ].map((entry) {
                            final (value, label) = entry;
                            final isSelected = switch (settings.themeMode) {
                              ThemeMode.system => value == 'system',
                              ThemeMode.light => value == 'light',
                              ThemeMode.dark => value == 'dark',
                            };
                            return ChoiceChip(
                              label: Text(
                                label,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: isSelected,
                              onSelected: (_) =>
                                  notifier.setThemeMode(switch (value) {
                                    'light' => ThemeMode.light,
                                    'dark' => ThemeMode.dark,
                                    _ => ThemeMode.system,
                                  }),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: 'Reading Theme'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ReadingViewTheme.values.map((t) {
                    final isSelected = settings.theme == t;
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => ThemePreviewScreen(
                              initialTheme: t,
                              onApply: (theme) => notifier.setTheme(theme),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 48,
                        height: 56,
                        decoration: BoxDecoration(
                          color: t.resolve(colors).background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? colors.primary
                                : t
                                      .resolve(colors)
                                      .text
                                      .withValues(alpha: 0.15),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.format_quote,
                              size: 16,
                              color: t.resolve(colors).text,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 8,
                                color: t.resolve(colors).text,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
