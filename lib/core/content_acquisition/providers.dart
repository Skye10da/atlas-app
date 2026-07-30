import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/sources/direct_url_source.dart';
import 'package:atlas_app/core/content_acquisition/sources/epub_url_source.dart';
import 'package:atlas_app/core/content_acquisition/sources/gutenberg_source.dart';
import 'package:atlas_app/core/content_acquisition/sources/mvlempyr_source.dart';
import 'package:atlas_app/core/content_acquisition/sources/open_library_source.dart';
import 'package:atlas_app/core/content_acquisition/sources/public_domain_library_source.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';

final sourceRegistryProvider = Provider<SourceRegistry>((ref) {
  final httpClient = ref.watch(httpClientProvider);
  final registry = SourceRegistry();
  registry.register(EpubUrlSource());
  registry.register(GutenbergSource(client: httpClient));
  registry.register(MvlempyrSource(client: httpClient));
  registry.register(OpenLibrarySource(client: httpClient));
  registry.register(PublicDomainLibrarySource(client: httpClient));
  registry.register(DirectUrlSource());
  return registry;
});

final contentAcquisitionEngineProvider = Provider<ContentAcquisitionEngine>((ref) {
  final registry = ref.watch(sourceRegistryProvider);
  final db = ref.watch(databaseProvider);
  return ContentAcquisitionEngine(registry: registry, db: db);
});
