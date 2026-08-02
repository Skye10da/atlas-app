import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CacheManager {
  CacheManager({String? basePath}) : _basePath = basePath;

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

  Future<Directory> bookDir(String bookId) async {
    final dir = Directory(p.join(await _path, bookId));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> chapterFile(String bookId, String chapterId) async {
    final dir = await bookDir(bookId);
    return File(p.join(dir.path, '$chapterId.txt'));
  }

  Future<void> saveChapter(String bookId, ChapterCacheData data) async {
    final file = await chapterFile(bookId, data.id);
    await file.writeAsString(data.content);
    final meta = File(p.join((await bookDir(bookId)).path, '${data.id}.meta'));
    await meta.writeAsString(data.toMetaString());
  }

  Future<String?> getChapter(String bookId, String chapterId) async {
    final file = await chapterFile(bookId, chapterId);
    if (!file.existsSync()) return null;
    return file.readAsString();
  }

  Future<bool> hasChapter(String bookId, String chapterId) async {
    final file = await chapterFile(bookId, chapterId);
    return file.existsSync();
  }

  Future<int> cacheSize(String bookId) async {
    final dir = Directory(p.join(await _path, bookId));
    if (!dir.existsSync()) return 0;
    int size = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) size += await entity.length();
    }
    return size;
  }

  /// Returns the book ids currently present in the txt cache directory.
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
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  Future<void> clearAll() async {
    final dir = Directory(await _path);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}

class ChapterCacheData {
  const ChapterCacheData({
    required this.id,
    required this.title,
    required this.index,
    required this.content,
    this.wordCount,
  });

  final String id;
  final String title;
  final int index;
  final String content;
  final int? wordCount;

  String toMetaString() => '$id|$index|$title|$wordCount';
}
