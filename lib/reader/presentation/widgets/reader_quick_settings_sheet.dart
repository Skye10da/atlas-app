import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/reading_colors.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';

/// "Aa" quick sheet: the things people change mid-chapter (text size, line
/// spacing, reading layout, theme, brightness) without opening the full
/// settings sheet. Uses the same [readingSettingsProvider] as the full sheet,
/// so both stay in sync.
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

  static const _spacing = <(String, double)>[
    ('Tight', 1.3),
    ('Normal', 1.6),
    ('Roomy', 1.9),
  ];

  static String _modeLabel(ReadingMode mode) => switch (mode) {
    ReadingMode.page => 'Pages',
    ReadingMode.continuous => 'Scroll',
    ReadingMode.realFlip => 'Flip',
  };

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
    var nearest = _spacing.first.$2;
    for (final preset in _spacing) {
      if ((preset.$2 - settings.lineHeight).abs() <
          (nearest - settings.lineHeight).abs()) {
        nearest = preset.$2;
      }
    }

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

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
          label('Text size'),
          Row(
            children: [
              Text('A', style: theme.textTheme.bodySmall),
              Expanded(
                child: Slider(
                  min: 12,
                  max: 32,
                  divisions: 20,
                  value: settings.fontSize.clamp(12.0, 32.0),
                  label: settings.fontSize.round().toString(),
                  onChanged: notifier.setFontSize,
                ),
              ),
              Text('A', style: theme.textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          label('Line spacing'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<double>(
              showSelectedIcon: false,
              segments: [
                for (final preset in _spacing)
                  ButtonSegment(value: preset.$2, label: Text(preset.$1)),
              ],
              selected: {nearest},
              onSelectionChanged: (s) => notifier.setLineHeight(s.first),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          label('Layout'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ReadingMode>(
              showSelectedIcon: false,
              segments: [
                for (final mode in ReadingMode.values)
                  ButtonSegment(
                    value: mode,
                    label: Text(_modeLabel(mode)),
                    icon: Icon(_modeIcon(mode), size: 18),
                  ),
              ],
              selected: {settings.readingMode},
              onSelectionChanged: (s) => notifier.setReadingMode(s.first),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          label('Theme'),
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
          const SizedBox(height: AppSpacing.md),
          label(
            settings.followSystemBrightness
                ? 'Brightness (following system)'
                : 'Brightness',
          ),
          Row(
            children: [
              Icon(Icons.brightness_low_rounded, size: 20, color: cs.onSurfaceVariant),
              Expanded(
                child: Slider(
                  value: settings.brightness.clamp(0.0, 1.0),
                  onChanged: settings.followSystemBrightness
                      ? null
                      : notifier.setBrightness,
                ),
              ),
              Icon(Icons.brightness_high_rounded, size: 20, color: cs.onSurfaceVariant),
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
