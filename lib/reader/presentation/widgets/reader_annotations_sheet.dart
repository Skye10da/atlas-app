import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/providers/annotations_provider.dart';
import 'package:atlas_app/reader/presentation/widgets/note_editor_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/quote_share_card_sheet.dart';

class ReaderAnnotationsSheet extends ConsumerStatefulWidget {
  const ReaderAnnotationsSheet({
    super.key,
    required this.bookId,
    required this.chapters,
    this.currentChapterId,
    this.bookTitle,
    this.author,
    this.coverPath,
    this.onJumpToChapter,
  });

  final String bookId;
  final List<ChapterEntity> chapters;
  final String? currentChapterId;
  final String? bookTitle;
  final String? author;
  final String? coverPath;
  final void Function(String chapterId, int? startOffset)? onJumpToChapter;

  static Future<void> show(
    BuildContext context, {
    required String bookId,
    required List<ChapterEntity> chapters,
    String? currentChapterId,
    String? bookTitle,
    String? author,
    String? coverPath,
    void Function(String chapterId, int? startOffset)? onJumpToChapter,
  }) {
    return AppSheet.show<void>(
      context: context,
      id: 'reader_annotations',
      title: 'Annotations & Notes',
      initialHeight: 0.75,
      snapPoints: const [0.55, 0.75, 0.92],
      child: ReaderAnnotationsSheet(
        bookId: bookId,
        chapters: chapters,
        currentChapterId: currentChapterId,
        bookTitle: bookTitle,
        author: author,
        coverPath: coverPath,
        onJumpToChapter: onJumpToChapter,
      ),
    );
  }

  @override
  ConsumerState<ReaderAnnotationsSheet> createState() =>
      _ReaderAnnotationsSheetState();
}

class _ReaderAnnotationsSheetState
    extends ConsumerState<ReaderAnnotationsSheet> {
  String _filterQuery = '';
  int _selectedTabIndex = 0; // 0 = All, 1 = Notes, 2 = Highlights
  bool _currentChapterOnly = false;

  ChapterEntity? _chapterFor(String chapterId) {
    for (final c in widget.chapters) {
      if (c.id == chapterId) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(annotationsProvider(widget.bookId));

    final notes = <NoteEntry>[];
    final highlights = <HighlightEntry>[];

    state.notes.forEach((chapId, list) {
      if (_currentChapterOnly && chapId != widget.currentChapterId) return;
      notes.addAll(list);
    });

    state.highlights.forEach((chapId, list) {
      if (_currentChapterOnly && chapId != widget.currentChapterId) return;
      highlights.addAll(list);
    });

    final query = _filterQuery.trim().toLowerCase();

    final filteredNotes = notes.where((n) {
      if (query.isEmpty) return true;
      return n.text.toLowerCase().contains(query) ||
          n.sentence.toLowerCase().contains(query) ||
          n.tags.any((t) => t.toLowerCase().contains(query));
    }).toList();

    final filteredHighlights = highlights.where((h) {
      if (query.isEmpty) return true;
      return h.text.toLowerCase().contains(query);
    }).toList();

    final totalCount = (_selectedTabIndex == 1)
        ? filteredNotes.length
        : (_selectedTabIndex == 2)
            ? filteredHighlights.length
            : (filteredNotes.length + filteredHighlights.length);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Bar & Scope Toggle
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        onChanged: (v) => setState(() => _filterQuery = v),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search notes & highlights…',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color:
                                colors.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          filled: true,
                          fillColor: colors.surface,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Current Chapter',
                        style: TextStyle(fontSize: 11)),
                    selected: _currentChapterOnly,
                    onSelected: (sel) =>
                        setState(() => _currentChapterOnly = sel),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Segmented Tab bar
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    label: Text('All'),
                    icon: Icon(Icons.list_alt_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text('Notes'),
                    icon: Icon(Icons.edit_note_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: 2,
                    label: Text('Highlights'),
                    icon: Icon(Icons.highlight_rounded, size: 16),
                  ),
                ],
                selected: {_selectedTabIndex},
                onSelectionChanged: (set) {
                  setState(() => _selectedTabIndex = set.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(height: 12),

              // List Content
              Expanded(
                child: totalCount == 0
                    ? _buildEmptyState(colors)
                    : ListView(
                        children: [
                          if (_selectedTabIndex == 0 ||
                              _selectedTabIndex == 1)
                            for (final note in filteredNotes)
                              _buildNoteCard(note, colors),
                          if (_selectedTabIndex == 0 ||
                              _selectedTabIndex == 2)
                            for (final hl in filteredHighlights)
                              _buildHighlightCard(hl, colors),
                        ],
                      ),
              ),
            ],
          ),
        );
  }

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.note_alt_outlined,
            size: 48,
            color: colors.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            _filterQuery.isNotEmpty
                ? 'No matching notes or highlights found'
                : 'No notes or highlights added yet',
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(NoteEntry note, ColorScheme colors) {
    final chapter = _chapterFor(note.chapterId);
    final noteColor = note.color ?? colors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: noteColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            widget.onJumpToChapter?.call(note.chapterId, note.highlightStart);
            Navigator.of(context).pop();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note_rounded, size: 16, color: noteColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        chapter?.title ?? 'Chapter',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        QuoteShareCardSheet.show(
                          context,
                          quoteText: note.sentence.isNotEmpty
                              ? note.sentence
                              : note.text,
                          bookTitle: widget.bookTitle,
                          author: widget.author,
                          chapterTitle: chapter?.title,
                          coverPath: widget.coverPath,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        NoteEditorSheet.show(
                          context,
                          bookId: widget.bookId,
                          chapterId: note.chapterId,
                          selectedText: note.sentence,
                          sentence: note.sentence,
                          chapterTitle: chapter?.title,
                          existingNote: note,
                        );
                      },
                    ),
                  ],
                ),
                if (note.sentence.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '“${note.sentence}”',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.85),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  note.text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface,
                    height: 1.35,
                  ),
                ),
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final tag in note.tags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: noteColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: noteColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightCard(HighlightEntry hl, ColorScheme colors) {
    final chapter = _chapterFor(hl.chapterId);
    final hlColor = hl.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: hlColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            widget.onJumpToChapter?.call(hl.chapterId, hl.start);
            Navigator.of(context).pop();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(hl.styleType.icon, size: 16, color: hlColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        chapter?.title ?? 'Chapter',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: hlColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        hl.styleType.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: hlColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        QuoteShareCardSheet.show(
                          context,
                          quoteText: hl.text,
                          bookTitle: widget.bookTitle,
                          author: widget.author,
                          chapterTitle: chapter?.title,
                          coverPath: widget.coverPath,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.note_add_outlined, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        NoteEditorSheet.show(
                          context,
                          bookId: widget.bookId,
                          chapterId: hl.chapterId,
                          selectedText: hl.text,
                          sentence: hl.text,
                          chapterTitle: chapter?.title,
                          highlightStart: hl.start,
                          highlightEnd: hl.end,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '“${hl.text}”',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                    color: colors.onSurface,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

