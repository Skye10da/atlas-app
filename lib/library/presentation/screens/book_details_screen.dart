import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'package:atlas_app/library/presentation/widgets/chapter_grouped_list.dart';
import 'package:atlas_app/library/presentation/widgets/open_reader.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';

class BookDetailsScreen extends ConsumerWidget {
  const BookDetailsScreen({
    super.key,
    required this.bookId,
    this.isEmbedded = false,
    this.onClose,
  });

  final String bookId;
  final bool isEmbedded;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(_bookDetailsProvider(bookId));

    return bookAsync.when(
      loading: () => isEmbedded
          ? const Center(child: CircularProgressIndicator())
          : const Scaffold(body: AppLoading()),
      error: (err, _) => isEmbedded
          ? Center(child: Text(err.toString()))
          : Scaffold(
              body: AppErrorState(
                message: 'Could not load book details.',
                technicalDetails: err.toString(),
              ),
            ),
      data: (result) => switch (result) {
        Success(value: final data) => _BookDetailsBody(
            book: data.book,
            chapters: data.chapters,
            lastReadChapterIndex: data.lastReadChapterIndex,
            onOpenReader: (chapterId) => openReader(
              bookId: bookId,
              ref: ref,
              context: context,
              book: data.book,
              chapters: data.chapters,
              lastReadChapterId: data.lastReadChapterId,
              chapterId: chapterId,
              onReturn: () => ref.invalidate(_bookDetailsProvider(bookId)),
            ),
            onDelete: () => _deleteBook(bookId, ref, context),
            onEditMetadata: (t, a) => _editMetadata(bookId, ref, t, a),
            isEmbedded: isEmbedded,
            onClose: onClose,
          ),
        Failure(error: final err) => isEmbedded
            ? Center(child: Text(err.userMessage))
            : Scaffold(
                body: AppErrorState(
                  message: err.userMessage,
                  technicalDetails: err.message,
                ),
              ),
      },
    );
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

class _BookDetailsBody extends StatelessWidget {
  const _BookDetailsBody({
    required this.book,
    required this.chapters,
    required this.onOpenReader,
    required this.onDelete,
    this.lastReadChapterIndex,
    this.onEditMetadata,
    this.isEmbedded = false,
    this.onClose,
  });

  final BookEntity book;
  final List<ChapterEntity> chapters;
  final VoidCallback onDelete;
  final int? lastReadChapterIndex;
  final Future<void> Function(String title, String? author)? onEditMetadata;
  final void Function(String? chapterId)? onOpenReader;
  final bool isEmbedded;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = book.progress ?? 0;

    final scrollView = CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: isEmbedded ? 240 : 320,
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
                        isEmbedded
                            ? BookCover(
                                coverPath: book.coverPath,
                                width: 100,
                                height: 150,
                                format: book.format,
                              )
                            : Hero(
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
                          if (isEmbedded)
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: onClose,
                            )
                          else
                            const Spacer(),
                          const Spacer(),
                          if (!isEmbedded) ...[
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white),
                              onPressed: () => _editMetadata(context),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.white),
                              onPressed: () => _deleteBook(context),
                            ),
                          ],
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
            child: ChapterGroupedList(
              chapters: chapters,
              lastReadChapterIndex: lastReadChapterIndex,
              onOpenReader: onOpenReader,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],
      );

    if (isEmbedded) return scrollView;
    return Scaffold(body: scrollView);
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

