import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:atlas_app/core/design_system/atoms/book_badge.dart';
import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';

class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.book,
    this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  final BookEntity book;
  final VoidCallback? onTap;
  final bool isSelectionMode;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = book.progress ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: isSelectionMode && isSelected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
              side: BorderSide(color: cs.primary, width: 2),
            )
          : null,
      color: isSelectionMode && isSelected
          ? cs.primaryContainer.withValues(alpha: 0.25)
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              if (isSelectionMode) ...[
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              _BookCoverStack(book: book),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BookInfoSection(book: book),
                    const SizedBox(height: AppSpacing.sm),
                    _ProgressBar(progress: progress),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookGridCard extends HookWidget {
  const BookGridCard({
    super.key,
    required this.book,
    this.onTap,
    this.onLongPress,
    this.coverWidth = 115,
    this.coverHeight = 175,
    this.isDesktop = false,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  final BookEntity book;
  final VoidCallback? onTap;
  final void Function(Offset position)? onLongPress;
  final double coverWidth;
  final double coverHeight;
  final bool isDesktop;
  final bool isSelectionMode;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final hovered = useState(false);
    final cs = Theme.of(context).colorScheme;
    final progress = book.progress ?? 0;

    return MouseRegion(
      onEnter: (_) => hovered.value = true,
      onExit: (_) => hovered.value = false,
      child: GestureDetector(
        onTap: onTap,
        onLongPressStart: onLongPress != null
            ? (d) => onLongPress!(d.globalPosition)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: hovered.value && isDesktop && !isSelectionMode
              ? (Matrix4.identity()..translateByDouble(0.0, -4.0, 0.0, 1.0))
              : Matrix4.identity(),
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape: isSelectionMode && isSelected
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
                    side: BorderSide(color: cs.primary, width: 2),
                  )
                : null,
            color: isSelectionMode && isSelected
                ? cs.primaryContainer.withValues(alpha: 0.25)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BookCoverStack(
                  book: book,
                  coverWidth: coverWidth,
                  coverHeight: coverHeight,
                  overlay: progress > 0
                      ? Positioned(
                          bottom: 4,
                          left: 4,
                          right: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress / 100,
                              minHeight: 3,
                              backgroundColor: Colors.black26,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                cs.primary,
                              ),
                            ),
                          ),
                        )
                      : null,
                  selectionOverlay: isSelectionMode
                      ? Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isSelected
                                  ? cs.primary
                                  : Colors.white70,
                              size: 24,
                            ),
                          ),
                        )
                      : null,
                  hoverOverlay: hovered.value && isDesktop && !isSelectionMode
                      ? Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: hovered.value ? 1.0 : 0.0,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.8),
                                    Colors.transparent,
                                  ],
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(4),
                                ),
                              ),
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: _BookInfoSection(
                                book: book,
                                compact: true,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: _BookInfoSection(book: book, compact: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 4,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${progress.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 10,
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return const BookBadge.primary(
      label: 'NEW',
      isCompact: true,
    );
  }
}

/// Marker for tracked ongoing novels that gained new chapters since the
/// user last opened them.
class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 0 ? '+$count' : 'NEW';
    return BookBadge.tertiary(
      label: label,
      icon: Icons.auto_stories_rounded,
      isCompact: true,
    );
  }
}

class _BookCoverStack extends StatelessWidget {
  const _BookCoverStack({
    required this.book,
    this.coverWidth,
    this.coverHeight,
    this.overlay,
    this.hoverOverlay,
    this.selectionOverlay,
  });

  final BookEntity book;
  final double? coverWidth;
  final double? coverHeight;
  final Widget? overlay;
  final Widget? hoverOverlay;
  final Widget? selectionOverlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Hero(
          tag: 'book-cover-${book.id}',
          child: BookCover(
            coverPath: book.coverPath,
            format: book.format,
            width: coverWidth ?? 72,
            height: coverHeight ?? 100,
          ),
        ),
        if (selectionOverlay != null)
          selectionOverlay!
        else if (book.hasUpdate)
          Positioned(
            top: 6,
            right: 6,
            child: _UpdateBadge(count: book.newChapterCount),
          )
        else if (book.progress == null)
          const Positioned(top: 6, right: 6, child: _NewBadge()),
        ?overlay,
        ?hoverOverlay,
      ],
    );
  }
}

class _BookInfoSection extends StatelessWidget {
  const _BookInfoSection({required this.book, this.compact = false});

  final BookEntity book;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = compact
        ? theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)
        : theme.textTheme.titleSmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          book.title,
          style: titleStyle,
          maxLines: compact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
        ),
        if (book.author != null) ...[
          SizedBox(height: compact ? 0 : AppSpacing.xs),
          Text(
            book.author!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
