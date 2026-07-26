import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/search/domain/entities/search_result_entity.dart';
import 'package:atlas_app/search/infrastructure/repositories/drift_search_repository.dart';

final searchRepositoryProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  return DriftSearchRepository(db);
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<Result<List<SearchResultEntity>>>((ref) {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return const Success([]);
  final repo = ref.watch(searchRepositoryProvider);
  return repo.search(query);
});
