import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/session/session_refresh_service.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
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
    this.horizontalPadding,
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
    this.onTap,
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
  final double? horizontalPadding;
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
  final void Function(
    String text,
    Color color,
    int start,
    int end, {
    HighlightStyleType styleType,
  })?
  onHighlight;
  final void Function(String text, String? sentence)? onAddNote;
  final void Function(String text)? onShare;
  final void Function(String text)? onSearchWeb;
  final void Function(String text, String? sentence, int start, int end)?
  onListen;
  final void Function(int start, int end)? onErase;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(readerChapterContentProvider(chapter));

    final activeItem = ref.watch(activeSpeechItemProvider);
    final activeForThisChapter =
        activeItem != null && activeItem.chapterId == chapter.id
        ? activeItem
        : null;

    final blockCardSpans = ref.watch(chapterBlockCardSpansProvider(chapter));

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
      error: (err, _) => _ChapterErrorState(
        vt: vt,
        chapter: chapter,
        error: err,
        fontSize: fontSize,
        lineHeight: lineHeight,
      ),
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
            horizontalPadding: horizontalPadding,
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
            onTap: onTap,
            spans: blockCardSpans,
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
///
/// Both actions are disabled while a retry is in-flight and the parent
/// immediately switches to the full shimmer (`AsyncLoading`) — this guard
/// closes the 1-frame window where rapid taps would queue duplicate
/// `invalidate` → concurrent `readerChapterContentProvider` fetches.
class _ChapterErrorState extends HookConsumerWidget {
  const _ChapterErrorState({
    required this.vt,
    required this.chapter,
    this.error,
    this.fontSize = 16,
    this.lineHeight = 1.6,
  });

  final ReadingViewTheme vt;
  final ChapterEntity chapter;
  final double fontSize;
  final double lineHeight;

  /// The error thrown by [readerChapterContentProvider], when available —
  /// used to show an actionable, source-specific message (e.g. "Unable to
  /// connect. Please check your connection and try again.") instead of a
  /// generic one.
  final Object? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRetrying = useState(false);
    final isReverifying = useState(false);
    final colorScheme = Theme.of(context).colorScheme;
    final session = SessionRefreshService.instance;
    final sourceUrlAsync = ref.watch(chapterSourceUrlProvider(chapter));
    // Disabled-until-settled + immediate shimmer: while the provider is
    // already loading (e.g. invalidated from outside) the buttons are
    // disabled, and once the user taps Retry/Re-verify we immediately
    // replace the error surface with the full shimmer so there is zero
    // “dead” feedback. The parent `ChapterContentLoader` will also switch
    // to `AsyncLoading` on the next frame — this just makes the shimmer
    // appear in the same frame as the tap.
    final providerLoading = ref
        .watch(readerChapterContentProvider(chapter))
        .isLoading;
    final isBusy = isRetrying.value || isReverifying.value || providerLoading;
    if (isBusy) {
      return Stack(
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
      );
    }
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
                  onPressed: isBusy
                      ? null
                      : () {
                          if (isRetrying.value) return;
                          isRetrying.value = true;
                          ref.invalidate(readerChapterContentProvider(chapter));
                        },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                if (showReverify) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: isBusy
                        ? null
                        : () async {
                            if (isReverifying.value) return;
                            isReverifying.value = true;
                            try {
                              final origin = SessionRefreshService.originOf(
                                sourceUrlAsync.valueOrNull,
                              );
                              if (origin == null) return;
                              final ok = await session.ensureFresh(
                                origin,
                                seedUrl: Uri.tryParse(
                                  sourceUrlAsync.valueOrNull ?? '',
                                ),
                              );
                              if (ok && context.mounted) {
                                ref.invalidate(
                                  readerChapterContentProvider(chapter),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                isReverifying.value = false;
                              }
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
