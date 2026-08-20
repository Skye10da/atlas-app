import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/molecules/app_empty_state.dart';
import 'package:atlas_app/core/design_system/molecules/app_error_state.dart';
import 'package:atlas_app/core/design_system/organisms/app_scaffold.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/design_system/widgets/app_context_menu.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredBooks = ref.watch(filteredLibraryProvider);
    final importActions = ref.watch(libraryImportProvider);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final isBigDesktop = width >= 1200;
    final isTablet = width >= 600 && !isDesktop;

    final recentlyRead = [...filteredBooks]
      ..sort(
        (a, b) => switch ((a.lastOpenedAt, b.lastOpenedAt)) {
          (null, null) => 0,
          (null, _) => 1,
          (_, null) => -1,
          (final aDate?, final bDate?) => bDate.compareTo(aDate),
        },
      );
    final recentBooks = recentlyRead.take(3).toList();

    return AppScaffold(
      title: 'Library',
      actions: [
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
                    color: Theme.of(context).colorScheme.primary,
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
        else
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddSheet(),
            tooltip: 'Add to library',
          ),
      ],
      child: _buildContent(
        ref,
        filteredBooks,
        recentBooks,
        importActions.isImporting,
        isDesktop,
        isBigDesktop,
        isTablet,
      ),
    );
  }

  Widget _buildContent(
    WidgetRef ref,
    List<BookEntity> filteredBooks,
    List<BookEntity> recentBooks,
    bool isImporting,
    bool isDesktop,
    bool isBigDesktop,
    bool isTablet,
  ) {
    final booksAsync = ref.watch(libraryBooksProvider);
    final selectedBookId = ref.watch(selectedBookIdProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Filter books...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: ref.watch(librarySearchQueryProvider).isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(librarySearchQueryProvider.notifier).state =
                            '';
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (v) =>
                ref.read(librarySearchQueryProvider.notifier).state = v,
          ),
        ),
        if (!isBigDesktop) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<LibraryCategory>(
                segments: const [
                  ButtonSegment(
                    value: LibraryCategory.books,
                    label: Text('Books'),
                  ),
                  ButtonSegment(
                    value: LibraryCategory.novels,
                    label: Text('Novels'),
                  ),
                ],
                selected: {ref.watch(libraryCategoryProvider)},
                onSelectionChanged: (selected) {
                  ref.read(libraryCategoryProvider.notifier).state =
                      selected.first;
                  ref.read(libraryGenreFilterProvider.notifier).state = null;
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
          if (ref.watch(libraryGenreFilterProvider) case final genre?)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
              child: Row(
                children: [
                  Chip(
                    label: Text(genre, style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () =>
                        ref.read(libraryGenreFilterProvider.notifier).state =
                            null,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
        ],
        Expanded(
          child: booksAsync.when(
            loading: () => const AppLoading(),
            error: (error, _) => AppErrorState(
              message: 'Something went wrong.',
              technicalDetails: error.toString(),
              onRetry: () => ref.invalidate(libraryBooksProvider),
            ),
            data: (result) {
              return switch (result) {
                Success(value: _) => _BookshelfContent(
                  books: filteredBooks,
                  recentBooks: recentBooks,
                  isDesktop: isDesktop,
                  isBigDesktop: isBigDesktop,
                  isTablet: isTablet,
                  onBookTap: (id) {
                    if (isDesktop) {
                      final current = ref.read(selectedBookIdProvider);
                      ref.read(selectedBookIdProvider.notifier).state =
                          current == id ? null : id;
                    } else {
                      final book = filteredBooks
                          .where((b) => b.id == id)
                          .firstOrNull;
                      if (book?.isNovel == true) {
                        context.push('/novel/$id');
                      } else {
                        context.push('/book/$id');
                      }
                    }
                  },
                  onBookLongPress: (id, pos) => _showBookContextMenu(id, pos),
                  onLoadSamples: () => _loadSamples(),
                  onImport: () => _showAddSheet(),
                  onDeleteBook: (id) => _deleteBook(id),
                  isImporting: isImporting,
                  selectedBookId: isDesktop ? selectedBookId : null,
                ),
                Failure(error: final err) => AppErrorState(
                  message: err.userMessage,
                  technicalDetails: err.message,
                  onRetry: () => ref.invalidate(libraryBooksProvider),
                ),
              };
            },
          ),
        ),
      ],
    );
  }

  void _showBookContextMenu(String bookId, Offset globalPosition) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          GestureDetector(
            onTap: () => entry.remove(),
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
          Material(
            type: MaterialType.transparency,
            child: AppContextMenu(
              anchor: globalPosition,
              quickActions: [
                AppContextMenuAction(
                  label: 'Continue',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => context.push('/reader/$bookId'),
                ),
                AppContextMenuAction(
                  label: 'Details',
                  icon: Icons.info_outline_rounded,
                  onPressed: () {
                    final books = ref.read(filteredLibraryProvider);
                    final book = books.where((b) => b.id == bookId).firstOrNull;
                    if (book?.isNovel == true) {
                      context.push('/novel/$bookId');
                    } else {
                      context.push('/book/$bookId');
                    }
                  },
                ),
              ],
              listActions: [
                AppContextMenuAction(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  onPressed: () => _deleteBook(bookId),
                  destructive: true,
                ),
              ],
              onDismiss: () => entry.remove(),
            ),
          ),
        ],
      ),
    );
    overlay.insert(entry);
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
        final route = result.value.category == ContentCategory.novel
            ? '/novel/${result.value.bookId}'
            : '/book/${result.value.bookId}';
        context.push(route);
      }
    });
  }

  Future<void> _deleteBook(String bookId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete book?'),
        content: const Text(
          'This will permanently remove the book and all reading progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
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
}

class _BookshelfContent extends ConsumerStatefulWidget {
  const _BookshelfContent({
    required this.books,
    required this.recentBooks,
    required this.isTablet,
    required this.isDesktop,
    required this.isBigDesktop,
    required this.onBookTap,
    required this.onBookLongPress,
    required this.onLoadSamples,
    required this.onImport,
    required this.onDeleteBook,
    this.isImporting = false,
    this.selectedBookId,
  });

  final List<BookEntity> books;
  final List<BookEntity> recentBooks;
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

  @override
  ConsumerState<_BookshelfContent> createState() => _BookshelfContentState();
}

class _BookshelfContentState extends ConsumerState<_BookshelfContent> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final books = widget.books;
    final recentBooks = widget.recentBooks;
    final isTablet = widget.isTablet;
    final isDesktop = widget.isDesktop;
    final onBookTap = widget.onBookTap;
    final onBookLongPress = widget.onBookLongPress;
    final onLoadSamples = widget.onLoadSamples;
    final onImport = widget.onImport;
    final onDeleteBook = widget.onDeleteBook;
    final isImporting = widget.isImporting;
    final layout = ref.watch(bookshelfLayoutProvider);

    if (books.isEmpty) {
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
                    if (recentBooks.isNotEmpty)
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
                            'Bookshelf',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: [
                              if (isDesktop)
                                SortToolbar(
                                  currentOrder: ref.watch(librarySortProvider),
                                  onSort: (order) =>
                                      ref
                                              .read(
                                                librarySortProvider.notifier,
                                              )
                                              .state =
                                          order,
                                )
                              else
                                SortDropdown(
                                  currentOrder: ref.watch(librarySortProvider),
                                  onSort: (order) =>
                                      ref
                                              .read(
                                                librarySortProvider.notifier,
                                              )
                                              .state =
                                          order,
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
                        onBookTap: onBookTap,
                        onBookLongPress: onBookLongPress,
                        onDeleteBook: onDeleteBook,
                      ),
                      BookshelfLayout.list => BookshelfList(
                        books: books,
                        onBookTap: onBookTap,
                        onDeleteBook: onDeleteBook,
                      ),
                      BookshelfLayout.scattered => BookshelfScattered(
                        books: books,
                        onBookTap: onBookTap,
                        onDeleteBook: onDeleteBook,
                      ),
                    },
                  ],
                ),
              ),
              if (isDesktop && widget.selectedBookId != null) ...[
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 400,
                  child: Material(
                    child: BookDetailPanel(
                      bookId: widget.selectedBookId!,
                      onClose: () =>
                          ref.read(selectedBookIdProvider.notifier).state =
                              null,
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
              'Drop file to import',
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
    final importer = ref.read(openedFileImportServiceProvider);
    final router = GoRouter.of(context);
    for (final file in details.files) {
      final bytes = await file.readAsBytes();
      final name = file.name;
      final result = await importer.importBytes(bytes.toList(), name);
      ref.invalidate(libraryBooksProvider);
      if (result is! Success<ImportOutcome> || !mounted) continue;
      final route = result.value.category == ContentCategory.novel
          ? '/novel/${result.value.bookId}'
          : '/book/${result.value.bookId}';
      unawaited(router.push(route));
    }
  }

  void cycleLayout() {
    final current = ref.read(bookshelfLayoutProvider);
    const values = BookshelfLayout.values;
    final nextIndex = (current.index + 1) % values.length;
    ref.read(bookshelfLayoutProvider.notifier).state = values[nextIndex];
  }
}
