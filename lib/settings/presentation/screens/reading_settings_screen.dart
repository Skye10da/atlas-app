import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';
import 'package:atlas_app/settings/presentation/widgets/settings_widgets.dart';

class ReadingSettingsScreen extends ConsumerWidget {
  const ReadingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(readingSettingsProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Reading')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Failed to load settings')),
        data: (settings) {
          final notifier = ref.read(readingSettingsProvider.notifier);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: [
              const SectionHeader(title: 'Text'),
              SettingsGroup(
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
                  SliderTile(
                    title: 'Line Height',
                    subtitle: settings.lineHeight.toStringAsFixed(1),
                    value: settings.lineHeight,
                    min: 1.0,
                    max: 2.0,
                    divisions: 10,
                    onChanged: notifier.setLineHeight,
                  ),
                  SliderTile(
                    title: 'Letter Spacing',
                    subtitle: settings.letterSpacing.toStringAsFixed(1),
                    value: settings.letterSpacing,
                    min: 0.0,
                    max: 5.0,
                    divisions: 20,
                    onChanged: notifier.setLetterSpacing,
                  ),
                  ChoiceTile<String?>(
                    title: 'Reader Font',
                    value: settings.fontFamily,
                    options: [
                      (null, 'System'),
                      ('Merriweather', 'Merriweather'),
                      ('Lora', 'Lora'),
                      ('Inter', 'Inter'),
                      ('Noto Serif', 'Noto Serif'),
                      ('Playfair Display', 'Playfair'),
                      ('Roboto Slab', 'Roboto Slab'),
                      ('Open Sans', 'Open Sans'),
                      ('EB Garamond', 'Garamond'),
                      ('JetBrains Mono', 'JetBrains'),
                    ],
                    onChanged: notifier.setFontFamily,
                  ),
                  ChoiceTile<TextAlignment>(
                    title: 'Text Alignment',
                    value: settings.textAlignment,
                    options: TextAlignment.values.map((a) => (a, a.label)).toList(),
                    onChanged: notifier.setTextAlignment,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const SectionHeader(title: 'Theme'),
              SettingsGroup(
                children: [
                  ChoiceTile<ReadingViewTheme>(
                    title: 'Reader Theme',
                    value: settings.theme,
                    options: ReadingViewTheme.values.map((t) => (t, t.label)).toList(),
                    onChanged: notifier.setTheme,
                    isSelected: (t) => t == settings.theme,
                    builder: (t) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: t.background,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: t.text.withValues(alpha: 0.3)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(t.label, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reader Brightness', style: textTheme.titleSmall),
                    Row(
                      children: [
                        Icon(Icons.brightness_low, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        Expanded(
                          child: Slider(
                            value: settings.brightness,
                            min: 0.0,
                            max: 1.0,
                            divisions: 20,
                            label: settings.brightness.toStringAsFixed(2),
                            onChanged: notifier.setBrightness,
                          ),
                        ),
                        Icon(Icons.brightness_high, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsGroup(
                children: [
                  SwitchTile(
                    title: 'Auto brightness',
                    subtitle: 'Dim brightness when battery is low',
                    value: settings.autoOptimizeBrightness,
                    onChanged: notifier.setAutoOptimizeBrightness,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const SectionHeader(title: 'Layout'),
              SettingsGroup(
                children: [
                  ChoiceTile<ReadingMode>(
                    title: 'Reading Mode',
                    value: settings.readingMode,
                    options: ReadingMode.values.map((m) => (m, m.label)).toList(),
                    onChanged: notifier.setReadingMode,
                  ),
                  ChoiceTile<MarginPreset>(
                    title: 'Margins',
                    value: settings.marginPreset,
                    options: MarginPreset.values.map((m) => (m, m.label)).toList(),
                    onChanged: notifier.setMarginPreset,
                  ),
                  if (settings.readingMode == ReadingMode.page)
                    ChoiceTile<PageTurnAnimation>(
                      title: 'Page Turn',
                      value: settings.pageTurnAnimation,
                      options: PageTurnAnimation.values.map((a) => (a, a.label)).toList(),
                      onChanged: (a) {
                        notifier.setPageTurnAnimation(a);
                        if (settings.readingMode != ReadingMode.page) {
                          notifier.setReadingMode(ReadingMode.page);
                        }
                      },
                    ),
                  if (settings.readingMode == ReadingMode.continuous)
                    ChoiceTile<ScrollAnimation>(
                      title: 'Scroll Animation',
                      value: settings.scrollAnimation,
                      options: ScrollAnimation.values.map((a) => (a, a.label)).toList(),
                      onChanged: notifier.setScrollAnimation,
                    ),
                  SwitchTile(
                    title: 'Keep screen awake',
                    subtitle: 'Prevent screen from turning off while reading',
                    value: settings.keepScreenAwake,
                    onChanged: notifier.setKeepScreenAwake,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}
