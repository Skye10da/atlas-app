import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/infrastructure/services/annotations_storage_service.dart';

/// Per-book annotation state with automatic local persistence.
///
/// Keys are chapter/page IDs (e.g. 'c1' or 'pdf_page_1') so each chapter or PDF
/// page keeps its own highlight/note lists. Changes are automatically written
/// to disk via [AnnotationsStorageService] and restored when the book is opened.
final annotationsProvider =
    NotifierProvider.family<
      ReaderAnnotationsController,
      ReaderAnnotationsState,
      String
    >(ReaderAnnotationsController.new);

class ReaderAnnotationsController
    extends FamilyNotifier<ReaderAnnotationsState, String> {
  int _noteCounter = 0;
  final AnnotationsStorageService _storage = const AnnotationsStorageService();

  @override
  ReaderAnnotationsState build(String arg) {
    _loadPersisted(arg);
    return const ReaderAnnotationsState();
  }

  Future<void> _loadPersisted(String bookId) async {
    final saved = await _storage.loadAnnotations(bookId);
    if (saved != null) {
      // Merge with any in-memory items added before disk read completed
      final mergedHighlights = <String, List<HighlightEntry>>{...saved.highlights};
      for (final entry in state.highlights.entries) {
        mergedHighlights[entry.key] = [
          ...?mergedHighlights[entry.key],
          ...entry.value,
        ];
      }

      final mergedNotes = <String, List<NoteEntry>>{...saved.notes};
      for (final entry in state.notes.entries) {
        mergedNotes[entry.key] = [
          ...?mergedNotes[entry.key],
          ...entry.value,
        ];
      }

      state = ReaderAnnotationsState(
        highlights: mergedHighlights,
        notes: mergedNotes,
      );
    }
  }

  void _persistState() {
    unawaited(_storage.saveAnnotations(arg, state));
  }

  void loadState(ReaderAnnotationsState newState) {
    state = newState;
    _persistState();
  }

  void addHighlight({
    required String chapterId,
    required int start,
    required int end,
    required String text,
    required int colorValue,
    HighlightStyleType styleType = HighlightStyleType.solid,
    List<double>? bounds,
  }) {
    if (start >= end && bounds == null) return;
    final existing = state;
    final highlights = {...existing.highlights};
    highlights[chapterId] = [
      ...?highlights[chapterId],
      HighlightEntry(
        chapterId: chapterId,
        start: start,
        end: end,
        text: text,
        colorValue: colorValue,
        styleType: styleType,
        bounds: bounds,
        createdAt: DateTime.now(),
      ),
    ];
    state = existing.copyWith(highlights: highlights);
    _persistState();
  }

  void updateHighlight({
    required String chapterId,
    required int start,
    required int end,
    int? colorValue,
    HighlightStyleType? styleType,
    List<double>? bounds,
  }) {
    final list = state.highlights[chapterId];
    if (list == null || list.isEmpty) return;
    final updatedList = [
      for (final h in list)
        if (h.start == start && h.end == end)
          h.copyWith(
            colorValue: colorValue ?? h.colorValue,
            styleType: styleType ?? h.styleType,
            bounds: bounds ?? h.bounds,
          )
        else
          h,
    ];
    final highlights = {...state.highlights};
    highlights[chapterId] = updatedList;
    state = state.copyWith(highlights: highlights);
    _persistState();
  }

  /// Removes every highlight in [chapterId] whose range overlaps
  /// [otherStart, otherEnd) — used by the "Erase" context-menu action.
  void eraseOverlapping(String chapterId, int otherStart, int otherEnd) {
    final list = state.highlights[chapterId];
    if (list == null || list.isEmpty) return;
    final surviving = [
      for (final h in list)
        if (!h.overlaps(otherStart, otherEnd)) h,
    ];
    final highlights = {...state.highlights};
    if (surviving.isEmpty) {
      highlights.remove(chapterId);
    } else {
      highlights[chapterId] = surviving;
    }
    state = state.copyWith(highlights: highlights);
    _persistState();
  }

  /// Returns the highlights in [chapterId] overlapping [start, end).
  List<HighlightEntry> highlightsIn(String chapterId, int start, int end) {
    final list = state.highlights[chapterId] ?? const [];
    return [
      for (final h in list)
        if (h.overlaps(start, end)) h,
    ];
  }

  void addNote({
    required String chapterId,
    required String text,
    required String sentence,
    int? colorValue,
    List<String> tags = const [],
    HighlightStyleType styleType = HighlightStyleType.solid,
    int? highlightStart,
    int? highlightEnd,
  }) {
    _noteCounter++;
    final notes = {...state.notes};
    final now = DateTime.now();
    notes[chapterId] = [
      ...?notes[chapterId],
      NoteEntry(
        id: '${chapterId}_${now.microsecondsSinceEpoch}_$_noteCounter',
        chapterId: chapterId,
        text: text,
        sentence: sentence,
        createdAt: now,
        updatedAt: now,
        colorValue: colorValue,
        tags: tags,
        styleType: styleType,
        highlightStart: highlightStart,
        highlightEnd: highlightEnd,
      ),
    ];
    state = state.copyWith(notes: notes);
    _persistState();
  }

  void updateNote({
    required String chapterId,
    required String noteId,
    required String text,
    int? colorValue,
    List<String>? tags,
  }) {
    final list = state.notes[chapterId];
    if (list == null) return;
    final updatedList = [
      for (final n in list)
        if (n.id == noteId)
          n.copyWith(
            text: text,
            updatedAt: DateTime.now(),
            colorValue: colorValue ?? n.colorValue,
            tags: tags ?? n.tags,
          )
        else
          n,
    ];
    final notes = {...state.notes};
    notes[chapterId] = updatedList;
    state = state.copyWith(notes: notes);
    _persistState();
  }

  void deleteNote(String chapterId, String noteId) {
    final list = state.notes[chapterId];
    if (list == null) return;
    final remaining = [
      for (final n in list)
        if (n.id != noteId) n,
    ];
    final notes = {...state.notes};
    if (remaining.isEmpty) {
      notes.remove(chapterId);
    } else {
      notes[chapterId] = remaining;
    }
    state = state.copyWith(notes: notes);
    _persistState();
  }

  int get totalHighlightsCount => state.totalHighlightsCount;
  int get totalNotesCount => state.totalNotesCount;

  void clear() {
    state = const ReaderAnnotationsState();
    _persistState();
  }
}
