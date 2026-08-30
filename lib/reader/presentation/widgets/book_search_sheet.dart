import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/atoms/book_badge.dart';
import 'package:atlas_app/core/design_system/molecules/app_search_bar.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/reader/application/book_search_service.dart';
import 'package:atlas_app/reader/domain/entities/book_search_result.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';

/// Full-text search modal bottom sheet for searching within the current book.
class BookSearchSheet extends ConsumerStatefulWidget {
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
  ConsumerState<BookSearchSheet> createState() => _BookSearchSheetState();
}

class _BookSearchSheetState extends ConsumerState<BookSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;
  bool _isLoading = false;
  List<BookSearchResult> _results = [];
  String _lastQuery = '';

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _isLoading = false;
        _results = [];
        _lastQuery = '';
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () => _performSearch(clean));
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _lastQuery = query;
    });

    final repo = ref.read(readerRepositoryProvider);
    final service = BookSearchService(repo);
    final result = await service.searchBook(bookId: widget.bookId, query: query);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result is Success<List<BookSearchResult>>) {
        _results = result.value;
      } else {
        _results = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: AppSearchBar(
            controller: _controller,
            hint: 'Search word or phrase...',
            autofocus: true,
            onChanged: _onQueryChanged,
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_lastQuery.isNotEmpty && _results.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No matches found for "$_lastQuery"',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_results.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_results.length} results found',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _results[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  title: Row(
                    children: [
                      BookBadge(label: 'Ch. ${item.chapterIndex + 1}'),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          item.chapterTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: _buildHighlightedSnippet(context, item),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onResultSelected(item.chapterIndex, item.charOffset);
                  },
                );
              },
            ),
          ),
        ] else
          Expanded(
            child: Center(
              child: Text(
                'Type a keyword to search this book',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHighlightedSnippet(BuildContext context, BookSearchResult result) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final snippet = result.snippet;
    final start = result.matchStartInSnippet;
    final length = result.matchLength;
    final end = (start + length).clamp(0, snippet.length);

    if (start < 0 || start >= snippet.length) {
      return Text(snippet, style: theme.textTheme.bodySmall);
    }

    final before = snippet.substring(0, start);
    final match = snippet.substring(start, end);
    final after = snippet.substring(end);

    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.25),
              color: colorScheme.primary,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}
