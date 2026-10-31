import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/presentation/entity_browser/entity_browser_sheet.dart';
import 'package:atlas_app/intelligence/presentation/providers/intelligence_providers.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';

/// Main characters from Story Memory, limited to those first seen at or
/// before the reader's current chapter (never reveals unread characters).
///
/// [scroll] lays them out as one horizontally scrolling row (phone);
/// otherwise they wrap into a grid showing up to [maxVisible].
class StoryCharactersSection extends ConsumerWidget {
  const StoryCharactersSection({
    super.key,
    required this.bookId,
    this.scroll = false,
    this.maxVisible = 8,
  });

  final String bookId;
  final bool scroll;
  final int maxVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final active =
        (ref.watch(lastReadChapterProvider(bookId)).valueOrNull?.index ?? 0) +
        1;
    final readThroughId =
        ref.watch(activeReadThroughProvider(bookId)).valueOrNull?.id ??
        'default';

    return ref
        .watch(storyEntitiesStreamProvider(bookId))
        .maybeWhen(
          data: (entities) {
            final characters =
                entities
                    .where(
                      (e) =>
                          e.type == StoryEntityType.character &&
                          e.firstSeenChapter <= active,
                    )
                    .toList()
                  ..sort((a, b) => b.mentionCount.compareTo(a.mentionCount));
            if (characters.isEmpty) return const SizedBox.shrink();

            void openCodex() => EntityBrowserSheet.show(
              context,
              bookId: bookId,
              readThroughId: readThroughId,
            );

            final header = Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Text(
                    'Characters',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: 'Fraunces',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: openCodex,
                    child: Text('See all ${characters.length}'),
                  ),
                ],
              ),
            );

            final shown = characters.take(scroll ? 12 : maxVisible).toList();

            final avatars = scroll
                ? SizedBox(
                    height: 104,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (_, i) =>
                          _CharacterAvatar(entity: shown[i], onTap: openCodex),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (final e in shown)
                          _CharacterAvatar(entity: e, onTap: openCodex),
                      ],
                    ),
                  );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                header,
                const SizedBox(height: AppSpacing.sm),
                avatars,
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }
}

class _CharacterAvatar extends StatelessWidget {
  const _CharacterAvatar({required this.entity, required this.onTap});

  final StoryEntity entity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = entity.canonicalName;
    // Stable colour per name (String.hashCode is not stable across runs).
    final seed = name.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    final color = HSLColor.fromAHSL(1, (seed % 360).toDouble(), 0.38, 0.36)
        .toColor();
    final role =
        (entity.attributes['role'] ?? entity.attributes['title'])?.toString();

    return Semantics(
      button: true,
      label: name,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 74,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color,
                child: Text(
                  name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 21,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                role != null && role.isNotEmpty
                    ? role
                    : 'Ch. ${entity.firstSeenChapter}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
