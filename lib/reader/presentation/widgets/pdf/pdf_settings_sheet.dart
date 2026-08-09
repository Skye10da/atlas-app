import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';
import 'package:atlas_app/settings/presentation/screens/reading_settings_screen.dart';
import 'package:atlas_app/settings/presentation/widgets/settings_widgets.dart';

/// PDF reader settings with the controls that actually apply to a fixed-page
/// viewer: reader theme (drives the night/invert effect) and keep-screen-awake,
/// plus a link to the full Reading settings for everything else. Text/layout
/// typography tabs are intentionally excluded — they can't reflow a PDF.
class PdfSettingsSheet extends ConsumerStatefulWidget {
  const PdfSettingsSheet({super.key});

  @override
  ConsumerState<PdfSettingsSheet> createState() => _PdfSettingsSheetState();
}

class _PdfSettingsSheetState extends ConsumerState<PdfSettingsSheet> {
  void _openFullSettings() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ReadingSettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final settingsAsync = ref.watch(readingSettingsProvider);
    final settings = settingsAsync.valueOrNull ?? const ReadingSettingsEntity();
    final notifier = ref.read(readingSettingsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Reading Settings',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Color Theme', style: textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ReadingViewTheme.values.map((t) {
                return _PdfThemeTile(
                  theme: t,
                  isSelected: settings.theme == t,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    notifier.setTheme(t);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Text('Options', style: textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            SettingsGroup(
              children: [
                SwitchTile(
                  title: 'Keep screen awake',
                  subtitle: 'Prevent the screen from turning off while reading',
                  value: settings.keepScreenAwake,
                  onChanged: notifier.setKeepScreenAwake,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openFullSettings,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('More in Reading settings'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfThemeTile extends StatelessWidget {
  const _PdfThemeTile({
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