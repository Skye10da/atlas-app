import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/atoms/app_chip.dart';
import 'package:atlas_app/core/design_system/atoms/app_divider.dart';
import 'package:atlas_app/core/design_system/atoms/app_section_header.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/theme_preview_screen.dart';

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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: 'Color Theme'),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ReadingViewTheme.values.map((t) {
              return _ThemeTile(
                theme: t,
                isSelected: theme == t,
                onTap: () => _openPreview(context, t),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppDivider(),
          const SizedBox(height: AppSpacing.sm),
          const AppSectionHeader(title: 'Margins'),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            children: MarginPreset.values.map((m) {
              final isSelected = marginPreset == m;
              return AppChip(
                label: m.label,
                selected: isSelected,
                onPressed: () => onMarginPresetChanged(m),
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
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 56,
        decoration: BoxDecoration(
          color: vt.resolve(colorScheme).background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : vt.resolve(colorScheme).text.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.format_quote,
              size: 16,
              color: vt.resolve(colorScheme).text,
            ),
            const SizedBox(height: 2),
            Text(
              theme.label,
              style: TextStyle(
                fontSize: 8,
                color: vt.resolve(colorScheme).text,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
