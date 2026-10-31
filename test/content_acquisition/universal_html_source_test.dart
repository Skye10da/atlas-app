import 'dart:io';

import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/content_acquisition/services/import_service.dart'
    show ImportException;
import 'package:atlas_app/core/content_acquisition/sources/universal_html_source.dart';
import 'package:atlas_app/core/content_engine/universal/origin_rules.dart';
import 'package:atlas_app/core/content_engine/universal/site_pattern_zoo.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;

/// Fixtures modeled on layouts real novel sites ship.
const String _wpStylePage = '''
<!DOCTYPE html>
<html><head>
<title>Shadow Cultivation | ReadNovel.example</title>
<meta property="og:title" content="Shadow Cultivation">
<meta property="og:description" content="A young cultivator wakes up with a dantian of pure darkness and sets out to rewrite the heavens.">
<meta property="og:image" content="/covers/shadow.jpg">
<meta name="author" content="Tan Sheng">
</head>
<body>
<nav><a href="/search">Search</a></nav>
<article class="novel-page">
  <h1 class="novel-title">Shadow Cultivation</h1>
  <div class="novel-info"><span class="author">Tan Sheng</span></div>
  <p class="novel-desc">A young cultivator wakes up with a dantian of pure darkness.</p>
  <div class="chapter-list">
    <a href="/novel/shadow-cultivation/chapter/1">Chapter 1</a>
    <a href="/novel/shadow-cultivation/chapter/2">Chapter 2</a>
    <a href="/novel/shadow-cultivation/chapter/3">Chapter 3</a>
    <a href="/novel/shadow-cultivation/chapter/4">Chapter 4</a>
    <a href="/login">Login</a>
    <a href="/genre/xianxia">Xianxia</a>
  </div>
</article>
</body></html>
''';

const String _chineseStylePage = '''
<!DOCTYPE html>
<html><head><title>第四十一章 - 玄夜阁</title></head>
<body>
<main>
  <h1>逆天邪神</h1>
  <span>作者：火星引力</span>
  <div id="chapterContent">
    <p>夜色如墨，云破天惊。</p>
    <p>少年捏紧了手中的古卷，迈出宗门的第一步。</p>
    <p>这一路，再无回头。</p>
  </div>
  <div class="chapter-list">
    <a href="/ys/chapter/40">第四十章</a>
    <a href="/ys/chapter/41">第四十一章</a>
    <a href="/ys/chapter/42">第四十二章</a>
  </div>
</main>
</body></html>
''';

const String _chapterPage = '''
<!DOCTYPE html>
<html><head><title>Chapter 4 - Shadow Cultivation</title></head>
<body>
<h2 class="chapter-title">Chapter 4: The Night Descends</h2>
<div class="chapter-content">
<p>The moon rose over the sect walls like a lantern.</p>
<p>Chen Mo clenched his fists, feeling the shadow qi coil inside him.</p>
<p>He thought about his master, and about the mountain road home.</p>
<p>"One day," he whispered, "I'll walk the heavens."</p>
<p>That night, the murmur of swords filled the courtyard.</p>
</div>
<footer><a href="/login">Login</a></footer>
</body></html>
''';

const String _paginatedListPage1 = '''
<html><head><title>Chapters 1-2</title></head><body>
<div class="chapter-list">
<a href="/novel/x/chapter/1">Chapter 1</a>
<a href="/novel/x/chapter/2">Chapter 2</a>
</div>
<a rel="next" href="/novel/x?c=2">»</a>
</body></html>
''';

const String _paginatedListPage2 = '''
<html><head><title>Chapter 3</title></head><body>
<div class="chapter-list">
<a href="/novel/x/chapter/3">Chapter 3</a>
</div>
<a rel="next" href="/novel/x?c=3">»</a>
</body></html>
''';

const String _paginatedListPage3 = '''
<html><head><title>Chapter 4</title></head><body>
<div class="chapter-list">
<a href="/novel/x/chapter/4">Chapter 4</a>
</div>
</body></html>
''';

const String _plainArticlePage = '''
<html><head><title>How To Brew Nightshade Tea</title></head><body>
<h1>How To Brew Nightshade Tea</h1>
<p>Nightshade tea takes patience and fresh leaves.</p>
<p>Steep for seven minutes, then strain through linen.</p>
<p>Serve cold with a twist of citrus.</p>
</body></html>
''';

/// Sparse navigation-only page: has a title, but nothing novel-like.
const String _minimalNavPage = '''
<html><head><title>StarNovel | Read free novels</title></head><body>
<nav><a href="/new">New</a><a href="/hot">Hot</a><a href="/done">Completed</a></nav>
</body></html>
''';

const String _challengeStylePage = '''
<html><head><title>Just a moment…</title></head>
<body><div id="cf-chl-widget" class="challenge">Verifying you are human<div class="rotate">Loading…</div></div></body>
</html>
''';

/// Two story-body-sized containers: a denser decoy every natural fallback
/// would pick, and the real body in a container the zoo does not know —
/// only a learned per-origin rule can find it directly.
const String _twoStoryBodiesPage = '''
<html><head><title>The Silent Harbor</title></head><body>
<div class="portnote">
<p>Word travels fast in a port town, and by the second bell every
freighter captain had heard that the Silent Harbor's manifests were
forged, that the insurance men were circling like gulls over a spill,
and that whoever sold the route to the tabloids was sitting in the
customs office at that very moment, smiling about it, while the
harbormaster pretended not to notice and the unions sharpened their
language for the evening papers.</p>
</div>
<div id="my-novel-body">
<p>Mara counted the bells twice before answering.</p>
<p>"If the tide turns early, we sail tonight," she said.</p>
<p>The crew said nothing, which was its own answer.</p>
<p>By dawn the harbor was empty except for gulls and rain.</p>
<p>She signed the ledger, hiding the stolen chart beneath it.</p>
<p>Then she went below and laughed until the lamp shook.</p>
</div>
</body></html>
''';

/// Serves fixture HTML by exact URL, falling back to a nav-only page (so a
/// missing fixture behaves like an unexpected/unsupported page).
/// [rules] consults / [learned] captures per-origin learned rules.
UniversalHtmlSource _source(
  Map<String, String> fixtures, {
  Map<String, UniversalOriginRule>? rules,
  Map<String, UniversalOriginRule>? learned,
}) =>
    UniversalHtmlSource(
      transport: (uri, {headers}) async =>
          fixtures[uri.toString()] ?? _minimalNavPage,
      sleep: (_) async {},
      loadRule: rules == null ? null : (origin) async => rules[origin],
      saveRule: learned == null
          ? null
          : (origin, rule) async => learned[origin] = rule,
    );

void main() {
  group('SitePatternZoo (pure DOM)', () {
    test('detects title from og metadata before headings', () {
      final doc = html_parser.parse(_wpStylePage);
      expect(SitePatternZoo.detectTitle(doc), 'Shadow Cultivation');
    });

    test('detectTitleAttributed names the winning zoo source', () {
      final doc = html_parser.parse(_wpStylePage);
      final (title, source) = SitePatternZoo.detectTitleAttributed(doc);
      expect(title, 'Shadow Cultivation');
      expect(source, 'og');
    });

    test('a learned preferred source jumps the zoo queue', () {
      final doc = html_parser.parse(_wpStylePage);
      final (title, source) =
          SitePatternZoo.detectTitleAttributed(doc, preferredSource: 'heading');
      expect(title, 'Shadow Cultivation');
      expect(source, 'heading');
    });

    test('detects author, description and cover from meta tags', () {
      final doc = html_parser.parse(_wpStylePage);
      expect(SitePatternZoo.detectAuthor(doc), 'Tan Sheng');
      expect(
        SitePatternZoo.detectDescription(doc),
        contains('dantian'),
      );
      expect(
        SitePatternZoo.detectCoverUrl(doc, Uri.parse('https://r.example/n/1')),
        'https://r.example/covers/shadow.jpg',
      );
    });

    test('detects Chinese 第…章 chapter links', () {
      final doc = html_parser.parse(_chineseStylePage);
      final links = SitePatternZoo.detectChapterLinks(
        doc,
        Uri.parse('https://site.example/ys'),
      );
      expect(links.length, 3);
      expect(links[0].title, contains('第四十'));
    });

    test('detects a chapter page title through class then heading', () {
      final doc = html_parser.parse(_chapterPage);
      expect(
        SitePatternZoo.detectChapterPageTitle(doc),
        contains('Night Descends'),
      );
    });

    test('excludes login/genre junk from the chapter list', () {
      final doc = html_parser.parse(_wpStylePage);
      final links = SitePatternZoo.detectChapterLinks(
        doc,
        Uri.parse('https://site.example/novel/shadow-cultivation'),
      );
      expect(links.length, 4);
      expect(links.any((l) => l.title == 'Login'), isFalse);
      expect(links.any((l) => l.title == 'Xianxia'), isFalse);
    });

    test('de-duplicates repeated chapter hrefs', () {
      final doc = html_parser.parse('''
<html><body>
<a href="/n/chapter/1">Chapter 1</a>
<a href="/n/chapter/1">Chapter 1</a>
<a href="/n/chapter/2">Chapter 2</a>
</body></html>
''');
      final links = SitePatternZoo.detectChapterLinks(
        doc,
        Uri.parse('https://site.example/n'),
      );
      expect(links.length, 2);
    });
  });

  group('UniversalHtmlSource', () {
    test('canHandle claims unknown http(s) pages only', () {
      final source = _source(const {});
      expect(
        source.canHandle(Uri.parse('https://unknown.example/novel/9')),
        isTrue,
      );
      expect(source.canHandle(Uri.parse('ftp://host/x')), isFalse);
      expect(source.canHandle(Uri.parse('https://host.com/book.epub')), isFalse);
      expect(source.canHandle(Uri.parse('https://host.com/manual.pdf')), isFalse);
      expect(source.canHandle(Uri.parse('about:blank')), isFalse);
    });

    test('getMetadata detects a novel page and its fields', () async {
      final source = _source({
        'https://site.example/novel/shadow-cultivation': _wpStylePage,
      });
      final model = await source.getMetadata(
        Uri.parse('https://site.example/novel/shadow-cultivation'),
      );
      expect(model.title, 'Shadow Cultivation');
      expect(model.author, 'Tan Sheng');
      expect(model.source, 'Universal');
      expect(model.category, ContentCategory.novel);
      expect(model.chapterCount, 4);
    });

    test('getMetadata refuses pages without novel structure', () async {
      final source = _source({
        'https://site.example/about': _minimalNavPage,
      });
      await expectLater(
        source.getMetadata(Uri.parse('https://site.example/about')),
        throwsA(isA<ImportException>()),
      );
    });

    test('a plain article page still imports as a single chapter', () async {
      final source = _source({
        'https://site.example/article/tea': _plainArticlePage,
      });
      final model = await source.getMetadata(
        Uri.parse('https://site.example/article/tea'),
      );
      expect(model.title, 'How To Brew Nightshade Tea');
      expect(model.chapterCount, 1);

      final chapters = await source.getChapters(model);
      expect(chapters.length, 1);

      final chapter = await source.getChapter(chapters.first);
      expect(chapter.content, contains('Steep for seven minutes'));
      expect(chapter.wordCount, greaterThan(10));
    });

    test('getChapters returns the detected chapter list in order', () async {
      final source =
          _source({
        'https://site.example/novel/shadow-cultivation': _wpStylePage,
      });
      final model = await source.getMetadata(
        Uri.parse('https://site.example/novel/shadow-cultivation'),
      );
      final chapters = await source.getChapters(model);
      expect(chapters.length, 4);
      expect(chapters.first.index, 0);
      expect(chapters[1].title, 'Chapter 2');
      expect(
        chapters[1].contentUrl,
        'https://site.example/novel/shadow-cultivation/chapter/2',
      );
    });

    test('getChapter extracts clean body text from a chapter page', () async {
      final source =
          _source({
        'https://site.example/novel/shadow-cultivation': _wpStylePage,
        'https://site.example/novel/shadow-cultivation/chapter/4':
            _chapterPage,
      });
      final model = await source.getMetadata(
        Uri.parse('https://site.example/novel/shadow-cultivation'),
      );
      final chapters = await source.getChapters(model);
      final chapter = await source.getChapter(
        chapters.firstWhere((c) => c.title == 'Chapter 4'),
      );
      expect(chapter.title, contains('Night Descends'));
      expect(chapter.content, contains('shadow qi coil'));
      expect(chapter.content, isNot(contains('<')));
    });

    test('getChapters follows bounded "next" pagination', () async {
      final source = _source({
        'https://site.example/novel/x': _paginatedListPage1,
        'https://site.example/novel/x?c=2': _paginatedListPage2,
        'https://site.example/novel/x?c=3': _paginatedListPage3,
      });
      final model = await source.getMetadata(
        Uri.parse('https://site.example/novel/x'),
      );
      final chapters = await source.getChapters(model);
      expect(
        chapters.map((c) => c.title),
        ['Chapter 1', 'Chapter 2', 'Chapter 3', 'Chapter 4'],
      );
    });

    test('getChapter fails with a readable error on challenge-style pages',
        () async {
      final source = _source({
        'https://site.example/novel/shadow-cultivation': _wpStylePage,
        'https://site.example/novel/shadow-cultivation/chapter/1':
            _challengeStylePage,
      });
      final model = await source.getMetadata(
        Uri.parse('https://site.example/novel/shadow-cultivation'),
      );
      final chapters = await source.getChapters(model);
      await expectLater(
        source.getChapter(chapters.first),
        throwsA(isA<ImportException>()),
      );
    });
  });

  group('Per-origin learning (Phase 2)', () {
    test('a successful metadata import learns the title provenance', () async {
      final learned = <String, UniversalOriginRule>{};
      final source = _source(
        {
          'https://site.example/novel/shadow-cultivation': _wpStylePage,
          'https://site.example/novel/shadow-cultivation?q=2': _wpStylePage,
        },
        learned: learned,
      );
      await source.getMetadata(
        Uri.parse('https://site.example/novel/shadow-cultivation?q=2'),
      );
      // The origin key sheds path and query alike.
      expect(learned.keys.single, 'https://site.example/');
      expect(learned.values.single.titleSource, 'og');
    });

    test('a chapter read learns the winning content container', () async {
      final learned = <String, UniversalOriginRule>{};
      final source = _source(
        {
          'https://site.example/novel/shadow-cultivation': _wpStylePage,
          'https://site.example/novel/shadow-cultivation/chapter/4':
              _chapterPage,
        },
        learned: learned,
      );
      final model = await source.getMetadata(
        Uri.parse('https://site.example/novel/shadow-cultivation'),
      );
      final chapters = await source.getChapters(model);
      await source.getChapter(
        chapters.firstWhere((c) => c.title == 'Chapter 4'),
      );
      expect(
        learned['https://site.example/']?.contentSelector,
        '.chapter-content',
      );
    });

    test('the learned rule wins over the natural density fallback', () async {
      // Without a rule the denser decoy div wins the readability pass.
      final plain = _source({'https://site.example/chapter/9': _twoStoryBodiesPage});
      final naive = await plain.getChapter(
        const ChapterModel(
          id: 'c9',
          title: 'Chapter 9',
          index: 8,
          contentUrl: 'https://site.example/chapter/9',
        ),
      );
      expect(naive.content, contains('manifests were forged'));

      // With a learned rule the loose container is used directly, even one
      // the zoo never knew.
      final rules = <String, UniversalOriginRule>{
        'https://site.example/': UniversalOriginRule(
          updatedAt: DateTime.now().toUtc(),
          contentSelector: '#my-novel-body',
        ),
      };
      final ruled = _source(
        {'https://site.example/chapter/9': _twoStoryBodiesPage},
        rules: rules,
        learned: rules,
      );
      final read = await ruled.getChapter(
        const ChapterModel(
          id: 'c9',
          title: 'Chapter 9',
          index: 8,
          contentUrl: 'https://site.example/chapter/9',
        ),
      );
      expect(read.content, contains('Mara counted the bells'));
      expect(read.content, isNot(contains('manifests were forged')));
    });

    test('a stale learned rule falls back and is overwritten', () async {
      final rules = <String, UniversalOriginRule>{
        'https://site.example/': UniversalOriginRule(
          updatedAt: DateTime.now().toUtc(),
          contentSelector: '.gone-since-redesign',
        ),
      };
      final source = _source(
        {'https://site.example/chapter/4': _chapterPage},
        rules: rules,
        learned: rules,
      );
      final read = await source.getChapter(
        const ChapterModel(
          id: 'c4',
          title: 'Chapter 4',
          index: 3,
          contentUrl: 'https://site.example/chapter/4',
        ),
      );
      expect(read.content, contains('shadow qi coil'));
      // The fallback recovered, and the rule was re-learned from it.
      expect(rules['https://site.example/']?.contentSelector, '.chapter-content');
    });
  });

  group('UniversalOriginRuleStore', () {
    test('rules round-trip through the JSON file', () async {
      final dir = await Directory.systemTemp.createTemp('atlas_rules');
      addTearDown(() => dir.delete(recursive: true));
      final path = p.join(dir.path, 'rules.json');

      await UniversalOriginRuleStore(filePath: path).put(
        'https://site.example/',
        UniversalOriginRule(
          updatedAt: DateTime.utc(2026, 1, 2, 3, 4),
          titleSource: 'og',
          contentSelector: '.chapter-content',
          searchTemplate: '/?s={query}',
        ),
      );

      final rule =
          await UniversalOriginRuleStore(filePath: path).rule(
        'https://site.example/',
      );
      expect(rule?.titleSource, 'og');
      expect(rule?.contentSelector, '.chapter-content');
      expect(rule?.searchTemplate, '/?s={query}');
      expect(rule?.updatedAt, DateTime.utc(2026, 1, 2, 3, 4));
    });

    test('a missing file yields an empty store and put creates it', () async {
      final dir = await Directory.systemTemp.createTemp('atlas_rules');
      addTearDown(() => dir.delete(recursive: true));
      final store = UniversalOriginRuleStore(
        filePath: p.join(dir.path, 'nested', 'rules.json'),
      );

      expect(await store.rule('https://x.example/'), isNull);

      await store.put(
        'https://x.example/',
        UniversalOriginRule(
          updatedAt: DateTime.now().toUtc(),
          contentSelector: '#content',
        ),
      );
      expect((await store.rule('https://x.example/'))?.contentSelector,
          '#content');
    });

    test('a corrupt rules file degrades to empty instead of crashing',
        () async {
      final dir = await Directory.systemTemp.createTemp('atlas_rules');
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, 'rules.json'))
        ..writeAsStringSync('{not json');

      final store = UniversalOriginRuleStore(filePath: file.path);
      expect(await store.rule('https://x.example/'), isNull);
      // And the store can still heal the file afterwards.
      await store.put(
        'https://x.example/',
        UniversalOriginRule(updatedAt: DateTime.now().toUtc()),
      );
      expect(await store.rule('https://x.example/'), isNotNull);
    });
  });

  group('Registry ordering (universal is the last resort)', () {
    test('a real plugin beats the universal adapter on its domain', () {
      final registry = SourceRegistry();
      registry.register(
        _FakeAdapter('PluginSite', canHandle: (_) => true),
      );
      registry.register(_source(const {}));
      final uri = Uri.parse('https://plugin.example/novel/1');
      expect(registry.resolve(uri)!.sourceName, 'PluginSite');
    });

    test('the universal adapter claims what no plugin claimed', () {
      final registry = SourceRegistry();
      registry.register(
        _FakeAdapter('PluginSite', canHandle: (uri) => uri.host.endsWith('plugin.example')),
      );
      registry.register(_source(const {}));
      final uri = Uri.parse('https://unknown.example/novel/1');
      expect(registry.resolve(uri)!.sourceName, 'Universal');
    });
  });
}

/// SourceAdapter stub for registry-order tests; every method unused.
class _FakeAdapter implements SourceAdapter {
  _FakeAdapter(this.name, {required bool Function(Uri) canHandle})
      : canHandleFn = canHandle;

  final String name;
  final bool Function(Uri) canHandleFn;

  @override
  bool canHandle(Uri uri) => canHandleFn(uri);

  @override
  String get sourceName => name;

  @override
  ContentCategory get contentCategory => ContentCategory.novel;

  @override
  Future<NovelModel> getMetadata(Uri uri) async => NovelModel(
        sourceId: uri.toString(),
        title: name,
        source: name,
        sourceUrl: uri.toString(),
      );

  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) async => const [];

  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) async => chapter;
}
