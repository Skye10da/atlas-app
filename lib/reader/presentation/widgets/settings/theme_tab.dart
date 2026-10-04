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
    required this.themeMode,
    required this.pattern,
    required this.patternOpacity,
    required this.customBackgroundColor,
    required this.fontSize,
    this.fontFamily,
    this.fontWeight,
    required this.lineHeight,
    required this.readingMode,
    required this.marginPreset,
    required this.onThemeChanged,
    required this.onThemeModeChanged,
    required this.onPatternChanged,
    required this.onPatternOpacityChanged,
    required this.onCustomBackgroundChanged,
    required this.onFontSizeChanged,
    required this.onFontFamilyChanged,
    required this.onLineHeightChanged,
    required this.onReadingModeChanged,
    required this.onMarginPresetChanged,
    this.onApplyPreset,
  });

  final ReadingViewTheme theme;
  final ThemeMode themeMode;
  final ReaderPattern pattern;
  final double patternOpacity;
  final Color? customBackgroundColor;
  final double fontSize;
  final String? fontFamily;
  final int? fontWeight;
  final double lineHeight;
  final ReadingMode readingMode;
  final MarginPreset marginPreset;

  final ValueChanged<ReadingViewTheme> onThemeChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<ReaderPattern> onPatternChanged;
  final ValueChanged<double> onPatternOpacityChanged;
  final ValueChanged<Color?> onCustomBackgroundChanged;
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
          const SizedBox(height: 4),
          Text(
            'Palette for chapter background & text — pairs with system theme mode below',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.sm),
          // Theme Mode — integrated into Color Theme with matching language
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.brightness_6_rounded,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Theme Mode',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      switch (themeMode) {
                        ThemeMode.system => 'System',
                        ThemeMode.light => 'Light',
                        ThemeMode.dark => 'Dark',
                      },
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_rounded, size: 16),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selected) {
                      HapticFeedback.selectionClick();
                      onThemeModeChanged(selected.first);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    showSelectedIcon: false,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),
          // Pattern picker — reader-only overlay
          Row(
            children: [
              Icon(Icons.texture_rounded, size: 14, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Pattern',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                pattern.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ReaderPattern.values.map((p) {
              final isSelected = pattern == p;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onPatternChanged(p);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        p.icon,
                        size: 14,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (pattern != ReaderPattern.none) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text(
                  'Opacity',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: patternOpacity.clamp(0.0, 0.20),
                    min: 0.0,
                    max: 0.20,
                    divisions: 10,
                    label: '${(patternOpacity * 100).round()}%',
                    onChanged: (v) => onPatternOpacityChanged(v),
                  ),
                ),
                Text(
                  '${(patternOpacity * 100).round()}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          // Custom background — reader-only color override
          Row(
            children: [
              Icon(
                Icons.format_paint_rounded,
                size: 14,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Custom Background',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (customBackgroundColor != null)
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onCustomBackgroundChanged(null);
                  },
                  child: const Text('Clear', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _CustomBackgroundPicker(
            selected: customBackgroundColor,
            onSelected: (c) {
              HapticFeedback.selectionClick();
              onCustomBackgroundChanged(c);
            },
          ),
          const SizedBox(height: 4),
          Text(
            customBackgroundColor == null
                ? 'Uses theme default'
                : 'Overrides theme — reader only',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
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
                  isSelected:
                      (lineHeight - 1.6).abs() < 0.1 ||
                      (lineHeight >= 1.4 &&
                          lineHeight <= 1.7 &&
                          (lineHeight - 1.3).abs() >= 0.1 &&
                          (lineHeight - 1.9).abs() >= 0.1),
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
                  isSelected:
                      (lineHeight - 1.9).abs() < 0.1 || lineHeight > 1.75,
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
                ? Icon(Icons.check, size: 20, color: colors.text)
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

class _CustomBackgroundPicker extends StatelessWidget {
  const _CustomBackgroundPicker({
    required this.selected,
    required this.onSelected,
  });

  final Color? selected;
  final ValueChanged<Color?> onSelected;

  static const _presets = [
    null, // theme default
    Color(0xFFFFFBF2), // paper
    Color(0xFFFFF8E1), // parchment
    Color(0xFFF5E6CC), // sepia
    Color(0xFFEAF6FF), // blue
    Color(0xFFE6F4EA), // mint
    Color(0xFFE3F2FD), // ocean light
    Color(0xFF1E1E1E), // dark
    Color(0xFF2E3440), // nord dark
    Color(0xFF070D1E), // midnight
    Color(0xFFFFE4EC), // blush
    Color(0xFFF3E8FF), // lavender
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in _presets)
          GestureDetector(
            onTap: () => onSelected(c),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c ?? scheme.surfaceContainerLow,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      selected == c ||
                          (selected == null && c == null) ||
                          (selected != null &&
                              c != null &&
                              selected!.toARGB32() == c.toARGB32())
                      ? scheme.primary
                      : (c == null
                            ? scheme.outlineVariant.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.12)),
                  width:
                      selected == c ||
                          (selected == null && c == null) ||
                          (selected != null &&
                              c != null &&
                              selected!.toARGB32() == c.toARGB32())
                      ? 2.5
                      : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: c == null
                  ? Icon(
                      Icons.block_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    )
                  : selected != null && c.toARGB32() == selected!.toARGB32()
                  ? Icon(Icons.check, size: 18, color: _contrasting(c))
                  : null,
            ),
          ),
        GestureDetector(
          onTap: () async {
            final picked = await _showColorPicker(context, selected);
            if (picked != null) onSelected(picked);
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Colors.red,
                  Colors.orange,
                  Colors.yellow,
                  Colors.green,
                  Colors.blue,
                  Colors.purple,
                  Colors.red,
                ],
              ),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(
              Icons.colorize_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Color _contrasting(Color bg) =>
      bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

  Future<Color?> _showColorPicker(BuildContext context, Color? initial) async {
    return showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick background', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 280,
          height: 280,
          child: GridView.count(
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final c in [
                ..._presets.where((e) => e != null).cast<Color>(),
                ...Colors.primaries,
                const Color(0xFF795548),
                const Color(0xFF607D8B),
                Colors.black,
                Colors.white,
              ])
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, c),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
