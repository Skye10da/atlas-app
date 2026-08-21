import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/core/logging/logger.dart';

/// Downloads font families on demand and registers them with Flutter's
/// font engine so they can be referenced via `TextStyle(fontFamily: ...)`.
///
/// Supports multi-weight downloads and groups all weight/subset files
/// into a single [FontLoader] per family so the reader's Font Weight
/// picker renders real weights (not synthetic bolding).
///
/// Font files are stored under `<support>/fonts/<Family>_<weight>_<subset>.ttf`
/// and re-registered on every launch (see [loadDownloaded]).
abstract final class FontDownloader {
  static const _cssApi = 'https://fonts.googleapis.com/css2';

  /// Old enough to be served TTF (truetype) instead of woff/woff2.
  static const _cssUserAgent =
      'Mozilla/5.0 (Linux; U; Android 4.1.1; en-us; Nexus S Build/JRO03D) '
      'AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30';

  static final _fontFaceBlockRe = RegExp(
    r'@font-face\s*{([^}]+)}',
    multiLine: true,
  );
  static final _weightRe = RegExp(r'font-weight:\s*(\d+)');
  static final _srcUrlRe = RegExp(r'src:\s*url\(([^)]+)\)');

  /// Families registered with the font engine this session.
  static final Set<String> _loadedFamilies = {};

  static String _fileName(String family, int weight, String subset) {
    final safeName = family.replaceAll(RegExp(r'\s+'), '_');
    return '$safeName-${weight}_$subset.ttf';
  }

  static Future<Directory> _fontsDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}fonts');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Whether [family] has been registered with the font engine this session.
  static bool isDownloaded(String family) => _loadedFamilies.contains(family);

  /// Re-registers every previously downloaded font file on disk so a restart
  /// keeps downloaded families usable. Groups all files for a family into
  /// a single [FontLoader] so multiple weights render correctly.
  static Future<void> loadDownloaded() async {
    try {
      final dir = await _fontsDir();
      // Group files by family name.
      final Map<String, List<File>> families = {};
      for (final entry in dir.listSync()) {
        if (entry is! File) continue;
        final name = entry.uri.pathSegments.last;
        if (!name.endsWith('.ttf')) continue;
        // Parse: Family-400_latin.ttf → Family
        final family = _parseFamilyFromFileName(name);
        if (family.isEmpty) continue;
        families.putIfAbsent(family, () => []).add(entry);
      }

      for (final MapEntry(:key, :value) in families.entries) {
        await _registerFamily(key, [
          for (final file in value) await file.readAsBytes(),
        ]);
      }
    } on Object catch (e, stack) {
      AppLogger.error('Failed to load downloaded fonts', e, stack);
    }
  }

  /// Downloads [family] for the given [weights], persists all subset files
  /// under `<support>/fonts/` and registers the family with the font engine.
  ///
  /// Returns the set of weights that were successfully downloaded.
  static Future<Set<int>> download(
    String family, {
    List<int> weights = const [400, 700],
  }) async {
    final weightParam = weights.join(';');
    final familyParam = Uri.encodeQueryComponent(family);
    final uri = Uri.parse('$_cssApi?family=$familyParam:wght@$weightParam&display=swap');

    final response = await http
        .get(uri, headers: {'User-Agent': _cssUserAgent})
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException('Font CSS request failed: ${response.statusCode}');
    }

    final variants = _parseVariants(utf8.decode(response.bodyBytes));
    if (variants.isEmpty) {
      throw const FormatException('No font variants found in CSS response');
    }

    final dir = await _fontsDir();
    final bytesForFamily = <int, List<_FontVariantBytes>>{};

    for (final variant in variants) {
      final file = File('${dir.path}${Platform.pathSeparator}'
          '${_fileName(family, variant.weight, variant.subset)}');

      Uint8List bytes;
      if (await file.exists()) {
        bytes = await file.readAsBytes();
      } else {
        final fontResponse = await http
            .get(Uri.parse(variant.url), headers: {'User-Agent': _cssUserAgent})
            .timeout(const Duration(seconds: 30));
        if (fontResponse.statusCode != 200) {
          throw HttpException(
            'Font file request failed: ${fontResponse.statusCode}',
          );
        }
        bytes = fontResponse.bodyBytes;
        await file.writeAsBytes(bytes, flush: true);
      }

      bytesForFamily
          .putIfAbsent(variant.weight, () => [])
          .add(_FontVariantBytes(weight: variant.weight, bytes: bytes));
    }

    // Group all variant bytes into one FontLoader per family.
    final allBytes = <Uint8List>[
      for (final variants in bytesForFamily.values)
        for (final v in variants) v.bytes,
    ];
    await _registerFamily(family, allBytes);

    return bytesForFamily.keys.toSet();
  }

  /// Loads a previously-downloaded family from disk without re-fetching
  /// the CSS or checking the network — call this on app start for any
  /// font family the user picked in a previous session.
  static Future<void> loadCachedFont(
    String family, {
    List<int> weights = const [400, 700],
  }) async {
    final dir = await _fontsDir();
    final allBytes = <Uint8List>[];

    for (final entry in dir.listSync()) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (!name.endsWith('.ttf')) continue;
      final parsedFamily = _parseFamilyFromFileName(name);
      if (parsedFamily != family) continue;
      if (!await entry.exists()) continue;
      allBytes.add(await entry.readAsBytes());
    }

    if (allBytes.isNotEmpty) {
      await _registerFamily(family, allBytes);
    }
  }

  /// Removes a downloaded font and its cached files from disk.
  static Future<void> remove(String family) async {
    final dir = await _fontsDir();
    for (final entry in dir.listSync()) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (!name.endsWith('.ttf')) continue;
      if (_parseFamilyFromFileName(name) == family) {
        entry.deleteSync();
      }
    }
  }

  /// Deletes every cached font file, regardless of family.
  static Future<void> clearAllCachedFonts() async {
    final dir = await _fontsDir();
    if (!dir.existsSync()) return;
    for (final entry in dir.listSync()) {
      if (entry is File) entry.deleteSync();
    }
  }

  /// Total bytes currently used by cached font files.
  static Future<int> cachedFontSizeBytes() async {
    final dir = await _fontsDir();
    if (!dir.existsSync()) return 0;
    var total = 0;
    for (final entry in dir.listSync()) {
      if (entry is File) total += entry.lengthSync();
    }
    return total;
  }

  // -- Internal helpers --

  static Future<void> _registerFamily(
    String family,
    List<Uint8List> fontBytes,
  ) async {
    final loader = FontLoader(family);
    for (final bytes in fontBytes) {
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
    _loadedFamilies.add(family);
  }

  /// Parses @font-face blocks and extracts weight/style/url/subset.
  static List<_FontVariant> _parseVariants(String css) {
    final variants = <_FontVariant>[];
    for (final match in _fontFaceBlockRe.allMatches(css)) {
      final block = match.group(1)!;
      final weight =
          int.tryParse(_weightRe.firstMatch(block)?.group(1) ?? '') ?? 400;
      final url = _srcUrlRe.firstMatch(block)?.group(1)?.trim();
      if (url == null) continue;

      // Determine subset from unicode-range comment or URL pattern.
      final subset = _extractSubset(css, match.start, url);
      variants.add(_FontVariant(weight: weight, subset: subset, url: url));
    }
    return variants;
  }

  /// Extracts a human-readable subset name from the CSS context around
  /// a @font-face block, falling back to the filename heuristic.
  static String _extractSubset(String css, int blockStart, String url) {
    // Look for a comment before the @font-face block like: /* latin */
    final searchRange = css.substring(0, blockStart).length;
    final preceding = css.substring(
      searchRange > 200 ? searchRange - 200 : 0,
      searchRange,
    );
    final commentMatches =
        RegExp(r'/\*\s*(\w[\w-]*)\s*\*/').allMatches(preceding);
    final commentMatch = commentMatches.isNotEmpty
        ? commentMatches.last
        : null;
    if (commentMatch != null) return commentMatch.group(1)!;

    // Fallback: extract from URL filename.
    final urlMatch = RegExp(r'/([^/]+)\.ttf').firstMatch(url);
    if (urlMatch != null) {
      final fileName = urlMatch.group(1)!;
      // Common pattern: family-latin, family-latin-ext, etc.
      final parts = fileName.split('-');
      if (parts.length > 1) return parts.last;
    }

    return 'latin';
  }

  /// Parses family name back from a cache filename.
  /// e.g. `Inter-400_latin.ttf` → `Inter`
  static String _parseFamilyFromFileName(String fileName) {
    if (!fileName.endsWith('.ttf')) return '';
    final base = fileName.substring(0, fileName.length - 4);
    // Find first occurrence of `-\d+_` pattern (weight + subset separator).
    final match = RegExp(r'-(\d+)_').firstMatch(base);
    if (match == null) return base;
    return base.substring(0, match.start);
  }
}

class _FontVariant {
  const _FontVariant({
    required this.weight,
    required this.subset,
    required this.url,
  });
  final int weight;
  final String subset;
  final String url;
}

class _FontVariantBytes {
  const _FontVariantBytes({required this.weight, required this.bytes});
  final int weight;
  final Uint8List bytes;
}
