import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/search/domain/entities/search_engine.dart';
import 'package:atlas_app/search/domain/repository_interfaces/search_engine_repository_interface.dart';

class SharedPrefsSearchEngineRepository
    implements SearchEngineRepositoryInterface {
  SharedPrefsSearchEngineRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'selected_search_engine';

  @override
  Future<SearchEngine> getSelected() async {
    final id = _prefs.getString(_key);
    return SearchEngine.fromId(id);
  }

  @override
  Future<void> setSelected(SearchEngine engine) async {
    await _prefs.setString(_key, engine.id);
  }
}
