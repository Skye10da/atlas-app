import 'dart:math';

import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/widgets/book_card.dart';

class BookshelfGrid extends StatelessWidget {
  const BookshelfGrid({
    super.key,
    required this.books,
    required this.isDesktop,
    required this.isTablet,
    required this.onBookTap,
    required this.onBookLongPress,
    required this.onDeleteBook,
    this.isSelectionMode = false,
    this.selectedIds = const {},
  });

  final List<BookEntity> books;
  final bool isDesktop;
  final bool isTablet;
  final void Function(String id) onBookTap;
  final void Function(String id, Offset globalPosition) onBookLongPress;
  final void Function(String id) onDeleteBook;
  final bool isSelectionMode;
  final Set<String> selectedIds;

  @override
  Widget build(BuildContext context) {
    final crossSpacing = isDesktop ? 20.0 : 12.0;
    final mainSpacing = isDesktop ? 20.0 : 12.0;
    final coverWidth = isDesktop
        ? 150.0
        : isTablet
        ? 130.0
        : 115.0;
    final coverHeight = isDesktop
        ? 225.0
        : isTablet
        ? 195.0
        : 175.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The GridView is wrapped in 24px of horizontal padding below, so
        // measure from the width the grid actually receives. Computing columns
        // and tile width from the unpadded width makes real tiles narrower
        // than `tileWidth`, which shrinks the aspect-ratio-derived tile height
        // below what the card's cover + info section need.
        final availableWidth = max(0.0, constraints.maxWidth - 48);
        final idealColumns =
            ((availableWidth + crossSpacing) / (coverWidth + crossSpacing))
                .round()
                .clamp(1, 100)
                .toInt();
        // Cap to the book count first, then derive the tile width from the
        // capped count. The planned tile width must equal the width the tiles
        // actually receive, otherwise the fixed mainAxisExtent (computed from
        // the planned width) and the real tile disagree.
        final columns = min(idealColumns, max(1, books.length));
        final tileWidth =
            (availableWidth - (columns - 1) * crossSpacing) / columns;
        final gridWidth = columns * tileWidth + (columns - 1) * crossSpacing;
        // Covers fill the whole tile width at the preset cover aspect ratio, and
        // the tile is exactly cover + info tall, so no card has dead space.
        final tileCoverHeight = tileWidth * (coverHeight / coverWidth);
        // The compact info section under every tile is 2 title lines + 1
        // author line of bodySmall, plus the section's top/bottom padding.
        // Measure the line height with TextPainter at the real text scaler:
        // Windows font scaling is non-linear (`scale(1) != scale(12)/12`),
        // and the padding is not scaled at all, so estimating from
        // `textScaler.scale(1)` underestimates the tile height and overflows
        // the card's Column. The Card's vertical margin is spent before the
        // Column starts, so count it against the tile as well. The +4 buffer
        // absorbs fractional paragraph rounding at unusual text scales.
        final cardMargin = Theme.of(context).cardTheme.margin;
        final cardMarginVertical =
            cardMargin is EdgeInsets ? cardMargin.vertical : 8.0;
        final infoHeight = _infoLineHeight(context) * 3 +
            AppSpacing.sm * 2 +
            cardMarginVertical +
            4;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: gridWidth,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 48),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: mainSpacing,
                  crossAxisSpacing: crossSpacing,
                  // Cover (full tile width) plus the title/author section.
                  mainAxisExtent: tileCoverHeight + infoHeight,
                ),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  final isSelected = selectedIds.contains(book.id);
                  return BookGridCard(
                    book: book,
                    coverWidth: tileWidth,
                    coverHeight: tileCoverHeight,
                    isDesktop: isDesktop,
                    isSelectionMode: isSelectionMode,
                    isSelected: isSelected,
                    onTap: () => onBookTap(book.id),
                    onLongPress: (pos) => onBookLongPress(book.id, pos),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Height of a single line of [TextTheme.bodySmall] at the context's text
/// scaler, measured with [TextPainter] instead of assumed from `scale(1)`.
double _infoLineHeight(BuildContext context) {
  final textPainter = TextPainter(
    text: TextSpan(text: 'Ag', style: Theme.of(context).textTheme.bodySmall),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: TextDirection.ltr,
  )..layout();
  final height = textPainter.height;
  textPainter.dispose();
  return height;
}
