import 'dart:math';

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/content_engine/models/atlas_document.dart';
import 'package:atlas_app/core/content_engine/pipeline/rich_source.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_filters.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_permissions.dart';
import 'package:atlas_app/core/content_engine/selectors/selector_set.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// The load-bearing seam between the plugin engine and the existing
/// acquisition UI: adapts a [Template] + [PluginManifest] to the existing
/// [SourceAdapter]/[SearchableSource] contract. Library and Reader code never
/// see [Template] or [PluginManifest] directly — from their perspective a
/// plugin-backed novel source looks exactly like the book sources.
class PluginSource implements SourceAdapter, SearchableSource, RichSource {
  PluginSource({
    required this.manifest,
    required this.template,
    required this.transport,
    this.selectors,
    this.filters,
    this.permissions,
  }) {
    _validateCapabilities();
  }

  final PluginManifest manifest;
  final Template template;
  final Transport transport;
  final SelectorSet? selectors;
  final PluginFilters? filters;
  final PluginPermissions? permissions;

  PluginContext get _context => PluginContext(
        plugin: manifest,
        transport: transport,
        selectors: selectors,
        filters: filters,
        permissions: permissions,
      );

  void _validateCapabilities() {
    if (manifest.requiresJsRendering) {
      throw PluginManifestException(
        'Plugin "${manifest.id}" requires browser (JS) rendering, which is '
        'not supported in this release',
      );
    }
    final unsupported = manifest.capabilities
        .where((c) => !template.supportedCapabilities.contains(c))
        .toList();
    if (unsupported.isNotEmpty) {
      throw PluginManifestException(
        'Plugin "${manifest.id}" declares capabilities not implemented by '
        'template "${manifest.templateId}": '
        '${unsupported.map((c) => c.name).join(', ')}',
      );
    }
  }

  @override
  bool canHandle(Uri uri) {
    final base = Uri.tryParse(manifest.baseUrl);
    if (base == null) return false;
    return _normalizeHost(uri.host) == _normalizeHost(base.host);
  }

  String _normalizeHost(String host) =>
      host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');

  @override
  String get sourceName => manifest.sourceName;

  @override
  ContentCategory get contentCategory => ContentCategory.novel;

  @override
  Future<NovelModel> getMetadata(Uri uri) async {
    final meta = await template.metadata(_context, uri.toString());
    return NovelModel(
      sourceId: meta.sourceId ?? uri.toString(),
      title: meta.title,
      author: meta.author,
      description: meta.description,
      coverUrl: meta.coverUrl,
      language: meta.language ?? manifest.language,
      source: sourceName,
      sourceUrl: uri.toString(),
      category: ContentCategory.novel,
      chapterCount: meta.chapterCount,
      genres: meta.genres,
      status: meta.status,
      rating: meta.rating,
      lastUpdated: meta.lastUpdated,
    );
  }

  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) async {
    _ensureCapability(PluginCapability.chapterList);
    final refs = await template.chapterList(_context, novel.sourceUrl);
    return List.generate(refs.length, (i) => ChapterModel(
          id: _chapterId(refs[i].url, i),
          title: refs[i].title,
          index: i,
          contentUrl: refs[i].url,
          publishedAt: refs[i].publishedAt,
        ));
  }

  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) async {
    _ensureCapability(PluginCapability.chapterContent);
    if (chapter.content != null) return chapter;
    final doc = await getDocument(chapter);
    final text = doc.renderToText();
    return ChapterModel(
      id: chapter.id,
      title: doc.title.isNotEmpty ? doc.title : chapter.title,
      index: chapter.index,
      contentUrl: chapter.contentUrl,
      content: text.isEmpty ? null : text,
      wordCount: max(1, doc.wordCount),
      publishedAt: chapter.publishedAt,
    );
  }

  @override
  Future<AtlasDocument> getDocument(ChapterModel chapter) async {
    _ensureCapability(PluginCapability.chapterContent);
    final url = chapter.contentUrl;
    if (url == null) {
      throw Exception('$sourceName: chapter has no content URL');
    }
    return template.chapterContent(_context, url);
  }

  @override
  Future<SourceSearchResponse> search(SourceSearchQuery query) async {
    _ensureCapability(PluginCapability.search);
    final results = await template.search(_context, query.term);
    return SourceSearchResponse(
      results: results
          .map((r) => SourceSearchResult(
                id: r.url,
                title: r.title,
                importUrl: r.url,
                author: r.author,
                coverUrl: r.coverUrl,
                description: r.description,
                language: r.language,
              ))
          .toList(),
    );
  }

  void _ensureCapability(PluginCapability capability) {
    if (!manifest.capabilities.contains(capability)) {
      throw PluginCapabilityException(
        capability,
        'Plugin "${manifest.id}" does not support ${capability.name}',
      );
    }
  }

  String _chapterId(String url, int index) => '$url#ch$index';
}
