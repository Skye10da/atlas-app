import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    required this.onFontSizeChanged,
    required this.onFontFamilyChanged,
    required this.onFontWeightChanged,
    required this.onLineHeightChanged,
    required this.onLetterSpacingChanged,
    required this.onTextAlignmentChanged,
  });

  final double fontSize;
  final String? fontFamily;
  /// Numeric reader body-text weight; `null` keeps the family default.
  final int? fontWeight;
  final double lineHeight;
  final double letterSpacing;
  final TextAlignment textAlignment;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<String?> onFontFamilyChanged;
  final ValueChanged<int?> onFontWeightChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<double> onLetterSpacingChanged;
  final ValueChanged<TextAlignment> onTextAlignmentChanged;

  static const _fontOptions = <String?>[
    null,
    'Merriweather',
    'Lora',
    'Inter',
    'Noto Serif',
    'Playfair Display',
    'Roboto Slab',
    'Open Sans',
    'EB Garamond',
    'JetBrains Mono',
  ];
  static const _fontLabels = [
    'System',
    'Merriweather',
    'Lora',
    'Inter',
    'Noto Serif',
    'Playfair',
    'Roboto Slab',
    'Open Sans',
    'Garamond',
    'JetBrains',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Font Size', style: textTheme.labelLarge),
          Slider(
            value: fontSize,
            min: 12,
            max: 28,
            divisions: 16,
            label: '${fontSize.round()}',
            onChanged: onFontSizeChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Font Family', style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: List.generate(_fontOptions.length, (i) {
              final f = _fontOptions[i];
              final isSelected = fontFamily == f;
              return ChoiceChip(
                label: Text(_fontLabels[i]),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  onFontFamilyChanged(f);
                },
              );
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Font Weight', style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final w in const <int?>[null, 400, 500, 600, 700])
                ChoiceChip(
                  label: Text(
                    switch (w) {
                      null => 'Regular',
                      500 => 'Medium',
                      600 => 'SemiBold',
                      700 => 'Bold',
                      _ => '$w',
                    },
                  ),
                  selected: fontWeight == w,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    onFontWeightChanged(w);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Line Height', style: textTheme.labelLarge),
          Slider(
            value: lineHeight,
            min: 1.0,
            max: 2.0,
            divisions: 10,
            label: lineHeight.toStringAsFixed(1),
            onChanged: onLineHeightChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Letter Spacing', style: textTheme.labelLarge),
          Slider(
            value: letterSpacing,
            min: 0.0,
            max: 5.0,
            divisions: 20,
            label: letterSpacing.toStringAsFixed(1),
            onChanged: onLetterSpacingChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Text Alignment', style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            children: TextAlignment.values.map((a) {
              final isSelected = textAlignment == a;
              return ChoiceChip(
                label: Text(a.label),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  onTextAlignmentChanged(a);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
