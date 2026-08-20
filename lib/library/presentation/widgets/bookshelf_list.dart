import 'package:flutter/material.dart';

import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/widgets/book_card.dart';

class BookshelfList extends StatelessWidget {
  const BookshelfList({
    super.key,
    required this.books,
    required this.onBookTap,
    required this.onDeleteBook,
  });

  final List<BookEntity> books;
  final void Function(String id) onBookTap;
  final void Function(String id) onDeleteBook;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
      itemCount: books.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final book = books[index];
        return Dismissible(
          key: ValueKey(book.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            onDeleteBook(book.id);
            return false;
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: Theme.of(context).colorScheme.error,
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          child: BookCard(book: book, onTap: () => onBookTap(book.id)),
        );
      },
    );
  }
}
