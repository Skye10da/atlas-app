import 'package:atlas_app/search/domain/entities/search_engine.dart';

abstract interface class SearchEngineRepositoryInterface {
  Future<SearchEngine> getSelected();
  Future<void> setSelected(SearchEngine engine);
}
