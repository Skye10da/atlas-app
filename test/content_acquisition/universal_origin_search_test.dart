import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_acquisition/services/import_service.dart'
    show ImportException;
import 'package:atlas_app/core/content_acquisition/sources/universal_origin_search_source.dart';
import 'package:atlas_app/core/content_engine/universal/origin_rules.dart';
import 'package:atlas_app/core/content_engine/universal/site_pattern_zoo.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

const String _listResultsPage = '''
<html><head><title>Search results for cultivation</title></head><body>
<div class="results">
  <a href="/novel/lotm">
    <img src="/covers/lotm.jpg" alt="Lord of the Mysteries">
    Lord of the Mysteries
  </a>
  <a href="/novel/ss">
    <img src="/covers/ss.jpg" alt="Shadow Slave">
    Shadow Slave
  </a>
  <a href="#">empty link</a>
  <a href="/login">Login</a>
  <a href="/genre/hot">Hot</a>
</div>
</body></html>
''';

/// Grid-tile layout: titles live on the images, not the anchors.
const String _gridResultsPage = '''
<html><head><title>Search results</title></head><body>
<ul class="book-list">
  <li><a href="/novel/lords"><img src="//img.example/lords.jpg" alt="The Two Lords"></a></li>
  <li><a href="/novel/mist"><img src="/imgs/mist.png" alt="Mistbound"></a></li>
  <li><a href="/novel/ash"><img data-src="/imgs/ash.jpg" alt="Ashfall Saga"></a></li>
</ul>
</body></html>
''';

const String _noResultsPage = '''
<html><body><p>No results found. Try a different keyword.</p></body></html>
''';

/// A nav-only page the probe gets whenever a fixture URL is missing —
/// with title filters in place it must yield ZERO book hits.
const String _navOnlyPage = '''
<html><head><title>StarNovel | Read free novels</title></head><body>
<nav><a href="/new">New</a><a href="/hot">Hot</a><a href="/done">Completed</a></nav>
</body></html>
''';

UniversalOriginSearchSource _makeSource(
  Map<String, UniversalOriginRule> rules,
  Map<String, String> fixtures,
  List<String> fetchLog,
) =>
    UniversalOriginSearchSource(
      origin: 'https://site.example/',
      transport: (uri, {headers}) async {
        fetchLog.add(uri.toString());
        return fixtures[uri.toString()] ?? _navOnlyPage;
      },
      loadRule: (origin) async => rules[origin],
      saveRule: (origin, rule) async => rules[origin] = rule,
      sleep: (_) async {},
    );

void main() {
  group('SitePatternZoo.detectSearchResults', () {
    test('extracts book links, covers and junk filtering', () {
      final doc = html_parser.parse(_listResultsPage);
      final hits = SitePatternZoo.detectSearchResults(
        doc,
        Uri.parse('https://site.example/?q=x'),
      );
      expect(hits.map((h) => h.title),
          ['Lord of the Mysteries', 'Shadow Slave']);
      expect(hits.first.uri.toString(),
          'https://site.example/novel/lotm');
      expect(hits.first.coverUrl, 'https://site.example/covers/lotm.jpg');
    });

    test('reads titles and covers off image-only grid tiles', () {
      final doc = html_parser.parse(_gridResultsPage);
      final hits = SitePatternZoo.detectSearchResults(
        doc,
        Uri.parse('https://site.example/search'),
      );
      expect(hits.map((h) => h.title),
          ['The Two Lords', 'Mistbound', 'Ashfall Saga']);
      // Protocol-relative and relative image URLs resolve against the site.
      expect(hits.first.coverUrl, 'https://img.example/lords.jpg');
      expect(hits[2].coverUrl, 'https://site.example/imgs/ash.jpg');
    });

    test('a "no results" marker yields an empty set', () {
      final doc = html_parser.parse(_noResultsPage);
      expect(
        SitePatternZoo.detectSearchResults(
          doc,
          Uri.parse('https://site.example/search'),
        ),
        isEmpty,
      );
    });

    test('nav-only chrome never counts as book hits', () {
      final doc = html_parser.parse(_navOnlyPage);
      expect(
        SitePatternZoo.detectSearchResults(
          doc,
          Uri.parse('https://site.example/anything'),
        ),
        isEmpty,
      );
    });
  });

  group('UniversalOriginSearchSource', () {
    late Map<String, UniversalOriginRule> rules;
    late Map<String, String> fixtures;
    late List<String> fetchLog;
    late UniversalOriginSearchSource source;

    setUp(() {
      rules = {};
      fixtures = {};
      fetchLog = [];
      source = _makeSource(rules, fixtures, fetchLog);
    });

    test('an empty term short-circuits without any fetch', () async {
      final response = await source.search(const SourceSearchQuery(term: ''));
      expect(response.results, isEmpty);
      expect(fetchLog, isEmpty);
    });

    test('probes conventions and learns the winning template', () async {
      // Only '/?s=' (the second convention) exists on this site.
      fixtures['https://site.example/?s=cultivation'] = _listResultsPage;

      final response = await source.search(
        const SourceSearchQuery(term: 'cultivation'),
      );

      expect(
        response.results.map((r) => r.title),
        ['Lord of the Mysteries', 'Shadow Slave'],
      );
      expect(
        response.results.map((r) => r.importUrl),
        ['https://site.example/novel/lotm', 'https://site.example/novel/ss'],
      );
      expect(
        rules['https://site.example/']?.searchTemplate,
        '/?s={query}',
      );
      // Two probes before the hit: /search?q= then /?s=.
      expect(
        fetchLog,
        [
          'https://site.example/search?q=cultivation',
          'https://site.example/?s=cultivation',
        ],
      );
    });

    test('a second search uses the learned template in one fetch', () async {
      fixtures['https://site.example/?s=cultivation'] = _listResultsPage;
      await source.search(const SourceSearchQuery(term: 'cultivation'));
      fetchLog.clear();

      final again = await source.search(
        const SourceSearchQuery(term: 'cultivation'),
      );
      expect(again.results.length, 2);
      expect(
        fetchLog,
        ['https://site.example/?s=cultivation'],
      );
    });

    test('a learned template with real no-results returns an empty set',
        () async {
      rules['https://site.example/'] = UniversalOriginRule(
        updatedAt: DateTime.now().toUtc(),
        searchTemplate: '/search?q={query}',
      );
      fixtures['https://site.example/search?q=zzz'] = _noResultsPage;

      final response = await source.search(
        const SourceSearchQuery(term: 'zzz'),
      );
      expect(response.results, isEmpty);
      expect(fetchLog, ['https://site.example/search?q=zzz']);
    });

    test('a broken learned template re-probes other conventions', () async {
      rules['https://site.example/'] = UniversalOriginRule(
        updatedAt: DateTime.now().toUtc(),
        searchTemplate: '/gone?q={query}',
      );
      fixtures['https://site.example/?query=xanadu'] = _listResultsPage;

      final response = await source.search(
        const SourceSearchQuery(term: 'xanadu'),
      );
      expect(response.results.length, 2);
      expect(
        rules['https://site.example/']?.searchTemplate,
        '/?query={query}',
      );
    });

    test('no conforming convention fails quietly and stores nothing', () async {
      final learning = rules;
      await expectLater(
        source.search(const SourceSearchQuery(term: 'anything')),
        throwsA(isA<ImportException>()),
      );
      expect(learning, isEmpty);
    });
  });

  group('Learned search sources in the registry', () {
    test('appear in .searchable but never claim URLs for resolve', () {
      final registry = SourceRegistry();
      final searchSource = UniversalOriginSearchSource(
        origin: 'https://site.example',
        transport: (_, {headers}) async => '',
        loadRule: (_) async => null,
        saveRule: (_, _) async {},
      );
      registry.register(searchSource);

      expect(registry.searchable.single.sourceName, 'site.example');
      expect(registry.resolve(Uri.parse('https://site.example/novel/1')),
          isNull);
    });
  });
}
