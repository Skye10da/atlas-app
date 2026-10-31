import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/widgets/novel/continue_reading_card.dart';
import 'package:atlas_app/library/presentation/widgets/novel/novel_metadata_bar.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';

/// How the header is sized, chosen from the available width. All layouts now
/// share the same profile-style arrangement; only the cover card differs.
enum NovelDetailLayout {
  /// Phone / side panel: smallest cover card.
  compact,

  /// Tablet left column.
  tablet,

  /// Desktop left column: largest cover card.
  desktop,
}

/// Cover, title, author, reading progress and the primary Continue button.
class NovelDetailHeader extends ConsumerWidget {
  const NovelDetailHeader({
    super.key,
    required this.book,
    required this.layout,
    this.isEmbedded = false,
    this.onReturn,
  });

  final BookEntity book;
  final NovelDetailLayout layout;
  final bool isEmbedded;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final lastRead = ref.watch(lastReadChapterProvider(book.id)).valueOrNull;

    Widget framedCover(double width, double height, double radius) {
      final cover = BookCover(
        coverPath: book.coverPath,
        format: book.format,
        width: width,
        height: height,
      );
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: isEmbedded
              ? cover
              : Hero(tag: 'book-cover-${book.id}', child: cover),
        ),
      );
    }

    final titleStyle = theme.textTheme.headlineSmall?.copyWith(
      fontFamily: 'Fraunces',
      fontWeight: FontWeight.w600,
      height: 1.14,
      fontSize: 22,
    );

    final authorLine = [
      if (book.author != null && book.author!.isNotEmpty) book.author!,
      if (book.totalChapters > 0) '${book.totalChapters} chapters',
    ].join(' · ');

    final progress = book.progress01.clamp(0.0, 1.0);
    final progressRow = progress > 0
        ? Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: progress, minHeight: 5),
                ),
                const SizedBox(height: 6),
                Text(
                  lastRead != null
                      ? '${book.progressPercent.toStringAsFixed(0)}% read · Ch. ${lastRead.index + 1}'
                      : '${book.progressPercent.toStringAsFixed(0)}% read',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    final title = Text(book.title, style: titleStyle, maxLines: 4, overflow: TextOverflow.ellipsis);
    final author = authorLine.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              authorLine,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          );
    final button = NovelContinueButton(book: book, onReturn: onReturn);

    // Blurred cover behind the header content, fading into the page surface
    // so the backdrop melts into the page instead of ending in a hard edge.
    // Clip.none lets the backdrop bleed below the header, over the top of the
    // first story sections, for a profile-style hero area.
    Widget withBackdrop(Widget header) => Stack(
      clipBehavior: Clip.none,
      children: [
        if (book.coverPath?.isNotEmpty ?? false)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: -140,
            child: _BackdropImage(coverPath: book.coverPath!),
          ),
        header,
      ],
    );

    // Profile-style header: a compact portrait cover card in front of the
    // large blurred backdrop, with title, author and the Continue button
    // beside it and the metadata below.
    final (coverWidth, coverHeight) = switch (layout) {
      NovelDetailLayout.compact => (120.0, 180.0),
      NovelDetailLayout.tablet => (140.0, 210.0),
      NovelDetailLayout.desktop => (170.0, 255.0),
    };

    // Top clearance for the floating pill action row that is overlaid on the
    // pane (8 top + 40 pill + 8 gap).
    const pad = EdgeInsets.fromLTRB(
      AppSpacing.md,
      56,
      AppSpacing.md,
      0,
    );

    return withBackdrop(
      Padding(
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and subtext are pinned to the bottom edge of the cover,
            // an inline column alignment.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                framedCover(coverWidth, coverHeight, 20),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, author],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.smMd),
            NovelMetadataBar(book: book),
            progressRow,
            // Primary action sits under the progress bar so the reading
            // status stack (title → metadata → progress) finishes into the
            // call to action. Full width: beside the cover it got only
            // ~110px in the 300px tablet pane and was crushed.
            const SizedBox(height: AppSpacing.smMd),
            button,
          ],
        ),
      ),
    );
  }
}

/// Blurred, dimmed rendition of the book cover behind the detail header.
///
/// The image is scaled up so the blur fades at its own edges, then scrimmed
/// with a surface-coloured gradient: translucent at the top (title readable
/// over the artwork) and fully opaque at the bottom (seamless with the page).
class _BackdropImage extends StatelessWidget {
  const _BackdropImage({required this.coverPath});

  final String coverPath;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isNetwork =
        coverPath.startsWith('http://') || coverPath.startsWith('https://');

    final image = isNetwork
        ? Image.network(
            coverPath,
            fit: BoxFit.cover,
            cacheWidth: 900,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          )
        : Image.file(
            File(coverPath),
            fit: BoxFit.cover,
            cacheWidth: 900,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          );

    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform.scale(
              scale: 1.6,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: image,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.surface.withValues(alpha: 0.30),
                    cs.surface.withValues(alpha: 0.72),
                    cs.surface,
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
