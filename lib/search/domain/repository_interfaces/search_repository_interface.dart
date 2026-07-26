import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/search/domain/entities/search_result_entity.dart';

abstract interface class SearchRepositoryInterface {
  Future<Result<List<SearchResultEntity>>> search(String query);
}
