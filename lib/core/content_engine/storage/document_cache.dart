import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/core/content_engine/models/atlas_document.dart';

/// Caches [AtlasDocument] JSON beside the plain-text cache in the same
/// `<cache>/<bookId>/` directory. The txt path stays authoritative for the
/// legacy reader; this is the rich-content surface Phase 3 consumers read.
class DocumentCache {
  DocumentCache({String? basePath}) : _basePath = basePath;

  final String? _basePath;
  String? _resolvedPath;

  Future<String> get _path async {
    if (_resolvedPath != null) return _resolvedPath!;
    if (_basePath != null) {
      _resolvedPath = _basePath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      _resolvedPath = p.join(dir.path, 'cache');
    }
    return _resolvedPath!;
  }

  Future<File> documentFile(String bookId, String chapterId) async {
    final dir = Directory(p.join(await _path, bookId));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return File(p.join(dir.path, '$chapterId.json'));
  }

  Future<void> save(String bookId, String chapterId, AtlasDocument doc) async {
    final file = await documentFile(bookId, chapterId);
    await file.writeAsString(jsonEncode(doc.toJson()));
  }

  Future<AtlasDocument?> load(String bookId, String chapterId) async {
    final file = await documentFile(bookId, chapterId);
    if (!file.existsSync()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) return null;
    return AtlasDocument.fromJson(Map<String, Object?>.from(decoded));
  }

  Future<bool> has(String bookId, String chapterId) async {
    final file = await documentFile(bookId, chapterId);
    return file.existsSync();
  }

  /// Returns the book ids currently present in the JSON document cache.
  Future<List<String>> bookIds() async {
    final dir = Directory(await _path);
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .toList();
  }

  Future<void> clearBook(String bookId) async {
    final dir = Directory(p.join(await _path, bookId));
    if (dir.existsSync()) {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          await entity.delete();
        }
      }
    }
  }

  Future<void> clearAll() async {
    final dir = Directory(await _path);
    if (dir.existsSync()) {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          await entity.delete();
        }
      }
    }
  }
}
