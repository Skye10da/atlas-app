import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/atoms/app_chip.dart';
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
    required this.onFontSizeChanged,
    required this.onFontFamilyChanged,
    required this.onFontWeightChanged,
    required this.onLineHeightChanged,
    required this.onLetterSpacingChanged,
    required this.onTextAlignmentChanged,
    required this.fontFamilies,
    required this.onDownloadMore,
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

  /// Available font families (bundled + downloaded).
  final List<String> fontFamilies;

  /// Called when the user taps "Download more fonts…".
  final VoidCallback onDownloadMore;

  /// Threshold: when System + fontFamilies exceeds this, use the sheet picker.
  static const _sheetThreshold = 6;

  List<(String?, String)> get _allOptions => [
        (null, 'System'),
        ...fontFamilies.map((f) => (f, f)),
      ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: 'Font Size'),
          Slider(
            value: fontSize,
            min: 12,
            max: 28,
            divisions: 16,
            label: '${fontSize.round()}',
            onChanged: onFontSizeChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppSectionHeader(title: 'Font Family'),
          const SizedBox(height: AppSpacing.xs),
          _buildFontFamilySection(context),
          const SizedBox(height: AppSpacing.xs),
          // Download more button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TextButton.icon(
              onPressed: onDownloadMore,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Download more fonts…'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppSectionHeader(title: 'Font Weight'),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final w in const <int?>[null, 400, 500, 600, 700])
                AppChip(
                  label: switch (w) {
                    null => 'Regular',
                    500 => 'Medium',
                    600 => 'SemiBold',
                    700 => 'Bold',
                    _ => '$w',
                  },
                  selected: fontWeight == w,
                  onPressed: () => onFontWeightChanged(w),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppSectionHeader(title: 'Line Height'),
          Slider(
            value: lineHeight,
            min: 1.0,
            max: 2.0,
            divisions: 10,
            label: lineHeight.toStringAsFixed(1),
            onChanged: onLineHeightChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppSectionHeader(title: 'Letter Spacing'),
          Slider(
            value: letterSpacing,
            min: 0.0,
            max: 5.0,
            divisions: 20,
            label: letterSpacing.toStringAsFixed(1),
            onChanged: onLetterSpacingChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppSectionHeader(title: 'Text Alignment'),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            children: TextAlignment.values.map((a) {
              final isSelected = textAlignment == a;
              return AppChip(
                label: a.label,
                selected: isSelected,
                onPressed: () => onTextAlignmentChanged(a),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFontFamilySection(BuildContext context) {
    final options = _allOptions;
    final totalOptions = options.length;

    // Few fonts: show chips (fast, glanceable).
    if (totalOptions <= _sheetThreshold) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: options.map((opt) {
            final (f, label) = opt;
            final isSelected = fontFamily == f;
            return AppChip(
              label: label,
              selected: isSelected,
              onPressed: () => onFontFamilyChanged(f),
            );
          }).toList(),
        ),
      );
    }

    // Many fonts: compact selector → modal bottom sheet.
    final currentLabel =
        _allOptions.firstWhere((o) => o.$1 == fontFamily, orElse: () => (null, 'System')).$2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: GestureDetector(
        onTap: () => _openFontPickerSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  currentLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFontPickerSheet(BuildContext context) {
    final options = _allOptions;
    final currentFamily = fontFamily;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
              child: Text(
                'Font Family',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: options.length,
                itemBuilder: (ctx, i) {
                  final (f, label) = options[i];
                  final isSelected = currentFamily == f;
                  return ListTile(
                    title: Text(
                      label,
                      style: TextStyle(
                        fontFamily: f,
                        fontSize: 16,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(ctx).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      onFontFamilyChanged(f);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
