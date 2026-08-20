import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/error_handling/result.dart';

/// Picks and validates a lightweight `.atlas` source-link package produced by
/// [NovelExportService.exportSourceLink]. The package only carries metadata,
/// cover and chapter pointers; the actual import is delegated to the
/// [ContentAcquisitionEngine], which re-fetches a fresh chapter list from the
/// original source and downloads bodies on demand.
class AtlasSourceImportService {
  const AtlasSourceImportService();

  static const format = 'atlas-source-v1';

  /// Prompts the user to pick a `.atlas` file and returns the embedded source
  /// URL. `null` means the picker was cancelled (a success result).
  Future<Result<String?>> pickSourceUrl() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['atlas'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return const Success(null);
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        return const Failure(ValidationException('Could not read file'));
      }

      return parseSourceUrl(bytes);
    } on Exception catch (e) {
      return Failure(ValidationException('Failed to pick file: $e'));
    }
  }

  /// Validates a raw `.atlas` package and extracts its source URL.
  /// Exposed separately so it can be tested without a file picker.
  Result<String?> parseSourceUrl(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        return const Failure(ValidationException('Not a valid Atlas package'));
      }
      if (decoded['format'] != format) {
        return const Failure(
          ValidationException('Unsupported Atlas package format'),
        );
      }
      final source = decoded['source'];
      final url = source is Map ? source['url'] : null;
      if (url is! String || url.isEmpty) {
        return const Failure(
          ValidationException('Package contains no source URL'),
        );
      }
      return Success(url);
    } on FormatException catch (e) {
      return Failure(ValidationException('Could not read package file: $e'));
    }
  }

  /// Parses an `.atlas` source-link package and returns a [NovelModel] for
  /// the preview stage without performing the actual import.
  Future<NovelModel> extractMetadata(
    List<int> bytes,
    String fileName,
  ) async {
    final decoded = jsonDecode(utf8.decode(bytes)) as Map;
    final book = decoded['book'] as Map? ?? {};
    final source = decoded['source'] as Map? ?? {};

    Uint8List? coverBytes;
    final coverBase64 = decoded['coverBase64'];
    if (coverBase64 is String && coverBase64.isNotEmpty) {
      // ignore: avoid_redundant_argument_values
      coverBytes = base64Decode(coverBase64);
    }

    return NovelModel(
      sourceId: source['id']?.toString() ?? fileName,
      title:
          book['title']?.toString() ?? fileName.replaceAll('.atlas', ''),
      author: book['author']?.toString(),
      description: book['description']?.toString(),
      coverBytes: coverBytes,
      language: book['language']?.toString(),
      genres: (book['genres'] as List?)?.cast<String>() ?? [],
      status: book['status']?.toString(),
      rating:
          book['rating'] is num ? (book['rating'] as num).toDouble() : null,
      source: source['name']?.toString() ?? 'Atlas',
      sourceUrl: source['url']?.toString() ?? '',
      category: decoded['category'] == 'novel'
          ? ContentCategory.novel
          : ContentCategory.book,
      chapterCount:
          book['totalChapters'] is int ? book['totalChapters'] as int : 0,
    );
  }
}
