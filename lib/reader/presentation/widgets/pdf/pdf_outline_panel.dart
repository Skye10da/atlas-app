import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';

/// Document outline (a.k.a. table of contents / bookmarks) navigator.
class PdfOutlinePanel extends HookWidget {
  const PdfOutlinePanel({
    super.key,
    required this.outline,
    required this.onSelected,
    this.nightMode = false,
  });

  final List<PdfOutlineNode> outline;
  final void Function(PdfOutlineNode node) onSelected;
  final bool nightMode;

  static void _flatten(
    PdfOutlineNode node,
    int depth,
    List<_OutlineRow> rows,
    Set<PdfOutlineNode> expanded,
  ) {
    rows.add(_OutlineRow(node, depth));
    if (node.children.isNotEmpty && expanded.contains(node)) {
      for (final child in node.children) {
        _flatten(child, depth + 1, rows, expanded);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expanded = useState<Set<PdfOutlineNode>>({});
    final colors = Theme.of(context).colorScheme;

    if (outline.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'This document has no outline',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    final rows = <_OutlineRow>[];
    for (final node in outline) {
      _flatten(node, 0, rows, expanded.value);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final hasChildren = row.node.children.isNotEmpty;
        final isExpanded = expanded.value.contains(row.node);

        return InkWell(
          onTap: () {
            if (hasChildren) {
              final next = Set<PdfOutlineNode>.from(expanded.value);
              if (isExpanded) {
                next.remove(row.node);
              } else {
                next.add(row.node);
              }
              expanded.value = next;
            }
            onSelected(row.node);
          },
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.md + row.depth * 16,
              right: AppSpacing.sm,
            ),
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  if (hasChildren)
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.chevron_right_rounded,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    )
                  else
                    const SizedBox(width: 20),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      row.node.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: row.depth == 0 ? FontWeight.w500 : FontWeight.normal,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OutlineRow {
  const _OutlineRow(this.node, this.depth);

  final PdfOutlineNode node;
  final int depth;
}
