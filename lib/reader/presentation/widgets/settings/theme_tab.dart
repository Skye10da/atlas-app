import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:atlas_app/core/design_system/atoms/app_divider.dart';
import 'package:atlas_app/core/design_system/atoms/app_section_header.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/reading_preset.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/theme_preview_screen.dart';

class ThemeTab extends StatelessWidget {
  const ThemeTab({
    super.key,
    required this.theme,
    required this.fontSize,
    this.fontFamily,
    this.fontWeight,
    required this.lineHeight,
    required this.readingMode,
    required this.marginPreset,
    required this.onThemeChanged,
    required this.onFontSizeChanged,
    required this.onFontFamilyChanged,
    required this.onLineHeightChanged,
    required this.onReadingModeChanged,
    required this.onMarginPresetChanged,
    this.onApplyPreset,
  });

  final ReadingViewTheme theme;
  final double fontSize;
  final String? fontFamily;
  final int? fontWeight;
  final double lineHeight;
  final ReadingMode readingMode;
  final MarginPreset marginPreset;

  final ValueChanged<ReadingViewTheme> onThemeChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<String?> onFontFamilyChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<ReadingMode> onReadingModeChanged;
  final ValueChanged<MarginPreset> onMarginPresetChanged;
  final ValueChanged<ReadingPreset>? onApplyPreset;

  void _openPreview(BuildContext context, ReadingViewTheme initial) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            ThemePreviewScreen(initialTheme: initial, onApply: onThemeChanged),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Curated Reading Presets
          const AppSectionHeader(title: 'Reading Presets', padding: 0),
          const SizedBox(height: 4),
          Text(
            'One-tap curated typography, themes, and spacing styles',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 94,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ReadingPreset.presets.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final preset = ReadingPreset.presets[index];
                final isSelected = preset.matches(
                  currentTheme: theme,
                  currentFontFamily: fontFamily,
                  currentFontSize: fontSize,
                  currentLineHeight: lineHeight,
                );

                final presetColors = preset.theme.resolve(colorScheme);

                return _PresetCard(
                  preset: preset,
                  isSelected: isSelected,
                  presetColors: presetColors,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onApplyPreset?.call(preset);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.md),
          const AppDivider(),
          const SizedBox(height: AppSpacing.sm),

          // 2. Font Size Stepper & Slider
          AppSectionHeader(
            title: 'Font Size',
            padding: 0,
            actionLabel: '${fontSize.round()} pt',
            action: () {},
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.remove, size: 18),
                tooltip: 'Decrease text size',
                onPressed: fontSize > 12
                    ? () {
                        HapticFeedback.selectionClick();
                        onFontSizeChanged((fontSize - 1).clamp(12.0, 32.0));
                      }
                    : null,
              ),
              Expanded(
                child: Slider(
                  value: fontSize.clamp(12.0, 32.0),
                  min: 12,
                  max: 32,
                  divisions: 20,
                  label: '${fontSize.round()} pt',
                  onChanged: (v) {
                    onFontSizeChanged(v);
                  },
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Increase text size',
                onPressed: fontSize < 32
                    ? () {
                        HapticFeedback.selectionClick();
                        onFontSizeChanged((fontSize + 1).clamp(12.0, 32.0));
                      }
                    : null,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          const AppDivider(),
          const SizedBox(height: AppSpacing.sm),

          // 3. Color Theme Palette
          AppSectionHeader(
            title: 'Color Theme',
            padding: 0,
            actionLabel: 'Preview',
            action: () => _openPreview(context, theme),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ReadingViewTheme.values.map((t) {
              return _ThemeSwatch(
                theme: t,
                isSelected: theme == t,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onThemeChanged(t);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.md),
          const AppDivider(),
          const SizedBox(height: AppSpacing.sm),

          // 4. Reading Mode Selector (Paged vs Real Flip vs Continuous)
          const AppSectionHeader(title: 'Reading Flow', padding: 0),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _ModeSelectionCard(
                  title: 'Page Flip',
                  subtitle: 'Fast animated book pages',
                  icon: Icons.auto_stories,
                  isSelected: readingMode == ReadingMode.page,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onReadingModeChanged(ReadingMode.page);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeSelectionCard(
                  title: 'Real Flip',
                  subtitle: 'Physical 3D curl physics & mesh',
                  icon: Icons.menu_book,
                  isSelected: readingMode == ReadingMode.realFlip,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onReadingModeChanged(ReadingMode.realFlip);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeSelectionCard(
                  title: 'Continuous',
                  subtitle: 'Smooth vertical scroll',
                  icon: Icons.view_day,
                  isSelected: readingMode == ReadingMode.continuous,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onReadingModeChanged(ReadingMode.continuous);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          const AppDivider(),
          const SizedBox(height: AppSpacing.sm),

          // 5. Line Spacing Density Presets
          const AppSectionHeader(title: 'Line Spacing', padding: 0),
          const SizedBox(height: 4),
          Text(
            'Choose your preferred reading line density',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _DensityPill(
                  label: 'Compact',
                  valueLabel: '1.3x',
                  icon: Icons.format_line_spacing,
                  isSelected: (lineHeight - 1.3).abs() < 0.1,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onLineHeightChanged(1.3);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DensityPill(
                  label: 'Comfortable',
                  valueLabel: '1.6x',
                  icon: Icons.format_line_spacing,
                  isSelected: (lineHeight - 1.6).abs() < 0.1 || (lineHeight >= 1.4 && lineHeight <= 1.7 && (lineHeight - 1.3).abs() >= 0.1 && (lineHeight - 1.9).abs() >= 0.1),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onLineHeightChanged(1.6);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DensityPill(
                  label: 'Relaxed',
                  valueLabel: '1.9x',
                  icon: Icons.format_line_spacing,
                  isSelected: (lineHeight - 1.9).abs() < 0.1 || lineHeight > 1.75,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onLineHeightChanged(1.9);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.isSelected,
    required this.presetColors,
    required this.onTap,
  });

  final ReadingPreset preset;
  final bool isSelected;
  final ReadingColors presetColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: presetColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : presetColors.text.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(
                  preset.icon,
                  size: 16,
                  color: isSelected ? colorScheme.primary : presetColors.text,
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              preset.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: presetColors.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              preset.subtitle,
              style: TextStyle(
                fontSize: 9,
                color: presetColors.text.withValues(alpha: 0.65),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  final ReadingViewTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = theme.resolve(colorScheme);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.background,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colors.text.withValues(alpha: 0.2),
                width: isSelected ? 3 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    size: 20,
                    color: colors.text,
                  )
                : null,
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 52,
            child: Text(
              theme.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelectionCard extends StatelessWidget {
  const _ModeSelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.4)
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: colorScheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DensityPill extends StatelessWidget {
  const _DensityPill({
    required this.label,
    required this.valueLabel,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String valueLabel;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              valueLabel,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
