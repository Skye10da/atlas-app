import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';

class ThemeTab extends StatelessWidget {
  const ThemeTab({
    super.key,
    required this.theme,
    required this.marginPreset,
    required this.onThemeChanged,
    required this.onMarginPresetChanged,
  });

  final ReadingViewTheme theme;
  final MarginPreset marginPreset;
  final ValueChanged<ReadingViewTheme> onThemeChanged;
  final ValueChanged<MarginPreset> onMarginPresetChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Color Theme', style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ReadingViewTheme.values.map((t) {
              return _ThemeTile(
                theme: t,
                isSelected: theme == t,
                onTap: () => onThemeChanged(t),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Text('Margins', style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            children: MarginPreset.values.map((m) {
              final isSelected = marginPreset == m;
              return ChoiceChip(
                label: Text(m.label),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  onMarginPresetChanged(m);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  final ReadingViewTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vt = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 56,
        decoration: BoxDecoration(
          color: vt.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : vt.text.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.format_quote, size: 16, color: vt.text),
            const SizedBox(height: 2),
            Text(
              theme.name,
              style: TextStyle(
                fontSize: 9,
                color: vt.text,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
