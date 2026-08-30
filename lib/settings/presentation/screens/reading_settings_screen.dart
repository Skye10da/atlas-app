import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';
import 'package:atlas_app/settings/presentation/providers/font_download_provider.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';
import 'package:atlas_app/settings/presentation/widgets/settings_widgets.dart';

class ReadingSettingsScreen extends ConsumerWidget {
  const ReadingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(readingSettingsProvider);
    final fontFamiliesAsync = ref.watch(availableFontFamiliesProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reading Preferences',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Failed to load settings')),
        data: (settings) {
          final notifier = ref.read(readingSettingsProvider.notifier);
          final fontFamilies = fontFamiliesAsync.valueOrNull ?? [];

          final resolvedTheme = settings.theme.resolve(colors);

          return Center(
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
                  // 1. Live Interactive Chapter Sample
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: resolvedTheme.background,
                      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
                      border: Border.all(
                        color: resolvedTheme.text.withValues(alpha: 0.18),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.menu_book_rounded, size: 16, color: resolvedTheme.text.withValues(alpha: 0.6)),
                            const SizedBox(width: 6),
                            Text(
                              'LIVE TEXT PREVIEW',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: resolvedTheme.text.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.smMd),
                        Text(
                          'Chapter 1 · The Beginning',
                          style: TextStyle(
                            fontFamily: settings.fontFamily,
                            fontSize: (settings.fontSize * 1.15).clamp(14.0, 32.0),
                            fontWeight: FontWeight.bold,
                            color: resolvedTheme.text,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'In the sacred lands of Wu, where might makes right, a single soul dared to defy the heavens. Cultivation was not merely a path to power — it was an art carved into the fabric of reality itself.',
                          textAlign: switch (settings.textAlignment) {
                            TextAlignment.center => TextAlign.center,
                            TextAlignment.right => TextAlign.right,
                            _ => TextAlign.left,
                          },
                          style: TextStyle(
                            fontFamily: settings.fontFamily,
                            fontSize: settings.fontSize,
                            height: settings.lineHeight,
                            letterSpacing: settings.letterSpacing,
                            fontWeight: settings.fontWeight != null
                                ? FontWeight.values.firstWhere(
                                    (w) => w.value == settings.fontWeight,
                                    orElse: () => FontWeight.normal,
                                  )
                                : FontWeight.normal,
                            color: resolvedTheme.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 2. Typography Sliders Card
                  _SettingsContainer(
                    title: 'Typography',
                    child: Column(
                      children: [
                        SliderTile(
                          title: 'Font Size',
                          subtitle: '${settings.fontSize.round()}px',
                          value: settings.fontSize,
                          min: 12,
                          max: 28,
                          divisions: 16,
                          onChanged: notifier.setFontSize,
                        ),
                        const Divider(),
                        SliderTile(
                          title: 'Line Height',
                          subtitle: settings.lineHeight.toStringAsFixed(1),
                          value: settings.lineHeight,
                          min: 1.0,
                          max: 2.0,
                          divisions: 10,
                          onChanged: notifier.setLineHeight,
                        ),
                        const Divider(),
                        SliderTile(
                          title: 'Letter Spacing',
                          subtitle: settings.letterSpacing.toStringAsFixed(1),
                          value: settings.letterSpacing,
                          min: 0.0,
                          max: 5.0,
                          divisions: 20,
                          onChanged: notifier.setLetterSpacing,
                        ),
                        const Divider(),
                        ChoiceTile<String?>(
                          title: 'Reader Font',
                          value: settings.fontFamily,
                          options: [
                            (null, 'System Default'),
                            for (final family in fontFamilies) (family, family),
                          ],
                          onChanged: notifier.setFontFamily,
                        ),
                        const Divider(),
                        ChoiceTile<int?>(
                          title: 'Font Weight',
                          value: settings.fontWeight,
                          options: const [
                            (null, 'Regular'),
                            (400, 'Normal (400)'),
                            (500, 'Medium (500)'),
                            (600, 'SemiBold (600)'),
                            (700, 'Bold (700)'),
                          ],
                          onChanged: notifier.setFontWeight,
                        ),
                        const Divider(),
                        ChoiceTile<TextAlignment>(
                          title: 'Text Alignment',
                          value: settings.textAlignment,
                          options: TextAlignment.values
                              .map((a) => (a, a.label))
                              .toList(),
                          onChanged: notifier.setTextAlignment,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. Reader Theme Swatches Card
                  _SettingsContainer(
                    title: 'Reader Theme',
                    child: ChoiceTile<ReadingViewTheme>(
                      title: 'Color Palette',
                      value: settings.theme,
                      options: ReadingViewTheme.values
                          .map((t) => (t, t.label))
                          .toList(),
                      onChanged: notifier.setTheme,
                      isSelected: (t) => t == settings.theme,
                      builder: (t) {
                        final colorScheme = Theme.of(context).colorScheme;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: t.resolve(colorScheme).background,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: t
                                      .resolve(colorScheme)
                                      .text
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(t.label, style: const TextStyle(fontSize: 12)),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 4. Layout & Behavior
                  _SettingsContainer(
                    title: 'Behavior & Screen',
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Keep Screen Awake'),
                          subtitle: const Text('Prevent display from sleeping while reading'),
                          value: settings.keepScreenAwake,
                          onChanged: notifier.setKeepScreenAwake,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsContainer extends StatelessWidget {
  const _SettingsContainer({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.smMd),
          child,
        ],
      ),
    );
  }
}
