import 'dart:convert';

import 'package:file_picker/file_picker.dart';

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
}
