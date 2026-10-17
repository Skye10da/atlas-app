import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';

/// "Continue reading" hero for the Library home — the most recently opened
/// in-progress book with a prominent Resume action.
///
/// Colours come from the theme's primary container pair, so the card follows
/// the active light/dark theme and any custom colour scheme.
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
          borderRadius: BorderRadius.circular(22),
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
      color: cs.primaryContainer,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Below ~320px the cover must shrink or the text column
              // overflows on very narrow phones.
              final compact = constraints.maxWidth < 320;
              final coverWidth = compact ? 64.0 : 88.0;
              final coverHeight = compact ? 92.0 : 122.0;
              final onDark = cs.onPrimaryContainer;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
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
                          'CONTINUE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: onDark.withValues(alpha: 0.7),
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
                            fontFamily: 'Fraunces',
                            fontWeight: FontWeight.w600,
                            color: onDark,
                            height: 1.15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (nowReading.author != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            nowReading.author!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: onDark.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.smMd),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 4,
                                  backgroundColor: onDark.withValues(
                                    alpha: 0.2,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    cs.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '${nowReading.progressPct}%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: onDark.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.smMd),
                        Semantics(
                          button: true,
                          label: 'Resume reading ${nowReading.title}',
                          child: FilledButton.icon(
                            onPressed: onContinue,
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                            ),
                            label: const Text('Resume'),
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              minimumSize: const Size(140, 40),
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
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
