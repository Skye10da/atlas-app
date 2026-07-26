import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/molecules/app_empty_state.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/search/domain/entities/search_result_entity.dart';
import 'package:atlas_app/search/presentation/providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search books and chapters...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
              ),
            ),
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
            },
          ),
        ),
        Expanded(
          child: resultsAsync.when(
            loading: () => const AppLoading(),
            error: (error, _) => Center(child: Text('Search failed: $error')),
            data: (result) => switch (result) {
              Success(value: final results) => _SearchResults(
                  results: results,
                  onBookTap: (bookId) => context.push('/book/$bookId'),
                  onChapterTap: (bookId, chapterIndex) => context.push('/reader/$bookId?chapter=$chapterIndex'),
                ),
              Failure(error: final err) => Center(child: Text(err.message)),
            },
          ),
        ),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.onBookTap,
    required this.onChapterTap,
  });

  final List<SearchResultEntity> results;
  final void Function(String bookId) onBookTap;
  final void Function(String bookId, int chapterIndex) onChapterTap;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const AppEmptyState(
        title: 'No results found',
        message: 'Try a different search term.',
        icon: Icons.search_off,
      );
    }

    final books = results.where((r) => r.kind == SearchResultKind.book).toList();
    final chapters = results.where((r) => r.kind == SearchResultKind.chapter).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (books.isNotEmpty) ...[
          const _SectionHeader(title: 'Books'),
          ...books.map((r) => _BookResultTile(result: r, onTap: () => onBookTap(r.bookId))),
        ],
        if (chapters.isNotEmpty) ...[
          const _SectionHeader(title: 'Chapters'),
          ...chapters.map((r) => _ChapterResultTile(
            result: r,
            onTap: () => onChapterTap(r.bookId, r.chapterIndex ?? 0),
          )),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _BookResultTile extends StatelessWidget {
  const _BookResultTile({required this.result, required this.onTap});

  final SearchResultEntity result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: BookCover(coverPath: result.coverPath, width: 40, height: 56),
      title: Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: result.author != null ? Text(result.author!, maxLines: 1) : null,
      trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

class _ChapterResultTile extends StatelessWidget {
  const _ChapterResultTile({required this.result, required this.onTap});

  final SearchResultEntity result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: BookCover(coverPath: result.coverPath, width: 40, height: 56),
      title: Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(result.bookTitle, maxLines: 1),
      trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
