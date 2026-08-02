import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/molecules/app_error_state.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/router/navigation.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';

class BookDetailsScreen extends ConsumerWidget {
  const BookDetailsScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(_bookDetailsProvider(bookId));
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return bookAsync.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (err, _) => Scaffold(
        body: AppErrorState(
          message: 'Could not load book details.',
          technicalDetails: err.toString(),
        ),
      ),
      data: (result) => switch (result) {
        Success(value: final data) => isDesktop
            ? _DesktopBookDetails(
                book: data.book,
                chapters: data.chapters,
                lastReadChapterIndex: data.lastReadChapterIndex,
                onOpenReader: (chapterId) async => _openReader(bookId, ref, context, data, chapterId),
                onDelete: () => _deleteBook(bookId, ref, context),
                onEditMetadata: (t, a) => _editMetadata(bookId, ref, t, a),
              )
            : _MobileBookDetails(
                book: data.book,
                chapters: data.chapters,
                lastReadChapterIndex: data.lastReadChapterIndex,
                onOpenReader: (chapterId) async => _openReader(bookId, ref, context, data, chapterId),
                onDelete: () => _deleteBook(bookId, ref, context),
                onEditMetadata: (t, a) => _editMetadata(bookId, ref, t, a),
              ),
        Failure(error: final err) => Scaffold(
            body: AppErrorState(
              message: err.userMessage,
              technicalDetails: err.message,
            ),
          ),
      },
    );
  }
}

Future<void> _openReader(String bookId, WidgetRef ref, BuildContext context, _BookDetailsData data, String? chapterId) async {
  final navigator = GoRouter.of(context);
  final libRepo = DriftLibraryRepository(ref.read(databaseProvider));
  await libRepo.markAsOpened(bookId);
  final base = '/reader/${data.book.id}';
  final params = <String, String>{};
  final id = chapterId ?? data.lastReadChapterId;
  if (id != null) {
    params['chapterId'] = id;
  }
  if (data.book.progress != null && data.book.progress! > 0) {
    params['progress'] = (data.book.progress! / 100).toStringAsFixed(4);
  }
  final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
  final route = query.isNotEmpty ? '$base?$query' : base;
  await navigator.push(route);
  if (context.mounted) {
    ref.invalidate(_bookDetailsProvider(bookId));
  }
}

Future<void> _deleteBook(String bookId, WidgetRef ref, BuildContext context) async {
  final db = ref.read(databaseProvider);
  final repo = DriftLibraryRepository(db);
  final r = await repo.deleteBook(bookId);
  if (context.mounted) {
    if (r is Success) {
      ref.invalidate(libraryBooksProvider);
      popOrGoToLibrary(context);
    } else if (r is Failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.error.userMessage)),
      );
    }
  }
}

Future<void> _editMetadata(String bookId, WidgetRef ref, String? title, String? author) async {
  final db = ref.read(databaseProvider);
  final repo = DriftLibraryRepository(db);
  await repo.updateBook(bookId, title: title, author: author);
  ref.invalidate(_bookDetailsProvider(bookId));
}

final _bookDetailsProvider =
    FutureProvider.family<Result<_BookDetailsData>, String>(
        (ref, bookId) async {
  final db = ref.watch(databaseProvider);
  final libRepo = DriftLibraryRepository(db);
  final readerRepo = DriftReaderRepository(db);

  final booksResult = await libRepo.getBookById(bookId);
  if (booksResult is Failure<BookEntity>) {
    return Failure<_BookDetailsData>(booksResult.error, booksResult.stackTrace);
  }

  final book = (booksResult as Success<BookEntity>).value;

  final chaptersResult = await readerRepo.getChapters(bookId);
  if (chaptersResult is Failure<List<ChapterEntity>>) {
    return Failure<_BookDetailsData>(
        chaptersResult.error, chaptersResult.stackTrace);
  }

  final chapters = (chaptersResult as Success<List<ChapterEntity>>).value;

  final progressRow = await db.getReadingProgress(bookId);
  final lastReadChapterIndex = progressRow != null
      ? chapters.indexWhere((c) => c.id == progressRow.chapterId)
      : -1;

  return Success(_BookDetailsData(
    book: book,
    chapters: chapters,
    lastReadChapterIndex: lastReadChapterIndex >= 0 ? lastReadChapterIndex : null,
    lastReadChapterId: lastReadChapterIndex >= 0 ? progressRow!.chapterId : null,
  ));
});

class _BookDetailsData {
  const _BookDetailsData({
    required this.book,
    required this.chapters,
    this.lastReadChapterIndex,
    this.lastReadChapterId,
  });
  final BookEntity book;
  final List<ChapterEntity> chapters;
  // Display-only: which position to show as "read up to" in the chapter
  // list. Never used for navigation — see lastReadChapterId for that.
  final int? lastReadChapterIndex;
  // Navigation identity for "Continue Reading" — the chapter actually
  // resumed is always resolved by id, never by a re-derived index.
  final String? lastReadChapterId;
}

int _groupSize(int total) {
  if (total <= 100) return 10;
  if (total <= 500) return 50;
  return 100;
}

List<List<ChapterEntity>> _groupChapters(List<ChapterEntity> chapters) {
  final size = _groupSize(chapters.length);
  final groups = <List<ChapterEntity>>[];
  for (var i = 0; i < chapters.length; i += size) {
    groups.add(chapters.sublist(i, min(i + size, chapters.length)));
  }
  return groups;
}

class _DesktopBookDetails extends StatelessWidget {
  const _DesktopBookDetails({
    required this.book,
    required this.chapters,
    required this.onOpenReader,
    required this.onDelete,
    this.lastReadChapterIndex,
    this.onEditMetadata,
  });

  final BookEntity book;
  final List<ChapterEntity> chapters;
  final VoidCallback onDelete;
  final int? lastReadChapterIndex;
  final Future<void> Function(String title, String? author)? onEditMetadata;
  final void Function(String? chapterId)? onOpenReader;

  @override
  Widget build(BuildContext context) {
    final progress = book.progress ?? 0;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 320,
            child: _CoverPanel(
              book: book,
              progress: progress,
              onOpenReader: onOpenReader,
              onDelete: onDelete,
              onEditMetadata: onEditMetadata,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _ChapterPanel(
              chapters: chapters,
              lastReadChapterIndex: lastReadChapterIndex,
              onOpenReader: onOpenReader,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPanel extends StatelessWidget {
  const _CoverPanel({
    required this.book,
    required this.progress,
    required this.onOpenReader,
    required this.onDelete,
    this.onEditMetadata,
  });

  final BookEntity book;
  final double progress;
  final VoidCallback onDelete;
  final Future<void> Function(String title, String? author)? onEditMetadata;
  final void Function(String? chapterId)? onOpenReader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      color: cs.surfaceContainerLow,
      child: Column(
        children: [
          SizedBox(
            height: 320,
            child: Stack(
              children: [
                if (book.coverPath != null)
                  Positioned.fill(
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Image.file(
                        File(book.coverPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => context.pop(),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          onPressed: () => _editMetadata(context),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white),
                          onPressed: () => _deleteBook(context),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Hero(
                    tag: 'book-cover-${book.id}',
                    child: BookCover(
                      coverPath: book.coverPath,
                      width: 120,
                      height: 180,
                      format: book.format,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title,
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                if (book.author != null) ...[
                  const SizedBox(height: 4),
                  Text(book.author!,
                      style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(book.format.toUpperCase(),
                      style: textTheme.labelSmall?.copyWith(
                          color: cs.onSecondaryContainer,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600)),
                ),
                if (progress > 0) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 4,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${progress.round()}% complete',
                      style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => onOpenReader?.call(null),
                    icon: Icon(progress > 0 ? Icons.play_arrow : Icons.menu_book),
                    label: Text(progress > 0 ? 'Continue Reading' : 'Start Reading'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _deleteBook(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete book?'),
        content: const Text('This will permanently remove the book and all reading progress.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () { Navigator.of(ctx).pop(); onDelete(); },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _editMetadata(BuildContext context) {
    final titleController = TextEditingController(text: book.title);
    final authorController = TextEditingController(text: book.author ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Metadata'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title'), autofocus: true),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: authorController, decoration: const InputDecoration(labelText: 'Author')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final t = titleController.text.trim();
              if (t.isNotEmpty) onEditMetadata?.call(t, authorController.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ChapterPanel extends StatefulWidget {
  const _ChapterPanel({
    required this.chapters,
    required this.onOpenReader,
    this.lastReadChapterIndex,
  });

  final List<ChapterEntity> chapters;
  final int? lastReadChapterIndex;
  final void Function(String? chapterId)? onOpenReader;

  @override
  State<_ChapterPanel> createState() => _ChapterPanelState();
}

class _ChapterPanelState extends State<_ChapterPanel> {
  final Set<int> _collapsedGroups = {};

  @override
  void initState() {
    super.initState();
    final groups = _groupChapters(widget.chapters);
    if (groups.length > 3) {
      for (var i = 1; i < groups.length; i++) {
        _collapsedGroups.add(i);
      }
    }
  }

  void _toggleGroup(int groupIndex) {
    setState(() {
      if (_collapsedGroups.contains(groupIndex)) {
        _collapsedGroups.remove(groupIndex);
      } else {
        _collapsedGroups.add(groupIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;
    final groups = _groupChapters(widget.chapters);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(
            children: [
              Icon(Icons.list_alt, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('${widget.chapters.length} Chapter${widget.chapters.length == 1 ? '' : 's'}',
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (var g = 0; g < groups.length; g++) ...[
                _buildGroupHeader(g, groups[g], cs, textTheme),
                if (!_collapsedGroups.contains(g))
                  for (final ch in groups[g])
                    _buildChapterItem(ch, cs, textTheme),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupHeader(int groupIndex, List<ChapterEntity> group, ColorScheme cs, TextTheme textTheme) {
    final start = group.first.index + 1;
    final end = group.last.index + 1;
    final isCollapsed = _collapsedGroups.contains(groupIndex);
    return InkWell(
      onTap: () => _toggleGroup(groupIndex),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
        child: Row(
          children: [
            Text('Chapters $start–$end',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                )),
            const Spacer(),
            Icon(
              isCollapsed ? Icons.expand_more : Icons.expand_less,
              color: cs.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterItem(ChapterEntity ch, ColorScheme cs, TextTheme textTheme) {
    final isRead = widget.lastReadChapterIndex != null && ch.index < widget.lastReadChapterIndex!;
    final isCurrent = ch.index == widget.lastReadChapterIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isCurrent ? cs.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.onOpenReader?.call(ch.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? cs.primary
                        : isRead
                            ? cs.primaryContainer
                            : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: isRead
                      ? Icon(Icons.check, size: 12, color: cs.onPrimaryContainer)
                      : Text('${ch.index + 1}',
                          style: textTheme.labelSmall?.copyWith(
                            color: isCurrent ? cs.onPrimary : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(ch.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.w600 : null,
                        color: isRead ? cs.onSurfaceVariant : null,
                      )),
                ),
                Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileBookDetails extends StatelessWidget {
  const _MobileBookDetails({
    required this.book,
    required this.chapters,
    required this.onOpenReader,
    required this.onDelete,
    this.lastReadChapterIndex,
    this.onEditMetadata,
  });

  final BookEntity book;
  final List<ChapterEntity> chapters;
  final VoidCallback onDelete;
  final int? lastReadChapterIndex;
  final Future<void> Function(String title, String? author)? onEditMetadata;
  final void Function(String? chapterId)? onOpenReader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = book.progress ?? 0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                children: [
                  if (book.coverPath != null)
                    Positioned.fill(
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Image.file(
                          File(book.coverPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Hero(
                          tag: 'book-cover-${book.id}',
                          child: BookCover(
                            coverPath: book.coverPath,
                            width: 100,
                            height: 150,
                            format: book.format,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(book.title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              )),
                        ),
                        if (book.author != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(book.author!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.85))),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: 200,
                          child: FilledButton.icon(
                            onPressed: () => onOpenReader?.call(null),
                            icon: Icon(progress > 0 ? Icons.play_arrow : Icons.menu_book),
                            label: Text(progress > 0 ? 'Continue Reading' : 'Start Reading'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => popOrGoToLibrary(context),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: () => _editMetadata(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white),
                            onPressed: () => _deleteBook(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (progress > 0 && progress < 100)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reading Progress',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: progress / 100, minHeight: 6),
                        ),
                        const SizedBox(height: 4),
                        Text('${progress.round()}% complete · ${chapters.length} chapters',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('${chapters.length} Chapter${chapters.length == 1 ? '' : 's'}',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ),
          ),
          SliverToBoxAdapter(
            child: _MobileChapterGroupedList(
              chapters: chapters,
              lastReadChapterIndex: lastReadChapterIndex,
              onOpenReader: onOpenReader,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],
      ),
    );
  }

  void _deleteBook(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete book?'),
        content: const Text('This will permanently remove the book and all reading progress.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () { Navigator.of(ctx).pop(); onDelete(); },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _editMetadata(BuildContext context) {
    final titleController = TextEditingController(text: book.title);
    final authorController = TextEditingController(text: book.author ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Metadata'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title'), autofocus: true),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: authorController, decoration: const InputDecoration(labelText: 'Author')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final t = titleController.text.trim();
              if (t.isNotEmpty) onEditMetadata?.call(t, authorController.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _MobileChapterGroupedList extends StatefulWidget {
  const _MobileChapterGroupedList({
    required this.chapters,
    this.lastReadChapterIndex,
    this.onOpenReader,
  });

  final List<ChapterEntity> chapters;
  final int? lastReadChapterIndex;
  final void Function(String? chapterId)? onOpenReader;

  @override
  State<_MobileChapterGroupedList> createState() => _MobileChapterGroupedListState();
}

class _MobileChapterGroupedListState extends State<_MobileChapterGroupedList> {
  final Set<int> _collapsedGroups = {};

  @override
  void initState() {
    super.initState();
    final groups = _groupChapters(widget.chapters);
    if (groups.length > 3) {
      for (var i = 1; i < groups.length; i++) {
        _collapsedGroups.add(i);
      }
    }
  }

  void _toggleGroup(int groupIndex) {
    setState(() {
      if (_collapsedGroups.contains(groupIndex)) {
        _collapsedGroups.remove(groupIndex);
      } else {
        _collapsedGroups.add(groupIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;
    final groups = _groupChapters(widget.chapters);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var g = 0; g < groups.length; g++) ...[
          _buildGroupHeader(g, groups[g], textTheme, cs),
          if (!_collapsedGroups.contains(g))
            for (final ch in groups[g])
              _buildChapterItem(ch, textTheme, cs),
        ],
      ],
    );
  }

  Widget _buildGroupHeader(int groupIndex, List<ChapterEntity> group, TextTheme textTheme, ColorScheme cs) {
    final start = group.first.index + 1;
    final end = group.last.index + 1;
    final isCollapsed = _collapsedGroups.contains(groupIndex);
    return InkWell(
      onTap: () => _toggleGroup(groupIndex),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: Text('Chapters $start–$end',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  )),
            ),
            Icon(
              isCollapsed ? Icons.expand_more : Icons.expand_less,
              color: cs.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterItem(ChapterEntity ch, TextTheme textTheme, ColorScheme cs) {
    final isRead = widget.lastReadChapterIndex != null && ch.index < widget.lastReadChapterIndex!;
    final isCurrent = ch.index == widget.lastReadChapterIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: isCurrent
                ? cs.primary
                : isRead
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
            child: isRead
                ? Icon(Icons.check, size: 14, color: cs.onPrimaryContainer)
                : Text('${ch.index + 1}',
                    style: textTheme.labelSmall?.copyWith(
                        color: isCurrent ? cs.onPrimary : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
          ),
          title: Text(ch.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.w600 : null,
                color: isRead ? cs.onSurfaceVariant : null,
              )),
          trailing: Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
          onTap: () => widget.onOpenReader?.call(ch.id),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        ),
      ),
    );
  }
}
