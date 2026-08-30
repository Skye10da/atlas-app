import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_viewer_models.dart';

/// List of user-created highlighted text markers.
class PdfMarkersPanel extends StatelessWidget {
  const PdfMarkersPanel({
    super.key,
    required this.markers,
    required this.onSelected,
    required this.onDelete,
    this.nightMode = false,
  });

  final List<PdfMarker> markers;
  final void Function(PdfMarker marker) onSelected;
  final void Function(PdfMarker marker) onDelete;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (markers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Select text in the document, then use the highlight menu to add a marker.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: markers.length,
      itemBuilder: (context, index) {
        final marker = markers[index];
        final snippet = marker.range.text.trim();

        return InkWell(
          onTap: () => onSelected(marker),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: marker.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurface,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Page ${marker.range.pageNumber}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  tooltip: 'Delete marker',
                  onPressed: () => onDelete(marker),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
