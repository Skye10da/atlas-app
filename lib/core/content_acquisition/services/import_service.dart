import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';

/// Reports 0.0 → 1.0 as an import advances through its phases.
typedef ImportProgressCallback = void Function(double progress);

class ImportResult {
  const ImportResult({
    required this.novel,
    required this.chapters,
    required this.source,
  });

  final NovelModel novel;
  final List<ChapterModel> chapters;
  final SourceAdapter source;
}

class ImportService {
  const ImportService(this.registry);

  final SourceRegistry registry;

  SourceAdapter? resolveSource(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    return registry.resolve(uri);
  }

  /// Resolves the source for [url] and fetches only its metadata.
  /// Does NOT fetch chapters — use [import] for the full pipeline.
  Future<NovelModel> fetchMetadata(String url) async {
    final uri = Uri.parse(url);
    final source = registry.resolve(uri);
    if (source == null) {
      throw ImportException('No source plugin available for: $url');
    }
    return source.getMetadata(uri);
  }

  Future<ImportResult> import(
    String url, {
    ImportProgressCallback? onProgress,
  }) async {
    final uri = Uri.parse(url);
    final source = registry.resolve(uri);
    if (source == null) {
      throw ImportException('No source plugin available for: $url');
    }

    onProgress?.call(0.0);
    try {
      final novel = await source.getMetadata(uri);
      onProgress?.call(0.5);
      final chapters = await source.getChapters(novel);
      onProgress?.call(0.8);
      return ImportResult(novel: novel, chapters: chapters, source: source);
    } on ImportRedirect {
      rethrow;
    } catch (e) {
      throw ImportException('Import failed for "$url": $e');
    }
  }
}

class ImportException implements Exception {
  const ImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ImportRedirect implements Exception {
  const ImportRedirect(this.redirectUrl);
  final String redirectUrl;
  @override
  String toString() => redirectUrl;
}
