import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';

class BookshelfScattered extends HookWidget {
  const BookshelfScattered({
    super.key,
    required this.books,
    required this.onBookTap,
    required this.onDeleteBook,
    this.isSelectionMode = false,
    this.selectedIds = const {},
  });

  final List<BookEntity> books;
  final void Function(String id) onBookTap;
  final void Function(String id) onDeleteBook;
  final bool isSelectionMode;
  final Set<String> selectedIds;

  static List<_ScatteredBook> _generateScattered(int count) {
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
    final scattered = useMemoized(
      () => _generateScattered(books.length),
      [books.length],
    );
    final cs = Theme.of(context).colorScheme;
    final isDesktop = AppBreakpoints.isLarge(context);
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
              ((books.length / cols).ceil() * cardHeight * 1.2) + 100;

          return SizedBox(
            height: totalHeight,
            child: Stack(
              children: books.asMap().entries.map((entry) {
                final i = entry.key;
                final book = entry.value;
                final isSelected = selectedIds.contains(book.id);
                final s = scattered[i];
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
                        onTap: () => onBookTap(book.id),
                        child: Card(
                          elevation: isSelected ? 8 : 4,
                          shadowColor: isSelected
                              ? cs.primary.withValues(alpha: 0.4)
                              : Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isSelected
                                ? BorderSide(color: cs.primary, width: 2)
                                : BorderSide.none,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                BookCover(
                                  coverPath: book.coverPath,
                                  width: coverWidth,
                                  height: coverHeight,
                                  format: book.format,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  book.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (book.progress != null && book.progress! > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: LinearProgressIndicator(
                                      value: book.progress,
                                      minHeight: 2,
                                    ),
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
