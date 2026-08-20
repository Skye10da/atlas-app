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
  });

  final List<BookEntity> books;
  final bool isDesktop;
  final bool isTablet;
  final void Function(String id) onBookTap;
  final void Function(String id, Offset globalPosition) onBookLongPress;
  final void Function(String id) onDeleteBook;

  @override
  Widget build(BuildContext context) {
    final crossSpacing = isDesktop ? 20.0 : 12.0;
    final mainSpacing = isDesktop ? 20.0 : 12.0;
    final coverWidth = isDesktop
        ? 140.0
        : isTablet
        ? 120.0
        : 100.0;
    final coverHeight = isDesktop
        ? 210.0
        : isTablet
        ? 180.0
        : 150.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final idealColumns =
            ((availableWidth + crossSpacing) / (coverWidth + crossSpacing))
                .floor()
                .clamp(1, 100)
                .toInt();
        final tileWidth =
            (availableWidth - (idealColumns - 1) * crossSpacing) / idealColumns;
        final columns = min(idealColumns, max(1, books.length));
        final gridWidth = columns * tileWidth + (columns - 1) * crossSpacing;

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
                  childAspectRatio: tileWidth / (coverHeight + 110),
                ),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  return BookGridCard(
                    book: book,
                    coverWidth: coverWidth,
                    coverHeight: coverHeight,
                    isDesktop: isDesktop,
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
