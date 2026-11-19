import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:atlas_app/core/design_system/atoms/app_divider.dart';
import 'package:atlas_app/core/design_system/atoms/app_section_header.dart';
import 'package:atlas_app/core/design_system/molecules/icon_controls.dart';
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

    // Highlight the density preset closest to the current line height.
    var nearestDensity = 1.3;
    for (final preset in const [1.3, 1.6, 1.9]) {
      if ((preset - lineHeight).abs() < (nearestDensity - lineHeight).abs()) {
        nearestDensity = preset;
      }
    }

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

          // 2. Font Size — live preview between the beads.
          IconStepper(
            value: fontSize.clamp(12.0, 32.0),
            min: 12,
            max: 32,
            step: 1,
            onChanged: onFontSizeChanged,
            semanticLabel: 'Text size',
            valueLabel: '${fontSize.round()} pt',
            preview: Text(
              'Aa',
              style: TextStyle(
                fontSize: (fontSize * 0.9).clamp(14.0, 28.0),
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
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
          // Theme Mode — auto / light / dark glyphs.
          IconSegment<ThemeMode>(
            options: const [
              IconSegmentOption(
                ThemeMode.system,
                label: 'System',
                icon: Icons.brightness_auto_rounded,
              ),
              IconSegmentOption(
                ThemeMode.light,
                label: 'Light',
                icon: Icons.light_mode_rounded,
              ),
              IconSegmentOption(
                ThemeMode.dark,
                label: 'Dark',
                icon: Icons.dark_mode_rounded,
              ),
            ],
            selected: themeMode,
            onSelected: (m) => onThemeModeChanged(m),
          ),

          const SizedBox(height: AppSpacing.sm),
          // Pattern & custom background — reader-only niche knobs.
          AdvancedDisclosure(
            label: 'Pattern & background',
            hint: pattern.label,
            children: [
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
                              : colorScheme.outlineVariant.withValues(
                                  alpha: 0.4,
                                ),
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
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          const AppDivider(),
          const SizedBox(height: AppSpacing.sm),

          // 4. Reading Mode Selector (Paged vs Real Flip vs Continuous)
          const AppSectionHeader(title: 'Reading Flow', padding: 0),
          const SizedBox(height: AppSpacing.sm),
          IconSegment<ReadingMode>(
            options: const [
              IconSegmentOption(
                ReadingMode.page,
                label: 'Page Flip',
                icon: Icons.auto_stories,
              ),
              IconSegmentOption(
                ReadingMode.realFlip,
                label: 'Real Flip',
                icon: Icons.menu_book,
              ),
              IconSegmentOption(
                ReadingMode.continuous,
                label: 'Continuous',
                icon: Icons.view_day,
              ),
            ],
            selected: readingMode,
            onSelected: (m) => onReadingModeChanged(m),
          ),

          const SizedBox(height: AppSpacing.md),
          const AppDivider(),
          const SizedBox(height: AppSpacing.sm),

          // 5. Line Spacing Density Presets
          const AppSectionHeader(title: 'Line Spacing', padding: 0),
          const SizedBox(height: AppSpacing.sm),
          IconSegment<double>(
            options: [
              IconSegmentOption(
                1.3,
                label: 'Compact',
                glyph: SpacedLinesGlyph(
                  gap: 2,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              IconSegmentOption(
                1.6,
                label: 'Comfortable',
                glyph: SpacedLinesGlyph(
                  gap: 4,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              IconSegmentOption(
                1.9,
                label: 'Relaxed',
                glyph: SpacedLinesGlyph(
                  gap: 6,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            selected: nearestDensity,
            onSelected: (v) => onLineHeightChanged(v),
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
