import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';

class NovelMetadataBar extends StatelessWidget {
  const NovelMetadataBar({super.key, required this.book});

  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final style = textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (book.rating != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
              const SizedBox(width: 2),
              Text(book.rating!.toStringAsFixed(1), style: style),
            ],
          ),
        if (book.status != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: book.status == 'Ongoing'
                  ? Colors.green.withValues(alpha: 0.15)
                  : colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              book.status!,
              style: textTheme.labelSmall?.copyWith(
                color: book.status == 'Ongoing' ? Colors.green.shade700 : colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        if (book.language != null)
          Text(book.language!, style: style),
        Text('${book.totalChapters}ch', style: style),
      ],
    );
  }
}
