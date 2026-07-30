import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';

class GenreTagRow extends ConsumerWidget {
  const GenreTagRow({super.key, required this.book});

  final BookEntity book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (book.tags.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: book.tags.map((tag) {
          return ActionChip(
            label: Text(tag, style: const TextStyle(fontSize: 12)),
            onPressed: () {
              ref.read(libraryCategoryProvider.notifier).state = LibraryCategory.novels;
              ref.read(libraryGenreFilterProvider.notifier).state = tag;
              context.pop();
            },
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: colors.outlineVariant),
          );
        }).toList(),
      ),
    );
  }
}
