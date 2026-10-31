import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_index_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_annotations_sheet.dart';

/// One panel for everything you navigate the book with: Chapters, Bookmarks
/// and Notes (notes + highlights). Replaces the separate chapter-list and
/// annotations sheets on the phone dock; [initialTab] lets the dock's Notes
/// button open it on the right tab.
class ReaderContentsSheet extends HookConsumerWidget {
  const ReaderContentsSheet({
    super.key,
    required this.bookId,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onChapterTap,
    required this.bookmarkedChapterIds,
    required this.onBookmarkToggle,
    required this.isBookmarked,
    this.bookTitle,
    this.coverPath,
    this.initialTab = 0,
  });

  final String bookId;
  final List<ChapterEntity> chapters;
  final int currentChapterIndex;
  final void Function(int index) onChapterTap;
  final Set<String> bookmarkedChapterIds;
  final VoidCallback onBookmarkToggle;
  final bool isBookmarked;
  final String? bookTitle;
  final String? coverPath;

  /// 0 = Chapters, 1 = Bookmarks, 2 = Notes.
  final int initialTab;

  static Future<void> show(
    BuildContext context, {
    required String sheetId,
    required String bookId,
    required List<ChapterEntity> chapters,
    required int currentChapterIndex,
    required void Function(int index) onChapterTap,
    required Set<String> bookmarkedChapterIds,
    required VoidCallback onBookmarkToggle,
    required bool isBookmarked,
    String? bookTitle,
    String? coverPath,
    int initialTab = 0,
  }) {
    return AppSheet.show<void>(
      context: context,
      id: sheetId,
      title: 'Contents',
      initialHeight: 0.7,
      snapPoints: const [0.5, 0.7, 0.92],
      child: ReaderContentsSheet(
        bookId: bookId,
        chapters: chapters,
        currentChapterIndex: currentChapterIndex,
        onChapterTap: onChapterTap,
        bookmarkedChapterIds: bookmarkedChapterIds,
        onBookmarkToggle: onBookmarkToggle,
        isBookmarked: isBookmarked,
        bookTitle: bookTitle,
        coverPath: coverPath,
        initialTab: initialTab,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = useTabController(
      initialLength: 3,
      initialIndex: initialTab.clamp(0, 2),
    );
    final safeIndex = chapters.isEmpty
        ? 0
        : currentChapterIndex.clamp(0, chapters.length - 1);

    return Column(
      children: [
        TabBar(
          controller: tabs,
          tabs: const [
            Tab(text: 'Chapters'),
            Tab(text: 'Bookmarks'),
            Tab(text: 'Notes'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: tabs,
            children: [
              ChapterIndexSheet(
                chapters: chapters,
                currentChapterIndex: currentChapterIndex,
                onChapterTap: onChapterTap,
              ),
              _BookmarksList(
                chapters: chapters,
                currentChapterIndex: safeIndex,
                bookmarkedChapterIds: bookmarkedChapterIds,
                isBookmarked: isBookmarked,
                onBookmarkToggle: onBookmarkToggle,
                onChapterTap: onChapterTap,
              ),
              ReaderAnnotationsSheet(
                bookId: bookId,
                chapters: chapters,
                currentChapterId: chapters.isEmpty
                    ? null
                    : chapters[safeIndex].id,
                bookTitle: bookTitle,
                coverPath: coverPath,
                onJumpToChapter: (chapterId, _) {
                  final idx = chapters.indexWhere((c) => c.id == chapterId);
                  if (idx >= 0) {
                    Navigator.of(context).pop();
                    onChapterTap(idx);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookmarksList extends HookWidget {
  const _BookmarksList({
    required this.chapters,
    required this.currentChapterIndex,
    required this.bookmarkedChapterIds,
    required this.isBookmarked,
    required this.onBookmarkToggle,
    required this.onChapterTap,
  });

  final List<ChapterEntity> chapters;
  final int currentChapterIndex;
  final Set<String> bookmarkedChapterIds;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;
  final void Function(int index) onChapterTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // The sheet receives a snapshot of the bookmarks; mirror the toggle
    // locally so the list updates immediately while the real state updates in
    // the reader behind it.
    final ids = useState<Set<String>>({...bookmarkedChapterIds});
    final currentId = chapters.isEmpty ? null : chapters[currentChapterIndex].id;
    final currentMarked = currentId != null && ids.value.contains(currentId);

    final marked = <int>[
      for (var i = 0; i < chapters.length; i++)
        if (ids.value.contains(chapters[i].id)) i,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: currentId == null
                  ? null
                  : () {
                      final next = {...ids.value};
                      if (!next.remove(currentId)) next.add(currentId);
                      ids.value = next;
                      onBookmarkToggle();
                    },
              icon: Icon(
                currentMarked
                    ? Icons.bookmark_remove_rounded
                    : Icons.bookmark_add_rounded,
              ),
              label: Text(
                currentMarked
                    ? 'Remove bookmark from this chapter'
                    : 'Bookmark this chapter',
              ),
            ),
          ),
        ),
        Expanded(
          child: marked.isEmpty
              ? Center(
                  child: Text(
                    'No bookmarks yet',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  itemCount: marked.length,
                  itemBuilder: (context, i) {
                    final index = marked[i];
                    return ListTile(
                      leading: Icon(Icons.bookmark_rounded, color: cs.primary),
                      title: Text(
                        chapters[index].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('Chapter ${index + 1}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).pop();
                        onChapterTap(index);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
