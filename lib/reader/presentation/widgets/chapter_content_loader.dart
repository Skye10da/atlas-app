import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/error_handling/result.dart';
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
  final void Function(String text, Color color, int start, int end)?
  onHighlight;
  final void Function(String text, String? sentence)? onAddNote;
  final void Function(String text)? onShare;
  final void Function(String text)? onSearchWeb;
  final void Function(String text, String? sentence, int start, int end)?
  onListen;
  final void Function(int start, int end)? onErase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(readerChapterContentProvider(chapter));

    final activeItem = ref.watch(activeSpeechItemProvider);
    final activeForThisChapter =
        activeItem != null && activeItem.chapterId == chapter.id
        ? activeItem
        : null;

    final colorScheme = Theme.of(context).colorScheme;

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
      error: (err, _) =>
          _ChapterErrorState(vt: vt, chapter: chapter, error: err),
      data: (content) {
        // Content is ready to render in the continuous layout.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ref.read(chapterLoadPhaseProvider(chapter).notifier).state =
                ChapterLoadPhase.done;
            // Prefetch neighboring chapters so the next swipe is instant.
            prefetchNeighboringChapters(ref, chapter);
          }
        });
        return Container(
          color: vt.resolve(colorScheme).background,
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

/// Error surface for a chapter that failed to load. Always offers a plain
/// "Retry" action; when the failure came from an expired session (see
/// [SessionRefreshService.lastInvalidOrigin]), also offers a "Re-verify
/// session" action that opens the quick source view, then reloads the
/// chapter.
class _ChapterErrorState extends ConsumerWidget {
  const _ChapterErrorState({
    required this.vt,
    required this.chapter,
    this.error,
  });

  final ReadingViewTheme vt;
  final ChapterEntity chapter;

  /// The error thrown by [readerChapterContentProvider], when available —
  /// used to show an actionable, source-specific message (e.g. "Unable to
  /// connect. Please check your connection and try again.") instead of a
  /// generic one.
  final Object? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final session = SessionRefreshService.instance;
    final sourceUrlAsync = ref.watch(chapterSourceUrlProvider(chapter));
    final err = error;
    final message = err is AppException
        ? err.userMessage
        : 'Could not load chapter.';
    return ValueListenableBuilder<Uri?>(
      valueListenable: session.lastInvalidOrigin,
      builder: (context, invalid, _) {
        final origin = SessionRefreshService.originOf(
          sourceUrlAsync.valueOrNull,
        );
        final showReverify =
            origin != null &&
            invalid != null &&
            SessionRefreshService.sameOrigin(invalid, origin);
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: vt.resolve(colorScheme).text.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(color: vt.resolve(colorScheme).text),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      ref.invalidate(readerChapterContentProvider(chapter)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                if (showReverify) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
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
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('Re-verify session'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
