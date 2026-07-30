import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';

class SynopsisCard extends StatefulWidget {
  const SynopsisCard({super.key, required this.book});

  final BookEntity book;

  @override
  State<SynopsisCard> createState() => _SynopsisCardState();
}

class _SynopsisCardState extends State<SynopsisCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final desc = widget.book.description;
    if (desc == null || desc.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    const maxLines = 4;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Synopsis', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            desc,
            style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.5),
            maxLines: _expanded ? null : maxLines,
            overflow: _expanded ? null : TextOverflow.ellipsis,
          ),
          if (desc.length > 200 || desc.contains('\n'))
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Show less' : 'Show more'),
            ),
        ],
      ),
    );
  }
}
