import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/molecules/app_empty_state.dart';
import 'package:atlas_app/core/design_system/molecules/app_error_state.dart';
import 'package:atlas_app/core/design_system/molecules/confirm_delete_dialog.dart';
import 'package:atlas_app/core/design_system/organisms/app_scaffold.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/import/file_open_providers.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/domain/entities/bookshelf_layout.dart';
import 'package:atlas_app/library/presentation/providers/library_actions.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/library/presentation/widgets/book_detail_panel.dart';
import 'package:atlas_app/library/presentation/widgets/bookshelf_grid.dart';
import 'package:atlas_app/library/presentation/widgets/bookshelf_list.dart';
import 'package:atlas_app/library/presentation/widgets/bookshelf_scattered.dart';
import 'package:atlas_app/library/presentation/widgets/home/continue_hero_card.dart';
import 'package:atlas_app/library/presentation/widgets/home/library_controls_row.dart';
import 'package:atlas_app/library/presentation/widgets/home/library_home_header.dart';
import 'package:atlas_app/library/presentation/widgets/home/library_insights_panel.dart';
import 'package:atlas_app/library/presentation/widgets/home/library_status_tabs.dart';
import 'package:atlas_app/library/presentation/widgets/home/weekly_activity_dots.dart';
import 'package:atlas_app/library/presentation/widgets/library_sort_filter_sheet.dart';

import 'package:atlas_app/discover/presentation/providers/reading_analytics_providers.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/core/router/app_router.dart';

/// Library home.
///
/// One screen, three arrangements chosen from the available width (not the
/// device): phone (stats strip, hero, controls, tabs, shelf), medium (hero
/// beside the stats card) and wide (shelf in the middle, stats + new chapters
/// in a right-hand panel). Navigation chrome (bottom bar / rail / sidebar)
/// lives in [AppShell].
class LibraryScreen extends HookConsumerWidget {
  const LibraryScreen({
    super.key,
    this.initialGenre,
    this.initialSort,
  });

  final String? initialGenre;
  final String? initialSort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchFocus = useFocusNode();
    final showSearchBar = useState(false);
    final isSelectionMode = useState(false);
    final selectedBookIds = useState<Set<String>>({});

    useEffect(() {
      final initialQuery = ref.read(librarySearchQueryProvider);
      if (initialQuery.isNotEmpty) {
        searchController.text = initialQuery;
        showSearchBar.value = true;
      }
      if (initialGenre != null && initialGenre!.trim().isNotEmpty) {
        Future.microtask(() {
          ref.read(libraryViewModelProvider.notifier).setGenreFilter(initialGenre!.trim());
        });
      }
      if (initialSort != null && initialSort!.trim().isNotEmpty) {
        Future.microtask(() {
          if (initialSort == 'recentlyAdded') {
            ref.read(libraryViewModelProvider.notifier).setSortOrder(LibrarySortOrder.recentlyAdded);
          } else if (initialSort == 'recentlyRead') {
            ref.read(libraryViewModelProvider.notifier).setSortOrder(LibrarySortOrder.recentlyRead);
          }
        });
      }
      return null;
    }, [initialGenre, initialSort]);

    final libraryAsync = ref.watch(libraryViewModelProvider);
    final libraryState = libraryAsync.valueOrNull ?? const LibraryState();
    final importActions = ref.watch(libraryImportProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppBreakpoints.tablet;
    final isBigDesktop = width >= AppBreakpoints.largeDesktop;
    final isTablet = width >= AppBreakpoints.mobile && !isDesktop;
    // False while this tab is hidden behind another shell branch.
    final isActiveTab = TickerMode.valuesOf(context).enabled;

    final cs = Theme.of(context).colorScheme;
    final selecting = isSelectionMode.value;
    final searchOpen =
        showSearchBar.value || libraryState.searchQuery.isNotEmpty;

    void openSearch() {
      showSearchBar.value = true;
      searchFocus.requestFocus();
    }

    void closeSearch() {
      showSearchBar.value = false;
      searchController.clear();
      ref.read(libraryViewModelProvider.notifier).setSearchQuery('');
    }

    // Ctrl/Cmd + K focuses library search on desktop-class windows.
    useEffect(() {
      if (!isDesktop || !isActiveTab) return null;
      bool handler(KeyEvent event) {
        if (event is! KeyDownEvent) return false;
        if (event.logicalKey != LogicalKeyboardKey.keyK) return false;
        final keyboard = HardwareKeyboard.instance;
        if (!keyboard.isControlPressed && !keyboard.isMetaPressed) {
          return false;
        }
        openSearch();
        return true;
      }

      HardwareKeyboard.instance.addHandler(handler);
      return () => HardwareKeyboard.instance.removeHandler(handler);
    }, [isDesktop, isActiveTab]);

    return AppScaffold(
      // The greeting header replaces the app bar; it only returns while
      // selecting books (select all / delete / cancel).
      title: selecting ? '${selectedBookIds.value.length} Selected' : null,
      actions: selecting
          ? [
              IconButton(
                icon: Icon(
                  selectedBookIds.value.length == libraryState.filteredBooks.length &&
                          libraryState.filteredBooks.isNotEmpty
                      ? Icons.deselect_rounded
                      : Icons.select_all_rounded,
                ),
                tooltip: selectedBookIds.value.length ==
                            libraryState.filteredBooks.length &&
                        libraryState.filteredBooks.isNotEmpty
                    ? 'Deselect all'
                    : 'Select all',
                onPressed: () {
                  if (selectedBookIds.value.length ==
                      libraryState.filteredBooks.length) {
                    selectedBookIds.value = {};
                  } else {
                    selectedBookIds.value =
                        libraryState.filteredBooks.map((b) => b.id).toSet();
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: selectedBookIds.value.isEmpty
                      ? cs.onSurfaceVariant
                      : cs.error,
                ),
                tooltip: 'Delete selected',
                onPressed: selectedBookIds.value.isEmpty
                    ? null
                    : () => _confirmDeleteSelected(
                          context,
                          ref,
                          selectedBookIds,
                          isSelectionMode,
                        ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel selection',
                onPressed: () {
                  isSelectionMode.value = false;
                  selectedBookIds.value = {};
                },
              ),
            ]
          : null,
      child: SafeArea(
        top: !selecting,
        bottom: false,
        child: _buildContent(
          context,
          ref,
          libraryAsync,
          libraryState,
          searchController,
          searchFocus,
          searchOpen,
          openSearch,
          closeSearch,
          isSelectionMode,
          selectedBookIds,
          importActions.isImporting,
          importActions.progress.message,
          isDesktop,
          isBigDesktop,
          isTablet,
        ),
      ),
    );
  }

  static Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<LibraryState> libraryAsync,
    LibraryState state,
    TextEditingController searchController,
    FocusNode searchFocus,
    bool searchOpen,
    VoidCallback openSearch,
    VoidCallback closeSearch,
    ValueNotifier<bool> isSelectionMode,
    ValueNotifier<Set<String>> selectedBookIds,
    bool isImporting,
    String? importMessage,
    bool isDesktop,
    bool isBigDesktop,
    bool isTablet,
  ) {
    return Column(
      children: [
        if (isImporting) _ImportBanner(message: importMessage),
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
              libraryIsEmpty: state.books.isEmpty,
              statusFilter: state.statusFilter,
              category: state.category,
              searchQuery: state.searchQuery,
              searchController: searchController,
              searchFocus: searchFocus,
              searchOpen: searchOpen,
              onToggleSearch: () => searchOpen ? closeSearch() : openSearch(),
              isDesktop: isDesktop,
              isBigDesktop: isBigDesktop,
              isTablet: isTablet,
              isSelectionMode: isSelectionMode.value,
              selectedIds: selectedBookIds.value,
              onBookTap: (id) {
                if (isSelectionMode.value) {
                  final next = Set<String>.from(selectedBookIds.value);
                  if (next.contains(id)) {
                    next.remove(id);
                  } else {
                    next.add(id);
                  }
                  selectedBookIds.value = next;
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
                if (isSelectionMode.value) {
                  final next = Set<String>.from(selectedBookIds.value);
                  if (next.contains(id)) {
                    next.remove(id);
                  } else {
                    next.add(id);
                  }
                  selectedBookIds.value = next;
                } else {
                  isSelectionMode.value = true;
                  selectedBookIds.value = {id};
                }
              },
              onLoadSamples: () => _loadSamples(ref),
              onImport: () => _showAddSheet(context, ref),
              onDeleteBook: (id) => _deleteBook(context, ref, id),
              isImporting: isImporting,
              selectedBookId: isDesktop ? state.selectedBookId : null,
            ),
          ),
        ),
      ],
    );
  }

  static void _loadSamples(WidgetRef ref) {
    ref.read(librarySeedProvider.future).then((_) {
      ref.invalidate(libraryBooksProvider);
    });
  }

  static void _showAddSheet(BuildContext context, WidgetRef ref) {
    unawaited(addToLibrary(context, ref));
  }

  static Future<void> _deleteBook(BuildContext context, WidgetRef ref, String bookId) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete book?',
      message: 'This will permanently remove the book and all reading progress.',
      confirmLabel: 'Delete',
    );

    if (confirmed != true || !context.mounted) return;

    final actions = ref.read(libraryDeleteProvider);
    final result = await actions.delete(bookId);
    ref.invalidate(libraryBooksProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        result is Success
            ? const SnackBar(content: Text('Book deleted'))
            : SnackBar(content: Text((result as Failure).error.userMessage)),
      );
    }
  }

  static Future<void> _confirmDeleteSelected(
    BuildContext context,
    WidgetRef ref,
    ValueNotifier<Set<String>> selectedBookIds,
    ValueNotifier<bool> isSelectionMode,
  ) async {
    final count = selectedBookIds.value.length;
    if (count == 0) return;

    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete $count ${count == 1 ? 'book' : 'books'}?',
      message:
          'This will permanently remove $count ${count == 1 ? 'book' : 'books'} and all reading progress from your library.',
      confirmLabel: 'Delete $count ${count == 1 ? 'Book' : 'Books'}',
    );

    if (confirmed != true || !context.mounted) return;

    final idsToDelete = selectedBookIds.value.toList();
    final actions = ref.read(libraryDeleteProvider);
    final result = await actions.deleteMultiple(idsToDelete);
    ref.invalidate(libraryBooksProvider);

    if (context.mounted) {
      isSelectionMode.value = false;
      selectedBookIds.value = {};
      ScaffoldMessenger.of(context).showSnackBar(
        result is Success
            ? SnackBar(content: Text('Deleted $count books'))
            : SnackBar(content: Text((result as Failure).error.userMessage)),
      );
    }
  }
}

/// Slim banner shown while a book import is running (replaces the spinner
/// that used to live in the app bar).
class _ImportBanner extends StatelessWidget {
  const _ImportBanner({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      color: cs.secondaryContainer,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.smMd),
          Expanded(
            child: Text(
              message ?? 'Importing...',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSecondaryContainer,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookshelfContent extends HookConsumerWidget {
  const _BookshelfContent({
    required this.books,
    required this.recentBooks,
    required this.libraryIsEmpty,
    required this.statusFilter,
    required this.category,
    required this.searchController,
    required this.searchFocus,
    required this.searchOpen,
    required this.onToggleSearch,
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

  /// Width of the right-hand insights column on wide windows.
  static const double _insightsWidth = 320;

  final List<BookEntity> books;
  final List<BookEntity> recentBooks;

  /// True when the whole library has no books at all (not just this filter).
  final bool libraryIsEmpty;
  final LibraryStatusFilter statusFilter;
  final LibraryCategory category;
  final String searchQuery;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final bool searchOpen;
  final VoidCallback onToggleSearch;
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
  Widget build(BuildContext context, WidgetRef ref) {
    final dragging = useState(false);
    final layout = ref.watch(bookshelfLayoutProvider);

    if (libraryIsEmpty) {
      return DropTarget(
        onDragDone: (details) => _handleFileDrop(context, ref, details, dragging),
        onDragEntered: (_) => dragging.value = true,
        onDragExited: (_) => dragging.value = false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: _LibraryGreetingHeader(),
            ),
            Expanded(
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.file_upload),
                          label: Text(
                            isImporting ? 'Importing...' : 'Import Book',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: onLoadSamples,
                          child: const Text('Load Sample Books'),
                        ),
                      ],
                    ),
                  ),
                  if (dragging.value) _buildDropOverlay(context),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return DropTarget(
      onDragDone: (details) => _handleFileDrop(context, ref, details, dragging),
      onDragEntered: (_) => dragging.value = true,
      onDragExited: (_) => dragging.value = false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth;
          final detailOpen =
              isDesktop && selectedBookId != null && !isSelectionMode;
          final showInsights =
              !detailOpen &&
              !isSelectionMode &&
              contentWidth >= AppBreakpoints.libraryInsightsMinWidth;
          final sidePanelWidth = detailOpen
              ? 400.0
              : showInsights
              ? _insightsWidth
              : 0.0;
          final mainWidth = contentWidth - sidePanelWidth;
          final wide = mainWidth >= AppBreakpoints.mobile;
          final notifier = ref.read(libraryViewModelProvider.notifier);

          return Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        // Stays visible while searching so the search field
                        // does not jump when the first character is typed.
                        if (!isSelectionMode)
                          _LibraryHomeSection(
                            recentBooks: recentBooks,
                            onBookTap: onBookTap,
                            wide: wide,
                            showInlineStats: !showInsights,
                          ),
                        if (!isSelectionMode) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.lg,
                              AppSpacing.sm,
                            ),
                            child: LibraryControlsRow(
                              wide: wide,
                              inlineSearch: isDesktop,
                              searchActive: searchOpen,
                              onToggleSearch: onToggleSearch,
                              onCheckUpdates: () =>
                                  checkAllLibraryUpdates(context, ref),
                              searchController: searchController,
                              searchFocusNode: searchFocus,
                            ),
                          ),
                          if (!isDesktop && searchOpen)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                AppSpacing.sm,
                              ),
                              child: LibrarySearchField(
                                controller: searchController,
                                focusNode: searchFocus,
                                autofocus: searchQuery.isEmpty,
                                onChanged: notifier.setSearchQuery,
                              ),
                            ),
                          const _LibraryStatusTabsRow(),
                          const _ActiveGenreChip(),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        if (books.isEmpty)
                          _EmptyShelfMessage(
                            searchQuery: searchQuery,
                            statusFilter: statusFilter,
                            category: category,
                          )
                        else
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
                  if (detailOpen) ...[
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 400,
                      child: Material(
                        child: BookDetailPanel(
                          bookId: selectedBookId!,
                          onClose: () => ref
                              .read(libraryViewModelProvider.notifier)
                              .selectBook(null),
                        ),
                      ),
                    ),
                  ],
                  if (showInsights)
                    SizedBox(
                      width: _insightsWidth,
                      child: _LibraryInsightsHost(onBookTap: onBookTap),
                    ),
                ],
              ),
              if (dragging.value) _buildDropOverlay(context),
            ],
          );
        },
      ),
    );
  }

  static Widget _buildDropOverlay(BuildContext context) {
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

  static Future<void> _handleFileDrop(
    BuildContext context,
    WidgetRef ref,
    DropDoneDetails details,
    ValueNotifier<bool> dragging,
  ) async {
    dragging.value = false;
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
      if (result is Success<ImportOutcome> && context.mounted) {
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

    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('Successfully imported $count books.')),
      );
    }
  }
}

/// Greeting header that resolves the live reading streak itself.
class _LibraryGreetingHeader extends ConsumerWidget {
  const _LibraryGreetingHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(readingAnalyticsReportProvider).valueOrNull;
    final goal = ref.watch(readingGoalProvider).valueOrNull;
    final streak = report?.currentStreak ?? goal?.currentStreak ?? 0;

    return LibraryHomeHeader(
      streakDays: streak,
      onOpenAnalytics: () => AppRouter.openAnalytics(context),
    );
  }
}

/// Greeting, weekly stats and the Continue hero, rendered above the shelf.
///
/// * phone: stats strip under the greeting, hero below it
/// * medium: hero with the stats card beside it
/// * wide ([showInlineStats] false): hero only, stats live in the side panel
class _LibraryHomeSection extends ConsumerWidget {
  const _LibraryHomeSection({
    required this.recentBooks,
    required this.onBookTap,
    required this.wide,
    required this.showInlineStats,
  });

  final List<BookEntity> recentBooks;
  final void Function(String id) onBookTap;
  final bool wide;
  final bool showInlineStats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(readingAnalyticsReportProvider).valueOrNull;
    final weekly = report?.weeklyActivity ?? const <ReadingDayActivity>[];
    final weekChapters = weekly.fold<int>(
      0,
      (sum, day) => sum + day.chaptersRead,
    );

    // Prefer an in-progress book for the hero; fall back to most recent.
    final BookEntity? heroBook = recentBooks.isEmpty
        ? null
        : recentBooks.firstWhere(
            (b) => b.progress01 > 0 && b.progress01 < 0.999,
            orElse: () => recentBooks.first,
          );

    final hero = ContinueHeroCard(
      book: heroBook,
      onTap: heroBook == null ? null : () => onBookTap(heroBook.id),
      onContinue: heroBook == null
          ? null
          : () => context.push('/reader/${heroBook.id}'),
    );

    final showStatsCard = showInlineStats && wide && weekly.isNotEmpty;
    final showStrip = showInlineStats && !wide && weekly.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: _LibraryGreetingHeader(),
        ),
        const SizedBox(height: AppSpacing.md),
        if (showStrip)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: WeeklyActivityStrip(
              weeklyActivity: weekly,
              onTap: () => AppRouter.openAnalytics(context),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: showStatsCard
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: hero),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 280,
                      child: WeeklyActivityDots(
                        weeklyActivity: weekly,
                        totalChapters: weekChapters,
                        onTap: () => AppRouter.openAnalytics(context),
                      ),
                    ),
                  ],
                )
              : hero,
        ),
      ],
    );
  }
}

/// Right-hand column on wide windows: weekly stats + new chapters.
class _LibraryInsightsHost extends ConsumerWidget {
  const _LibraryInsightsHost({required this.onBookTap});

  final void Function(String id) onBookTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryViewModelProvider).valueOrNull;
    final report = ref.watch(readingAnalyticsReportProvider).valueOrNull;
    final weekly = report?.weeklyActivity ?? const <ReadingDayActivity>[];
    final weekChapters = weekly.fold<int>(
      0,
      (sum, day) => sum + day.chaptersRead,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        0,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: LibraryInsightsPanel(
        weeklyActivity: weekly,
        weekChapters: weekChapters,
        updatedBooks: state?.updatedBooks ?? const <BookEntity>[],
        isChecking: state?.isCheckingUpdates ?? false,
        onOpenAnalytics: () => AppRouter.openAnalytics(context),
        onBookTap: onBookTap,
        onCheckForUpdates: () => checkAllLibraryUpdates(context, ref),
      ),
    );
  }
}

/// Status tabs with the sort & filter and layout actions docked at the end.
class _LibraryStatusTabsRow extends ConsumerWidget {
  const _LibraryStatusTabsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryViewModelProvider).valueOrNull;
    final layout = ref.watch(bookshelfLayoutProvider);
    final genre = ref.watch(libraryGenreFilterProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: LibraryStatusTabs(
        selected: state?.statusFilter ?? LibraryStatusFilter.all,
        updatedCount: state?.updatedCount ?? 0,
        onSelected: (filter) =>
            ref.read(libraryViewModelProvider.notifier).setStatusFilter(filter),
        trailing: [
          IconButton(
            tooltip: 'Sort & filter',
            icon: Badge(
              isLabelVisible: genre != null,
              smallSize: 8,
              child: const Icon(Icons.filter_list_rounded),
            ),
            onPressed: () => showLibrarySortFilterSheet(context),
          ),
          IconButton(
            tooltip: 'Layout: ${layout.label} (tap to change)',
            icon: Icon(layout.icon),
            onPressed: () {
              const values = BookshelfLayout.values;
              final next = values[(layout.index + 1) % values.length];
              ref.read(libraryViewModelProvider.notifier).setLayout(next);
            },
          ),
        ],
      ),
    );
  }
}

/// Removable chip showing the active genre filter (so a filter chosen in the
/// sheet is never invisible).
class _ActiveGenreChip extends ConsumerWidget {
  const _ActiveGenreChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genre = ref.watch(libraryGenreFilterProvider);
    if (genre == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InputChip(
          label: Text(genre),
          avatar: const Icon(Icons.sell_outlined, size: 16),
          onDeleted: () =>
              ref.read(libraryViewModelProvider.notifier).setGenreFilter(null),
          deleteButtonTooltipMessage: 'Clear genre filter',
        ),
      ),
    );
  }
}

/// Shown when the library has books but the current search / tab / category
/// matches none of them. Keeps the controls above it reachable.
class _EmptyShelfMessage extends ConsumerWidget {
  const _EmptyShelfMessage({
    required this.searchQuery,
    required this.statusFilter,
    required this.category,
  });

  final String searchQuery;
  final LibraryStatusFilter statusFilter;
  final LibraryCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noun = category == LibraryCategory.novels ? 'novels' : 'books';

    if (searchQuery.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppEmptyState(
              title: 'No results found',
              message: 'No $noun match "$searchQuery".',
              icon: Icons.search_off_rounded,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(libraryViewModelProvider.notifier).setSearchQuery(''),
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: const Text('Clear search'),
            ),
          ],
        ),
      );
    }

    final message = switch (statusFilter) {
      LibraryStatusFilter.updated => 'No $noun have new chapters right now.',
      LibraryStatusFilter.reading => 'No $noun in progress.',
      LibraryStatusFilter.unread => 'No unread $noun.',
      LibraryStatusFilter.finished => 'No finished $noun yet.',
      LibraryStatusFilter.all => 'No $noun here yet.',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: AppEmptyState(
        title: 'Nothing here',
        message: message,
        icon: Icons.auto_stories_outlined,
      ),
    );
  }
}
