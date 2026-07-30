import 'dart:io';

import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/widgets/novel/novel_metadata_bar.dart';

class NovelHeroHeader extends StatelessWidget {
  const NovelHeroHeader({super.key, required this.book});

  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 360,
      child: Stack(
        children: [
          if (book.coverPath != null)
            Positioned.fill(
              child: Image.file(
                File(book.coverPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(color: colors.surfaceContainerHigh),
              ),
            )
          else
            Container(color: colors.surfaceContainerHigh),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    colors.surface.withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Hero(
                  tag: 'book-cover-${book.id}',
                  child: BookCover(coverPath: book.coverPath, width: 110, height: 165),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        book.title,
                        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (book.author != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          book.author!,
                          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      NovelMetadataBar(book: book),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
