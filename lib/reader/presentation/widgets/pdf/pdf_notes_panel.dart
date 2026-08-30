import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_viewer_models.dart';

/// List of user-created notes anchored to pages.
class PdfNotesPanel extends StatelessWidget {
  const PdfNotesPanel({
    super.key,
    required this.notes,
    required this.onSelected,
    required this.onDelete,
    this.nightMode = false,
  });

  final List<PdfNoteEntry> notes;
  final void Function(PdfNoteEntry note) onSelected;
  final void Function(PdfNoteEntry note) onDelete;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (notes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Select text in the document, then use the note menu to add a note.',
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
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];

        return InkWell(
          onTap: () => onSelected(note),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.snippet.isNotEmpty) ...[
                  Text(
                    note.snippet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  note.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Page ${note.pageNumber}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      tooltip: 'Delete note',
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
