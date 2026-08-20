import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Document outline (a.k.a. table of contents / bookmarks) navigator.
class PdfOutlinePanel extends StatefulWidget {
  const PdfOutlinePanel({
    required this.outline,
    required this.onSelected,
    required this.nightMode,
    super.key,
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
    if (widget.outline.isEmpty) {
      return Center(
        child: Text(
          'This document has no outline',
          style: TextStyle(
            color: widget.nightMode ? Colors.white70 : Colors.grey,
          ),
        ),
      );
    }
    final rows = <_OutlineRow>[];
    for (final node in widget.outline) {
      _flatten(node, 0, rows);
    }
    return ListView.builder(
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
            padding: EdgeInsets.only(left: 12.0 + row.depth * 16, right: 8),
            child: SizedBox(
              height: 36,
              child: Row(
                children: [
                  if (hasChildren)
                    Icon(
                      isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                      color: widget.nightMode ? Colors.white70 : Colors.grey,
                    )
                  else
                    const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      row.node.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.nightMode ? Colors.white : Colors.black87,
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
