import 'dart:convert';

import 'package:atlas_app/core/content_engine/plugins/plugin_filters.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_permissions.dart';
import 'package:atlas_app/core/content_engine/plugins/verification.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/templates/wtrlab_template.dart';
import 'package:atlas_app/core/content_engine/transport/http_transport.dart';

const _manifest = PluginManifest(
  id: 'wtrlab',
  name: 'WTR-LAB',
  sourceName: 'WTR-LAB',
  version: PluginVersion(major: 1, minor: 0, patch: 0),
  templateId: 'wtrlab',
  baseUrl: 'https://wtr-lab.com',
  language: 'en',
);

Future<void> main() async {
  final context = PluginContext(
    plugin: _manifest,
    transport: HttpTransport(),
    filters: const PluginFilters(),
    permissions: const PluginPermissions(),
  );
  const template = WtrLabTemplate();

  final results = await template.search(context, 'charm');
  print('search results: ${results.length}');
  if (results.isEmpty) throw StateError('search returned nothing');
  final result = results.first;
  print('  title: ${result.title}');
  print('  url:   ${result.url}');
  final novelUrl = result.url;

  final meta = await template.metadata(context, novelUrl);
  print('metadata:');
  print('  title:   ${meta.title}');
  print('  author:  ${meta.author}');
  print('  status:  ${meta.status}');
  print('  chapters:${meta.chapterCount}');
  print('  sourceId:${meta.sourceId}');
  print('  genres:  ${meta.genres.take(4).join(', ')}');

  final refs = await template.chapterList(context, novelUrl);
  print('chapter list: ${refs.length} chapters');
  final first = refs.first;
  print('  first: ${first.title}  ${first.url}');
  final last = refs.last;
  print('  last:  ${last.title}  ${last.url}');

  final doc = await template.chapterContent(context, first.url);
  final text = doc.renderToText();
  print('chapter content:');
  print('  title:  ${doc.title}');
  print('  length: ${text.length} chars');
  print('  sample: ${text.substring(0, text.length > 40 ? 40 : text.length)}');
  print('  isChinese sample: ${RegExp(r'[\u4e00-\u9fff]').hasMatch(text)}');
  if (!RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) {
    throw StateError('expected raw Chinese content, got: ${jsonEncode(text.substring(0, 80))}');
  }
  print('LIVE SMOKE OK');
}
