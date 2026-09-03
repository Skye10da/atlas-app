import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';

class SynopsisCard extends HookWidget {
  const SynopsisCard({super.key, required this.book});

  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    final expanded = useState(false);
    final desc = book.description;
    if (desc == null || desc.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    const maxLines = 4;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Synopsis',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            desc,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
            maxLines: expanded.value ? null : maxLines,
            overflow: expanded.value ? null : TextOverflow.ellipsis,
          ),
          if (desc.length > 200 || desc.contains('\n'))
            TextButton(
              onPressed: () => expanded.value = !expanded.value,
              child: Text(expanded.value ? 'Show less' : 'Show more'),
            ),
        ],
      ),
    );
  }
}
