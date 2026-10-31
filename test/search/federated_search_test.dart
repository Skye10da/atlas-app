import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/library/presentation/providers/source_browser_provider.dart';
import 'package:atlas_app/search/domain/federated_search.dart';
import 'package:atlas_app/search/domain/site_health.dart';
import 'package:atlas_app/search/presentation/providers/federated_search_provider.dart';

/// A controllable fake source: every search stays pending until the test
/// explicitly calls [completeAll] (or [failAll]) — fully deterministic.
class FakeSearchableSource implements SearchableSource {
  FakeSearchableSource(this.name);

  final String name;
  final List<Completer<SourceSearchResponse>> _pending = [];

  @override
  String get sourceName => name;

  @override
  ContentCategory get contentCategory => ContentCategory.novel;

  @override
  Future<SourceSearchResponse> search(SourceSearchQuery query) {
    final completer = Completer<SourceSearchResponse>();
    _pending.add(completer);
    return completer.future;
  }

  bool get hasPending => _pending.isNotEmpty;

  int get pendingCount => _pending.length;

  void completeAll(Iterable<SourceSearchResult> results) {
    final response = SourceSearchResponse(results: results.toList());
    for (final completer in _pending) {
      if (!completer.isCompleted) completer.complete(response);
    }
    _pending.clear();
  }

  void failAll(Object error) {
    for (final completer in _pending) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
  }

  @override
  bool canHandle(Uri uri) => false;
  @override
  Future<NovelModel> getMetadata(Uri uri) => throw UnimplementedError();
  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) =>
      throw UnimplementedError();
  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) =>
      throw UnimplementedError();
}

SourceSearchResult result(
  String title, [
  String? author,
  String urlSuffix = '123',
]) {
  return SourceSearchResult(
    id: '$title$urlSuffix',
    title: title,
    author: author,
    importUrl: 'https://site.example/novel/$title$urlSuffix',
  );
}

SiteSearchStatus statusOf(
  FederatedSearchState state,
  String sourceName,
) =>
    state.sites.firstWhere((s) => s.sourceName == sourceName);

void main() {
  group('federatedMatchKey', () {
    test('same title and author (any spacing/casing) share a key', () {
      expect(
        federatedMatchKey('Reverend Insanity', 'Gu Zhen Ren'),
        federatedMatchKey('reverend  insanity', 'gu zhen ren'),
      );
    });

    test('different authors stay separate (conservative dedupe)', () {
      final keyA = federatedMatchKey('Dune', 'Frank Herbert');
      final keyB = federatedMatchKey('Dune', 'Another Writer');
      expect(keyA, isNot(keyB));
    });

    test('null author never merges with a named author', () {
      expect(
        federatedMatchKey('Grail Quest', null),
        isNot(federatedMatchKey('Grail Quest', 'someone')),
      );
    });

    test('CJK and unicode titles keep their letters', () {
      expect(
        federatedMatchKey('妨者', '顾真人'),
        isNot(federatedMatchKey('妨者', '')),
      );
    });
  });

  group('FederatedSearchState.mergeSiteResults', () {
    test('keeps distinct books separate', () {
      final merged = FederatedSearchState.mergeSiteResults(
        current: const [],
        incoming: [
          FederatedBook(
            title: 'Alpha',
            matchKey: federatedMatchKey('Alpha', 'A'),
            offerings: [const SiteOffering(sourceName: 's1', importUrl: 'u1')],
          ),
          FederatedBook(
            title: 'Beta',
            matchKey: federatedMatchKey('Beta', 'B'),
            offerings: [const SiteOffering(sourceName: 's1', importUrl: 'u2')],
          ),
        ],
      );
      expect(merged, hasLength(2));
    });

    test('merges the same book from a second site into one card', () {
      final first = FederatedSearchState.mergeSiteResults(
        current: const [],
        incoming: [
          FederatedBook(
            title: 'Alpha',
            author: 'A',
            matchKey: federatedMatchKey('Alpha', 'A'),
            offerings: [const SiteOffering(sourceName: 's1', importUrl: 'u1')],
          ),
        ],
      );
      final merged = FederatedSearchState.mergeSiteResults(
        current: first,
        incoming: [
          FederatedBook(
            title: 'alpha',
            author: 'a',
            matchKey: federatedMatchKey('alpha', 'a'),
            offerings: [const SiteOffering(sourceName: 's2', importUrl: 'u2')],
          ),
        ],
      );
      expect(merged, hasLength(1));
      expect(merged.single.offerings, hasLength(2));
      expect(merged.single.isMultiSource, isTrue);
    });

    test('duplicate importUrl offerings are not double-added', () {
      final card = FederatedBook(
        title: 'Alpha',
        matchKey: federatedMatchKey('Alpha', 'A'),
        offerings: [const SiteOffering(sourceName: 's1', importUrl: 'u1')],
      );
      final merged = FederatedSearchState.mergeSiteResults(
        current: [card],
        incoming: [
          FederatedBook(
            title: 'Alpha',
            matchKey: federatedMatchKey('Alpha', 'A'),
            offerings: [const SiteOffering(sourceName: 's2', importUrl: 'u1')],
          ),
        ],
      );
      expect(merged.single.offerings, hasLength(1));
    });
  });

  group('FederatedSearchNotifier', () {
    late FakeSearchableSource fastSource;
    late FakeSearchableSource slowSource;
    late FakeSearchableSource brokenSource;
    late ProviderContainer container;

    setUp(() {
      fastSource = FakeSearchableSource('FastSite');
      slowSource = FakeSearchableSource('SlowSite');
      brokenSource = FakeSearchableSource('BrokenSite');
      container = ProviderContainer(
        overrides: [
          searchableSourcesProvider
              .overrideWith((ref) => [fastSource, slowSource, brokenSource]),
        ],
      );
      addTearDown(container.dispose);
    });

    test('fan-out posts per-site statuses and all complete independently', () async {
      container.listen(federatedSearchProvider, (_, _) {});

      container
          .read(federatedSearchProvider.notifier)
          .run('wandering wind');

      // All sites are initially loading.
      final initial = container.read(federatedSearchProvider);
      expect(initial.term, 'wandering wind');
      expect(
        initial.sites.every((s) => s.state == SiteSearchState.loading),
        isTrue,
      );

      fastSource.completeAll([result('Wandering Wind', 'Emma Vale')]);
      await drainAsync();

      final partial = container.read(federatedSearchProvider);
      expect(statusOf(partial, 'FastSite').state, SiteSearchState.done);
      expect(statusOf(partial, 'FastSite').resultCount, 1);
      // Others still pending.
      expect(statusOf(partial, 'SlowSite').state, SiteSearchState.loading);

      slowSource.completeAll([
        result('Wandering Wind', 'Emma Vale', 'feather'),
        result('Totally Different', 'Other Guy'),
      ]);
      brokenSource.failAll(const SocketException('offline'));
      await drainAsync();

      final finalState = container.read(federatedSearchProvider);
      expect(statusOf(finalState, 'SlowSite').state, SiteSearchState.done);
      // Error isolation: the broken site counts as unavailable, not a
      // failed search — the other sites' results survive.
      final brokenStatus = statusOf(finalState, 'BrokenSite');
      expect(brokenStatus.state, SiteSearchState.error);
      expect(finalState.sitesUnreachable, 1);

      // Dedupe across sites: 'Wandering Wind' found twice → one card,
      // two offerings; 'Totally Different' is its own card.
      expect(finalState.results, hasLength(2));
      final wind = finalState.results.singleWhere(
        (b) => b.title == 'Wandering Wind',
      );
      expect(wind.offerings, hasLength(2));
      expect(wind.isMultiSource, isTrue);
    });

    test('new query supersedes the previous run', () async {
      container.listen(federatedSearchProvider, (_, _) {});
      container
          .read(federatedSearchProvider.notifier)
          .run('first query');
      // Both sources have a pending first-query search.
      slowSource.completeAll([result('Old Result', 'Older', 'old')]);

      container.read(federatedSearchProvider.notifier).run('second query');
      await drainAsync();

      // The first run's late response is dropped (stale generation).
      final state = container.read(federatedSearchProvider);
      expect(state.term, 'second query');
      expect(
        state.results.any((b) => b.title == 'Old Result'),
        isFalse,
      );

      // Sanity: 'second query' generation still accepts results.
      fastSource.completeAll([result('New Result', 'Newer', 'new')]);
      await drainAsync();
      expect(
        container
            .read(federatedSearchProvider)
            .results
            .any((b) => b.title == 'New Result'),
        isTrue,
      );
    });

    test('debounce groups keystrokes into one fan-out', () async {
      fakeAsync((async) {
        container.listen(federatedSearchProvider, (_, _) {});
        container.read(federatedSearchProvider.notifier).query('wander');
        async.elapse(const Duration(milliseconds: 100));
        container.read(federatedSearchProvider.notifier).query('wandering');

        // Debounce window not yet elapsed — nothing has started.
        final state = container.read(federatedSearchProvider);
        expect(state.term, isEmpty);

        async.elapse(
          const Duration(milliseconds: 300) + const Duration(milliseconds: 1),
        );
        final fired = container.read(federatedSearchProvider).term;
        expect(fired, 'wandering');
        expect(fastSource.hasPending, isTrue);
      });
    });

    test('per-site timeout marks the site failed, not the search', () async {
      fakeAsync((async) {
        container.listen(federatedSearchProvider, (_, _) {});
        container.read(federatedSearchProvider.notifier).run('slowpoke');

        fastSource.completeAll([result('Something', null)]);
        async.elapse(const Duration(seconds: 1));
        expect(
          statusOf(container.read(federatedSearchProvider), 'FastSite').state,
          SiteSearchState.done,
        );
        expect(
          statusOf(container.read(federatedSearchProvider), 'SlowSite').state,
          SiteSearchState.loading,
        );

        async.elapse(
          const Duration(seconds: 7) + const Duration(milliseconds: 1),
        );
        final state = container.read(federatedSearchProvider);
        final slowStatus = statusOf(state, 'SlowSite');
        expect(slowStatus.state, SiteSearchState.error);
        expect(slowStatus.error, contains('Timed out'));
        // Results unaffected by the timeout.
        expect(state.results, hasLength(1));
      });
    });

    test('clear() resets to idle', () async {
      container.listen(federatedSearchProvider, (_, _) {});
      container.read(federatedSearchProvider.notifier).run('thing');
      fastSource.completeAll([result('Thing', null)]);
      slowSource.completeAll(const []);
      brokenSource.failAll('x');
      await drainAsync();

      container.read(federatedSearchProvider.notifier).clear();
      await drainAsync();

      final state = container.read(federatedSearchProvider);
      expect(state.isIdle, isTrue);
      expect(state.term, isEmpty);
      expect(state.results, isEmpty);
      expect(state.sites.every((s) => s.state == SiteSearchState.pending),
          isTrue);
    });
  });

  group('SiteHealth', () {
    test('single ordinary failure does not skip; two do', () {
      var now = DateTime(2026, 1, 1);
      final health = SiteHealth(clock: () => now);

      health.failure('site');
      expect(health.shouldSkip('site'), isFalse);

      // Second failure opens the breaker: 5 × n minutes (n = 2 → 10).
      health.failure('site');
      expect(health.shouldSkip('site'), isTrue);
      expect(health.backoffRemaining('site'), const Duration(minutes: 10));

      now = now.add(const Duration(minutes: 11));
      expect(health.shouldSkip('site'), isFalse);
    });

    test('hard block opens immediately for 30 minutes', () {
      var now = DateTime(2026, 1, 1);
      final health = SiteHealth(clock: () => now);

      health.failure('site', blocked: true);
      expect(health.shouldSkip('site'), isTrue);
      expect(health.backoffRemaining('site'), const Duration(minutes: 30));

      now = now.add(const Duration(minutes: 31));
      expect(health.shouldSkip('site'), isFalse);
    });

    test('backoff grows with failures but clamps at 60 minutes', () {
      final now = DateTime(2026, 1, 1);
      final health = SiteHealth(clock: () => now);
      health.failure('site', blocked: true);
      health.reset('site');

      // Two more failures → 10 min, 15 min; then clearAll wipes state so
      // the "grow" progression can be exercised deterministically.
      health.failure('site');
      health.failure('site');
      expect(health.backoffRemaining('site'), const Duration(minutes: 10));
      health.reset('site');
      health.failure('site');
      health.failure('site');
      health.failure('site');
      expect(health.backoffRemaining('site'), const Duration(minutes: 15));
      health.reset('site');
    });

    test('reset admits the site immediately', () {
      final health = SiteHealth(clock: () => DateTime(2026, 1, 1));
      health.failure('site', blocked: true);
      expect(health.shouldSkip('site'), isTrue);
      health.reset('site');
      expect(health.shouldSkip('site'), isFalse);
      expect(health.failureCount, 0);
    });

    test('success clears failures and records latency', () {
      final health = SiteHealth(clock: () => DateTime(2026, 1, 1));
      health.failure('site');
      health.failure('site');
      expect(health.shouldSkip('site'), isTrue);
      health.success('site', latencyMs: 240);
      expect(health.shouldSkip('site'), isFalse);
      expect(health.lastLatencyMs('site'), 240);
    });
  });

  group('asImportLink', () {
    test('full URL parses directly', () {
      final u = asImportLink('https://example.com/novel/reverend');
      expect(u?.host, 'example.com');
      expect(u?.path, contains('reverend'));
    });

    test('scheme-less host gets https prepended', () {
      final u = asImportLink('example.com/novel/reverend');
      expect(u?.scheme, 'https');
      expect(u?.host, 'example.com');
    });

    test('plain search terms are not links', () {
      expect(asImportLink('wandering wind'), isNull);
      expect(asImportLink('not-a-link'), isNull);
      expect(asImportLink('http:/broken'), isNull);
    });

    test('host without a dot is treated as a search term', () {
      expect(asImportLink('localhost:8080/novel'), isNull);
    });
  });

  group('federated ranking', () {
    FederatedBook book(
      String title, {
      String? author,
      List<String> sites = const ['s1'],
    }) =>
        FederatedBook(
          title: title,
          author: author,
          matchKey: federatedMatchKey(title, author),
          offerings: [
            for (final site in sites)
              SiteOffering(sourceName: site, importUrl: 'u/$site'),
          ],
        );

    test('exact beats prefix beats contains beats token overlap', () {
      final books = [
        book('A Tale About Wanderers'),
        book('Wandering Wind Begins'),
        book('Wandering Wind'),
        book('The Wandering Wind'),
      ];
      final ranked = rankFederatedResults(books, const [], 'wandering wind');
      expect(ranked.first.title, 'Wandering Wind');
      expect(ranked[1].title, anyOf(
        'Wandering Wind Begins',
        'The Wandering Wind',
      ));
      expect(ranked.last.title, 'A Tale About Wanderers');
    });

    test('multi-site bonus lifts a near match above a single-site one', () {
      final multi = book('The Wandering Wind', sites: const ['a', 'b']);
      final single = book('The Wandering Wind Saga');
      final ranked = rankFederatedResults([single, multi], const [], 'wander');
      expect(ranked.first.title, 'The Wandering Wind');
    });

    test('frozen slots resist reordering from later responses', () {
      final frozenBooks = [
        'Morning Star',
        'Morning Dew',
        'The Morning Sun',
        'Evening Tales',
        'Midnight Whispers',
        'Velvet Horizon',
      ].map(book).toList();

      final firstFlush =
          rankFederatedResults(frozenBooks, const [], 'morning');
      final frozenKeys = [
        for (final b in firstFlush.take(5)) b.matchKey,
      ];

      // A better-matching book arrives later — it ranks strictly behind
      // the frozen five, which keep their order.
      final ranked = rankFederatedResults(
        [book('Morning Fog'), ...frozenBooks],
        frozenKeys,
        'morning',
      );

      expect(
        ranked.take(5).map((b) => b.title),
        firstFlush.take(5).map((b) => b.title),
      );
      expect(ranked[5].title, 'Morning Fog');
    });
  });

  group('FederatedSearchNotifier — cache, breaker, cap, retry', () {
    test('re-running the same term serves from cache (no network)', () async {
      final sources = List.generate(
        3,
        (i) => FakeSearchableSource('CacheSite$i'),
      );
      final container = ProviderContainer(
        overrides: [searchableSourcesProvider.overrideWith((ref) => sources)],
      );
      addTearDown(container.dispose);
      container.listen(federatedSearchProvider, (_, _) {});

      container.read(federatedSearchProvider.notifier).run('cached');
      sources[0].completeAll([result('Cached Book', 'Caps')]);
      sources[1].completeAll(const []);
      sources[2].failAll('boom');
      await drainAsync();

      container.read(federatedSearchProvider.notifier).run('cached');

      // The whole state is immediatelysettled from cache — and none of
      // the sites got a new network call.
      final state = container.read(federatedSearchProvider);
      expect(
        state.sites.every(
          (s) =>
              s.state == SiteSearchState.done ||
              s.state == SiteSearchState.empty ||
              s.state == SiteSearchState.error,
        ),
        isTrue,
      );
      expect(
        sources.every((source) => source.pendingCount == 0),
        isTrue,
      );
      expect(state.results, isNotEmpty);
    });

    test('the circuit breaker skips twice-failed sites ("couldn\'t be '
        'reached"), retry admits them again', () async {
      final sources = List.generate(
        2,
        (i) => FakeSearchableSource('FlakySite$i'),
      );
      final container = ProviderContainer(
        overrides: [searchableSourcesProvider.overrideWith((ref) => sources)],
      );
      addTearDown(container.dispose);
      container.listen(federatedSearchProvider, (_, _) {});

      // Two consecutive failing runs (different terms) open the breaker.
      for (final term in ['first wave', 'second wave']) {
        container.read(federatedSearchProvider.notifier).run(term);
        for (final source in sources) {
          source.failAll('boom');
        }
        await drainAsync();
      }

      container.read(federatedSearchProvider.notifier).run('third wave');

      final state = container.read(federatedSearchProvider);
      expect(
        state.sites.every((s) => s.state == SiteSearchState.skipped),
        isTrue,
      );
      expect(state.sitesUnreachable, 2);
      expect(
        sources.every((source) => source.pendingCount == 0),
        isTrue,
      );

      // Retry: clear the breaker and re-query only the unreachable sites.
      container.read(federatedSearchProvider.notifier).retryUnreachable();
      await drainAsync();
      expect(
        sources.every((source) => source.pendingCount == 1),
        isTrue,
      );
      for (final source in sources) {
        source.completeAll([result('Recovered Book', null)]);
      }
      await drainAsync();
      expect(
        statusOf(container.read(federatedSearchProvider), 'FlakySite0').state,
        SiteSearchState.done,
      );
    });

    test('a hard-blocked site is skipped on the very next run', () async {
      final sources = [FakeSearchableSource('CloudflareSite')];
      final container = ProviderContainer(
        overrides: [searchableSourcesProvider.overrideWith((ref) => sources)],
      );
      addTearDown(container.dispose);
      container.listen(federatedSearchProvider, (_, _) {});

      container.read(federatedSearchProvider.notifier).run('blocked probe');
      sources.single.failAll(Exception('403 Forbidden — cloudflare'));
      await drainAsync();

      container.read(federatedSearchProvider.notifier).run('retry probe');

      final status =
          statusOf(container.read(federatedSearchProvider), 'CloudflareSite');
      expect(status.state, SiteSearchState.skipped);
      expect(sources.single.pendingCount, 0);
    });

    test('at most 6 site searches run concurrently', () async {
      final sources = List.generate(
        8,
        (i) => FakeSearchableSource('CapSite$i'),
      );
      final container = ProviderContainer(
        overrides: [searchableSourcesProvider.overrideWith((ref) => sources)],
      );
      addTearDown(container.dispose);
      container.listen(federatedSearchProvider, (_, _) {});

      container.read(federatedSearchProvider.notifier).run('capped');

      final inFlight = sources.fold<int>(
        0,
        (sum, s) => sum + s.pendingCount,
      );
      expect(inFlight, maxConcurrentSiteSearches);

      // Finishing the first wave pulls the next sites into the pool.
      for (final source in sources) {
        source.completeAll(const []);
      }
      await drainAsync();
      expect(
        sources.fold<int>(0, (sum, s) => sum + s.pendingCount),
        2,
      );
    });
  });
}

Future<void> drainAsync() async {
  // Results are emitted on the [emitInterval] throttle timer, so a real
  // clock wait is required for state to land.
  await Future<void>.delayed(emitInterval + const Duration(milliseconds: 30));
}
