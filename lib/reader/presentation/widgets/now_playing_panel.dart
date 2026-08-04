import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/now_playing_sheet.dart';

/// Desktop adaptation of the Now Playing UI: rendered inside the reader's
/// right side panel (instead of the overlay bottom sheet used on mobile).
/// Reuses [NowPlayingSheet] for the content so lyrics, transport controls and
/// narration settings stay identical across form factors.
class NowPlayingPanel extends StatelessWidget {
  const NowPlayingPanel({
    super.key,
    this.bookTitle,
    this.coverPath,
    this.chapterTitle,
    this.accent,
    required this.onClose,
  });

  final String? bookTitle;
  final String? coverPath;
  final String? chapterTitle;
  final Color? accent;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      elevation: 4,
      color: colors.surfaceContainerLow,
      child: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  Icons.headphones,
                  size: 18,
                  color: accent ?? colors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Now Playing',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                  tooltip: 'Close panel',
                ),
              ],
            ),
          ),
          Expanded(
            child: NowPlayingSheet(
              chapterTitle: chapterTitle,
              bookTitle: bookTitle,
              coverPath: coverPath,
            ),
          ),
        ],
      ),
    );
  }
}
