import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';

/// Per-book, in-memory annotation state. Highlights and notes live only while
/// the reader is open; nothing here touches the database (persistence is an
/// explicit future step). Keys are chapter IDs so each chapter keeps its own
/// highlight/note lists.
final annotationsProvider =
    NotifierProvider.family<
      ReaderAnnotationsController,
      ReaderAnnotationsState,
      String
    >(ReaderAnnotationsController.new);

class ReaderAnnotationsController
    extends FamilyNotifier<ReaderAnnotationsState, String> {
  int _noteCounter = 0;

  @override
  ReaderAnnotationsState build(String arg) => const ReaderAnnotationsState();

  void addHighlight({
    required String chapterId,
    required int start,
    required int end,
    required String text,
    required int colorValue,
  }) {
    if (start >= end) return;
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
      ),
    ];
    state = existing.copyWith(highlights: highlights);
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
  }) {
    _noteCounter++;
    final notes = {...state.notes};
    notes[chapterId] = [
      ...?notes[chapterId],
      NoteEntry(
        id: '${chapterId}_${DateTime.now().microsecondsSinceEpoch}_$_noteCounter',
        chapterId: chapterId,
        text: text,
        sentence: sentence,
        createdAt: DateTime.now(),
      ),
    ];
    state = state.copyWith(notes: notes);
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
  }

  void clear() => state = const ReaderAnnotationsState();
}

class ReaderAnnotationsState {
  const ReaderAnnotationsState({
    this.highlights = const {},
    this.notes = const {},
  });

  final Map<String, List<HighlightEntry>> highlights;
  final Map<String, List<NoteEntry>> notes;

  ReaderAnnotationsState copyWith({
    Map<String, List<HighlightEntry>>? highlights,
    Map<String, List<NoteEntry>>? notes,
  }) {
    return ReaderAnnotationsState(
      highlights: highlights ?? this.highlights,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderAnnotationsState &&
      other.highlights == highlights &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(highlights, notes);
}
