import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';

/// Rail of tracked books that gained new chapters, with a
/// "Check for updates" action.
///
/// Default presentation is the horizontal [NewChaptersCard] rail used on
/// mobile/tablet; [vertical] renders the mockup's desktop right-rail card —
/// a bordered card listing one compact row per book.
class NewChaptersCard extends StatelessWidget {
  const NewChaptersCard({
    super.key,
    required this.books,
    required this.onBookTap,
    this.onCheckForUpdates,
    this.isChecking = false,
    this.vertical = false,
  });

  final List<BookEntity> books;
  final void Function(String id) onBookTap;
  final VoidCallback? onCheckForUpdates;
  final bool isChecking;

  /// Desktop right-rail presentation (frame G).
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (books.isEmpty) return const SizedBox.shrink();

    if (vertical) {
      return Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Flexible(
                  child: Text(
                    'New chapters',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: cs.tertiary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${books.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (onCheckForUpdates != null)
                  IconButton(
                    tooltip: 'Check for updates',
                    onPressed: isChecking ? null : onCheckForUpdates,
                    icon: isChecking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            for (final book in books)
              _NewChapterListRow(book: book, onTap: () => onBookTap(book.id)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                'New chapters',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${books.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            if (onCheckForUpdates != null)
              TextButton.icon(
                onPressed: isChecking ? null : onCheckForUpdates,
                icon: isChecking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Check'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final book = books[index];
              return _NewChapterTile(
                book: book,
                onTap: () => onBookTap(book.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NewChapterTile extends StatelessWidget {
  const _NewChapterTile({required this.book, required this.onTap});

  final BookEntity book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final count = book.newChapterCount;

    return SizedBox(
      width: 92,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BookCover(
                    coverPath: book.coverPath,
                    format: book.format,
                    width: 92,
                    height: 124,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.tertiary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      count > 0 ? '+$count' : 'NEW',
                      style: TextStyle(
                        color: cs.onTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              book.title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact list row inside the desktop vertical "New chapters" card
/// (cover 36x50, badge, title, "+N new chapters").
class _NewChapterListRow extends StatelessWidget {
  const _NewChapterListRow({required this.book, required this.onTap});

  final BookEntity book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = book.newChapterCount;
    final cs = Theme.of(context).colorScheme;
    final coverClip = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BookCover(
        coverPath: book.coverPath,
        format: book.format,
        width: 36,
        height: 50,
      ),
    );

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(top: 10, bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                coverClip,
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: cs.tertiary,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      count > 0 ? '+$count' : 'NEW',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onTertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count > 0 ? '+$count new chapters' : 'New chapters',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
