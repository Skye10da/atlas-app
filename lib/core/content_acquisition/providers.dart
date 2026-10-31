import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_acquisition/application/chapter_update_service.dart';
import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/sources/direct_url_source.dart';
import 'package:atlas_app/core/content_acquisition/sources/epub_url_source.dart';
import 'package:atlas_app/core/content_acquisition/sources/gutenberg_source.dart';
import 'package:atlas_app/core/content_acquisition/sources/open_library_source.dart';
import 'package:atlas_app/core/content_acquisition/sources/public_domain_library_source.dart';
import 'package:atlas_app/core/content_acquisition/sources/universal_html_source.dart';
import 'package:atlas_app/core/content_acquisition/sources/universal_origin_search_source.dart';
import 'package:atlas_app/core/content_engine/image/image_pipeline.dart';
import 'package:atlas_app/core/content_engine/index/content_indexer.dart';
import 'package:atlas_app/core/content_engine/universal/origin_rules.dart';
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
import 'package:atlas_app/core/content_engine/transport/domain_governor.dart';
import 'package:atlas_app/core/content_engine/transport/http_transport.dart';
import 'package:atlas_app/core/content_engine/transport/webview_transport.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/notifications/infrastructure/notification_service.dart';
import 'package:atlas_app/notifications/infrastructure/update_check_settings_store.dart';
import 'package:atlas_app/notifications/presentation/providers/update_check_settings_provider.dart';

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
  final database = ref.watch(databaseProvider);

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
      database: database,
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
    database: database,
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
  // LAST-RESORT universal importer — registered only after every plugin so
  // `SourceRegistry.resolve` can never match it before a real plugin. It
  // attempts heuristic detection on URLs no plugin claims, instead of the
  // bare "no source plugin available" failure. Per-origin learned rules
  // (Phase 2) make repeat visits from the same site skip the heuristics.
  final ruleStore = await ref.watch(universalOriginRuleStoreProvider.future);
  final transport = WebViewTransport(
    inner: CookieTransport(
      inner: HttpTransport(client: ref.watch(httpClientProvider)),
    ),
  );
  registry.register(
    UniversalHtmlSource(
      transport: transport.fetchHtml,
      loadRule: ruleStore.rule,
      saveRule: ruleStore.put,
    ),
  );

  // LEARNED SEARCH ORIGINS (Phase 3): sites we imported from before get a
  // searchable view at boot; origins learned later register live via
  // [learnedOriginSearchRegistrar].
  for (final origin in (await ruleStore.all()).keys) {
    registry.register(
      UniversalOriginSearchSource(
        origin: origin,
        transport: transport.fetchHtml,
        loadRule: ruleStore.rule,
        saveRule: ruleStore.put,
      ),
    );
  }
  return sources;
});

/// The persistent store of learned per-origin rules (Phase 2), shared by
/// the universal import adapter and the learned search sources (Phase 3).
final universalOriginRuleStoreProvider =
    FutureProvider<UniversalOriginRuleStore>((ref) async {
  final supportDir = await getApplicationSupportDirectory();
  return UniversalOriginRuleStore(
    filePath: p.join(supportDir.path, 'universal_origin_rules.json'),
  );
});

/// Bumped whenever a newly learned origin is registered as a searchable
/// source, so the directory/search-surface providers re-read the registry.
final learnedOriginsVersionProvider = StateProvider<int>((ref) => 0);

/// Registers a searchable view for an origin learned *during this session*
/// (e.g. right after a universal import). Safe to call repeatedly.
final learnedOriginSearchRegistrar =
    Provider<Future<void> Function(String origin)>((ref) {
  final storeFuture = ref.read(universalOriginRuleStoreProvider.future);
  final registry = ref.read(sourceRegistryProvider);
  final transport = WebViewTransport(
    inner: CookieTransport(
      inner: HttpTransport(client: ref.watch(httpClientProvider)),
    ),
  );
  return (origin) async {
    if (UniversalOriginSearchSource.registeredOrigins.contains(origin)) {
      return;
    }
    final store = await storeFuture;
    final source = UniversalOriginSearchSource(
      origin: origin,
      transport: transport.fetchHtml,
      loadRule: store.rule,
      saveRule: store.put,
    );
    registry.register(source);
    ref.read(learnedOriginsVersionProvider.notifier).state++;
  };
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

/// Re-fetches chapter lists of tracked ongoing novels and stores new
/// chapters. Plugin sources register into the shared [sourceRegistryProvider]
/// instance, so this resolves them once [pluginSourcesProvider] has warmed up.
final chapterUpdateServiceProvider = Provider<ChapterUpdateService>((ref) {
  return ChapterUpdateService(
    db: ref.watch(databaseProvider),
    registry: ref.watch(sourceRegistryProvider),
    governor: DomainGovernor.instance,
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
  final scheduler = TaskScheduler(
    // Mirrored by `updateCheckIntervalHoursProvider` (synced on every
    // settings change), so runtime changes take effect on the next tick.
    updateCheckIntervalResolver: () =>
        Duration(hours: ref.read(updateCheckIntervalHoursProvider)),
  );

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
        database: ref.watch(databaseProvider),
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
    updateCheck: () async {
      final settings = await UpdateCheckSettingsStore.load();
      if (!settings.enabled) return null;
      final result = await ref
          .read(chapterUpdateServiceProvider)
          .checkTrackedBooks();
      if (result.booksWithUpdates == 0) return null;
      final db = ref.read(databaseProvider);
      await UpdateNotificationService.instance.initialize(db: db);
      await UpdateNotificationService.instance.showUpdateSummary(
        result.updates
            .map(
              (u) => (title: u.title, bookId: u.bookId, count: u.newChapters),
            )
            .toList(),
        settings: settings,
      );
      if (settings.autoDownloadChapters) {
        AppLogger.info(
          'Auto-download enabled: ${result.totalNewChapters} new chapter(s) discovered; foreground prefetch will cache bodies.',
        );
      }
      return 'found ${result.totalNewChapters} new chapter(s) '
          'across ${result.booksWithUpdates} novel(s)';
    },
  );

  return scheduler;
});
