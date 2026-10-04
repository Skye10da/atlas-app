import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:atlas_app/core/design_system/atoms/app_chip.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/molecules/app_search_bar.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/intelligence/domain/entities/confidence.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/presentation/providers/intelligence_providers.dart';

import 'package:atlas_app/intelligence/presentation/read_through/read_through_selector_sheet.dart';

class EntityBrowserSheet extends HookConsumerWidget {
  const EntityBrowserSheet({
    super.key,
    required this.bookId,
    this.readThroughId,
  });

  final String bookId;
  final String? readThroughId;

  static void show(
    BuildContext context, {
    required String bookId,
    String? readThroughId,
  }) {
    AppSheet.show(
      context: context,
      id: 'entity_browser_$bookId',
      title: 'Story Entities & Codex',
      initialHeight: 0.80,
      child: EntityBrowserSheet(bookId: bookId, readThroughId: readThroughId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedEntity = useState<StoryEntity?>(null);
    final selectedType = useState<StoryEntityType?>(null);
    final searchQuery = useState<String>('');

    if (selectedEntity.value != null) {
      return _EntityDetailView(
        bookId: bookId,
        entity: selectedEntity.value!,
        onBack: () => selectedEntity.value = null,
      );
    }

    final activeRt = ref.watch(activeReadThroughProvider(bookId)).valueOrNull;
    final sessionName = activeRt?.name ?? 'Primary Read';
    final effectiveRtId = readThroughId ?? activeRt?.id ?? 'default';

    final entitiesAsync = ref.watch(
      scopedStoryEntitiesStreamProvider(
        (bookId: bookId, readThroughId: effectiveRtId),
      ),
    );
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return entitiesAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: AppLoading(),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text('Failed to load entities: $e'),
        ),
      ),
      data: (allEntities) {
        final query = searchQuery.value.trim().toLowerCase();
        final filtered = allEntities.where((e) {
          if (selectedType.value != null && e.type != selectedType.value) {
            return false;
          }
          if (query.isNotEmpty) {
            final matchesName = e.canonicalName.toLowerCase().contains(query);
            final matchesAlias = e.aliases.any((a) => a.toLowerCase().contains(query));
            if (!matchesName && !matchesAlias) return false;
          }
          return true;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppSearchBar(
                      hint: 'Search characters, factions, places…',
                      onChanged: (val) => searchQuery.value = val,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ActionChip(
                    avatar: const Icon(Icons.history_edu_rounded, size: 14),
                    label: Text(sessionName),
                    labelStyle: const TextStyle(fontSize: 11),
                    onPressed: () =>
                        ReadThroughSelectorSheet.show(context, bookId: bookId),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  AppChip(
                    label: 'All',
                    selected: selectedType.value == null,
                    onPressed: () => selectedType.value = null,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ...StoryEntityType.values.where((t) => t != StoryEntityType.blockCard).map((type) {
                    final isSelected = selectedType.value == type;
                    final label = switch (type) {
                      StoryEntityType.character => 'Characters',
                      StoryEntityType.faction => 'Factions',
                      StoryEntityType.location => 'Locations',
                      StoryEntityType.item => 'Items',
                      StoryEntityType.blockCard => 'BlockCards',
                    };
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: AppChip(
                        label: label,
                        selected: isSelected,
                        onPressed: () =>
                            selectedType.value = isSelected ? null : type,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          query.isEmpty
                              ? 'No entities discovered yet.'
                              : 'No entities match "$query".',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final entity = filtered[index];
                        return _EntityListTile(
                          entity: entity,
                          onTap: () => selectedEntity.value = entity,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _EntityListTile extends StatelessWidget {
  const _EntityListTile({
    required this.entity,
    required this.onTap,
  });

  final StoryEntity entity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final typeIcon = switch (entity.type) {
      StoryEntityType.character => Icons.person_outline,
      StoryEntityType.faction => Icons.shield_outlined,
      StoryEntityType.location => Icons.place_outlined,
      StoryEntityType.item => Icons.auto_awesome_outlined,
      StoryEntityType.blockCard => Icons.article_outlined,
    };

    final tierColor = entity.userConfirmed
        ? Colors.purple
        : switch (entity.tier) {
            ConfidenceTier.high => Colors.green,
            ConfidenceTier.medium => Colors.blue,
            ConfidenceTier.low => Colors.orange,
          };

    final tierText = entity.userConfirmed
        ? 'VERIFIED'
        : entity.tier.name.toUpperCase();

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(typeIcon, size: 20, color: colors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entity.canonicalName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entity.userConfirmed) ...[
                          const SizedBox(width: AppSpacing.micro),
                          Icon(Icons.verified, size: 14, color: colors.primary),
                        ],
                      ],
                    ),
                    if (entity.aliases.isNotEmpty)
                      Text(
                        'aka: ${entity.aliases.join(", ")}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tierText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: tierColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entity.mentionCount} mentions',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.micro),
              Icon(Icons.chevron_right, size: 18, color: colors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntityDetailView extends ConsumerWidget {
  const _EntityDetailView({
    required this.bookId,
    required this.entity,
    required this.onBack,
  });

  final String bookId;
  final StoryEntity entity;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final relationshipsAsync = ref.watch(
      storyRelationshipsProvider((bookId: bookId, entityId: entity.id)),
    );
    final eventsAsync = ref.watch(
      storyEventsProvider((bookId: bookId, entityId: entity.id, maxChapter: null)),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  entity.canonicalName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Metadata card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Type: ${entity.type.name.toUpperCase()}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Chapters: ${entity.firstSeenChapter}–${entity.lastSeenChapter}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Confidence: ${(entity.confidenceScore * 100).toInt()}% (${entity.tier.name})',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (entity.aliases.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Known Aliases: ${entity.aliases.join(", ")}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Relationships section
              Text(
                'Relationships',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              relationshipsAsync.when(
                loading: () => const AppLoading(),
                error: (e, _) => Text('Error loading relationships: $e'),
                data: (relations) {
                  if (relations.isEmpty) {
                    return Text(
                      'No relationships recorded yet.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    );
                  }
                  return Column(
                    children: relations.map((r) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.people_outline, size: 20),
                        title: Text(r.relationType),
                        subtitle: Text('Recorded in Chapter ${r.chapterEstablished}'),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Events timeline section
              Text(
                'Timeline & Appearances',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              eventsAsync.when(
                loading: () => const AppLoading(),
                error: (e, _) => Text('Error loading events: $e'),
                data: (events) {
                  if (events.isEmpty) {
                    return Text(
                      'No key events logged for this entity yet.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    );
                  }
                  return Column(
                    children: events.map((ev) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: colors.primaryContainer,
                          child: Text(
                            '${ev.chapter}',
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Text(ev.summary),
                        subtitle: Text('Chapter ${ev.chapter}'),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

