import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/molecules/app_empty_state.dart';
import 'package:atlas_app/core/design_system/molecules/app_error_state.dart';
import 'package:atlas_app/core/design_system/organisms/app_scaffold.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/domain/entities/bookshelf_layout.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
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
    final isDesktop = MediaQuery.of(context).size.width >= 1200;
    final isTablet = MediaQuery.of(context).size.width >= 600 && !isDesktop;

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
        IconButton(
          icon: const Icon(Icons.file_upload_outlined),
          onPressed: importActions.isImporting ? null : () => _importBook(),
          tooltip: 'Import EPUB',
        ),
      ],
      child: Column(
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
                      layout: layout,
                      isTablet: isTablet,
                      isDesktop: isDesktop,
                      onBookTap: (id) => context.push('/book/$id'),
                      onLoadSamples: () => _loadSamples(),
                      onImport: () => _importBook(),
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

  void _cycleLayout() {
    final current = ref.read(bookshelfLayoutProvider);
    const values = BookshelfLayout.values;
    final nextIndex = (current.index + 1) % values.length;
    ref.read(bookshelfLayoutProvider.notifier).state = values[nextIndex];
  }

  void _showSortMenu() {
    final current = ref.read(librarySortProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
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
                Navigator.of(ctx).pop();
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

class _BookshelfContent extends StatelessWidget {
  const _BookshelfContent({
    required this.books,
    required this.layout,
    required this.isTablet,
    required this.isDesktop,
    required this.onBookTap,
    required this.onLoadSamples,
    required this.onImport,
    required this.onDeleteBook,
    this.isImporting = false,
  });

  final List<BookEntity> books;
  final BookshelfLayout layout;
  final bool isTablet;
  final bool isDesktop;
  final void Function(String id) onBookTap;
  final VoidCallback onLoadSamples;
  final VoidCallback onImport;
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
              message: 'Import an EPUB file or load samples to start reading.',
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
              label: Text(isImporting ? 'Importing...' : 'Import EPUB'),
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

    return Stack(
      children: [
        switch (layout) {
          BookshelfLayout.grid => _BookshelfGrid(
              books: books,
              isDesktop: isDesktop,
              isTablet: isTablet,
              onBookTap: onBookTap,
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
        if (isImporting)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2),
                    const SizedBox(width: 16),
                    Text('Importing EPUB...',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
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
    required this.onDeleteBook,
  });

  final List<BookEntity> books;
  final bool isDesktop;
  final bool isTablet;
  final void Function(String id) onBookTap;
  final void Function(String id) onDeleteBook;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = isDesktop ? 5 : isTablet ? 4 : 2;
    final coverWidth = isDesktop ? 140.0 : isTablet ? 120.0 : 100.0;
    final coverHeight = isDesktop ? 210.0 : isTablet ? 180.0 : 150.0;

    return GridView.builder(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
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
          onTap: () => onBookTap(book.id),
        );
      },
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
      padding: const EdgeInsets.all(16),
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
                                BookCover(
                                  coverPath: book.coverPath,
                                  format: book.format,
                                  width: coverWidth,
                                  height: coverHeight,
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
