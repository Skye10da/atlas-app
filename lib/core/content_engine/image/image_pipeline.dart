import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/core/content_engine/models/content_hasher.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// Downloads images through a [Transport] (so headers / UA rotation / caching
/// compose with the rest of the pipeline) and stores them content-addressed:
/// the on-disk filename is the SHA-256 of the bytes, so identical images
/// fetched from different URLs are deduplicated to a single file.
class ImagePipeline {
  ImagePipeline({
    required this.transport,
    this.hasher = const ContentHasher(),
    String? basePath,
  }) : _basePath = basePath;

  final Transport transport;
  final ContentHasher hasher;
  final String? _basePath;
  final Map<String, String> _knownByUrl = {};
  String? _resolvedPath;

  Future<String> get _path async {
    if (_resolvedPath != null) return _resolvedPath!;
    if (_basePath != null) {
      _resolvedPath = _basePath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      _resolvedPath = p.join(dir.path, 'cache', 'images');
    }
    return _resolvedPath!;
  }

  /// Fetches [url] and writes it under `images/<sha256>.<ext>`, returning the
  /// absolute path. Skips the network fetch if the content hash already exists
  /// on disk (dedupe).
  Future<String?> download(
    Uri url, {
    Map<String, String>? headers,
    String? extension,
  }) async {
    final cachedByUrl = _knownByUrl[url.toString()];
    if (cachedByUrl != null) return cachedByUrl;

    final ext = extension ?? _extensionFor(url);
    final dir = Directory(await _path);
    if (!dir.existsSync()) await dir.create(recursive: true);

    final bytes = await transport.fetchBytes(url, headers: headers);
    if (bytes.isEmpty) return null;

    final hash = hasher.sha256OfBytes(bytes);
    final file = File(p.join(dir.path, '$hash.$ext'));
    if (!file.existsSync()) await file.writeAsBytes(bytes);

    _knownByUrl[url.toString()] = file.path;
    return file.path;
  }

  /// Look up the stored path for a URL without fetching it. Useful for
  /// checking whether a cover is already cached.
  Future<String?> cachedPathFor(Uri url, {String? extension}) async {
    final dir = Directory(await _path);
    if (!dir.existsSync()) return null;
    final ext = extension ?? _extensionFor(url);
    final matching = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.$ext'))
        .toList();
    if (matching.isEmpty) return null;
    return matching.first.path;
  }

  Future<void> clearAll() async {
    final dir = Directory(await _path);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  String _extensionFor(Uri url) {
    final path = url.path;
    final dot = path.lastIndexOf('.');
    if (dot != -1) {
      final ext = path.substring(dot + 1).toLowerCase();
      if (RegExp(r'^(jpe?g|png|gif|webp|svg|bmp|avif)$').hasMatch(ext)) {
        return ext == 'jpeg' ? 'jpg' : ext;
      }
    }
    return 'img';
  }
}
