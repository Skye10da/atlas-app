import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/molecules/icon_controls.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';

/// "Aa" quick sheet — icon-first and self-explaining: every control shows
/// its effect (live "Aa" preview, spacing glyphs, layout glyphs, theme
/// swatches) instead of relying on text titles. Uses the same
/// [readingSettingsProvider] as the full settings screen, so both stay in
/// sync.
class ReaderQuickSettingsSheet extends ConsumerWidget {
  const ReaderQuickSettingsSheet({super.key, required this.onAllSettings});

  /// Opens the full reading settings (called after this sheet closes).
  final VoidCallback onAllSettings;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onAllSettings,
  }) {
    return AppSheet.show<void>(
      context: context,
      id: 'reader_quick_settings',
      title: 'Reading',
      fitToContent: true,
      maxWidth: 520,
      child: ReaderQuickSettingsSheet(onAllSettings: onAllSettings),
    );
  }

  static IconData _modeIcon(ReadingMode mode) => switch (mode) {
    ReadingMode.page => Icons.menu_book_rounded,
    ReadingMode.continuous => Icons.view_day_rounded,
    ReadingMode.realFlip => Icons.auto_stories_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings =
        ref.watch(readingSettingsProvider).valueOrNull ??
        const ReadingSettingsEntity();
    final notifier = ref.read(readingSettingsProvider.notifier);

    // Highlight the preset closest to the current line height.
    var nearest = 1.3;
    for (final preset in const [1.3, 1.6, 1.9]) {
      if ((preset - settings.lineHeight).abs() <
          (nearest - settings.lineHeight).abs()) {
        nearest = preset;
      }
    }

    SpacedLinesGlyph spacingGlyph(double gap) =>
        SpacedLinesGlyph(gap: gap, color: cs.onSurfaceVariant);

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
          // Text size — live "Aa" preview between the stepper beads.
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
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Line spacing — the gaps in the glyphs ARE the setting.
          IconSegment<double>(
            options: [
              IconSegmentOption(1.3, label: 'Tight', glyph: spacingGlyph(2)),
              IconSegmentOption(1.6, label: 'Normal', glyph: spacingGlyph(4)),
              IconSegmentOption(1.9, label: 'Roomy', glyph: spacingGlyph(6)),
            ],
            selected: nearest,
            onSelected: notifier.setLineHeight,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Layout — page / scroll / flip glyphs.
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
                  icon: _modeIcon(mode),
                ),
            ],
            selected: settings.readingMode,
            onSelected: notifier.setReadingMode,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Theme — "Aa" swatches in the theme's own colors.
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ReadingViewTheme.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final option = ReadingViewTheme.values[i];
                final colors = option.resolve(cs);
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
                          color: colors.background,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? cs.primary : cs.outlineVariant,
                            width: selected ? 3 : 1,
                          ),
                        ),
                        child: Text(
                          'Aa',
                          style: TextStyle(
                            color: colors.text,
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
          const SizedBox(height: AppSpacing.sm),
          // Brightness + keep-awake on one row: the sun glyphs explain the
          // slider, the bead is lit while the screen stays awake.
          Row(
            children: [
              Icon(
                Icons.brightness_low_rounded,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              Expanded(
                child: Slider(
                  value: settings.brightness.clamp(0.0, 1.0),
                  onChanged: settings.followSystemBrightness
                      ? null
                      : notifier.setBrightness,
                ),
              ),
              Icon(
                Icons.brightness_high_rounded,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              IconToggleBead(
                active: settings.keepScreenAwake,
                label: 'Keep screen awake',
                activeIcon: Icons.lightbulb_rounded,
                inactiveIcon: Icons.lightbulb_outline_rounded,
                onChanged: notifier.setKeepScreenAwake,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onAllSettings();
              },
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('All reading settings'),
            ),
          ),
        ],
      ),
    );
  }
}
