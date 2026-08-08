import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_shimmer.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_styles.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';

class ChapterContentLoader extends ConsumerWidget {
  const ChapterContentLoader({
    super.key,
    required this.chapter,
    required this.fontSize,
    this.fontFamily,
    this.fontWeight,
    required this.lineHeight,
    required this.letterSpacing,
    required this.vt,
    this.textAlignment = TextAlignment.left,
    this.marginPreset = MarginPreset.normal,
    this.scrollable = true,
    this.chapterStyle,
    this.restoreCharOffset,
    this.onRestoreRevealed,
    this.onNarrationOutOfSyncChanged,
    this.onRegisterNarrationReveal,
  });

  final ChapterEntity chapter;
  final double fontSize;
  final String? fontFamily;
  /// Numeric reader body-text weight; `null` keeps the family default.
  final int? fontWeight;
  final double lineHeight;
  final double letterSpacing;
  final ReadingViewTheme vt;
  final TextAlignment textAlignment;
  final MarginPreset marginPreset;
  final bool scrollable;
  final ChapterStyle? chapterStyle;

  /// Character offset (into [chapter]'s content) to reveal on open — a
  /// one-shot exact-position resume. Omit for no resume.
  final int? restoreCharOffset;

  /// Called once the resume offset has been revealed, letting the parent clear
  /// it so it doesn't re-fire. Omit to disable.
  final void Function()? onRestoreRevealed;

  /// Whether this chapter is narrating but its highlighted sentence has
  /// scrolled out of view. See [ChapterView.onNarrationOutOfSyncChanged].
  final ValueChanged<bool>? onNarrationOutOfSyncChanged;

  /// Opt-in handle to scroll this chapter's narration into view; see
  /// [ChapterView.onRegisterNarrationReveal].
  final void Function(void Function() reveal)? onRegisterNarrationReveal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync =
        ref.watch(readerChapterContentProvider(chapter));

    final activeItem = ref.watch(activeSpeechItemProvider);
    final activeForThisChapter =
        activeItem != null && activeItem.chapterId == chapter.id
        ? activeItem
        : null;

    return contentAsync.when(
      loading: () => Stack(
        children: [
          const Positioned.fill(child: SizedBox.expand()),
          ChapterShimmer(
            vt: vt,
            showHeaders: false,
            fontSize: fontSize,
            lineHeight: lineHeight,
          ),
          ReaderLoadingOverlay(chapter: chapter, vt: vt),
        ],
      ),
      error: (err, _) => Center(
        child: Text('Could not load chapter.',
            style: TextStyle(color: vt.text)),
      ),
      data: (content) {
        // Content is ready to render in the continuous layout.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ref.read(chapterLoadPhaseProvider(chapter).notifier).state =
                ChapterLoadPhase.done;
          }
        });
        return Container(
          color: vt.background,
          child: ChapterView(
            content: content,
            fontSize: fontSize,
            fontFamily: fontFamily,
            fontWeight: fontWeight,
            lineHeight: lineHeight,
            letterSpacing: letterSpacing,
            theme: vt,
            textAlignment: textAlignment,
            marginPreset: marginPreset,
            scrollable: scrollable,
            dropCapStyle: chapterStyle?.dropCapStyle,
            chapterTitle: chapter.title,
            restoreCharOffset: restoreCharOffset,
            onRestoreRevealed: onRestoreRevealed,
            activeSpeechItem: activeForThisChapter,
            onNarrationOutOfSyncChanged: onNarrationOutOfSyncChanged,
            onRegisterNarrationReveal: onRegisterNarrationReveal,
          ),
        );
      },
    );
  }
}