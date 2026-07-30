import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';

class SourceRegistry {
  final List<SourceAdapter> _adapters = [];

  void register(SourceAdapter adapter) {
    _adapters.add(adapter);
  }

  SourceAdapter? resolve(Uri uri) {
    for (final adapter in _adapters) {
      if (adapter.canHandle(uri)) return adapter;
    }
    return null;
  }

  List<SourceAdapter> get all => List.unmodifiable(_adapters);

  List<SearchableSource> get searchable => _adapters.whereType<SearchableSource>().toList();
}
