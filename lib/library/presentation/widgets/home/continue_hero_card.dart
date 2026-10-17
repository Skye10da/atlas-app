import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';

/// "Continue reading" hero for the Library home — the most recently opened
/// in-progress book, with a prominent resume action.
class ContinueHeroCard extends StatelessWidget {
  const ContinueHeroCard({
    super.key,
    required this.book,
    this.onTap,
    this.onContinue,
  });

  final BookEntity? book;

  /// Tapping the card body (usually opens details).
  final VoidCallback? onTap;

  /// Tapping the primary action (opens the reader).
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (book == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_stories_outlined, color: cs.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Nothing in progress yet — pick a book to start reading.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final nowReading = book!;
    final progress = nowReading.progress01.clamp(0.0, 1.0);

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Below ~320px the cover, action and percentage must shrink or
              // the progress row overflows on very narrow phones.
              final compact = constraints.maxWidth < 320;
              final coverWidth = compact ? 48.0 : 64.0;
              final coverHeight = compact ? 68.0 : 92.0;
              final actionSize = compact ? 44.0 : 52.0;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BookCover(
                      coverPath: nowReading.coverPath,
                      format: nowReading.format,
                      width: coverWidth,
                      height: coverHeight,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'CONTINUE READING',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nowReading.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (nowReading.author != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            nowReading.author!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 5,
                                  backgroundColor: cs.surfaceContainerHighest,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    cs.primary,
                                  ),
                                ),
                              ),
                            ),
                            if (!compact) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                '${nowReading.progressPct}%',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Semantics(
                    button: true,
                    label: 'Continue reading ${nowReading.title}',
                    child: Material(
                      color: cs.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: onContinue,
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: actionSize,
                          height: actionSize,
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: cs.onPrimary,
                            size: compact ? 24 : 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
