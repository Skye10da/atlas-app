import 'package:flutter/material.dart';

import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_viewer_models.dart';

/// List of user-created notes anchored to pages.
class PdfNotesPanel extends StatelessWidget {
  const PdfNotesPanel({
    required this.notes,
    required this.onSelected,
    required this.onDelete,
    required this.nightMode,
    super.key,
  });

  final List<PdfNoteEntry> notes;
  final void Function(PdfNoteEntry note) onSelected;
  final void Function(PdfNoteEntry note) onDelete;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Select text in the document, then use the note menu to add a note.',
            textAlign: TextAlign.center,
            style: TextStyle(color: nightMode ? Colors.white70 : Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return InkWell(
          onTap: () => onSelected(note),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: nightMode ? Colors.white12 : Colors.black12, width: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.snippet.isNotEmpty)
                  Text(
                    note.snippet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: nightMode ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  note.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: nightMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'page ${note.pageNumber}',
                      style: TextStyle(
                        fontSize: 11,
                        color: nightMode ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 18, color: nightMode ? Colors.white54 : Colors.grey),
                      onPressed: () => onDelete(note),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
