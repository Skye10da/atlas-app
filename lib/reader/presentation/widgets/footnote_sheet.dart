import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';

/// Bottom sheet displaying an interactive footnote or endnote text.
class FootnoteSheet extends StatelessWidget {
  const FootnoteSheet({
    super.key,
    required this.noteNumber,
    required this.noteText,
  });

  final String noteNumber;
  final String noteText;

  static void show(
    BuildContext context, {
    required String noteNumber,
    required String noteText,
  }) {
    AppSheet.show(
      context: context,
      id: 'footnote_sheet',
      title: 'Footnote $noteNumber',
      fitToContent: true,
      minHeight: 120,
      maxHeightFactor: 0.65,
      child: FootnoteSheet(
        noteNumber: noteNumber,
        noteText: noteText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.format_quote_rounded, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Note $noteNumber',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            noteText,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Dismiss'),
            ),
          ),
        ],
      ),
    );
  }
}
