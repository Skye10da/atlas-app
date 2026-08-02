import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/atoms/app_section_header.dart';
import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/molecules/app_empty_state.dart';
import 'package:atlas_app/core/design_system/molecules/app_list_item.dart';
import 'package:atlas_app/core/design_system/molecules/app_search_bar.dart';
import 'package:atlas_app/core/design_system/organisms/app_scaffold.dart';
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
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider);

    return AppScaffold(
      title: 'Search',
      child: Column(
        children: [
          AppSearchBar(
            controller: _controller,
            autofocus: true,
            hint: 'Search books and chapters...',
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
            },
          ),
          Expanded(
            child: resultsAsync.when(
              loading: () => const AppLoading(),
              error: (error, _) => Center(child: Text('Search failed: $error')),
              data: (result) => switch (result) {
                Success(value: final results) => _SearchResults(
                    results: results,
                    onBookTap: (bookId, isNovel) => isNovel
                        ? context.push('/novel/$bookId')
                        : context.push('/book/$bookId'),
                    onChapterTap: (bookId, chapterId) => context.push(
                        chapterId != null
                            ? '/reader/$bookId?chapterId=$chapterId'
                            : '/reader/$bookId'),
                  ),
                Failure(error: final err) => Center(child: Text(err.message)),
              },
            ),
          ),
        ],
      ),
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
  final void Function(String bookId, bool isNovel) onBookTap;
  final void Function(String bookId, String? chapterId) onChapterTap;

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
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      children: [
        if (books.isNotEmpty) ...[
          const AppSectionHeader(title: 'Books'),
          ...books.map((r) => _BookResultTile(
            result: r,
            onTap: () => onBookTap(r.bookId, r.isNovel),
          )),
        ],
        if (chapters.isNotEmpty) ...[
          const AppSectionHeader(title: 'Chapters'),
          ...chapters.map((r) => _ChapterResultTile(
            result: r,
            onTap: () => onChapterTap(r.bookId, r.chapterId),
          )),
        ],
      ],
    );
  }
}

class _BookResultTile extends StatelessWidget {
  const _BookResultTile({required this.result, required this.onTap});

  final SearchResultEntity result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppListItem(
      leading: BookCover(coverPath: result.coverPath, width: 40, height: 56),
      title: result.title,
      subtitle: result.author,
      trailing: Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
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
    final colors = Theme.of(context).colorScheme;
    return AppListItem(
      leading: BookCover(coverPath: result.coverPath, width: 40, height: 56),
      title: result.title,
      subtitle: result.bookTitle,
      trailing: Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
