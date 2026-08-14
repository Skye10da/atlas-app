import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/session/session_refresh_service.dart';
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
    this.onHighlight,
    this.onAddNote,
    this.onShare,
    this.onSearchWeb,
    this.onListen,
    this.onErase,
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

  /// Context-menu callbacks forwarded to [ChapterView].
  final void Function(String text, Color color, int start, int end)? onHighlight;
  final void Function(String text, String? sentence)? onAddNote;
  final void Function(String text)? onShare;
  final void Function(String text)? onSearchWeb;
  final void Function(String text, String? sentence, int start, int end)? onListen;
  final void Function(int start, int end)? onErase;

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
      error: (err, _) => _ChapterErrorState(vt: vt, chapter: chapter),
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
            bookId: chapter.bookId,
            chapterId: chapter.id,
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
            onHighlight: onHighlight,
            onAddNote: onAddNote,
            onShare: onShare,
            onSearchWeb: onSearchWeb,
            onListen: onListen,
            onErase: onErase,
          ),
        );
      },
    );
  }
}

/// Error surface for a chapter that failed to load. When the failure came from
/// an expired session (see [SessionRefreshService.lastInvalidOrigin]), offers a
/// manual "Re-verify session" action that opens the quick source view, then
/// reloads the chapter.
class _ChapterErrorState extends ConsumerWidget {
  const _ChapterErrorState({required this.vt, required this.chapter});

  final ReadingViewTheme vt;
  final ChapterEntity chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = SessionRefreshService.instance;
    final sourceUrlAsync = ref.watch(chapterSourceUrlProvider(chapter));
    return ValueListenableBuilder<Uri?>(
      valueListenable: session.lastInvalidOrigin,
      builder: (context, invalid, _) {
        final origin = SessionRefreshService.originOf(sourceUrlAsync.valueOrNull);
        final showRetry = origin != null &&
            invalid != null &&
            SessionRefreshService.sameOrigin(invalid, origin);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load chapter.',
                style: TextStyle(color: vt.text),
              ),
              if (showRetry) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final origin = SessionRefreshService.originOf(
                      sourceUrlAsync.valueOrNull,
                    );
                    if (origin == null) return;
                    final ok = await session.ensureFresh(
                      origin,
                      seedUrl: Uri.tryParse(sourceUrlAsync.valueOrNull ?? ''),
                    );
                    if (ok && context.mounted) {
                      ref.invalidate(readerChapterContentProvider(chapter));
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Re-verify session'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}