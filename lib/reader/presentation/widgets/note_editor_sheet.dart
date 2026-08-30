import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/providers/annotations_provider.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_selection_menu.dart';

/// Interactive modal sheet to create or edit a note attached to a passage.
class NoteEditorSheet extends ConsumerStatefulWidget {
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
  ConsumerState<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends ConsumerState<NoteEditorSheet> {
  late final TextEditingController _textController;
  late int? _selectedColor;
  late final Set<String> _selectedTags;

  static const List<String> _suggestedTags = [
    'Quote',
    'Idea',
    'Question',
    'Vocabulary',
    'Favorite',
    'Plot',
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.existingNote?.text ?? '',
    );
    _selectedColor = widget.existingNote?.colorValue ??
        ChapterSelectionMenuBuilder.highlightPalette.first.color.toARGB32();
    _selectedTags = widget.existingNote?.tags.toSet() ?? <String>{};
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _save() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final notifier = ref.read(annotationsProvider(widget.bookId).notifier);
    if (widget.existingNote != null) {
      notifier.updateNote(
        chapterId: widget.chapterId,
        noteId: widget.existingNote!.id,
        text: text,
        colorValue: _selectedColor,
        tags: _selectedTags.toList(),
      );
    } else {
      notifier.addNote(
        chapterId: widget.chapterId,
        sentence: widget.sentence ?? widget.selectedText,
        text: text,
        highlightStart: widget.highlightStart,
        highlightEnd: widget.highlightEnd,
        colorValue: _selectedColor,
        tags: _selectedTags.toList(),
      );
    }
    widget.onSaved?.call();
    Navigator.of(context).pop();
  }

  void _delete() {
    if (widget.existingNote == null) return;
    ref
        .read(annotationsProvider(widget.bookId).notifier)
        .deleteNote(widget.chapterId, widget.existingNote!.id);
    widget.onSaved?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEditing = widget.existingNote != null;
    final quote = widget.sentence ?? widget.selectedText;

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
                    color: _selectedColor != null
                        ? Color(_selectedColor!)
                        : colors.primary,
                    width: 3.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.chapterTitle != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        widget.chapterTitle!,
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
              controller: _textController,
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
                              setState(() {
                                _selectedColor = opt.color.toARGB32();
                              });
                            },
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: opt.color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selectedColor == opt.color.toARGB32()
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
                  onPressed: _delete,
                ),

              // Save Button
              FilledButton.icon(
                onPressed: _save,
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
                      selected: _selectedTags.contains(tag),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                        });
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

