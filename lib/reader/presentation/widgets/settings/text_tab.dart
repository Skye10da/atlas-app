import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:atlas_app/core/design_system/atoms/app_divider.dart';
import 'package:atlas_app/core/design_system/atoms/app_section_header.dart';
import 'package:atlas_app/core/design_system/molecules/icon_controls.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';

/// Reader "Text" tab — icon-first: the four everyday knobs (size, spacing,
/// alignment, margins) explain themselves through glyphs and live previews;
/// the rarely-touched typography knobs (typeface, weight, letter tracking)
/// sink behind an [AdvancedDisclosure].
class TextTab extends StatelessWidget {
  const TextTab({
    super.key,
    required this.fontSize,
    this.fontFamily,
    this.fontWeight,
    required this.lineHeight,
    required this.letterSpacing,
    required this.textAlignment,
    required this.marginPreset,
    required this.onFontSizeChanged,
    required this.onFontFamilyChanged,
    required this.onFontWeightChanged,
    required this.onLineHeightChanged,
    required this.onLetterSpacingChanged,
    required this.onTextAlignmentChanged,
    required this.onMarginPresetChanged,
    required this.fontFamilies,
    required this.onDownloadMore,
  });

  final double fontSize;
  final String? fontFamily;
  final int? fontWeight;
  final double lineHeight;
  final double letterSpacing;
  final TextAlignment textAlignment;
  final MarginPreset marginPreset;

  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<String?> onFontFamilyChanged;
  final ValueChanged<int?> onFontWeightChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<double> onLetterSpacingChanged;
  final ValueChanged<TextAlignment> onTextAlignmentChanged;
  final ValueChanged<MarginPreset> onMarginPresetChanged;

  final List<String> fontFamilies;
  final VoidCallback onDownloadMore;

  List<(String?, String)> get _allOptions => [
    (null, 'System'),
    ...fontFamilies.map((f) => (f, f)),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Highlight the spacing preset closest to the current line height.
    var nearestSpacing = 1.3;
    for (final preset in const [1.3, 1.6, 1.9]) {
      if ((preset - lineHeight).abs() < (nearestSpacing - lineHeight).abs()) {
        nearestSpacing = preset;
      }
    }

    SpacedLinesGlyph spacingGlyph(double gap) =>
        SpacedLinesGlyph(gap: gap, color: colorScheme.onSurfaceVariant);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Text size — live preview between the beads.
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

          // 2. Line spacing — the glyph gaps ARE the setting.
          IconSegment<double>(
            options: [
              IconSegmentOption(1.3, label: 'Tight', glyph: spacingGlyph(2)),
              IconSegmentOption(1.6, label: 'Normal', glyph: spacingGlyph(4)),
              IconSegmentOption(1.9, label: 'Roomy', glyph: spacingGlyph(6)),
            ],
            selected: nearestSpacing,
            onSelected: onLineHeightChanged,
          ),

          const SizedBox(height: AppSpacing.md),

          // 3. Text alignment — ragged edge vs clean edges.
          IconSegment<TextAlignment>(
            options: const [
              IconSegmentOption(
                TextAlignment.left,
                label: 'Left',
                icon: Icons.format_align_left,
              ),
              IconSegmentOption(
                TextAlignment.justify,
                label: 'Justify',
                icon: Icons.format_align_justify,
              ),
              IconSegmentOption(
                TextAlignment.center,
                label: 'Center',
                icon: Icons.format_align_center,
              ),
            ],
            selected: textAlignment,
            onSelected: onTextAlignmentChanged,
          ),

          const SizedBox(height: AppSpacing.md),

          // 4. Page margins — wider margins = narrower text column.
          IconSegment<MarginPreset>(
            options: const [
              IconSegmentOption(
                MarginPreset.narrow,
                label: 'Compact',
                icon: Icons.unfold_less,
              ),
              IconSegmentOption(
                MarginPreset.normal,
                label: 'Standard',
                icon: Icons.crop_portrait,
              ),
              IconSegmentOption(
                MarginPreset.wide,
                label: 'Spacious',
                icon: Icons.unfold_more,
              ),
            ],
            selected: marginPreset,
            onSelected: onMarginPresetChanged,
          ),

          const SizedBox(height: AppSpacing.md),

          // 5. Advanced — typeface, weight, letter tracking.
          AdvancedDisclosure(
            label: 'Advanced typography',
            hint: fontFamily ?? 'System',
            children: [
              const AppDivider(),
              const SizedBox(height: AppSpacing.sm),
              AppSectionHeader(
                title: 'Typeface',
                padding: 0,
                actionLabel: 'Get Fonts',
                action: onDownloadMore,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildFontCards(context),

              const SizedBox(height: AppSpacing.md),
              const AppDivider(),
              const SizedBox(height: AppSpacing.sm),

              const AppSectionHeader(title: 'Font Weight', padding: 0),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children:
                    [
                      (400, 'Regular'),
                      (500, 'Medium'),
                      (600, 'Semi-Bold'),
                      (700, 'Bold'),
                    ].map((entry) {
                      final isSelected =
                          (fontWeight == null && entry.$1 == 400) ||
                          fontWeight == entry.$1;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onFontWeightChanged(entry.$1);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                              child: Text(
                                entry.$2,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight(entry.$1),
                                  color: isSelected
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),

              const SizedBox(height: AppSpacing.md),
              const AppDivider(),
              const SizedBox(height: AppSpacing.sm),

              AppSectionHeader(
                title: 'Letter Spacing',
                padding: 0,
                actionLabel: '${letterSpacing.toStringAsFixed(1)} pt',
                action: () {},
              ),
              Slider(
                value: letterSpacing.clamp(-1.0, 3.0),
                min: -1.0,
                max: 3.0,
                divisions: 20,
                label: '${letterSpacing.toStringAsFixed(1)} pt',
                onChanged: onLetterSpacingChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFontCards(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final options = _allOptions;

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == options.length) {
            return GestureDetector(
              onTap: onDownloadMore,
              child: Container(
                width: 100,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'More Fonts',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final (font, label) = options[index];
          final isSelected = fontFamily == font;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onFontFamilyChanged(font);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 120,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aa Bb Gg',
                    style: TextStyle(
                      fontFamily: font,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
