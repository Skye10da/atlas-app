import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/core/logging/logger.dart';

/// File-based LRU cache for synthesized TTS audio. Scoped to the
/// currently-reading book only — other bookIds are pruned on switch.
///
/// Key = hash(text+voiceId+rate+pitch+locale). Files stored as
/// `<support>/tts_cache/<bookId>/<hash>.cache`.
class TtsFileCache {
  TtsFileCache({String? basePath}) : _basePath = basePath;

  final String? _basePath;
  String? _resolvedPath;
  String? _activeBookId;

  Future<String> get _path async {
    if (_resolvedPath != null) return _resolvedPath!;
    if (_basePath != null) {
      _resolvedPath = _basePath;
    } else {
      final dir = await getApplicationSupportDirectory();
      _resolvedPath = p.join(dir.path, 'tts_cache');
    }
    return _resolvedPath!;
  }

  String _hash({
    required String text,
    String? voiceId,
    required double rate,
    required double pitch,
    required String locale,
  }) {
    final input = '$text|$voiceId|$rate|$pitch|$locale';
    return sha256.convert(input.codeUnits).toString().substring(0, 24);
  }

  String hashFor({
    required String text,
    String? voiceId,
    required double rate,
    required double pitch,
    required String locale,
  }) => _hash(
    text: text,
    voiceId: voiceId,
    rate: rate,
    pitch: pitch,
    locale: locale,
  );

  Future<File> fileFor({
    required String bookId,
    required String text,
    String? voiceId,
    required double rate,
    required double pitch,
    required String locale,
  }) async {
    final h = _hash(
      text: text,
      voiceId: voiceId,
      rate: rate,
      pitch: pitch,
      locale: locale,
    );
    return fileForHash(bookId: bookId, hash: h);
  }

  Future<File> fileForHash({
    required String bookId,
    required String hash,
  }) async {
    final base = await _path;
    return File(p.join(base, bookId, '$hash.cache'));
  }

  Future<List<int>?> get({
    required String bookId,
    required String text,
    String? voiceId,
    required double rate,
    required double pitch,
    required String locale,
  }) async {
    if (bookId != _activeBookId) return null;
    try {
      final file = await fileFor(
        bookId: bookId,
        text: text,
        voiceId: voiceId,
        rate: rate,
        pitch: pitch,
        locale: locale,
      );
      if (!file.existsSync()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> put({
    required String bookId,
    required String text,
    String? voiceId,
    required double rate,
    required double pitch,
    required String locale,
    required List<int> bytes,
  }) async {
    if (bookId != _activeBookId) return;
    try {
      final file = await fileFor(
        bookId: bookId,
        text: text,
        voiceId: voiceId,
        rate: rate,
        pitch: pitch,
        locale: locale,
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      await _touch(file);
    } catch (e) {
      AppLogger.warning('TtsFileCache put failed: $e');
    }
  }

  Future<void> setActiveBook(String bookId, {int maxMb = 500}) async {
    final previous = _activeBookId;
    _activeBookId = bookId;
    if (previous != null && previous != bookId) {
      await clearBook(previous);
    }
    await pruneIfNeeded(activeBookId: bookId, maxMb: maxMb);
    await pruneOtherBooks(activeBookId: bookId);
  }

  Future<void> clearBook(String bookId) async {
    try {
      final dir = Directory(p.join(await _path, bookId));
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  Future<void> clearAll() async {
    try {
      final dir = Directory(await _path);
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  Future<int> sizeFor(String bookId) async {
    try {
      final dir = Directory(p.join(await _path, bookId));
      if (!dir.existsSync()) return 0;
      int total = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) total += await entity.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<int> totalSize() async {
    try {
      final dir = Directory(await _path);
      if (!dir.existsSync()) return 0;
      int total = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) total += await entity.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<void> pruneIfNeeded({
    required String activeBookId,
    required int maxMb,
  }) async {
    if (maxMb <= 0) return;
    final maxBytes = maxMb * 1024 * 1024;
    final dir = Directory(p.join(await _path, activeBookId));
    if (!dir.existsSync()) return;
    final files = dir.listSync(recursive: false).whereType<File>().toList();
    if (files.isEmpty) return;
    files.sort(
      (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
    );
    int total = files.fold(0, (sum, f) => sum + f.statSync().size);
    for (final file in files) {
      if (total <= maxBytes) break;
      try {
        total -= file.statSync().size;
        file.deleteSync();
      } catch (_) {}
    }
  }

  Future<void> pruneOtherBooks({required String activeBookId}) async {
    try {
      final base = Directory(await _path);
      if (!base.existsSync()) return;
      for (final entity in base.listSync()) {
        if (entity is Directory && p.basename(entity.path) != activeBookId) {
          try {
            entity.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> _touch(File file) async {
    try {
      final now = DateTime.now();
      file.setLastModifiedSync(now);
    } catch (_) {}
  }
}
