import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';

class SourceSearchQuery {
  const SourceSearchQuery({
    required this.term,
    this.page = 1,
    this.pageSize = 20,
  });

  final String term;
  final int page;
  final int pageSize;
}

class SourceSearchResult {
  const SourceSearchResult({
    required this.id,
    required this.title,
    required this.importUrl,
    this.author,
    this.coverUrl,
    this.description,
    this.language,
  });

  final String id;
  final String title;
  final String importUrl;
  final String? author;
  final String? coverUrl;
  final String? description;
  final String? language;
}

class SourceSearchResponse {
  const SourceSearchResponse({
    required this.results,
    this.totalCount,
    this.nextPage,
  });

  final List<SourceSearchResult> results;
  final int? totalCount;
  final int? nextPage;
}

abstract interface class SearchableSource implements SourceAdapter {
  Future<SourceSearchResponse> search(SourceSearchQuery query);
}
