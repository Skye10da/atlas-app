import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/providers/annotations_provider.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_selection_menu.dart';

/// Interactive modal sheet to create or edit a note attached to a passage.
class NoteEditorSheet extends HookConsumerWidget {
  const NoteEditorSheet({
    super.key,
    required this.bookId,
    required this.chapterId,
    required this.selectedText,
    this.sentence,
    this.chapterTitle,
    this.existingNote,
    this.highlightStart,
    this.highlightEnd,
    this.onSaved,
  });

  final String bookId;
  final String chapterId;
  final String selectedText;
  final String? sentence;
  final String? chapterTitle;
  final NoteEntry? existingNote;
  final int? highlightStart;
  final int? highlightEnd;
  final VoidCallback? onSaved;

  static const List<String> _suggestedTags = [
    'Quote',
    'Idea',
    'Question',
    'Vocabulary',
    'Favorite',
    'Plot',
  ];

  static Future<void> show(
    BuildContext context, {
    required String bookId,
    required String chapterId,
    required String selectedText,
    String? sentence,
    String? chapterTitle,
    NoteEntry? existingNote,
    int? highlightStart,
    int? highlightEnd,
    VoidCallback? onSaved,
  }) {
    final isEditing = existingNote != null;
    return AppSheet.show<void>(
      context: context,
      id: 'note_editor',
      title: isEditing ? 'Edit Note' : 'Add Note',
      fitToContent: true,
      child: NoteEditorSheet(
        bookId: bookId,
        chapterId: chapterId,
        selectedText: selectedText,
        sentence: sentence,
        chapterTitle: chapterTitle,
        existingNote: existingNote,
        highlightStart: highlightStart,
        highlightEnd: highlightEnd,
        onSaved: onSaved,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textController = useTextEditingController(
      text: existingNote?.text ?? '',
    );
    final selectedColor = useState<int?>(
      existingNote?.colorValue ??
          ChapterSelectionMenuBuilder.highlightPalette.first.color.toARGB32(),
    );
    final selectedTags = useState<Set<String>>(
      existingNote?.tags.toSet() ?? <String>{},
    );

    void save() {
      final text = textController.text.trim();
      if (text.isEmpty) return;

      final notifier = ref.read(annotationsProvider(bookId).notifier);
      if (existingNote != null) {
        notifier.updateNote(
          chapterId: chapterId,
          noteId: existingNote!.id,
          text: text,
          colorValue: selectedColor.value,
          tags: selectedTags.value.toList(),
        );
      } else {
        notifier.addNote(
          chapterId: chapterId,
          sentence: sentence ?? selectedText,
          text: text,
          highlightStart: highlightStart,
          highlightEnd: highlightEnd,
          colorValue: selectedColor.value,
          tags: selectedTags.value.toList(),
        );
      }
      onSaved?.call();
      Navigator.of(context).pop();
    }

    void delete() {
      if (existingNote == null) return;
      ref
          .read(annotationsProvider(bookId).notifier)
          .deleteNote(chapterId, existingNote!.id);
      onSaved?.call();
      Navigator.of(context).pop();
    }

    final colors = Theme.of(context).colorScheme;
    final isEditing = existingNote != null;
    final quote = sentence ?? selectedText;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quoted Passage Preview
          if (quote.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(
                    color: selectedColor.value != null
                        ? Color(selectedColor.value!)
                        : colors.primary,
                    width: 3.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (chapterTitle != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        chapterTitle!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  Text(
                    '“$quote”',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: colors.onSurface.withValues(alpha: 0.85),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Note Text Field
          SizedBox(
            height: 130,
            child: TextField(
              controller: textController,
              autofocus: true,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 14.5, height: 1.4),
              decoration: InputDecoration(
                hintText: 'Type your thoughts, reflections, or notes here…',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: colors.surface,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Color & Tag selectors
          Row(
            children: [
              // Color Palette Swatches
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final opt in ChapterSelectionMenuBuilder.highlightPalette)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () {
                              selectedColor.value = opt.color.toARGB32();
                            },
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: opt.color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedColor.value == opt.color.toARGB32()
                                      ? colors.onSurface
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              if (isEditing)
                IconButton(
                  tooltip: 'Delete Note',
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colors.error,
                    size: 20,
                  ),
                  onPressed: delete,
                ),

              // Save Button
              FilledButton.icon(
                onPressed: save,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Save Note'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tags Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tag in _suggestedTags)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(tag, style: const TextStyle(fontSize: 11)),
                      selected: selectedTags.value.contains(tag),
                      onSelected: (selected) {
                        final next = Set<String>.from(selectedTags.value);
                        if (selected) {
                          next.add(tag);
                        } else {
                          next.remove(tag);
                        }
                        selectedTags.value = next;
                      },
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
