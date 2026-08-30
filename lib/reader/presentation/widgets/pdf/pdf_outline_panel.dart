import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';

/// Document outline (a.k.a. table of contents / bookmarks) navigator.
class PdfOutlinePanel extends StatefulWidget {
  const PdfOutlinePanel({
    super.key,
    required this.outline,
    required this.onSelected,
    this.nightMode = false,
  });

  final List<PdfOutlineNode> outline;
  final void Function(PdfOutlineNode node) onSelected;
  final bool nightMode;

  @override
  State<PdfOutlinePanel> createState() => _PdfOutlinePanelState();
}

class _PdfOutlinePanelState extends State<PdfOutlinePanel> {
  final _expanded = <PdfOutlineNode>{};

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (widget.outline.isEmpty) {
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
    for (final node in widget.outline) {
      _flatten(node, 0, rows);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final hasChildren = row.node.children.isNotEmpty;
        final isExpanded = _expanded.contains(row.node);

        return InkWell(
          onTap: () {
            if (hasChildren) {
              setState(() {
                if (isExpanded) {
                  _expanded.remove(row.node);
                } else {
                  _expanded.add(row.node);
                }
              });
            }
            widget.onSelected(row.node);
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

  void _flatten(PdfOutlineNode node, int depth, List<_OutlineRow> rows) {
    rows.add(_OutlineRow(node, depth));
    if (node.children.isNotEmpty && _expanded.contains(node)) {
      for (final child in node.children) {
        _flatten(child, depth + 1, rows);
      }
    }
  }
}

class _OutlineRow {
  const _OutlineRow(this.node, this.depth);

  final PdfOutlineNode node;
  final int depth;
}
