import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/search/domain/federated_search.dart';

/// One quiet summary line for the whole federated search — the user
/// never sees technical failure states:
///
/// * Searching: "Searching 12 sites… · 8 matches" + a thin progress bar.
/// * All reached: "12 sites searched · 31 matches".
/// * Some couldn't be reached: "10 of 12 sites searched · 31 matches" with
///   a Retry action that re-queries only the unreachable sites; expanding
///   reveals the per-site detail.
/// * Sites kept out by the circuit breaker, Cloudflare blocks and timeouts
///   are all counted as "couldn't be reached" — no verify prompts, no
///   error text.
class SearchSummaryLine extends StatelessWidget {
  const SearchSummaryLine({
    required this.statuses,
    required this.matchCount,
    required this.onRetry,
    super.key,
  });

  final List<SiteSearchStatus> statuses;
  final int matchCount;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = statuses.length;
    final reached = statuses
        .where(
          (s) =>
              s.state == SiteSearchState.done ||
              s.state == SiteSearchState.empty,
        )
        .length;
    final loading = statuses
        .where((s) => s.state == SiteSearchState.loading)
        .length;
    final unreachable = total - reached - loading;

    final progress = total == 0
        ? 1.0
        : (reached + (total - loading - unreachable)) / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _headLine(total, reached, unreachable, loading, matchCount),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (unreachable > 0 && loading == 0)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Retry'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // Thin progress bar — doubles as the determinate "how far along"
        // indicator while sites are still being searched.
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: loading == 0 ? 1.0 : progress.clamp(0.0, 1.0),
            minHeight: 2,
            backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        ),
        if (unreachable > 0 && loading == 0) ...[
          const SizedBox(height: AppSpacing.xs),
          _UnreachableDetail(unreachable: unreachable, statuses: statuses),
        ],
      ],
    );
  }

  String _headLine(
    int total,
    int reached,
    int unreachable,
    int loading,
    int matches,
  ) {
    final matchesLabel = '$matches ${matches == 1 ? 'match' : 'matches'}';
    if (total == 0) return 'No sites configured · $matchesLabel';
    if (loading > 0) {
      return 'Searching $loading of $total ${total == 1 ? 'site' : 'sites'}… · '
          '$matchesLabel';
    }
    if (unreachable > 0) {
      return '$reached of $total ${total == 1 ? 'site' : 'sites'} searched · '
          '$matchesLabel';
    }
    return '$total ${total == 1 ? 'site' : 'sites'} searched · $matchesLabel';
  }
}

/// The expandable per-site detail — collapsed by default, so a first-time
/// user never sees the internals unless they look for them.
class _UnreachableDetail extends StatelessWidget {
  const _UnreachableDetail({
    required this.unreachable,
    required this.statuses,
  });

  final List<SiteSearchStatus> statuses;
  final int unreachable;

  String _label(SiteSearchStatus status) => switch (status.state) {
        SiteSearchState.empty => 'No results',
        SiteSearchState.skipped => "Couldn't be reached",
        SiteSearchState.error => "Couldn't be reached",
        _ => status.state.name,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final detail = [
      for (final status in statuses)
        if (status.state == SiteSearchState.error ||
            status.state == SiteSearchState.skipped)
          status,
    ];

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      initiallyExpanded: false,
      iconColor: cs.outline,
      collapsedIconColor: cs.outline,
      title: Text(
        detail.length == 1
            ? "1 site couldn't be reached"
            : "${detail.length} sites couldn't be reached",
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
        ),
      ),
      children: [
        for (final status in detail)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                '${status.sourceName} — ${_label(status)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
