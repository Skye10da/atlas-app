import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';

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

  Future<ImportResult> import(String url) async {
    final uri = Uri.parse(url);
    final source = registry.resolve(uri);
    if (source == null) {
      throw ImportException('No source plugin available for: $url');
    }

    try {
      final novel = await source.getMetadata(uri);
      final chapters = await source.getChapters(novel);
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
