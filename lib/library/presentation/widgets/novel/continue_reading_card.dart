import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';

class ContinueReadingCard extends ConsumerWidget {
  const ContinueReadingCard({super.key, required this.book});

  final BookEntity book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastReadAsync = ref.watch(lastReadChapterProvider(book.id));
    final progress = book.progress ?? 0;

    return lastReadAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (chapter) {
        final isContinue = chapter != null && progress > 0;

        final colors = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isContinue ? 'Continue Reading' : 'Start Reading',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isContinue) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Chapter ${chapter.index + 1} · ${chapter.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (progress / 100).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: colors.surfaceContainerHighest,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openReader(context, chapter, isContinue),
                    icon: Icon(isContinue ? Icons.play_arrow : Icons.menu_book),
                    label: Text(isContinue ? 'Continue Reading' : 'Start'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openReader(
    BuildContext context,
    ChapterEntity? chapter,
    bool isContinue,
  ) {
    final base = '/reader/${book.id}';
    if (!isContinue) {
      context.push(base);
      return;
    }
    final progress = book.progress ?? 0;
    final params = <String, String>{};
    params['chapterId'] = chapter!.id;
    if (progress > 0) {
      params['progress'] = (progress / 100).toStringAsFixed(4);
    }
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    context.push(query.isNotEmpty ? '$base?$query' : base);
  }
}
