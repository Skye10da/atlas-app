import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/organisms/draggable_bottom_sheet.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';

/// The chapter-list bottom sheet previously duplicated verbatim as
/// `_showChapterIndex` in both ContinuousReaderLayout and PagedReaderLayout.
/// The only thing that differed between the two call sites was what
/// happens on tap (scroll-to-chapter vs. page-jump-to-chapter), which is
/// now just [onChapterTap].
class ChapterIndexSheet extends StatelessWidget {
  const ChapterIndexSheet({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onChapterTap,
  });

  final List<ChapterEntity> chapters;
  final int currentChapterIndex;
  final void Function(int index) onChapterTap;

  static void show(
    BuildContext context, {
    required String sheetId,
    required List<ChapterEntity> chapters,
    required int currentChapterIndex,
    required void Function(int index) onChapterTap,
  }) {
    DraggableBottomSheet.show(
      context: context,
      id: sheetId,
      initialHeight: 0.5,
      child: ChapterIndexSheet(
        chapters: chapters,
        currentChapterIndex: currentChapterIndex,
        onChapterTap: onChapterTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const chromeHeight = 57.0;
        final listHeight = (constraints.maxHeight - chromeHeight).clamp(
          0.0,
          double.infinity,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Chapters',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: listHeight,
              child: ListView.separated(
                itemCount: chapters.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 16),
                itemBuilder: (_, idx) {
                  final ch = chapters[idx];
                  final isCurrent = idx == currentChapterIndex;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.onPrimary
                              : null,
                        ),
                      ),
                    ),
                    title: Text(
                      ch.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.w600 : null,
                      ),
                    ),
                    trailing: isCurrent
                        ? Icon(
                            Icons.check,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      onChapterTap(idx);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
