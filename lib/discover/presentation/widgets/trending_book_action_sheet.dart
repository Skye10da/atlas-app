import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/library/presentation/widgets/import_url_dialog.dart';

/// Opens the Quick Action & Preview bottom sheet for a trending or recommended book.
Future<void> showTrendingBookActionSheet(
  BuildContext context,
  TrendingBook book,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => TrendingBookActionSheet(book: book),
  );
}

/// A modal sheet displaying preview details and direct action buttons
/// (1-tap Add to Library, Read in Web Reader, Explore Source).
class TrendingBookActionSheet extends StatelessWidget {
  const TrendingBookActionSheet({
    required this.book,
    super.key,
  });

  final TrendingBook book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.xs,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero Row: Cover + Metadata
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Thumbnail
              Container(
                width: 90,
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: colorScheme.surfaceContainerHighest,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  image: book.coverUrl != null && book.coverUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(book.coverUrl!),
                          fit: BoxFit.cover,
                          onError: (_, _) {},
                        )
                      : null,
                ),
                child: (book.coverUrl == null || book.coverUrl!.isEmpty)
                    ? Center(
                        child: Icon(
                          book.isOpds
                              ? Icons.menu_book_rounded
                              : Icons.auto_stories_rounded,
                          size: 36,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),

              // Title, Author, Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Match % or Source Tag
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            book.sourceName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        if (book.matchPercentage != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${book.matchPercentage}% match',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Title
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Author
                    if (book.author != null && book.author!.isNotEmpty)
                      Text(
                        'by ${book.author}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 6),

                    // Genre & Popularity
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (book.genre != null && book.genre!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              book.genre!,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (book.popularity != null &&
                            book.popularity!.isNotEmpty)
                          Text(
                            book.popularity!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (book.description != null && book.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              book.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),

          // Primary Action: 1-Tap Add to Library / Direct Import
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.bookmark_add_rounded, size: 20),
            label: const Text(
              'Add to Library (Direct Import)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              if (book.detailUrl != null && book.detailUrl!.isNotEmpty) {
                showImportUrlSheet(
                  context,
                  initialUrl: book.detailUrl,
                  skipInputStage: true,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Importing "${book.title}"...'),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Secondary Action: Read in Web Reader
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.public_rounded, size: 18),
            label: const Text(
              'Open in Web Reader',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              if (book.detailUrl != null && book.detailUrl!.isNotEmpty) {
                context.push(
                  '/web?url=${Uri.encodeComponent(book.detailUrl!)}',
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

