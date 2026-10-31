import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/library/presentation/providers/source_browser_provider.dart';
import 'package:atlas_app/search/domain/federated_search.dart';
import 'package:atlas_app/search/domain/site_health.dart';

/// Debounce for the hero search — groups keystrokes into one fan-out.
const searchDebounce = Duration(milliseconds: 300);

/// How long one site may take before it is marked failed.
const siteSearchTimeout = Duration(seconds: 8);

/// Hard cap for a whole run so the summary line always finishes.
const runDeadline = Duration(seconds: 8);

/// How many site searches may run concurrently.
const maxConcurrentSiteSearches = 6;

/// UI update cadence — coalesces bursts of site responses so the results
/// list doesn't rebuild on every single response.
const emitInterval = Duration(milliseconds: 120);

/// How long successful per-site results are reused without re-querying.
const cacheHitTtl = Duration(minutes: 10);

/// How long a "no results" or "failed" site stays cached — re-searching
/// backspaced text then only hits the sites that actually missed.
const cacheMissTtl = Duration(minutes: 2);

/// Book state survives ~this long after the last listener leaves, so
/// "tap a book, go back" is not an empty screen. The lazy-start rule
/// still holds: nothing is created at launch.
const keepAliveGrace = Duration(minutes: 3);

/// Minimum number of characters before a search starts.
const minSearchCharacters = 2;

const _maxCacheEntries = 80;

final federatedSearchProvider = AutoDisposeNotifierProvider<
    FederatedSearchNotifier, FederatedSearchState>(
  FederatedSearchNotifier.new,
);

/// Fans one query out to every supported [SearchableSource], with:
/// * per-site error isolation (a failing site is never a failed search);
/// * a circuit breaker that skips twice-failed / blocked sites — those are
///   surfaced as "couldn't be reached", never as a technical error;
/// * a per-site TTL cache (results 10 min, empty/failed 2 min);
/// * a concurrency cap and an 8 s whole-run deadline;
/// * UI emission throttled to one update per [emitInterval], with the top
///   5 result slots frozen after the first flush so cards don't jump;
/// * keep-alive grace so tapping into a book and returning keeps results.
/// Nothing here runs at app start — the provider is only created when the
/// search screen is open.
class FederatedSearchNotifier extends AutoDisposeNotifier<FederatedSearchState> {
  Timer? _debounce;
  Timer? _runDeadline;
  Timer? _flushTimer;
  int _generation = 0;

  /// Health of each site across runs. Lives with the notifier (and the
  /// keep-alive grace) — resets on restart, never persisted.
  final SiteHealth siteHealth = SiteHealth();

  // Defaulted so subclasses that replace build() (test stubs) are still
  // safe to touch before any real search ran.
  FederatedSearchState _state = FederatedSearchState.idle(const []);

  /// Top result slots frozen after the first flush of the current run.
  List<String> _frozenKeys = const [];

  final Map<String, _CacheEntry> _cache = {};
  final List<SearchableSource> _queue = [];
  int _active = 0;
  bool _isInitialized = false;
  bool _graceRegistered = false;

  @override
  FederatedSearchState build() {
    ref.onDispose(() {
      _generation++;
      _runDeadline?.cancel();
      _cancelDebounce();
      _flushTimer?.cancel();
    });

    if (!_graceRegistered) {
      _graceRegistered = true;
      // Keep-alive grace: hold results ~[keepAliveGrace] after the last
      // listener leaves.
      final link = ref.keepAlive();
      Timer? grace;
      ref.onCancel(() => grace = Timer(keepAliveGrace, link.close));
      ref.onResume(() => grace?.cancel());
      ref.onDispose(() => grace?.cancel());
    }

    final sources = ref.watch(searchableSourcesProvider);
    final names = [for (final source in sources) source.sourceName];

    if (!_isInitialized) {
      _isInitialized = true;
      _state = FederatedSearchState.idle(names);
    } else if (_state.term.isEmpty) {
      // Idle: refresh the pending-site snapshot with the latest registry
      // (plugin warm-up may have added sites since the first build).
      _state = FederatedSearchState.idle(names);
    }
    return _state;
  }

  /// Debounced entry point from the hero search field.
  void query(String term) {
    final trimmed = term.trim();
    if (trimmed.isEmpty) {
      clear();
      return;
    }
    if (trimmed.length < minSearchCharacters) return;
    if (trimmed == _state.term) return;
    _cancelDebounce();
    _debounce = Timer(searchDebounce, () => run(trimmed));
  }

  /// Runs the full fan-out immediately (debounce completion, Enter key).
  void run(String term) {
    final sources = ref.read(searchableSourcesProvider);
    final gen = ++_generation;
    _cancelDebounce();
    _startDeadline(gen);
    _frozenKeys = const [];

    _update(
      _initialState(term, sources),
      immediate: true,
    );

    for (final source in sources) {
      _scheduleSite(source, term, gen, force: false);
    }
  }

  /// Re-queries only the sites that couldn't be reached last round.
  /// Results from the sites that answered stay on screen — no reset.
  void retryUnreachable() {
    final term = _state.term.trim();
    if (term.isEmpty) return;
    final sources = ref.read(searchableSourcesProvider);

    // Capture BEFORE swapping those sites to loading.
    final failedSites = [
      for (final site in _state.sites)
        if (site.state == SiteSearchState.error ||
            site.state == SiteSearchState.skipped)
          site,
    ];
    final failedNames = {for (final site in failedSites) site.sourceName};

    final gen = ++_generation;
    _startDeadline(gen);

    _update(
      _state.copyWith(
        sites: [
          for (final site in _state.sites)
            if (failedNames.contains(site.sourceName))
              SiteSearchStatus(
                sourceName: site.sourceName,
                state: SiteSearchState.loading,
                resultCount: 0,
              )
            else
              site,
        ],
      ),
      immediate: true,
    );

    for (final source
        in sources.where((s) => failedNames.contains(s.sourceName))) {
      siteHealth.reset(source.sourceName);
      _scheduleSite(source, term, gen, force: true);
    }
  }

  /// Back to the dashboard (idle) state.
  void clear() {
    _generation++;
    _runDeadline?.cancel();
    _cancelDebounce();
    _flushTimer?.cancel();
    _flushNow();
    final sources = ref.read(searchableSourcesProvider);
    _frozenKeys = const [];
    _update(FederatedSearchState.idle(
      [for (final source in sources) source.sourceName],
    ), immediate: true);
  }

  /// Orders a book's site offerings for the confirm sheet: healthy sites
  /// first, then fastest-responding, merge order as tiebreak.
  /// Breaker-open sites sink to the bottom — the top one is the
  /// "Recommended" default the user can confirm in a single tap.
  List<SiteOffering> rankOfferings(List<SiteOffering> offerings) {
    final ranked = [...offerings];
    ranked.sort((a, b) {
      final aSkipped = siteHealth.shouldSkip(a.sourceName);
      final bSkipped = siteHealth.shouldSkip(b.sourceName);
      if (aSkipped != bSkipped) return aSkipped ? 1 : -1;
      final aLatency = siteHealth.lastLatencyMs(a.sourceName) ?? 1 << 30;
      final bLatency = siteHealth.lastLatencyMs(b.sourceName) ?? 1 << 30;
      return aLatency.compareTo(bLatency);
    });
    return ranked;
  }

  // ------------------------------------------------------------------
  // internals

  void _startDeadline(int gen) {
    _runDeadline?.cancel();
    _runDeadline = Timer(runDeadline, () => _finishStaleRun(gen));
  }

  /// Initial state for a new full run: every source loading, except
  /// breaker-skipped ones (state [SiteSearchState.skipped]) and ones
  /// served straight from a fresh cache.
  FederatedSearchState _initialState(
    String term,
    List<SearchableSource> sources,
  ) {
    var results = const <FederatedBook>[];
    final siteStatuses = <SiteSearchStatus>[];

    for (final source in sources) {
      if (siteHealth.shouldSkip(source.sourceName)) {
        siteStatuses.add(SiteSearchStatus(
          sourceName: source.sourceName,
          state: SiteSearchState.skipped,
          error: 'Couldn\'t be reached',
        ));
        continue;
      }
      final cached = _cacheGet(source.sourceName, term);
      if (cached != null) {
        siteStatuses.add(cached.status(source.sourceName));
        final cachedBooks = cached.books;
        if (cachedBooks != null) {
          results = FederatedSearchState.mergeSiteResults(
            current: results,
            incoming: cachedBooks,
          );
        }
        continue;
      }
      siteStatuses.add(SiteSearchStatus(
        sourceName: source.sourceName,
        state: SiteSearchState.loading,
      ));
    }

    _frozenKeys = const [];
    return FederatedSearchState(
      term: term,
      sites: siteStatuses,
      results: rankFederatedResults(results, _frozenKeys, term),
    );
  }

  void _scheduleSite(
    SearchableSource source,
    String term,
    int gen, {
    required bool force,
  }) {
    if (siteHealth.shouldSkip(source.sourceName)) {
      if (gen != _generation) return;
      _update(
        stateWithSite(
          sourceName: source.sourceName,
          status: SiteSearchStatus(
            sourceName: source.sourceName,
            state: SiteSearchState.skipped,
            error: 'Couldn\'t be reached',
          ),
        ),
      );
      return;
    }
    if (!force) {
      final cached = _cacheGet(source.sourceName, term);
      if (cached != null) {
        if (gen != _generation) return;
        _update(
          stateWithSite(
            sourceName: source.sourceName,
            status: cached.status(source.sourceName),
            books: cached.books ?? const <FederatedBook>[],
          ),
        );
        return;
      }
    }
    _queue.add(source);
    _drainQueue(term, gen);
  }

  void _drainQueue(String term, int gen) {
    while (_active < maxConcurrentSiteSearches && _queue.isNotEmpty) {
      final source = _queue.removeAt(0);
      _active++;
      _searchSite(source, term, gen).whenComplete(() {
        _active--;
        if (gen == _generation) _drainQueue(term, gen);
      });
    }
  }

  Future<void> _searchSite(
    SearchableSource source,
    String term,
    int gen,
  ) async {
    final startedAt = DateTime.now();
    try {
      final response = await source
          .search(SourceSearchQuery(term: term, page: 1))
          .timeout(siteSearchTimeout);
      final latencyMs = DateTime.now().difference(startedAt).inMilliseconds;
      siteHealth.success(source.sourceName, latencyMs: latencyMs);
      if (gen != _generation) return;
      final books = [
        for (final result in response.results)
          FederatedBook(
            title: result.title,
            author: result.author,
            coverUrl: result.coverUrl,
            description: result.description,
            matchKey: federatedMatchKey(result.title, result.author),
            offerings: [
              SiteOffering(
                sourceName: source.sourceName,
                importUrl: result.importUrl,
                coverUrl: result.coverUrl,
                description: result.description,
              ),
            ],
          ),
      ];
      _cacheStore(
        source.sourceName,
        term,
        _CacheEntry(
          kind: response.results.isEmpty
              ? _CacheKind.empty
              : _CacheKind.results,
          books: books,
          count: response.results.length,
          at: DateTime.now(),
        ),
      );
      _update(
        stateWithSite(
          sourceName: source.sourceName,
          status: SiteSearchStatus(
            sourceName: source.sourceName,
            state: response.results.isEmpty
                ? SiteSearchState.empty
                : SiteSearchState.done,
            resultCount: response.results.length,
          ),
          books: books,
        ),
      );
    } catch (error) {
      final isTimeout = error is TimeoutException;
      final blocked = _isBlocked(error);
      siteHealth.failure(source.sourceName, blocked: blocked);
      if (gen != _generation) return;
      _cacheStore(
        source.sourceName,
        term,
        _CacheEntry(
          kind: _CacheKind.error,
          count: 0,
          at: DateTime.now(),
        ),
      );
      _update(
        stateWithSite(
          sourceName: source.sourceName,
          status: SiteSearchStatus(
            sourceName: source.sourceName,
            state: SiteSearchState.error,
            error: isTimeout
                ? 'Timed out'
                : blocked
                    ? 'Blocked by the site'
                    : 'Couldn\'t reach the site',
          ),
        ),
      );
    }
  }

  /// True when an exception looks like an anti-bot / Cloudflare block
  /// rather than a generic network failure.
  static bool _isBlocked(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('403') ||
        message.contains('405') ||
        message.contains('503') ||
        message.contains('forbidden') ||
        message.contains('cloudflare') ||
        message.contains('challenge') ||
        message.contains('checking your browser');
  }

  /// Deadline ticker for a run: force-finishes still-loading sites so the
  /// summary always completes.
  void _finishStaleRun(int gen) {
    if (gen != _generation) return;
    final stillLoading = [
      for (final site in _state.sites)
        if (site.state == SiteSearchState.loading) site.sourceName,
    ];
    for (final name in stillLoading) {
      siteHealth.failure(name);
      _update(
        stateWithSite(
          sourceName: name,
          status: SiteSearchStatus(
            sourceName: name,
            state: SiteSearchState.error,
            error: 'Timed out',
          ),
        ),
        immediate: true,
      );
    }
  }

  /// One site's status swapped in and its books merged into the
  /// deduplicated, ranked result set.
  FederatedSearchState stateWithSite({
    required String sourceName,
    required SiteSearchStatus status,
    List<FederatedBook> books = const [],
  }) {
    return FederatedSearchState(
      term: _state.term,
      sites: [
        for (final site in _state.sites)
          if (site.sourceName == sourceName) status else site,
      ],
      results: books.isEmpty
          ? _state.results
          : rankWithFreezing(
              FederatedSearchState.mergeSiteResults(
                current: _state.results,
                incoming: books,
              ),
              _state.term,
            ),
    );
  }

  /// Orders [books] for display, honoring frozen slots; freezes the
  /// current top 5 on the first flush of a run.
  List<FederatedBook> rankWithFreezing(
    List<FederatedBook> books,
    String term,
  ) {
    final ranked = rankFederatedResults(books, _frozenKeys, term);
    if (_frozenKeys.isEmpty && ranked.isNotEmpty) {
      _frozenKeys = [
        for (final book in ranked.take(5)) book.matchKey,
      ];
    }
    return ranked;
  }

  /// Throttled update: keeps `_state` current; commits to `state` at the
  /// [emitInterval] cadence so bursts of responses coalesce.
  void _update(FederatedSearchState next, {bool immediate = false}) {
    _state = next;
    if (immediate) {
      _flushTimer?.cancel();
      _flushTimer = null;
      state = next;
      return;
    }
    _flushTimer ??= Timer(emitInterval, _flushNow);
  }

  void _flushNow() {
    _flushTimer = null;
    state = _state;
  }

  void _cancelDebounce() {
    _debounce?.cancel();
    _debounce = null;
  }

  _CacheEntry? _cacheGet(String site, String term) {
    final entry = _cache[_cacheKey(site, term)];
    if (entry == null) return null;
    final ttl = entry.kind == _CacheKind.results ? cacheHitTtl : cacheMissTtl;
    if (entry.at.isBefore(DateTime.now().subtract(ttl))) {
      _cache.remove(_cacheKey(site, term));
      return null;
    }
    return entry;
  }

  void _cacheStore(String site, String term, _CacheEntry entry) {
    _cache[_cacheKey(site, term)] = entry;
    while (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  String _cacheKey(String site, String term) =>
      '$site|${term.trim().toLowerCase()}';
}

enum _CacheKind { results, empty, error }

class _CacheEntry {
  const _CacheEntry({
    required this.kind,
    required this.at,
    this.books,
    this.count = 0,
  });

  final _CacheKind kind;
  final DateTime at;
  final List<FederatedBook>? books;
  final int count;

  SiteSearchStatus status(String sourceName) {
    return switch (kind) {
      _CacheKind.results => SiteSearchStatus(
          sourceName: sourceName,
          state: SiteSearchState.done,
          resultCount: count,
        ),
      _CacheKind.empty => SiteSearchStatus(
          sourceName: sourceName,
          state: SiteSearchState.empty,
        ),
      _CacheKind.error => SiteSearchStatus(
          sourceName: sourceName,
          state: SiteSearchState.error,
          error: 'Couldn\'t reach the site',
        ),
    };
  }
}
