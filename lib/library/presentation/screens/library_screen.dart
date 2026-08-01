import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/molecules/app_empty_state.dart';
import 'package:atlas_app/core/design_system/molecules/app_error_state.dart';
import 'package:atlas_app/core/design_system/organisms/app_scaffold.dart';
import 'package:atlas_app/core/design_system/organisms/draggable_bottom_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/design_system/widgets/app_context_menu.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/domain/entities/bookshelf_layout.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/library/presentation/widgets/book_card.dart';

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
    final booksAsync = ref.watch(libraryBooksProvider);
    final filteredBooks = ref.watch(filteredLibraryProvider);
    final importActions = ref.watch(libraryImportProvider);
    final layout = ref.watch(bookshelfLayoutProvider);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final isTablet = width >= 600 && !isDesktop;

    final recentBooks = filteredBooks.take(3).toList();

    return AppScaffold(
      title: 'Library',
      actions: [
        IconButton(
          icon: const Icon(Icons.sort),
          onPressed: () => _showSortMenu(),
          tooltip: 'Sort',
        ),
        IconButton(
          icon: Icon(layout.icon),
          onPressed: () => _cycleLayout(),
          tooltip: 'Layout: ${layout.label}',
        ),
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
        else ...[
          IconButton(
            icon: const Icon(Icons.explore),
            onPressed: () => context.push('/sources'),
            tooltip: 'Browse',
          ),
          IconButton(
            icon: const Icon(Icons.auto_stories),
            onPressed: () => _importNovel(),
            tooltip: 'Add Novel',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import Book',
            onSelected: (value) {
              if (value == 'file') {
                _importBook();
              } else if (value == 'link') {
                _importBookFromUrl();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'file',
                child: Text('From device (.epub)'),
              ),
              PopupMenuItem(
                value: 'link',
                child: Text('From link'),
              ),
            ],
          ),
        ],
      ],
      child: Column(
        children: [
          if (isDesktop)
            _SortToolbar(
              currentOrder: ref.watch(librarySortProvider),
              onSort: (order) => ref.read(librarySortProvider.notifier).state = order,
            ),
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
                          ref.read(librarySearchQueryProvider.notifier).state = '';
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<LibraryCategory>(
                segments: const [
                  ButtonSegment(value: LibraryCategory.books, label: Text('Books')),
                  ButtonSegment(value: LibraryCategory.novels, label: Text('Novels')),
                ],
                selected: {ref.watch(libraryCategoryProvider)},
                onSelectionChanged: (selected) {
                  ref.read(libraryCategoryProvider.notifier).state = selected.first;
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
                    onDeleted: () => ref.read(libraryGenreFilterProvider.notifier).state = null,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
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
                      layout: layout,
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                      onBookTap: (id) {
                        final book = filteredBooks.where((b) => b.id == id).firstOrNull;
                        if (book?.isNovel == true) {
                          context.push('/novel/$id');
                        } else {
                          context.push('/book/$id');
                        }
                      },
                      onBookLongPress: (id, pos) => _showBookContextMenu(id, pos),
                      onLoadSamples: () => _loadSamples(),
                      onImport: () => _importBook(),
                      onAddNovel: () => _importNovel(),
                      onDeleteBook: (id) => _deleteBook(id),
                      isImporting: importActions.isImporting,
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
      ),
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

  void _cycleLayout() {
    final current = ref.read(bookshelfLayoutProvider);
    const values = BookshelfLayout.values;
    final nextIndex = (current.index + 1) % values.length;
    ref.read(bookshelfLayoutProvider.notifier).state = values[nextIndex];
  }

  void _showSortMenu() {
    final current = ref.read(librarySortProvider);
    DraggableBottomSheet.show(
      context: context,
      id: 'library_sort',
      initialHeight: 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...LibrarySortOrder.values.map((order) {
            final label = switch (order) {
              LibrarySortOrder.titleAsc => 'Title A-Z',
              LibrarySortOrder.titleDesc => 'Title Z-A',
              LibrarySortOrder.author => 'Author',
              LibrarySortOrder.recentlyAdded => 'Recently Added',
              LibrarySortOrder.recentlyRead => 'Recently Read',
            };
            return ListTile(
              leading: Icon(
                order == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: order == current ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(label),
              trailing: order == current
                  ? Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                ref.read(librarySortProvider.notifier).state = order;
                Navigator.of(context).pop();
              },
            );
          }),
        ],
      ),
    );
  }

  void _loadSamples() {
    ref.read(librarySeedProvider.future).then((_) {
      ref.invalidate(libraryBooksProvider);
    });
  }

  Future<void> _importFromUrl({
    String title = 'Import from URL',
    String labelText = 'Book URL',
    String hintText = 'https://example.com/book.epub',
    String buttonLabel = 'Import',
  }) async {
    final actions = ref.read(libraryImportProvider);
    final result = await actions.importUrl(
      context,
      title: title,
      labelText: labelText,
      hintText: hintText,
      buttonLabel: buttonLabel,
    );
    ref.invalidate(libraryBooksProvider);

    if (result is Success<ImportOutcome> && mounted) {
      final route = result.value.category == ContentCategory.novel
          ? '/novel/${result.value.bookId}'
          : '/book/${result.value.bookId}';
      await context.push(route);
    } else if (result is Failure<ImportOutcome> && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error.userMessage)),
      );
    }
  }

  Future<void> _importBookFromUrl() {
    return _importFromUrl(
      title: 'Import book from link',
      labelText: 'Book link',
      hintText: 'https://example.com/book.epub',
      buttonLabel: 'Import',
    );
  }

  Future<void> _importNovel() {
    return _importFromUrl(
      title: 'Add novel from link',
      labelText: 'Novel link',
      hintText: 'https://www.mvlempyr.io/novel/...',
      buttonLabel: 'Add',
    );
  }

  Future<void> _importBook() async {
    final actions = ref.read(libraryImportProvider);
    final result = await actions.import();
    ref.invalidate(libraryBooksProvider);

    if (result is Failure && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error.userMessage)),
      );
    }
  }

  Future<void> _deleteBook(String bookId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete book?'),
        content: const Text('This will permanently remove the book and all reading progress.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
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

class _SortToolbar extends StatelessWidget {
  const _SortToolbar({
    required this.currentOrder,
    required this.onSort,
  });

  final LibrarySortOrder currentOrder;
  final void Function(LibrarySortOrder) onSort;

  @override
  Widget build(BuildContext context) {
    final options = [
      (LibrarySortOrder.recentlyRead, 'Recent'),
      (LibrarySortOrder.titleAsc, 'Title'),
      (LibrarySortOrder.author, 'Author'),
      (LibrarySortOrder.recentlyAdded, 'Added'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          ...options.map((o) {
            final selected = o.$1 == currentOrder;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(o.$2, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (_) => onSort(o.$1),
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ContinueReadingStrip extends StatelessWidget {
  const _ContinueReadingStrip({
    required this.books,
    required this.onBookTap,
  });

  final List<BookEntity> books;
  final void Function(String id) onBookTap;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(Icons.trending_up, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text('Continue Reading',
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: books.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final book = books[index];
              return _ContinueReadingCard(
                book: book,
                onTap: () => onBookTap(book.id),
              );
            },
          ),
        ),
        const Divider(indent: 16, endIndent: 16),
      ],
    );
  }
}

class _ContinueReadingCard extends StatefulWidget {
  const _ContinueReadingCard({required this.book, required this.onTap});

  final BookEntity book;
  final VoidCallback onTap;

  @override
  State<_ContinueReadingCard> createState() => _ContinueReadingCardState();
}

class _ContinueReadingCardState extends State<_ContinueReadingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: cs.surfaceContainerHighest,
            boxShadow: _hovered
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))]
                : null,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                child: BookCover(
                  coverPath: widget.book.coverPath,
                  width: 80,
                  height: 140,
                  format: widget.book.format,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      if (widget.book.author != null)
                        Text(
                          widget.book.author!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      const Spacer(),
                      if (widget.book.progress != null && widget.book.progress! > 0)
                        LinearProgressIndicator(
                          value: widget.book.progress! / 100,
                          minHeight: 3,
                          backgroundColor: cs.surfaceContainerHighest,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookshelfContent extends StatelessWidget {
  const _BookshelfContent({
    required this.books,
    required this.recentBooks,
    required this.layout,
    required this.isTablet,
    required this.isDesktop,
    required this.onBookTap,
    required this.onBookLongPress,
    required this.onLoadSamples,
    required this.onImport,
    required this.onAddNovel,
    required this.onDeleteBook,
    this.isImporting = false,
  });

  final List<BookEntity> books;
  final List<BookEntity> recentBooks;
  final BookshelfLayout layout;
  final bool isTablet;
  final bool isDesktop;
  final void Function(String id) onBookTap;
  final void Function(String id, Offset globalPosition) onBookLongPress;
  final VoidCallback onLoadSamples;
  final VoidCallback onImport;
  final VoidCallback onAddNovel;
  final void Function(String id) onDeleteBook;
  final bool isImporting;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppEmptyState(
              title: 'Your library is empty',
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
            TextButton.icon(
              onPressed: isImporting ? null : onAddNovel,
              icon: const Icon(Icons.auto_stories, size: 18),
              label: const Text('Add Novel from link'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onLoadSamples,
              child: const Text('Load Sample Books'),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        if (isDesktop || recentBooks.isNotEmpty)
          _ContinueReadingStrip(books: recentBooks, onBookTap: onBookTap),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            isDesktop ? 0 : AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(
            isDesktop ? 'All Books' : 'Library',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        switch (layout) {
          BookshelfLayout.grid => _BookshelfGrid(
              books: books,
              isDesktop: isDesktop,
              isTablet: isTablet,
              onBookTap: onBookTap,
              onBookLongPress: onBookLongPress,
              onDeleteBook: onDeleteBook,
            ),
          BookshelfLayout.list => _BookshelfList(
              books: books,
              onBookTap: onBookTap,
              onDeleteBook: onDeleteBook,
            ),
          BookshelfLayout.scattered => _BookshelfScattered(
              books: books,
              onBookTap: onBookTap,
              onDeleteBook: onDeleteBook,
            ),
        },
      ],
    );
  }
}

class _BookshelfGrid extends StatelessWidget {
  const _BookshelfGrid({
    required this.books,
    required this.isDesktop,
    required this.isTablet,
    required this.onBookTap,
    required this.onBookLongPress,
    required this.onDeleteBook,
  });

  final List<BookEntity> books;
  final bool isDesktop;
  final bool isTablet;
  final void Function(String id) onBookTap;
  final void Function(String id, Offset globalPosition) onBookLongPress;
  final void Function(String id) onDeleteBook;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = isDesktop ? 5 : isTablet ? 4 : 2;
    final coverWidth = isDesktop ? 140.0 : isTablet ? 120.0 : 100.0;
    final coverHeight = isDesktop ? 210.0 : isTablet ? 180.0 : 150.0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: isDesktop ? 20 : 12,
        crossAxisSpacing: isDesktop ? 20 : 12,
        childAspectRatio: coverWidth / (coverHeight + 70),
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return BookGridCard(
          book: book,
          coverWidth: coverWidth,
          coverHeight: coverHeight,
          isDesktop: isDesktop,
          onTap: () => onBookTap(book.id),
          onLongPress: (pos) => onBookLongPress(book.id, pos),
        );
      },
    );
  }
}

class BookGridCard extends StatefulWidget {
  const BookGridCard({
    super.key,
    required this.book,
    required this.coverWidth,
    required this.coverHeight,
    this.isDesktop = false,
    required this.onTap,
    this.onLongPress,
  });

  final BookEntity book;
  final double coverWidth;
  final double coverHeight;
  final bool isDesktop;
  final VoidCallback onTap;
  final void Function(Offset position)? onLongPress;

  @override
  State<BookGridCard> createState() => _BookGridCardState();
}

class _BookGridCardState extends State<BookGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPressStart: widget.onLongPress != null
            ? (d) => widget.onLongPress!(d.globalPosition)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: _hovered && widget.isDesktop
              ? (Matrix4.identity()..translateByDouble(0.0, -4.0, 0.0, 1.0))
              : Matrix4.identity(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Hero(
                    tag: 'book-cover-${widget.book.id}',
                    child: BookCover(
                      coverPath: widget.book.coverPath,
                      width: widget.coverWidth,
                      height: widget.coverHeight,
                      format: widget.book.format,
                    ),
                  ),
                  if (widget.book.progress == null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'New',
                          style: TextStyle(
                            color: cs.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  if (widget.book.progress != null && widget.book.progress! > 0)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      right: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: widget.book.progress! / 100,
                          minHeight: 3,
                          backgroundColor: Colors.black26,
                          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                        ),
                      ),
                    ),
                  if (_hovered && widget.isDesktop)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _hovered ? 1.0 : 0.0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _QuickActionChip(
                                icon: Icons.play_arrow,
                                label: 'Read',
                                onTap: widget.onTap,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              ),
              if (widget.book.author != null)
                Text(
                  widget.book.author!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookshelfList extends StatelessWidget {
  const _BookshelfList({
    required this.books,
    required this.onBookTap,
    required this.onDeleteBook,
  });

  final List<BookEntity> books;
  final void Function(String id) onBookTap;
  final void Function(String id) onDeleteBook;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
      itemCount: books.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final book = books[index];
        return Dismissible(
          key: ValueKey(book.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            onDeleteBook(book.id);
            return false;
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: Theme.of(context).colorScheme.error,
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          child: BookCard(
            book: book,
            onTap: () => onBookTap(book.id),
          ),
        );
      },
    );
  }
}

class _BookshelfScattered extends StatefulWidget {
  const _BookshelfScattered({
    required this.books,
    required this.onBookTap,
    required this.onDeleteBook,
  });

  final List<BookEntity> books;
  final void Function(String id) onBookTap;
  final void Function(String id) onDeleteBook;

  @override
  State<_BookshelfScattered> createState() => _BookshelfScatteredState();
}

class _BookshelfScatteredState extends State<_BookshelfScattered> {
  late final List<_ScatteredBook> _scattered;

  @override
  void initState() {
    super.initState();
    _scattered = _generateScattered(widget.books.length);
  }

  List<_ScatteredBook> _generateScattered(int count) {
    final rng = Random(42);
    return List.generate(count, (i) {
      final angle = (rng.nextDouble() - 0.5) * 0.15;
      final xOff = (rng.nextDouble() - 0.5) * 0.1;
      final yOff = rng.nextDouble() * 0.2;
      return _ScatteredBook(
        angle: angle,
        xOffset: xOff,
        yOffset: yOff,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 1200;
    final coverWidth = isDesktop ? 130.0 : 90.0;
    final coverHeight = isDesktop ? 195.0 : 135.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 48 : 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = coverWidth + 24;
          final cardHeight = coverHeight + 80;
          final cols = (constraints.maxWidth / (cardWidth * 0.8)).floor().clamp(2, 6);
          final totalHeight = ((widget.books.length / cols).ceil() * cardHeight * 1.2) + 100;

          return SizedBox(
            height: totalHeight,
            child: Stack(
              children: widget.books.asMap().entries.map((entry) {
                final i = entry.key;
                final book = entry.value;
                final s = _scattered[i];
                final col = i % cols;
                final row = i ~/ cols;
                final left = col * cardWidth * 0.78 + (s.xOffset + 0.5) * 30;
                final top = row * cardHeight * 1.1 + (s.yOffset - 0.3) * 40;

                return Positioned(
                  left: left,
                  top: top,
                  child: Transform.rotate(
                    angle: s.angle,
                    child: SizedBox(
                      width: coverWidth + 16,
                      child: GestureDetector(
                        onTap: () => widget.onBookTap(book.id),
                        child: Card(
                          elevation: 4,
                          shadowColor: Colors.black26,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  children: [
                                    BookCover(
                                      coverPath: book.coverPath,
                                      format: book.format,
                                      width: coverWidth,
                                      height: coverHeight,
                                    ),
                                    if (book.progress == null)
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: cs.primary,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            'New',
                                            style: TextStyle(
                                              color: cs.onPrimary,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  book.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class _ScatteredBook {
  const _ScatteredBook({
    required this.angle,
    required this.xOffset,
    required this.yOffset,
  });

  final double angle;
  final double xOffset;
  final double yOffset;
}
