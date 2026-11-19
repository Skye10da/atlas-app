import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/atoms/app_divider.dart';
import 'package:atlas_app/core/design_system/atoms/app_section_header.dart';
import 'package:atlas_app/core/design_system/molecules/icon_controls.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';
import 'package:atlas_app/settings/presentation/providers/font_download_provider.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';
import 'package:atlas_app/settings/presentation/widgets/settings_widgets.dart';

/// Reading preferences — icon-first: a live text preview followed by
/// self-explaining controls (size stepper, spacing glyphs, theme swatches,
/// layout glyphs, keep-awake bead); the rare typography knobs (typeface,
/// weight, letter tracking) sink behind an [AdvancedDisclosure].
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
          style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w700),
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Failed to load settings')),
        data: (settings) {
          final notifier = ref.read(readingSettingsProvider.notifier);
          final fontFamilies = fontFamiliesAsync.valueOrNull ?? [];

          final resolvedTheme = settings.theme.resolve(colors);

          // Highlight the spacing preset closest to the current line height.
          var nearestSpacing = 1.3;
          for (final preset in const [1.3, 1.6, 1.9]) {
            if ((preset - settings.lineHeight).abs() <
                (nearestSpacing - settings.lineHeight).abs()) {
              nearestSpacing = preset;
            }
          }

          SpacedLinesGlyph spacingGlyph(double gap) =>
              SpacedLinesGlyph(gap: gap, color: colors.onSurfaceVariant);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.shellContentMaxWidth,
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
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusLg,
                      ),
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
                            Icon(
                              Icons.menu_book_rounded,
                              size: 16,
                              color: resolvedTheme.text.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'LIVE TEXT PREVIEW',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: resolvedTheme.text.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.smMd),
                        Text(
                          'Chapter 1 · The Beginning',
                          style: TextStyle(
                            fontFamily: settings.fontFamily,
                            fontSize: (settings.fontSize * 1.15).clamp(
                              14.0,
                              32.0,
                            ),
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

                  // 2. Text size — live preview between the beads.
                  IconStepper(
                    value: settings.fontSize.clamp(12.0, 32.0),
                    min: 12,
                    max: 32,
                    step: 1,
                    onChanged: notifier.setFontSize,
                    semanticLabel: 'Text size',
                    valueLabel: '${settings.fontSize.round()} pt',
                    preview: Text(
                      'Aa',
                      style: TextStyle(
                        fontSize: (settings.fontSize * 0.9).clamp(14.0, 28.0),
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. Line spacing glyphs.
                  IconSegment<double>(
                    options: [
                      IconSegmentOption(
                        1.3,
                        label: 'Tight',
                        glyph: spacingGlyph(2),
                      ),
                      IconSegmentOption(
                        1.6,
                        label: 'Normal',
                        glyph: spacingGlyph(4),
                      ),
                      IconSegmentOption(
                        1.9,
                        label: 'Roomy',
                        glyph: spacingGlyph(6),
                      ),
                    ],
                    selected: nearestSpacing,
                    onSelected: notifier.setLineHeight,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 4. Layout glyphs.
                  IconSegment<ReadingMode>(
                    options: [
                      for (final mode in ReadingMode.values)
                        IconSegmentOption(
                          mode,
                          label: switch (mode) {
                            ReadingMode.page => 'Pages',
                            ReadingMode.continuous => 'Scroll',
                            ReadingMode.realFlip => 'Flip',
                          },
                          icon: switch (mode) {
                            ReadingMode.page => Icons.menu_book_rounded,
                            ReadingMode.continuous => Icons.view_day_rounded,
                            ReadingMode.realFlip => Icons.auto_stories_rounded,
                          },
                        ),
                    ],
                    selected: settings.readingMode,
                    onSelected: notifier.setReadingMode,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 5. Reader theme — "Aa" swatches in the theme's colors.
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: ReadingViewTheme.values.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final option = ReadingViewTheme.values[i];
                        final themeColors = option.resolve(colors);
                        final selected = settings.theme == option;
                        return Semantics(
                          button: true,
                          selected: selected,
                          label: '${option.label} theme',
                          child: Tooltip(
                            message: option.label,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => notifier.setTheme(option),
                              child: Container(
                                width: 56,
                                height: 56,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: themeColors.background,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? colors.primary
                                        : colors.outlineVariant,
                                    width: selected ? 3 : 1,
                                  ),
                                ),
                                child: Text(
                                  'Aa',
                                  style: TextStyle(
                                    color: themeColors.text,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 6. Keep awake bead + brightness slider on one row.
                  Row(
                    children: [
                      IconToggleBead(
                        active: settings.keepScreenAwake,
                        label: 'Keep screen awake',
                        activeIcon: Icons.lightbulb_rounded,
                        inactiveIcon: Icons.lightbulb_outline_rounded,
                        onChanged: notifier.setKeepScreenAwake,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Keep screen awake',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  if (!settings.followSystemBrightness) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.brightness_low_rounded,
                          size: 20,
                          color: colors.onSurfaceVariant,
                        ),
                        Expanded(
                          child: Slider(
                            value: settings.brightness.clamp(0.0, 1.0),
                            onChanged: notifier.setBrightness,
                          ),
                        ),
                        Icon(
                          Icons.brightness_high_rounded,
                          size: 20,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),

                  // 7. Advanced typography — typeface, weight, tracking,
                  // alignment.
                  AdvancedDisclosure(
                    label: 'Advanced typography',
                    hint: settings.fontFamily ?? 'System',
                    children: [
                      const AppDivider(),
                      const SizedBox(height: AppSpacing.sm),
                      const AppSectionHeader(title: 'Typeface', padding: 0),
                      const SizedBox(height: AppSpacing.sm),
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
                      const Divider(),
                      SliderTile(
                        title: 'Letter Spacing',
                        subtitle: settings.letterSpacing.toStringAsFixed(1),
                        value: settings.letterSpacing,
                        min: -1.0,
                        max: 3.0,
                        divisions: 20,
                        onChanged: notifier.setLetterSpacing,
                      ),
                    ],
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
