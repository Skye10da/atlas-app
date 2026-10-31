import 'package:atlas_app/core/content_acquisition/utils/book_id_normalizer.dart';

/// A single site's machine state during a federated search fan-out.
///
/// [SiteSearchState.skipped] means the circuit breaker kept the site out of
/// this run — surfaced to the user as "couldn't be reached", never as a
/// technical error.
enum SiteSearchState { pending, loading, done, empty, error, skipped }

/// Lifecycle snapshot of one supported site inside a federated search.
class SiteSearchStatus {
  const SiteSearchStatus({
    required this.sourceName,
    this.state = SiteSearchState.pending,
    this.error,
    this.resultCount = 0,
  });

  final String sourceName;
  final SiteSearchState state;

  /// Human-readable failure reason when [state] is [SiteSearchState.error].
  final String? error;
  final int resultCount;

  SiteSearchStatus copyWith({
    SiteSearchState? state,
    String? error,
    int? resultCount,
  }) {
    return SiteSearchStatus(
      sourceName: sourceName,
      state: state ?? this.state,
      error: error ?? this.error,
      resultCount: resultCount ?? this.resultCount,
    );
  }

  /// Initial all-[pending] snapshot for a fan-out across [siteNames].
  static List<SiteSearchStatus> pendingFor(List<String> siteNames) =>
      [for (final name in siteNames) SiteSearchStatus(sourceName: name)];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SiteSearchStatus &&
          sourceName == other.sourceName &&
          state == other.state &&
          error == other.error &&
          resultCount == other.resultCount;

  @override
  int get hashCode => Object.hash(sourceName, state, error, resultCount);
}

/// One concrete offer of a book on a specific site — the address the
/// import engine can fetch the novel from.
class SiteOffering {
  const SiteOffering({
    required this.sourceName,
    required this.importUrl,
    this.coverUrl,
    this.description,
  });

  final String sourceName;
  final String importUrl;
  final String? coverUrl;
  final String? description;
}

/// A book found on one or more supported sites after deduplication.
///
/// The same novel surfaced on several sites is merged into a single
/// [FederatedBook] so the searcher sees one card with a per-site list
/// instead of near-duplicates.
class FederatedBook {
  const FederatedBook({
    required this.title,
    required this.matchKey,
    required this.offerings,
    this.author,
    this.coverUrl,
    this.description,
  });

  final String title;
  final String? author;
  final String? coverUrl;
  final String? description;

  /// Deduplication identity — see [federatedMatchKey].
  final String matchKey;
  final List<SiteOffering> offerings;

  bool get isMultiSource => offerings.length > 1;

  /// First offering is the default import target (the site that reported
  /// the result first — i.e. the fastest responding source).
  SiteOffering? get primaryOffering => offerings.isEmpty ? null : offerings.first;

  /// Returns a copy with [offering] appended to [offerings], keeping the
  /// first-seen metadata (title/author/cover) for stability during fan-in.
  FederatedBook withOffering(SiteOffering offering) {
    return FederatedBook(
      matchKey: matchKey,
      title: title,
      author: author,
      coverUrl: coverUrl,
      description: description,
      offerings: [...offerings, offering],
    );
  }
}

/// Result of merging the per-site search results of one [query].
class FederatedSearchState {
  const FederatedSearchState({
    required this.term,
    required this.sites,
    required this.results,
  });

  /// The idle state — no active or completed search.
  factory FederatedSearchState.idle(List<String> siteNames) {
    return FederatedSearchState(
      term: '',
      sites: SiteSearchStatus.pendingFor(siteNames),
      results: const [],
    );
  }
  final String term;
  final List<SiteSearchStatus> sites;
  final List<FederatedBook> results;

  bool get isIdle => term.isEmpty && results.isEmpty;

  /// Merges one site's raw results into the running federated result set,
  /// deduplicating books across sites via [federatedMatchKey].
  ///
  /// Returns a new list; never mutates [current].
  static List<FederatedBook> mergeSiteResults({
    required List<FederatedBook> current,
    required List<FederatedBook> incoming,
  }) {
    if (incoming.isEmpty) return current;
    final merged = [...current];
    final byKey = {for (final b in merged) b.matchKey: b};
    for (final book in incoming) {
      final existing = byKey[book.matchKey];
      if (existing == null) {
        byKey[book.matchKey] = book;
        merged.add(book);
      } else {
        // Attach every new site offering to the first-seen card.
        final added = <SiteOffering>[
          ...existing.offerings,
          for (final offering in book.offerings)
            if (!existing.offerings.any(
              (o) => o.importUrl == offering.importUrl,
            ))
              offering,
        ];
        final index = merged.indexOf(existing);
        byKey[book.matchKey] = FederatedBook(
          matchKey: existing.matchKey,
          title: existing.title,
          author: existing.author,
          coverUrl: existing.coverUrl,
          description: existing.description,
          offerings: added,
        );
        merged[index] = byKey[book.matchKey]!;
      }
    }
    return merged;
  }

  int get sitesLoading =>
      sites.where((s) => s.state == SiteSearchState.loading).length;

  int get sitesFinished =>
      sites.where((s) => s.state == SiteSearchState.done).length;

  /// Sites that answered for this query (found something or legitimately
  /// nothing) — the "N of M sites searched" number on the summary line.
  int get sitesReached =>
      sites.where(
        (s) => s.state == SiteSearchState.done || s.state == SiteSearchState.empty,
      ).length;

  /// Sites the user may not get results from this round: failed requests
  /// and circuit-breaker-skipped ones alike. Counted as "couldn't be
  /// reached" — never surfaced as a technical error.
  int get sitesUnreachable =>
      sites.where(
        (s) => s.state == SiteSearchState.error || s.state == SiteSearchState.skipped,
      ).length;

  bool get allSitesFinished =>
      sites.isNotEmpty &&
      sites.every(
        (s) =>
            s.state == SiteSearchState.done ||
            s.state == SiteSearchState.empty ||
            s.state == SiteSearchState.error ||
            s.state == SiteSearchState.skipped,
      );

  int get resultTotalCount =>
      sites.fold(0, (sum, s) => sum + s.resultCount);

  FederatedSearchState copyWith({
    String? term,
    List<SiteSearchStatus>? sites,
    List<FederatedBook>? results,
  }) {
    return FederatedSearchState(
      term: term ?? this.term,
      sites: sites ?? this.sites,
      results: results ?? this.results,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FederatedSearchState &&
          term == other.term &&
          _listEquals(sites, other.sites) &&
          _listEquals(results, other.results);

  @override
  int get hashCode => Object.hash(
        term,
        Object.hashAll(sites),
        Object.hashAll(results),
      );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Conservative dedup key: a normalized title, merged across sites ONLY when
/// the normalized author matches too (or both have none). Near-miss titles
/// stay separate cards — showing a false merge is worse than a duplicate.
String federatedMatchKey(String title, String? author) {
  final normAuthor = (author ?? '').trim().toLowerCase();
  final collapsed = normAuthor.replaceAll(RegExp(r'\s+'), ' ');
  return '${BookIdNormalizer.normalize(title)}|'
      '${collapsed.isEmpty ? '-' : collapsed}';
}

/// Detects a URL typed or pasted into the single search field.
///
/// Conservative on purpose: anything containing whitespace, without a dot,
/// or unparseable is a search term, not a link. A scheme-less host gets
/// `https://` prepended — "example.com/novel/x" behaves like the full URL.
Uri? asImportLink(String input) {
  final t = input.trim();
  if (t.contains(' ') || !t.contains('.')) return null;
  final u = Uri.tryParse(t.startsWith('http') ? t : 'https://$t');
  return (u != null && u.host.contains('.')) ? u : null;
}

/// Ranking tier for a result card relative to the search [term]:
/// 0 exact title → 1 prefix → 2 contains → ≥3 token-overlap distance.
/// Multi-site books get a one-tier bonus (the merged card is the one the
/// user is most likely looking for).
int federatedRankScore(FederatedBook book, String term) {
  final t = term.trim().toLowerCase();
  final title = book.title.toLowerCase();
  int score;
  if (title == t) {
    score = 0;
  } else if (title.startsWith(t)) {
    score = 1;
  } else if (title.contains(t)) {
    score = 2;
  } else {
    final tokens = t.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toSet();
    final titleTokens =
        title.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toSet();
    final overlap = tokens.intersection(titleTokens).length;
    score = 3 + (tokens.isEmpty ? 0 : tokens.length - overlap).clamp(0, 10);
  }
  // Multi-site bonus: the same book confirmed across sites outranks a
  // near-name single-site book on the bottom tiers.
  if (book.isMultiSource) score -= 1;
  return score;
}

/// Orders the merged result set for display, honoring frozen slots.
///
/// [frozenKeys] are the matchKeys of the top cards from an earlier flush —
/// they keep their position so late site responses don't reorder cards
/// under the user's thumb. Frozen keys that are no longer present are
/// ignored; new cards are ranked strictly after the frozen block.
List<FederatedBook> rankFederatedResults(
  List<FederatedBook> current,
  List<String> frozenKeys,
  String term,
) {
  final byKey = {for (final book in current) book.matchKey: book};
  final frozen = <FederatedBook>[
    for (final key in frozenKeys) if (byKey.containsKey(key)) byKey.remove(key)!,
  ];
  final rest = byKey.values.toList()
    ..sort((a, b) {
      final byScore = federatedRankScore(a, term)
          .compareTo(federatedRankScore(b, term));
      if (byScore != 0) return byScore;
      // Multi-site first as tiebreak, then title.
      if (a.isMultiSource != b.isMultiSource) return a.isMultiSource ? -1 : 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
  return [...frozen, ...rest];
}
