import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';

final searchableSourcesProvider = Provider<List<SearchableSource>>((ref) {
  ref.watch(pluginSourcesProvider);
  final registry = ref.watch(sourceRegistryProvider);
  return registry.searchable;
});

final searchResultsProvider =
    FutureProvider.family<SourceSearchResponse, _SearchParams>((
      ref,
      params,
    ) async {
      return params.source.search(
        SourceSearchQuery(term: params.term, page: params.page, pageSize: 20),
      );
    });

class _SearchParams {
  const _SearchParams({
    required this.source,
    required this.term,
    required this.page,
  });

  final SearchableSource source;
  final String term;
  final int page;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SearchParams &&
          runtimeType == other.runtimeType &&
          source.sourceName == other.source.sourceName &&
          term == other.term &&
          page == other.page;

  @override
  int get hashCode => Object.hash(source.sourceName, term, page);
}
