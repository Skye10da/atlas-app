import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/content_acquisition/application/chapter_update_service.dart';
import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/molecules/app_empty_state.dart';
import 'package:atlas_app/core/design_system/molecules/app_error_state.dart';
import 'package:atlas_app/core/design_system/molecules/app_search_bar.dart';
import 'package:atlas_app/core/design_system/molecules/confirm_delete_dialog.dart';
import 'package:atlas_app/core/design_system/organisms/app_scaffold.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/import/file_open_providers.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/domain/entities/bookshelf_layout.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/library/presentation/widgets/book_detail_panel.dart';
import 'package:atlas_app/library/presentation/widgets/bookshelf_grid.dart';
import 'package:atlas_app/library/presentation/widgets/bookshelf_list.dart';
import 'package:atlas_app/library/presentation/widgets/bookshelf_scattered.dart';
import 'package:atlas_app/library/presentation/widgets/continue_reading_strip.dart';
import 'package:atlas_app/library/presentation/widgets/sort_dropdown.dart';
import 'package:atlas_app/library/presentation/widgets/sort_toolbar.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  bool _showSearchBar = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedBookIds = {};

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(librarySearchQueryProvider);
    if (initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
      _showSearchBar = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(libraryViewModelProvider);
    final libraryState = libraryAsync.valueOrNull ?? const LibraryState();
    final importActions = ref.watch(libraryImportProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppBreakpoints.tablet;
    final isBigDesktop = width >= AppBreakpoints.largeDesktop;
    final isTablet = width >= AppBreakpoints.mobile && !isDesktop;

    final cs = Theme.of(context).colorScheme;

    return AppScaffold(
      title: _isSelectionMode
          ? '${_selectedBookIds.length} Selected'
          : 'Library',
      actions: _isSelectionMode
          ? [
              IconButton(
                icon: Icon(
                  _selectedBookIds.length == libraryState.filteredBooks.length &&
                          libraryState.filteredBooks.isNotEmpty
                      ? Icons.deselect_rounded
                      : Icons.select_all_rounded,
                ),
                tooltip: _selectedBookIds.length ==
                            libraryState.filteredBooks.length &&
                        libraryState.filteredBooks.isNotEmpty
                    ? 'Deselect all'
                    : 'Select all',
                onPressed: () {
                  setState(() {
                    if (_selectedBookIds.length ==
                        libraryState.filteredBooks.length) {
                      _selectedBookIds.clear();
                    } else {
                      _selectedBookIds
                          .addAll(libraryState.filteredBooks.map((b) => b.id));
                    }
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: _selectedBookIds.isEmpty ? cs.onSurfaceVariant : cs.error,
                ),
                tooltip: 'Delete selected',
                onPressed:
                    _selectedBookIds.isEmpty ? null : () => _confirmDeleteSelected(),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel selection',
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedBookIds.clear();
                  });
                },
              ),
            ]
          : [
              if (importActions.isImporting)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        importActions.progress.message ?? 'Importing...',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                )
              else ...[
                IconButton(
                  icon: Icon(
                    _showSearchBar || libraryState.searchQuery.isNotEmpty
                        ? Icons.search_off_rounded
                        : Icons.search_rounded,
                  ),
                  tooltip:
                      _showSearchBar || libraryState.searchQuery.isNotEmpty
                          ? 'Close search'
                          : 'Search library',
                  onPressed: () {
                    setState(() {
                      if (_showSearchBar ||
                          libraryState.searchQuery.isNotEmpty) {
                        _showSearchBar = false;
                        _searchController.clear();
                        ref
                            .read(libraryViewModelProvider.notifier)
                            .setSearchQuery('');
                      } else {
                        _showSearchBar = true;
                      }
                    });
                  },
                ),
                if (libraryState.filteredBooks.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showAddSheet(),
                    tooltip: 'Add to library',
                  ),
              ],
              IconButton(
                icon: libraryState.isCheckingUpdates
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                tooltip: 'Check ongoing novels for updates',
                onPressed: libraryState.isCheckingUpdates
                    ? null
                    : () => _checkAllUpdates(),
              ),
            ],
      child: _buildContent(
        ref,
        libraryAsync,
        libraryState,
        importActions.isImporting,
        isDesktop,
        isBigDesktop,
        isTablet,
      ),
    );
  }

  Future<void> _checkAllUpdates() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(chapterUpdateServiceProvider);
      final result = await ref
          .read(libraryViewModelProvider.notifier)
          .checkUpdates(service);
      if (result == null) return;
      final message = result.booksWithUpdates == 0
          ? 'No new chapters found.'
          : 'Found ${result.totalNewChapters} new chapter(s) in '
                '${result.booksWithUpdates} novel(s).';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Update check failed: '
            '${ChapterUpdateService.describeFailure(e)}',
          ),
        ),
      );
    }
  }

  Widget _buildContent(
    WidgetRef ref,
    AsyncValue<LibraryState> libraryAsync,
    LibraryState state,
    bool isImporting,
    bool isDesktop,
    bool isBigDesktop,
    bool isTablet,
  ) {
    final showSearch = _showSearchBar || state.searchQuery.isNotEmpty;

    return Column(
      children: [
        if (showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: AppSearchBar(
              controller: _searchController,
              hint: 'Search library...',
              autofocus: _showSearchBar && state.searchQuery.isEmpty,
              onChanged: (q) =>
                  ref.read(libraryViewModelProvider.notifier).setSearchQuery(q),
            ),
          ),
        if (!isDesktop && !_isSelectionMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<LibraryCategory>(
                segments: const [
                  ButtonSegment(
                    value: LibraryCategory.novels,
                    label: Text('Novels'),
                    icon: Icon(Icons.auto_stories_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: LibraryCategory.books,
                    label: Text('Books'),
                    icon: Icon(Icons.menu_book_rounded, size: 16),
                  ),
                ],
                selected: {state.category},
                onSelectionChanged: (selected) {
                  ref
                      .read(libraryViewModelProvider.notifier)
                      .setCategory(selected.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
        if (state.category == LibraryCategory.novels &&
            state.availableGenres.isNotEmpty &&
            !_isSelectionMode)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: state.genreFilter == null,
                  onSelected: (_) => ref
                      .read(libraryViewModelProvider.notifier)
                      .setGenreFilter(null),
                ),
                const SizedBox(width: 8),
                ...state.availableGenres.map(
                  (tag) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(tag),
                      selected: state.genreFilter == tag,
                      onSelected: (selected) => ref
                          .read(libraryViewModelProvider.notifier)
                          .setGenreFilter(selected ? tag : null),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: libraryAsync.when(
            loading: () => const Center(child: AppLoading()),
            error: (error, _) => AppErrorState(
              message: 'Something went wrong.',
              technicalDetails: error.toString(),
              onRetry: () => ref.invalidate(libraryViewModelProvider),
            ),
            data: (state) => _BookshelfContent(
              books: state.filteredBooks,
              recentBooks: state.recentBooks,
              searchQuery: state.searchQuery,
              isDesktop: isDesktop,
              isBigDesktop: isBigDesktop,
              isTablet: isTablet,
              isSelectionMode: _isSelectionMode,
              selectedIds: _selectedBookIds,
              onBookTap: (id) {
                if (_isSelectionMode) {
                  setState(() {
                    if (_selectedBookIds.contains(id)) {
                      _selectedBookIds.remove(id);
                    } else {
                      _selectedBookIds.add(id);
                    }
                  });
                  return;
                }
                if (isDesktop) {
                  ref.read(libraryViewModelProvider.notifier).selectBook(id);
                } else {
                  final book = state.filteredBooks
                      .where((b) => b.id == id)
                      .firstOrNull;
                  if (book?.isNovel == true) {
                    context.push('/novel/$id');
                  } else {
                    context.push('/book/$id');
                  }
                }
              },
              onBookLongPress: (id, pos) {
                if (_isSelectionMode) {
                  setState(() {
                    if (_selectedBookIds.contains(id)) {
                      _selectedBookIds.remove(id);
                    } else {
                      _selectedBookIds.add(id);
                    }
                  });
                } else {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedBookIds.add(id);
                  });
                }
              },
              onLoadSamples: () => _loadSamples(),
              onImport: () => _showAddSheet(),
              onDeleteBook: (id) => _deleteBook(id),
              isImporting: isImporting,
              selectedBookId: isDesktop ? state.selectedBookId : null,
            ),
          ),
        ),
      ],
    );
  }

  void _loadSamples() {
    ref.read(librarySeedProvider.future).then((_) {
      ref.invalidate(libraryBooksProvider);
    });
  }

  void _showAddSheet() {
    final actions = ref.read(libraryImportProvider);
    actions.importLocal(context).then((result) {
      ref.invalidate(libraryBooksProvider);
      if (result is Success<ImportOutcome> && mounted) {
        if (result.value.bookId.startsWith('batch:')) {
          final count = result.value.bookId.split(':').last;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully imported $count books.')),
          );
        } else {
          final route = result.value.category == ContentCategory.novel
              ? '/novel/${result.value.bookId}'
              : '/book/${result.value.bookId}';
          context.push(route);
        }
      }
    });
  }

  Future<void> _deleteBook(String bookId) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete book?',
      message: 'This will permanently remove the book and all reading progress.',
      confirmLabel: 'Delete',
    );

    if (confirmed != true || !mounted) return;

    final actions = ref.read(libraryDeleteProvider);
    final result = await actions.delete(bookId);
    ref.invalidate(libraryBooksProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        result is Success
            ? const SnackBar(content: Text('Book deleted'))
            : SnackBar(content: Text((result as Failure).error.userMessage)),
      );
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final count = _selectedBookIds.length;
    if (count == 0) return;

    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete $count ${count == 1 ? 'book' : 'books'}?',
      message:
          'This will permanently remove $count ${count == 1 ? 'book' : 'books'} and all reading progress from your library.',
      confirmLabel: 'Delete $count ${count == 1 ? 'Book' : 'Books'}',
    );

    if (confirmed != true || !mounted) return;

    final idsToDelete = _selectedBookIds.toList();
    final actions = ref.read(libraryDeleteProvider);
    final result = await actions.deleteMultiple(idsToDelete);
    ref.invalidate(libraryBooksProvider);

    if (mounted) {
      setState(() {
        _isSelectionMode = false;
        _selectedBookIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        result is Success
            ? SnackBar(content: Text('Deleted $count books'))
            : SnackBar(content: Text((result as Failure).error.userMessage)),
      );
    }
  }
}

class _BookshelfContent extends ConsumerStatefulWidget {
  const _BookshelfContent({
    required this.books,
    required this.recentBooks,
    required this.isDesktop,
    required this.isBigDesktop,
    required this.isTablet,
    required this.onBookTap,
    required this.onBookLongPress,
    required this.onLoadSamples,
    required this.onImport,
    required this.onDeleteBook,
    this.searchQuery = '',
    this.isImporting = false,
    this.selectedBookId,
    this.isSelectionMode = false,
    this.selectedIds = const {},
  });

  final List<BookEntity> books;
  final List<BookEntity> recentBooks;
  final String searchQuery;
  final bool isTablet;
  final bool isDesktop;
  final bool isBigDesktop;
  final void Function(String id) onBookTap;
  final void Function(String id, Offset globalPosition) onBookLongPress;
  final VoidCallback onLoadSamples;
  final VoidCallback onImport;
  final void Function(String id) onDeleteBook;
  final bool isImporting;
  final String? selectedBookId;
  final bool isSelectionMode;
  final Set<String> selectedIds;

  @override
  ConsumerState<_BookshelfContent> createState() => _BookshelfContentState();
}

class _BookshelfContentState extends ConsumerState<_BookshelfContent> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final books = widget.books;
    final recentBooks = widget.recentBooks;
    final searchQuery = widget.searchQuery;
    final isTablet = widget.isTablet;
    final isDesktop = widget.isDesktop;
    final onBookTap = widget.onBookTap;
    final onBookLongPress = widget.onBookLongPress;
    final onLoadSamples = widget.onLoadSamples;
    final onImport = widget.onImport;
    final onDeleteBook = widget.onDeleteBook;
    final isImporting = widget.isImporting;
    final isSelectionMode = widget.isSelectionMode;
    final selectedIds = widget.selectedIds;
    final layout = ref.watch(bookshelfLayoutProvider);

    if (books.isEmpty) {
      if (searchQuery.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppEmptyState(
                title: 'No results found',
                message: 'No books match "$searchQuery".',
                icon: Icons.search_off_rounded,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  ref
                      .read(libraryViewModelProvider.notifier)
                      .setSearchQuery('');
                },
                icon: const Icon(Icons.clear_rounded, size: 18),
                label: const Text('Clear search'),
              ),
            ],
          ),
        );
      }

      return DropTarget(
        onDragDone: (details) => _handleFileDrop(details),
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppEmptyState(
                    title: 'Your bookshelf is empty',
                    message: 'Import a book or add a novel to start reading.',
                    icon: Icons.library_books,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: isImporting ? null : onImport,
                    icon: isImporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_upload),
                    label: Text(isImporting ? 'Importing...' : 'Import Book'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onLoadSamples,
                    child: const Text('Load Sample Books'),
                  ),
                ],
              ),
            ),
            if (_dragging) _buildDropOverlay(),
          ],
        ),
      );
    }

    return DropTarget(
      onDragDone: (details) => _handleFileDrop(details),
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    if (recentBooks.isNotEmpty && !isSelectionMode)
                      ContinueReadingStrip(
                        books: recentBooks,
                        onBookTap: onBookTap,
                      ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        isDesktop ? 0 : AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isSelectionMode
                                ? 'Select books'
                                : 'Bookshelf',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: [
                              if (isDesktop)
                                SortToolbar(
                                  currentOrder: ref.watch(librarySortProvider),
                                  onSort: (order) => ref
                                      .read(libraryViewModelProvider.notifier)
                                      .setSortOrder(order),
                                )
                              else
                                SortDropdown(
                                  currentOrder: ref.watch(librarySortProvider),
                                  onSort: (order) => ref
                                      .read(libraryViewModelProvider.notifier)
                                      .setSortOrder(order),
                                ),
                              IconButton(
                                icon: Icon(
                                  layout.icon,
                                  size: isDesktop ? 20 : 18,
                                ),
                                onPressed: () => cycleLayout(),
                                tooltip: 'Layout: ${layout.label}',
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    switch (layout) {
                      BookshelfLayout.grid => BookshelfGrid(
                        books: books,
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                        isSelectionMode: isSelectionMode,
                        selectedIds: selectedIds,
                        onBookTap: onBookTap,
                        onBookLongPress: onBookLongPress,
                        onDeleteBook: onDeleteBook,
                      ),
                      BookshelfLayout.list => BookshelfList(
                        books: books,
                        isSelectionMode: isSelectionMode,
                        selectedIds: selectedIds,
                        onBookTap: onBookTap,
                        onDeleteBook: onDeleteBook,
                      ),
                      BookshelfLayout.scattered => BookshelfScattered(
                        books: books,
                        isSelectionMode: isSelectionMode,
                        selectedIds: selectedIds,
                        onBookTap: onBookTap,
                        onDeleteBook: onDeleteBook,
                      ),
                    },
                  ],
                ),
              ),
              if (isDesktop && widget.selectedBookId != null && !isSelectionMode) ...[
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 400,
                  child: Material(
                    child: BookDetailPanel(
                      bookId: widget.selectedBookId!,
                      onClose: () => ref
                          .read(libraryViewModelProvider.notifier)
                          .selectBook(null),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_dragging) _buildDropOverlay(),
        ],
      ),
    );
  }

  Widget _buildDropOverlay() {
    final cs = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Container(
        color: cs.primaryContainer.withValues(alpha: 0.85),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_to_photos, size: 48, color: cs.onPrimaryContainer),
            const SizedBox(height: 12),
            Text(
              'Drop file(s) to import',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: cs.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFileDrop(DropDoneDetails details) async {
    setState(() => _dragging = false);
    if (details.files.isEmpty) return;

    final importer = ref.read(openedFileImportServiceProvider);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (details.files.length == 1) {
      final file = details.files.first;
      final bytes = await file.readAsBytes();
      final name = file.name;
      final result = await importer.importBytes(bytes.toList(), name);
      ref.invalidate(libraryBooksProvider);
      if (result is Success<ImportOutcome> && mounted) {
        final route = result.value.category == ContentCategory.novel
            ? '/novel/${result.value.bookId}'
            : '/book/${result.value.bookId}';
        unawaited(router.push(route));
      }
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text('Importing ${details.files.length} books...')),
    );

    int count = 0;
    for (final file in details.files) {
      final bytes = await file.readAsBytes();
      final name = file.name;
      final result = await importer.importBytes(bytes.toList(), name);
      if (result is Success<ImportOutcome>) {
        count++;
      }
    }
    ref.invalidate(libraryBooksProvider);

    if (mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('Successfully imported $count books.')),
      );
    }
  }

  void cycleLayout() {
    final current = ref.read(bookshelfLayoutProvider);
    const values = BookshelfLayout.values;
    final nextIndex = (current.index + 1) % values.length;
    ref.read(libraryViewModelProvider.notifier).setLayout(values[nextIndex]);
  }
}
