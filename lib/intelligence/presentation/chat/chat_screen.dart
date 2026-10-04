import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/intelligence/domain/entities/reader_position.dart';
import 'package:atlas_app/intelligence/presentation/chat/chat_controller.dart';
import 'package:atlas_app/intelligence/presentation/entity_browser/entity_browser_sheet.dart';
import 'package:atlas_app/intelligence/presentation/review_queue/review_queue_sheet.dart';

import 'package:atlas_app/intelligence/presentation/providers/intelligence_providers.dart';
import 'package:atlas_app/intelligence/presentation/read_through/read_through_selector_sheet.dart';

class ChatScreen extends HookConsumerWidget {
  const ChatScreen({
    super.key,
    required this.bookId,
    required this.readerPosition,
    this.initialPrompt,
  });

  final String bookId;
  final ReaderPosition readerPosition;
  final String? initialPrompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatControllerProvider(bookId));
    final controller = ref.read(chatControllerProvider(bookId).notifier);
    final textController = useTextEditingController();
    final scrollController = useScrollController();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final activeRt = ref.watch(activeReadThroughProvider(bookId)).valueOrNull;
    final sessionName = activeRt?.name ?? 'Primary Read';

    void send(String text) {
      if (text.trim().isEmpty) return;
      controller.sendMessage(text: text, position: readerPosition);
      textController.clear();
    }

    useEffect(() {
      if (initialPrompt != null && initialPrompt!.trim().isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          send(initialPrompt!.trim());
        });
      }
      return null;
    }, const []);

    useEffect(() {
      if (state.messages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
      return null;
    }, [state.messages.length]);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Atlas Companion', style: TextStyle(fontSize: 16)),
            Text(
              'Bounded to Ch. ${readerPosition.currentChapter} • $sessionName • Zero Spoilers',
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_edu_outlined),
            tooltip: 'Reading Sessions ($sessionName)',
            onPressed: () =>
                ReadThroughSelectorSheet.show(context, bookId: bookId),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Entities & Codex',
            onPressed: () => EntityBrowserSheet.show(
              context,
              bookId: bookId,
              readThroughId: readerPosition.readThroughId,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.rate_review_outlined),
            tooltip: 'Review Queue',
            onPressed: () => ReviewQueueSheet.show(
              context,
              bookId: bookId,
              readThroughId: readerPosition.readThroughId,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Message list
          Expanded(
            child: state.messages.isEmpty
                ? _EmptyChatPlaceholder(
                    chapter: readerPosition.currentChapter,
                    onPromptTap: send,
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: state.messages.length + (state.isThinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.messages.length) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.sm),
                            child: AppLoading(),
                          ),
                        );
                      }
                      final msg = state.messages[index];
                      return _ChatMessageBubble(message: msg);
                    },
                  ),
          ),

          if (state.error != null)
            Container(
              color: colors.errorContainer,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: colors.onErrorContainer),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                top: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: send,
                      decoration: InputDecoration(
                        hintText: 'Ask about characters, places, plot…',
                        isDense: true,
                        filled: true,
                        fillColor: colors.surfaceContainerLow,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton.filled(
                    onPressed: () => send(textController.text),
                    icon: const Icon(Icons.arrow_upward, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatPlaceholder extends StatelessWidget {
  const _EmptyChatPlaceholder({
    required this.chapter,
    required this.onPromptTap,
  });

  final int chapter;
  final void Function(String prompt) onPromptTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final suggestions = [
      'Catch me up to chapter $chapter',
      'Who is the main protagonist?',
      'What are the active factions?',
      'What happened in the last chapter?',
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 48,
              color: colors.primary.withValues(alpha: 0.8),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Atlas Intelligence',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '100% offline story codex and contextual AI assistant.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              alignment: WrapAlignment.center,
              children: suggestions.map((prompt) {
                return ActionChip(
                  label: Text(prompt),
                  onPressed: () => onPromptTap(prompt),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isUser ? colors.primary : colors.surfaceContainerLow,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.4),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    message.source == 'offline_memory'
                        ? Icons.offline_bolt_outlined
                        : Icons.cloud_outlined,
                    size: 13,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    message.source == 'offline_memory'
                        ? 'Offline Memory'
                        : 'AI Orchestrator',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              message.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isUser ? colors.onPrimary : colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

