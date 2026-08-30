import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/services/cover_palette_service.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/widgets/novel/novel_metadata_bar.dart';

class NovelHeroHeader extends ConsumerWidget {
  const NovelHeroHeader({
    super.key,
    required this.book,
    this.isEmbedded = false,
  });

  final BookEntity book;
  final bool isEmbedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final paletteAsync = ref.watch(coverPaletteProvider(book.coverPath));
    final palette = paletteAsync.valueOrNull ?? CoverPalette.fallback;

    return SizedBox(
      height: 360,
      child: Stack(
        children: [
          // Ambient blurred cover backdrop
          if (book.coverPath != null)
            Positioned.fill(
              child: Image.file(
                File(book.coverPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Container(color: colors.surfaceContainerHigh),
              ),
            )
          else
            Container(color: colors.surfaceContainerHigh),

          // Dynamic Palette Gradient Blend
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.dark.withValues(alpha: 0.75),
                    palette.dark.withValues(alpha: 0.90),
                    colors.surface,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Content Row
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
                    boxShadow: [
                      BoxShadow(
                        color: palette.dominant.withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: isEmbedded
                      ? BookCover(
                          coverPath: book.coverPath,
                          width: 110,
                          height: 165,
                        )
                      : Hero(
                          tag: 'book-cover-${book.id}',
                          child: BookCover(
                            coverPath: book.coverPath,
                            width: 110,
                            height: 165,
                          ),
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        book.title,
                        style: textTheme.titleLarge?.copyWith(
                          fontFamily: 'Playfair Display',
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (book.author != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          book.author!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
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
