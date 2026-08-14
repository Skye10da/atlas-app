// Tests the CURRENT, unmodified novelfull plugin (atlas-plugins/novelfull)
// against the noveldrama.org clone by pointing the plugin's baseUrl at
// noveldrama.org. Template code, selectors.json, filters.json are loaded
// verbatim from disk — only the manifest's baseUrl (a data field) is switched
// to the target site, mirroring how the same plugin would be registered for a
// new host.
//
// Run from the package root:
//   dart run tool/repro_noveldrama.dart

import 'dart:convert';
import 'dart:io';

import 'package:atlas_app/core/content_engine/plugins/plugin_filters.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/selectors/selector_set.dart';
import 'package:atlas_app/core/content_engine/templates/html_template.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/transport/http_transport.dart';

const _pluginRoot = 'atlas-plugins/novelfull';
const _targetBase = 'https://noveldrama.org';
const _novelUrl = '$_targetBase/noveldrama/rebirth-super-banking-system';

Map<String, Object?> _readJson(String path) =>
    Map<String, Object?>.from(jsonDecode(File(path).readAsStringSync()));

void main() async {
  final manifest = PluginManifest.fromJson({
    ..._readJson('$_pluginRoot/plugin.json'),
    'baseUrl': _targetBase,
  });
  final selectors =
      SelectorSet.fromJson(_readJson('$_pluginRoot/selectors.json'));
  final filters = PluginFilters.fromJson(_readJson('$_pluginRoot/filters.json'));
  final context = PluginContext(
    plugin: manifest,
    transport: HttpTransport(),
    selectors: selectors,
    filters: filters,
  );

  const template = HtmlTemplate();
  var failures = 0;

  void check(String label, bool ok, [String? detail]) {
    stdout.writeln('${ok ? 'PASS' : 'FAIL'}  $label'
        '${detail != null ? '  ->  $detail' : ''}');
    if (!ok) failures++;
  }

  stdout.writeln('=== search ===');
  try {
    final results = await template.search(context, 'rebirth');
    stdout.writeln('  results: ${results.length}');
    for (final r in results.take(3)) {
      stdout.writeln('    ${r.title}  ${r.url}');
    }
    check('search returns noveldrama results', results.any((r) =>
        r.url.contains('rebirth-super-banking-system')));
  } catch (e) {
    check('search', false, '$e');
  }

  stdout.writeln('=== metadata ===');
  try {
    final meta = await template.metadata(context, _novelUrl);
    stdout.writeln('  title: ${meta.title}');
    stdout.writeln('  author: ${meta.author}');
    stdout.writeln('  genres: ${meta.genres}');
    stdout.writeln('  status: ${meta.status}');
    final desc = (meta.description ?? '').replaceAll('\n', ' ');
    stdout.writeln(
        '  description: ${desc.substring(0, desc.length < 90 ? desc.length : 90)}');
    check('metadata title', meta.title.contains('Rebirth'));
    check('metadata author', meta.author != null);
    check('metadata genres', meta.genres.isNotEmpty);
    check('metadata description', (meta.description ?? '').isNotEmpty);
  } catch (e) {
    check('metadata', false, '$e');
  }

  stdout.writeln('=== chapterList ===');
  try {
    final chapters = await template.chapterList(context, _novelUrl);
    stdout.writeln('  chapterCount: ${chapters.length}');
    if (chapters.isNotEmpty) {
      stdout.writeln('  first: ${chapters.first.title}  ${chapters.first.url}');
      stdout.writeln('  last: ${chapters.last.title}  ${chapters.last.url}');
    }
    check('chapterList returns chapters', chapters.isNotEmpty);
    check(
      'chapterList urls are absolute noveldrama',
      chapters.every((c) => c.url.startsWith(_targetBase)),
    );
  } catch (e) {
    check('chapterList', false, '$e');
  }

  stdout.writeln('=== chapterContent ===');
  try {
    final doc = await template.chapterContent(
      context,
      '$_targetBase/noveldrama/rebirth-super-banking-system/chapter-1-no-one-cares1',
    );
    final text = doc.renderToText();
    final snippet =
        text.substring(0, text.length < 140 ? text.length : 140);
    stdout.writeln('  title: ${doc.title}');
    stdout.writeln('  blockCount: ${doc.blocks.length}');
    stdout.writeln('  textLength: ${text.length}');
    stdout.writeln('  snippet: $snippet');
    check('chapterContent has body', text.length > 200);
  } catch (e) {
    check('chapterContent', false, '$e');
  }

  stdout.writeln('');
  stdout.writeln(failures == 0
      ? 'ALL CHECKS PASSED'
      : '$failures CHECK(S) FAILED');
  exitCode = failures == 0 ? 0 : 1;
}