import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';

/// Persists reader annotations (highlights, formatting styles, notes, and tags)
/// to disk on a per-book basis as JSON files so they are preserved across app restarts.
class AnnotationsStorageService {
  const AnnotationsStorageService();

  Future<File> _getFile(String bookId) async {
    final dir = await getApplicationDocumentsDirectory();
    final annotationsDir = Directory(p.join(dir.path, 'annotations'));
    if (!annotationsDir.existsSync()) {
      await annotationsDir.create(recursive: true);
    }
    final safeName = bookId.replaceAll(RegExp(r'[^\w\.-]'), '_');
    return File(p.join(annotationsDir.path, 'annotations_$safeName.json'));
  }

  Future<ReaderAnnotationsState?> loadAnnotations(String bookId) async {
    try {
      final file = await _getFile(bookId);
      if (!file.existsSync()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;

      final rawHighlights = json['highlights'] as Map<String, dynamic>? ?? {};
      final highlights = <String, List<HighlightEntry>>{};
      for (final entry in rawHighlights.entries) {
        final list = (entry.value as List<dynamic>?)
                ?.map((e) => HighlightEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [];
        if (list.isNotEmpty) {
          highlights[entry.key] = list;
        }
      }

      final rawNotes = json['notes'] as Map<String, dynamic>? ?? {};
      final notes = <String, List<NoteEntry>>{};
      for (final entry in rawNotes.entries) {
        final list = (entry.value as List<dynamic>?)
                ?.map((e) => NoteEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [];
        if (list.isNotEmpty) {
          notes[entry.key] = list;
        }
      }

      return ReaderAnnotationsState(
        highlights: highlights,
        notes: notes,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAnnotations(
    String bookId,
    ReaderAnnotationsState state,
  ) async {
    try {
      final file = await _getFile(bookId);
      if (state.highlights.isEmpty && state.notes.isEmpty) {
        if (file.existsSync()) {
          await file.delete();
        }
        return;
      }

      final payload = {
        'bookId': bookId,
        'updatedAt': DateTime.now().toIso8601String(),
        'highlights': {
          for (final entry in state.highlights.entries)
            entry.key: entry.value.map((h) => h.toJson()).toList(),
        },
        'notes': {
          for (final entry in state.notes.entries)
            entry.key: entry.value.map((n) => n.toJson()).toList(),
        },
      };

      final tmpFile = File('${file.path}.tmp');
      await tmpFile.writeAsString(jsonEncode(payload));
      if (file.existsSync()) {
        await file.delete();
      }
      await tmpFile.rename(file.path);
    } catch (_) {
      // Fail-soft on storage write failure
    }
  }
}

