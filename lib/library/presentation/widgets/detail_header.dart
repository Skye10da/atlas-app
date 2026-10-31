import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';

/// Slim action row at the top of the book / novel detail pages (replaces the
/// tall collapsing app bar): leading back/close on the left, actions on the
/// right. Colours come from the theme, so it works in light and dark.
class DetailTopBar extends StatelessWidget {
  const DetailTopBar({
    super.key,
    required this.leading,
    this.actions = const <Widget>[],
  });

  final Widget leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(children: [leading, const Spacer(), ...actions]),
    );
  }
}

/// Cover + title block shared by the book and novel detail pages.
///
/// Cover on the left (framed, with a soft shadow), serif title, author, an
/// optional [meta] row and an optional [footer] (progress / primary action)
/// on the right. No blurred backdrop or hard-coded colours.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.book,
    required this.isEmbedded,
    this.meta,
    this.footer,
  });

  final BookEntity book;
  final bool isEmbedded;
  final Widget? meta;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final coverWidth = isEmbedded ? 96.0 : 120.0;

    final cover = BookCover(
      coverPath: book.coverPath,
      format: book.format,
      width: coverWidth,
      height: coverWidth * 1.5,
    );

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: isEmbedded
                  ? cover
                  : Hero(tag: 'book-cover-${book.id}', child: cover),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFamily: 'Fraunces',
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                if (book.author != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    book.author!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (meta != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  meta!,
                ],
                if (footer != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  footer!,
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Stack(
      children: [
        Positioned.fill(child: _CoverBackdrop(coverPath: book.coverPath)),
        content,
      ],
    );
  }
}

/// Blurred, softly faded copy of the cover behind the header. It blends into
/// the theme surface at the top and bottom, so it works in light and dark and
/// leaves no hard edge against the top bar or the content below.
class _CoverBackdrop extends StatelessWidget {
  const _CoverBackdrop({required this.coverPath});

  final String? coverPath;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final path = coverPath;
    final hasImage = path != null && path.isNotEmpty;
    final isNetwork =
        hasImage && (path.startsWith('http://') || path.startsWith('https://'));

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: isNetwork
                  ? Image.network(
                      path,
                      fit: BoxFit.cover,
                      cacheWidth: 240,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    )
                  : Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      cacheWidth: 240,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cs.surface,
                  cs.surface.withValues(alpha: 0.62),
                  cs.surface,
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small tonal pill used for format / chapter-count / progress facts.
class DetailPill extends StatelessWidget {
  const DetailPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
