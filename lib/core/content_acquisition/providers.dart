import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/sources/direct_url_source.dart';
import 'package:atlas_app/core/content_acquisition/sources/epub_url_source.dart';
import 'package:atlas_app/core/content_acquisition/sources/gutenberg_source.dart';
import 'package:atlas_app/core/content_acquisition/sources/open_library_source.dart';
import 'package:atlas_app/core/content_acquisition/sources/public_domain_library_source.dart';
import 'package:atlas_app/core/content_engine/image/image_pipeline.dart';
import 'package:atlas_app/core/content_engine/index/content_indexer.dart';
import 'package:atlas_app/core/content_engine/pipeline/content_pipeline_orchestrator.dart';
import 'package:atlas_app/core/content_engine/plugins/github_plugin_source.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_distribution_config.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_repository.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_updater.dart';
import 'package:atlas_app/core/content_engine/registry/plugin_source.dart';
import 'package:atlas_app/core/content_engine/scheduler/task_scheduler.dart';
import 'package:atlas_app/core/content_engine/storage/document_cache.dart';
import 'package:atlas_app/core/content_engine/templates/template_registry.dart';
import 'package:atlas_app/core/content_engine/transport/cookie_transport.dart';
import 'package:atlas_app/core/content_engine/transport/http_transport.dart';
import 'package:atlas_app/core/content_engine/transport/webview_transport.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';

final sourceRegistryProvider = Provider<SourceRegistry>((ref) {
  final httpClient = ref.watch(httpClientProvider);
  final registry = SourceRegistry();
  registry.register(EpubUrlSource());
  registry.register(GutenbergSource(client: httpClient));
  registry.register(OpenLibrarySource(client: httpClient));
  registry.register(PublicDomainLibrarySource(client: httpClient));
  registry.register(DirectUrlSource());
  return registry;
});

/// Discovers plugin-backed novel sources in `<support>/plugins/<pluginId>/`
/// and registers them into the shared [sourceRegistryProvider] instance.
/// A no-op when no plugin directory exists; a broken plugin is skipped and
/// reported rather than taking down app startup.
///
/// Before discovery, [PluginUpdater.sync] pulls the plugin catalog from the
/// distribution GitHub repo and installs/upgrades whatever is newer. Sync is
/// best-effort: any distribution failure is logged and discovery proceeds with
/// whatever is already installed on disk.
///
/// When the `ATLAS_PLUGINS_DIR` environment variable is set, plugins are read
/// directly from that local directory and the GitHub sync is skipped entirely.
final pluginSourcesProvider = FutureProvider<List<PluginSource>>((ref) async {
  final templateRegistry = TemplateRegistry.defaults;

  final localOverride = GithubPluginDistributionConfig.localPluginsDir;
  final Directory pluginsDir;
  if (localOverride != null && localOverride.isNotEmpty) {
    pluginsDir = Directory(localOverride);
    AppLogger.info('Using local plugin directory: $localOverride');
  } else {
    final supportDir = await getApplicationSupportDirectory();
    pluginsDir = Directory(p.join(supportDir.path, 'plugins'));

    final updater = PluginUpdater(
      source: GithubPluginSource(
        config: const GithubPluginDistributionConfig(),
        transport: HttpTransport(client: ref.watch(httpClientProvider)),
      ),
      targetDirectory: pluginsDir,
      templateRegistry: templateRegistry,
    );
    try {
      final updates = await updater.sync();
      for (final update in updates) {
        AppLogger.info(
          'Plugin ${update.pluginId}: ${update.status.name} '
          '(-> ${update.toVersion})',
        );
      }
    } catch (e) {
      AppLogger.warning(
        'Plugin catalog sync failed; using installed plugins only: $e',
      );
    }
  }

  final repository = PluginRepository(
    baseDirectory: pluginsDir,
    templateRegistry: templateRegistry,
  );
  final manifests = await repository.loadAll();
  final registry = ref.watch(sourceRegistryProvider);
  final sources = <PluginSource>[];
  for (final manifest in manifests) {
    try {
      final source = await repository.buildSource(manifest.id);
      registry.register(source);
      sources.add(source);
    } catch (e) {
      AppLogger.warning('Skipping plugin "${manifest.id}": $e');
    }
  }
  return sources;
});

final contentAcquisitionEngineProvider = Provider<ContentAcquisitionEngine>((
  ref,
) {
  final registry = ref.watch(sourceRegistryProvider);
  final db = ref.watch(databaseProvider);
  return ContentAcquisitionEngine(
    registry: registry,
    db: db,
    imagePipeline: ref.watch(imagePipelineProvider),
  );
});

/// Rich-content cache: AtlasDocument JSON stored beside each chapter's txt.
final documentCacheProvider = Provider<DocumentCache>((ref) => DocumentCache());

/// Image downloader with content-addressed storage, wired to the same layered
/// transport stack as plugin sources (cookie replay + webview fallback) so
/// cover-image downloads can pass Cloudflare bot challenges that block a bare
/// HTTP client.
final imagePipelineProvider = Provider<ImagePipeline>((ref) {
  final http = HttpTransport(client: ref.watch(httpClientProvider));
  return ImagePipeline(
    transport: WebViewTransport(inner: CookieTransport(inner: http)),
  );
});

/// End-to-end chapter pipeline: discovery → source resolution → transport →
/// clean → normalize → post-normalize (version+checksum) → index → cache →
/// deliver.
final pipelineOrchestratorProvider = Provider<ContentPipelineOrchestrator>((
  ref,
) {
  return ContentPipelineOrchestrator(
    registry: ref.watch(sourceRegistryProvider),
    cache: ref.watch(documentCacheProvider),
    indexer: ref.watch(contentIndexerProvider),
  );
});

/// Phase 3 indexers (search, dictionary, character extraction) shared by the
/// pipeline. Kept alive so the search index survives across pipeline runs.
final contentIndexerProvider = Provider<ContentIndexer>(
  (ref) => ContentIndexer(),
  name: 'contentIndexerProvider',
);

/// Runs background maintenance on fixed intervals. Tasks are wired to the
/// engine's download manager (resume), the plugin updater (refresh), and the
/// caches (cleanup). Not started until the app calls [TaskScheduler.start].
final taskSchedulerProvider = Provider<TaskScheduler>((ref) {
  final engine = ref.watch(contentAcquisitionEngineProvider);
  final scheduler = TaskScheduler();

  scheduler.setTasks(
    resumeDownloads: () async {
      final resumed = await engine.resumeDownloads();
      return resumed > 0 ? 'resumed $resumed downloads' : null;
    },
    pluginRefresh: () async {
      if (GithubPluginDistributionConfig.localPluginsDir != null) return null;
      final supportDir = await getApplicationSupportDirectory();
      final templateRegistry = TemplateRegistry.defaults;
      final pluginsDir = Directory(p.join(supportDir.path, 'plugins'));
      final updater = PluginUpdater(
        source: GithubPluginSource(
          config: const GithubPluginDistributionConfig(),
          transport: HttpTransport(client: ref.watch(httpClientProvider)),
        ),
        targetDirectory: pluginsDir,
        templateRegistry: templateRegistry,
      );
      final updates = await updater.sync();
      final applied = updates
          .where(
            (u) =>
                u.status == PluginUpdateStatus.installed ||
                u.status == PluginUpdateStatus.upgraded,
          )
          .length;
      return applied > 0 ? 'refreshed $applied plugins' : null;
    },
    cacheCleanup: () async {
      final db = ref.watch(databaseProvider);
      final bookRows = await (db.select(db.books)).get();
      final valid = bookRows.map((b) => b.id).toSet();
      final removed = <String>{};

      final documentCache = ref.watch(documentCacheProvider);
      for (final bookId in await documentCache.bookIds()) {
        if (!valid.contains(bookId)) {
          await documentCache.clearBook(bookId);
          removed.add(bookId);
        }
      }

      final engine = ref.watch(contentAcquisitionEngineProvider);
      for (final bookId in await engine.cacheManager.bookIds()) {
        if (!valid.contains(bookId)) {
          await engine.cacheManager.clearBook(bookId);
          removed.add(bookId);
        }
      }

      return removed.isNotEmpty
          ? 'cleaned ${removed.length} stale book cache(s)'
          : null;
    },
  );

  return scheduler;
});
