import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:atlas_app/core/design_system/atoms/app_divider.dart';
import 'package:atlas_app/core/design_system/atoms/app_section_header.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';

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

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Typeface / Font Family
          AppSectionHeader(
            title: 'Typeface',
            padding: 0,
            actionLabel: 'Get Fonts',
            action: onDownloadMore,
          ),
          const SizedBox(height: 4),
          Text(
            'Select font family to customize your reading experience',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildFontCards(context),

          const SizedBox(height: AppSpacing.md),
          const AppDivider(),
          const SizedBox(height: AppSpacing.sm),

          // 2. Font Weight
          const AppSectionHeader(title: 'Font Weight', padding: 0),
          const SizedBox(height: 4),
          Text(
            'Adjust stroke thickness for higher contrast or delicate serifs',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              (400, 'Regular', 'Normal weight'),
              (500, 'Medium', 'Balanced contrast'),
              (600, 'Semi-Bold', 'Strong clarity'),
              (700, 'Bold', 'High emphasis'),
            ].map((entry) {
              final isSelected = (fontWeight == null && entry.$1 == 400) ||
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
                              : colorScheme.outlineVariant.withValues(alpha: 0.4),
                          width: isSelected ? 1.8 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight(entry.$1),
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ],
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

          // 3. Text Alignment
          const AppSectionHeader(title: 'Text Alignment', padding: 0),
          const SizedBox(height: 4),
          Text(
            'Choose between ragged-right edge or clean newspaper justification',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              (TextAlignment.left, 'Left', Icons.format_align_left, 'Natural spacing'),
              (TextAlignment.justify, 'Justify', Icons.format_align_justify, 'Clean edges'),
              (TextAlignment.center, 'Center', Icons.format_align_center, 'Poetry style'),
            ].map((entry) {
              final isSelected = textAlignment == entry.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTextAlignmentChanged(entry.$1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
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
                          Icon(
                            entry.$3,
                            size: 20,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            entry.$4,
                            style: TextStyle(
                              fontSize: 9,
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
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

          // 4. Page Margins
          const AppSectionHeader(title: 'Page Margins', padding: 0),
          const SizedBox(height: 4),
          Text(
            'Control the white space breathing room along page edges',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              (MarginPreset.narrow, 'Compact', 'More text per page', Icons.unfold_less),
              (MarginPreset.normal, 'Standard', 'Balanced comfort', Icons.crop_portrait),
              (MarginPreset.wide, 'Spacious', 'Focused column width', Icons.unfold_more),
            ].map((entry) {
              final isSelected = marginPreset == entry.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onMarginPresetChanged(entry.$1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
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
                          Icon(
                            entry.$4,
                            size: 20,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            entry.$3,
                            style: TextStyle(
                              fontSize: 9,
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
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

          // 5. Letter Spacing Fine-Tuning
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
            onChanged: (v) {
              onLetterSpacingChanged(v);
            },
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
                    Icon(Icons.add_circle_outline, size: 20, color: colorScheme.primary),
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
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
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
