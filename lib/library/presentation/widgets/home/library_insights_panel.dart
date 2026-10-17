import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/widgets/home/weekly_activity_dots.dart';

/// Right-hand column of the Library on wide windows: the weekly stats card
/// and the list of novels with new chapters. Below the wide breakpoint these
/// live inline (stats beside the hero) and in the Updated tab instead.
class LibraryInsightsPanel extends StatelessWidget {
  const LibraryInsightsPanel({
    super.key,
    required this.weeklyActivity,
    required this.weekChapters,
    required this.updatedBooks,
    required this.onOpenAnalytics,
    required this.onBookTap,
    required this.onCheckForUpdates,
    this.isChecking = false,
  });

  final List<ReadingDayActivity> weeklyActivity;
  final int weekChapters;
  final List<BookEntity> updatedBooks;
  final VoidCallback onOpenAnalytics;
  final void Function(String id) onBookTap;
  final VoidCallback onCheckForUpdates;
  final bool isChecking;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (weeklyActivity.isNotEmpty)
          WeeklyActivityDots(
            weeklyActivity: weeklyActivity,
            totalChapters: weekChapters,
            onTap: onOpenAnalytics,
          ),
        if (updatedBooks.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _NewChaptersList(
            books: updatedBooks,
            onBookTap: onBookTap,
            onCheckForUpdates: onCheckForUpdates,
            isChecking: isChecking,
          ),
        ],
      ],
    );
  }
}

class _NewChaptersList extends StatelessWidget {
  const _NewChaptersList({
    required this.books,
    required this.onBookTap,
    required this.onCheckForUpdates,
    required this.isChecking,
  });

  final List<BookEntity> books;
  final void Function(String id) onBookTap;
  final VoidCallback onCheckForUpdates;
  final bool isChecking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'New chapters',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: cs.tertiary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${books.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: isChecking ? null : onCheckForUpdates,
                  tooltip: 'Check for updates',
                  icon: isChecking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded, size: 20),
                ),
              ],
            ),
            for (final book in books.take(6))
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onBookTap(book.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: BookCover(
                          coverPath: book.coverPath,
                          format: book.format,
                          width: 36,
                          height: 50,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.smMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              book.newChapterCount > 0
                                  ? '+${book.newChapterCount} new chapters'
                                  : 'New chapters',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
