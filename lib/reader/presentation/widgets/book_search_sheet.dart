import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/atoms/book_badge.dart';
import 'package:atlas_app/core/design_system/molecules/app_search_bar.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/reader/application/book_search_service.dart';
import 'package:atlas_app/reader/domain/entities/book_search_result.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';

/// Full-text search modal bottom sheet for searching within the current book.
class BookSearchSheet extends HookConsumerWidget {
  const BookSearchSheet({
    super.key,
    required this.bookId,
    required this.onResultSelected,
  });

  final String bookId;
  final void Function(int chapterIndex, int charOffset) onResultSelected;

  static void show(
    BuildContext context, {
    required String bookId,
    required void Function(int chapterIndex, int charOffset) onResultSelected,
  }) {
    AppSheet.show(
      context: context,
      id: 'book_search_sheet',
      title: 'Search in Book',
      initialHeight: 0.75,
      snapPoints: const [0.5, 0.75, 0.95],
      child: BookSearchSheet(
        bookId: bookId,
        onResultSelected: onResultSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final debounceTimer = useRef<Timer?>(null);
    final isLoading = useState(false);
    final results = useState<List<BookSearchResult>>([]);
    final lastQuery = useState('');

    useEffect(() {
      return () => debounceTimer.value?.cancel();
    }, const []);

    Future<void> performSearch(String query) async {
      isLoading.value = true;
      lastQuery.value = query;

      final repo = ref.read(readerRepositoryProvider);
      final service = BookSearchService(repo);
      final result = await service.searchBook(bookId: bookId, query: query);

      if (!context.mounted) return;
      isLoading.value = false;
      if (result is Success<List<BookSearchResult>>) {
        results.value = result.value;
      } else {
        results.value = [];
      }
    }

    void onQueryChanged(String query) {
      debounceTimer.value?.cancel();
      final clean = query.trim();
      if (clean.isEmpty) {
        isLoading.value = false;
        results.value = [];
        lastQuery.value = '';
        return;
      }

      debounceTimer.value = Timer(
        const Duration(milliseconds: 300),
        () => performSearch(clean),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSearchBar(
            controller: controller,
            hint: 'Search book contents…',
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isLoading.value)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else if (lastQuery.value.isNotEmpty && results.value.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 40,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'No matches found for "${lastQuery.value}"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (results.value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs, left: 4),
              child: Text(
                '${results.value.length} results found',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: ListView.separated(
              itemCount: results.value.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = results.value[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  title: Row(
                    children: [
                      BookBadge(
                        label: 'Ch. ${item.chapterIndex + 1}',
                        isCompact: true,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          item.chapterTitle,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: RichText(
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                        children: _highlightSnippet(
                          snippet: item.snippet,
                          matchStart: item.matchStartInSnippet,
                          matchLength: lastQuery.value.length,
                          highlightColor: colorScheme.primaryContainer,
                          highlightTextColor: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onResultSelected(item.chapterIndex, item.charOffset);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _highlightSnippet({
    required String snippet,
    required int matchStart,
    required int matchLength,
    required Color highlightColor,
    required Color highlightTextColor,
  }) {
    if (matchStart < 0 || matchStart + matchLength > snippet.length) {
      return [TextSpan(text: snippet)];
    }

    final before = snippet.substring(0, matchStart);
    final match = snippet.substring(matchStart, matchStart + matchLength);
    final after = snippet.substring(matchStart + matchLength);

    return [
      TextSpan(text: before),
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          decoration: BoxDecoration(
            color: highlightColor,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            match,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: highlightTextColor,
              fontSize: 12,
            ),
          ),
        ),
      ),
      TextSpan(text: after),
    ];
  }
}
