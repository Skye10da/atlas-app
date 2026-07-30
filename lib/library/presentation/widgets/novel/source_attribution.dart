import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';

class SourceAttribution extends StatelessWidget {
  const SourceAttribution({super.key, required this.book});

  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    if (book.sourceName == null && book.sourceUrl == null) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Source', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_outlined, size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    book.sourceName ?? 'Unknown',
                    style: textTheme.bodyMedium,
                  ),
                ),
                if (book.sourceUrl != null)
                  IconButton(
                    icon: Icon(Icons.open_in_new, size: 18, color: colors.primary),
                    onPressed: () {},
                    tooltip: 'Open source',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
