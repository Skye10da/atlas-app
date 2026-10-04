import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/search/domain/entities/search_engine.dart';
import 'package:atlas_app/search/domain/repository_interfaces/search_engine_repository_interface.dart';

final searchEngineRepositoryProvider =
    Provider<SearchEngineRepositoryInterface>((ref) {
  throw UnimplementedError(
    'searchEngineRepositoryProvider must be overridden with SharedPreferences instance',
  );
});

final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final selectedSearchEngineProvider =
    NotifierProvider<SelectedSearchEngineNotifier, SearchEngine>(
  SelectedSearchEngineNotifier.new,
);

class SelectedSearchEngineNotifier extends Notifier<SearchEngine> {
  @override
  SearchEngine build() {
    // Default synchronously; async load will override when ready.
    _loadAsync();
    return SearchEngine.google;
  }

  Future<void> _loadAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final engine = SearchEngine.fromId(prefs.getString(_kKey));
      if (state != engine) state = engine;
    } catch (_) {
      // Keep default on failure.
    }
  }

  Future<void> select(SearchEngine engine) async {
    if (state == engine) return;
    state = engine;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKey, engine.id);
    } catch (_) {
      // Ignore persistence failure; in-memory selection still applied.
    }
  }

  static const String _kKey = 'selected_search_engine';
}

// Repository-backed variant for tests where SharedPreferences is injected.
final selectedSearchEngineAsyncProvider =
    FutureProvider<SearchEngine>((ref) async {
  final repo = ref.watch(searchEngineRepositoryProvider);
  return repo.getSelected();
});
