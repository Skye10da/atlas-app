import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/search/presentation/providers/recent_searches_provider.dart';

/// Tappable rows of the last few queries, shown while the search field is
/// focused and empty — the same small bookmark/history list language as
/// the source list below. Nothing runs at startup: the store is only
/// consulted while these rows are actually on screen.
class RecentSearchesPanel extends ConsumerWidget {
  const RecentSearchesPanel({
    required this.onSelect,
    super.key,
  });

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (recentSearchesLimit <= 0) return const SizedBox.shrink();
    final recents = ref.watch(recentSearchesProvider);
    if (recents.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          'RECENT',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final term in recents)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
              onTap: () => onSelect(term),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.sm + 2,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        term,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Icon(
                      Icons.north_west_rounded,
                      size: 14,
                      color: cs.outline.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
