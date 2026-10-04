import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/intelligence/domain/entities/reader_position.dart';
import 'package:atlas_app/intelligence/presentation/chat/chat_screen.dart';
import 'package:atlas_app/intelligence/presentation/entity_browser/entity_browser_sheet.dart';
import 'package:atlas_app/intelligence/presentation/providers/intelligence_providers.dart';
import 'package:atlas_app/intelligence/presentation/read_through/read_through_selector_sheet.dart';
import 'package:atlas_app/intelligence/presentation/review_queue/review_queue_sheet.dart';
import 'package:atlas_app/intelligence/presentation/settings/ai_provider_settings_screen.dart';

/// Modal sheet opened from inside the Reader, bounded to the current chapter
/// to guarantee zero spoilers.
class ReaderIntelligenceSheet extends ConsumerWidget {
  const ReaderIntelligenceSheet({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.chapterIndex,
  });

  final String bookId;
  final String bookTitle;
  final int chapterIndex;

  static Future<void> show(
    BuildContext context, {
    required String bookId,
    required String bookTitle,
    required int chapterIndex,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.borderRadiusLg),
        ),
      ),
      builder: (_) => ReaderIntelligenceSheet(
        bookId: bookId,
        bookTitle: bookTitle,
        chapterIndex: chapterIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final activeRt = ref.watch(activeReadThroughProvider(bookId)).valueOrNull;
    final sessionName = activeRt?.name ?? 'Primary Read';
    final readThroughId = activeRt?.id ?? 'default';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.psychology_rounded, color: cs.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Story Intelligence',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Bounded to Ch. $chapterIndex • $sessionName • Zero Spoilers',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: Text(sessionName),
                  labelStyle: const TextStyle(fontSize: 11),
                  onPressed: () {
                    Navigator.of(context).pop();
                    ReadThroughSelectorSheet.show(context, bookId: bookId);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.xs),
            ListTile(
              leading: Icon(Icons.forum_outlined, color: cs.primary),
              title: const Text('Ask Novel (Chat)'),
              subtitle: const Text('Ask questions about the plot, characters, or recap safely.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      bookId: bookId,
                      readerPosition: ReaderPosition(
                        bookId: bookId,
                        currentChapter: chapterIndex,
                        readThroughId: readThroughId,
                      ),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.menu_book_rounded, color: cs.secondary),
              title: const Text('Character & Entity Codex'),
              subtitle: Text('Explore characters, factions, and items seen up to Chapter $chapterIndex.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.of(context).pop();
                EntityBrowserSheet.show(
                  context,
                  bookId: bookId,
                  readThroughId: readThroughId,
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.verified_outlined, color: cs.tertiary),
              title: const Text('Review Queue'),
              subtitle: const Text('Confirm or correct newly discovered entities and aliases.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.of(context).pop();
                ReviewQueueSheet.show(
                  context,
                  bookId: bookId,
                  readThroughId: readThroughId,
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.history_edu_rounded, color: cs.primary),
              title: Text('Reading Sessions ($sessionName)'),
              subtitle: const Text('Switch session or start a new spoiler-free read-through.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.of(context).pop();
                ReadThroughSelectorSheet.show(context, bookId: bookId);
              },
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined, color: cs.outline),
              title: const Text('AI & BYOK Provider Settings'),
              subtitle: const Text('Configure Ollama, llama.cpp, Gemini, OpenAI, or Claude.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AiProviderSettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
