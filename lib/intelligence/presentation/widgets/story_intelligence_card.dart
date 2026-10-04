import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/intelligence/domain/entities/reader_position.dart';
import 'package:atlas_app/intelligence/presentation/chat/chat_screen.dart';
import 'package:atlas_app/intelligence/presentation/entity_browser/entity_browser_sheet.dart';
import 'package:atlas_app/intelligence/presentation/providers/intelligence_providers.dart';
import 'package:atlas_app/intelligence/presentation/read_through/read_through_selector_sheet.dart';
import 'package:atlas_app/intelligence/presentation/review_queue/review_queue_sheet.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';

/// Overview card placed on the Novel Details screen giving readers one-tap
/// access to Story Memory, Character Codex, Review Queue, and Zero-Spoiler Chat.
class StoryIntelligenceCard extends HookConsumerWidget {
  const StoryIntelligenceCard({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.currentChapter = 1,
  });

  final String bookId;
  final String bookTitle;
  final int currentChapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final lastReadAsync = ref.watch(lastReadChapterProvider(bookId));
    final activeChapter = lastReadAsync.valueOrNull != null
        ? (lastReadAsync.valueOrNull!.index + 1)
        : currentChapter;
    final activeRt = ref.watch(activeReadThroughProvider(bookId)).valueOrNull;
    final sessionName = activeRt?.name ?? 'Primary Read';
    final readThroughId = activeRt?.id ?? 'default';

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.5),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.borderRadiusSm),
                  ),
                  child: Icon(
                    Icons.psychology_rounded,
                    size: 20,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Story Intelligence',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Offline knowledge base & zero-spoiler chat',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.history_edu_rounded, size: 14),
                  label: Text(sessionName),
                  labelStyle: const TextStyle(fontSize: 11),
                  onPressed: () =>
                      ReadThroughSelectorSheet.show(context, bookId: bookId),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ref.watch(storyEntitiesStreamProvider(bookId)).when(
                  loading: () => Text(
                    'Loading story memory ($sessionName)...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  error: (_, _) => Text(
                    'Story memory offline',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  data: (entities) => Text(
                    entities.isEmpty
                        ? 'No entities extracted for "$sessionName" yet. Read chapters to populate memory.'
                        : '${entities.length} entities discovered in "$sessionName" across characters, factions & items.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          bookId: bookId,
                          readerPosition: ReaderPosition(
                            bookId: bookId,
                            currentChapter: activeChapter,
                            readThroughId: readThroughId,
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.forum_outlined, size: 16),
                  label: const Text('Ask Novel'),
                ),
                OutlinedButton.icon(
                  onPressed: () => EntityBrowserSheet.show(
                    context,
                    bookId: bookId,
                    readThroughId: readThroughId,
                  ),
                  icon: const Icon(Icons.menu_book_rounded, size: 16),
                  label: const Text('Codex'),
                ),
                OutlinedButton.icon(
                  onPressed: () => ReviewQueueSheet.show(
                    context,
                    bookId: bookId,
                    readThroughId: readThroughId,
                  ),
                  icon: const Icon(Icons.verified_outlined, size: 16),
                  label: const Text('Review Queue'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      ReadThroughSelectorSheet.show(context, bookId: bookId),
                  icon: const Icon(Icons.auto_stories_rounded, size: 16),
                  label: const Text('Sessions'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
