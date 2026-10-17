import 'dart:math';

import 'package:flutter/material.dart';

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
    this.columns,
  });

  final List<BookEntity> books;
  final bool isDesktop;
  final bool isTablet;
  final void Function(String id) onBookTap;
  final void Function(String id, Offset globalPosition) onBookLongPress;
  final void Function(String id) onDeleteBook;
  final bool isSelectionMode;
  final Set<String> selectedIds;

  /// Explicit column count from the refined frames (3 mobile / 5 tablet &
  /// desktop). When set, the tile width is derived from the available width
  /// and the covers scale with the tile instead of driving the layout. When
  /// null the column count is auto-calculated from the ideal cover width.
  final int? columns;

  @override
  Widget build(BuildContext context) {
    final crossSpacing = isDesktop ? 20.0 : 12.0;
    final mainSpacing = isDesktop ? 20.0 : 12.0;
    var coverWidth = isDesktop
        ? 150.0
        : isTablet
        ? 130.0
        : 115.0;
    var coverHeight = isDesktop
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
        final int columnCount;
        if (columns != null) {
          columnCount = columns!;
          // Covers follow the tile so a fixed column count at any window
          // width keeps the card's cover + info proportions (5/7 ratio).
          final tileWidth =
              (availableWidth - (columnCount - 1) * crossSpacing) / columnCount;
          if (tileWidth > 0) {
            coverWidth = min(coverWidth, tileWidth);
            coverHeight = coverWidth * 7 / 5;
          }
        } else {
          columnCount =
              ((availableWidth + crossSpacing) / (coverWidth + crossSpacing))
                  .floor()
                  .clamp(1, 100)
                  .toInt();
        }
        final tileWidth =
            (availableWidth - (columnCount - 1) * crossSpacing) / columnCount;
        final usedColumns = min(columnCount, max(1, books.length));
        final gridWidth =
            usedColumns * tileWidth + (usedColumns - 1) * crossSpacing;

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
                  crossAxisCount: usedColumns,
                  mainAxisSpacing: mainSpacing,
                  crossAxisSpacing: crossSpacing,
                  // Pin the tile height so it always leaves room for the
                  // fixed-size cover plus the title/author section below it.
                  mainAxisExtent: coverHeight + 100,
                ),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  final isSelected = selectedIds.contains(book.id);
                  return BookGridCard(
                    book: book,
                    coverWidth: coverWidth,
                    coverHeight: coverHeight,
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
