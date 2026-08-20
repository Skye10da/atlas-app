import 'package:flutter/material.dart';

import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_viewer_models.dart';

/// List of user-created highlighted text markers.
class PdfMarkersPanel extends StatelessWidget {
  const PdfMarkersPanel({
    required this.markers,
    required this.onSelected,
    required this.onDelete,
    required this.nightMode,
    super.key,
  });

  final List<PdfMarker> markers;
  final void Function(PdfMarker marker) onSelected;
  final void Function(PdfMarker marker) onDelete;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    if (markers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Select text in the document, then use the highlight menu to add a marker.',
            textAlign: TextAlign.center,
            style: TextStyle(color: nightMode ? Colors.white70 : Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: markers.length,
      itemBuilder: (context, index) {
        final marker = markers[index];
        final snippet = marker.range.text.trim();
        return InkWell(
          onTap: () => onSelected(marker),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: nightMode ? Colors.white12 : Colors.black12,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: marker.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
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
                          color: nightMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'page ${marker.range.pageNumber}',
                        style: TextStyle(
                          fontSize: 11,
                          color: nightMode
                              ? Colors.white54
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: nightMode ? Colors.white54 : Colors.grey,
                  ),
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
