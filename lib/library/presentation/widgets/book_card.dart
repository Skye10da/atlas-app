import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';

class BookCard extends StatelessWidget {
  const BookCard({super.key, required this.book, this.onTap});

  final BookEntity book;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress = book.progress ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
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

class BookGridCard extends StatefulWidget {
  const BookGridCard({
    super.key,
    required this.book,
    this.onTap,
    this.onLongPress,
    this.coverWidth = 120,
    this.coverHeight = 180,
    this.isDesktop = false,
  });

  final BookEntity book;
  final VoidCallback? onTap;
  final void Function(Offset position)? onLongPress;
  final double coverWidth;
  final double coverHeight;
  final bool isDesktop;

  @override
  State<BookGridCard> createState() => _BookGridCardState();
}

class _BookGridCardState extends State<BookGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = widget.book.progress ?? 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPressStart: widget.onLongPress != null
            ? (d) => widget.onLongPress!(d.globalPosition)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: _hovered && widget.isDesktop
              ? (Matrix4.identity()..translateByDouble(0.0, -4.0, 0.0, 1.0))
              : Matrix4.identity(),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BookCoverStack(
                  book: widget.book,
                  coverWidth: widget.coverWidth,
                  coverHeight: widget.coverHeight,
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
                  hoverOverlay: _hovered && widget.isDesktop
                      ? Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: _hovered ? 1.0 : 0.0,
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
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 8,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _QuickActionChip(
                                    icon: Icons.play_arrow,
                                    label: 'Read',
                                    onTap: widget.onTap,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.sm,
                    0,
                  ),
                  child: _BookInfoSection(book: widget.book, compact: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'New',
        style: TextStyle(
          color: cs.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
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
  });

  final BookEntity book;
  final double? coverWidth;
  final double? coverHeight;
  final Widget? overlay;
  final Widget? hoverOverlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Hero(
          tag: 'book-cover-${book.id}',
          child: BookCover(
            coverPath: book.coverPath,
            format: book.format,
            width: coverWidth ?? 56,
            height: coverHeight ?? 80,
          ),
        ),
        if (book.progress == null)
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
