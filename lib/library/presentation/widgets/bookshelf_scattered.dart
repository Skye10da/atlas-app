import 'dart:math';

import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';

class BookshelfScattered extends StatefulWidget {
  const BookshelfScattered({
    super.key,
    required this.books,
    required this.onBookTap,
    required this.onDeleteBook,
  });

  final List<BookEntity> books;
  final void Function(String id) onBookTap;
  final void Function(String id) onDeleteBook;

  @override
  State<BookshelfScattered> createState() => _BookshelfScatteredState();
}

class _BookshelfScatteredState extends State<BookshelfScattered> {
  late List<_ScatteredBook> _scattered;

  @override
  void initState() {
    super.initState();
    _scattered = _generateScattered(widget.books.length);
  }

  @override
  void didUpdateWidget(covariant BookshelfScattered oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.books.length != oldWidget.books.length) {
      _scattered = _generateScattered(widget.books.length);
    }
  }

  List<_ScatteredBook> _generateScattered(int count) {
    final rng = Random(42);
    return List.generate(count, (i) {
      final angle = (rng.nextDouble() - 0.5) * 0.15;
      final xOff = (rng.nextDouble() - 0.5) * 0.1;
      final yOff = rng.nextDouble() * 0.2;
      return _ScatteredBook(angle: angle, xOffset: xOff, yOffset: yOff);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 1200;
    final coverWidth = isDesktop ? 130.0 : 90.0;
    final coverHeight = isDesktop ? 195.0 : 135.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 48 : 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = coverWidth + 24;
          final cardHeight = coverHeight + 80;
          final cols = (constraints.maxWidth / (cardWidth * 0.8)).floor().clamp(
            2,
            6,
          );
          final totalHeight =
              ((widget.books.length / cols).ceil() * cardHeight * 1.2) + 100;

          return SizedBox(
            height: totalHeight,
            child: Stack(
              children: widget.books.asMap().entries.map((entry) {
                final i = entry.key;
                final book = entry.value;
                final s = _scattered[i];
                final col = i % cols;
                final row = i ~/ cols;
                final left = col * cardWidth * 0.78 + (s.xOffset + 0.5) * 30;
                final top = row * cardHeight * 1.1 + (s.yOffset - 0.3) * 40;

                return Positioned(
                  left: left,
                  top: top,
                  child: Transform.rotate(
                    angle: s.angle,
                    child: SizedBox(
                      width: coverWidth + 16,
                      child: GestureDetector(
                        onTap: () => widget.onBookTap(book.id),
                        child: Card(
                          elevation: 4,
                          shadowColor: Colors.black26,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  children: [
                                    BookCover(
                                      coverPath: book.coverPath,
                                      format: book.format,
                                      width: coverWidth,
                                      height: coverHeight,
                                    ),
                                    if (book.progress == null)
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cs.primary,
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: Text(
                                            'New',
                                            style: TextStyle(
                                              color: cs.onPrimary,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  book.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class _ScatteredBook {
  const _ScatteredBook({
    required this.angle,
    required this.xOffset,
    required this.yOffset,
  });

  final double angle;
  final double xOffset;
  final double yOffset;
}
