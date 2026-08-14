import 'dart:convert';
import 'dart:io';

import 'package:atlas_app/core/content_engine/plugins/plugin_filters.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/selectors/selector_set.dart';
import 'package:atlas_app/core/content_engine/templates/novelfull_template.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:flutter/foundation.dart';

const _fixtures = r'C:\Users\skye\AppData\Local\Temp\opencode\novelfull_fixtures';

class _FakeTransport implements Transport {
  _FakeTransport(this._routes);

  final Map<String, String> _routes;

  String _body(Uri url) {
    for (final entry in _routes.entries) {
      if (url.toString().startsWith(entry.key)) return entry.value;
    }
    throw TransportException('no route for $url');
  }

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async =>
      _body(url);

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async =>
      jsonDecode(_body(url));

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async =>
      _body(url).codeUnits;
}

const _novelUrl = 'https://novelfull.net/legend-of-swordsman.html';
const _chapterUrl = 'https://novelfull.net/legend-of-swordsman/chapter-1.html';
const _ajaxUrl = 'https://novelfull.net/ajax-chapter-option?novelId=361';

void main() async {
  final manifest = PluginManifest.fromJson(const {
    'id': 'novelfull',
    'name': 'NovelFull',
    'sourceName': 'NovelFull',
    'version': '1.0.0',
    'templateId': 'novelfull',
    'baseUrl': 'https://novelfull.net',
  });
  final selectors = SelectorSet.fromJson(const {
    'search': {
      'resultItem': '.row.top-item',
      'title': '.s-title a@text',
      'detailUrl': '.s-title a@href',
    },
    'chapterList': {
      'item': '#list-chapter li',
      'title': '.chapter-text@text',
      'url': 'a@href',
    },
    'chapterContent': {
      'container': '#chapter-content',
      'title': '.chapter-title',
    },
  });
  const filters = PluginFilters(
    extraStripSelectors: ['#frame', '[id^="bg-ssp"]', '.ads-holder', '.box-notice'],
  );

  final routes = <String, String>{
    _novelUrl: File('$_fixtures\\novel.html').readAsStringSync(),
    _ajaxUrl:
        File('$_fixtures\\ajax_chapter_option.html').readAsStringSync(),
    _chapterUrl: File('$_fixtures\\chapter.html').readAsStringSync(),
  };
  final context = PluginContext(
    plugin: manifest,
    transport: _FakeTransport(routes),
    selectors: selectors,
    filters: filters,
  );

  const template = NovelfullTemplate();

  final chapters = await template.chapterList(context, _novelUrl);
  if (kDebugMode) {
    print('CURRENT chapterList count: ${chapters.length}');
  }
  if (chapters.isNotEmpty) {
    if (kDebugMode) {
      print('  first: ${chapters.first.title} ${chapters.first.url}');
      print('  last: ${chapters.last.title} ${chapters.last.url}');
    }
    
  }

  final doc = await template.chapterContent(context, _chapterUrl);
  final text = doc.renderToText();
  if (kDebugMode) {
    print('CURRENT chapterContent:');
  }
  if (kDebugMode) {
    print('  title: ${doc.title}');
    print('  blockCount: ${doc.blocks.length}');
    print('  textLength: ${text.length}');
    print('  snippet: ${text.substring(0, text.length < 120 ? text.length : 120)}');
  }
}
