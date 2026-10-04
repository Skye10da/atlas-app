import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:atlas_app/reader/presentation/utils/chapter_position_resolver.dart';
import 'package:atlas_app/reader/speech/parser/sentence_splitter.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

class ChapterNarrationCoordinator {
  const ChapterNarrationCoordinator();

  /// Finds the chapter's single [RenderParagraph] keyed by [textKey].
  RenderParagraph? findRenderParagraph(GlobalKey textKey) {
    final renderObject = textKey.currentContext?.findRenderObject();
    if (renderObject is RenderParagraph) {
      return renderObject;
    }
    if (renderObject is RenderObject) {
      RenderParagraph? found;
      void visitor(RenderObject child) {
        if (found != null) return;
        if (child is RenderParagraph) {
          found = child;
          return;
        }
        child.visitChildren(visitor);
      }

      renderObject.visitChildren(visitor);
      return found;
    }
    return null;
  }

  /// Resolves the character offset in [content] where [item] begins.
  int? resolveActiveSpeechOffset({
    required SpeechItem? item,
    required String content,
  }) {
    if (item == null || content.isEmpty) return null;

    final segments = const ChapterPositionResolver().paragraphsOf(content);
    if (segments.isEmpty) return null;

    const splitter = SentenceSplitter();

    int? tryParagraph(int pIdx) {
      if (pIdx < 0 || pIdx >= segments.length) return null;
      final para = segments[pIdx];
      final paraTrim = para.text.trim();
      if (paraTrim.isEmpty) return null;
      final paraOffsetInSeg = para.text.indexOf(paraTrim);

      final spans = splitter.splitParagraphSpans(paraTrim);
      if (spans.isEmpty) return null;
      final span = spans[item.sentenceIndex.clamp(0, spans.length - 1)];
      final start = para.offset + paraOffsetInSeg + span.offset;

      if (content.startsWith(item.text, start)) return start;

      final inParagraph = paraTrim.indexOf(item.text);
      if (inParagraph >= 0) return para.offset + paraOffsetInSeg + inParagraph;
      return null;
    }

    // Try direct index first
    var result = tryParagraph(item.paragraphIndex);
    if (result != null) return result;

    // Try shifted index (accounting for prepended chapter title in SpeechSessionBuilder)
    result = tryParagraph(item.paragraphIndex - 1);
    if (result != null) return result;

    final anywhere = content.indexOf(item.text);
    return anywhere >= 0 ? anywhere : null;
  }

  /// Resolves the character range `(start, end)` of the whole paragraph containing [item].
  ({int start, int end})? resolveActiveParagraphRange({
    required SpeechItem? item,
    required String content,
  }) {
    if (item == null || content.isEmpty) return null;

    final segments = const ChapterPositionResolver().paragraphsOf(content);
    if (segments.isEmpty) return null;

    ({int start, int end})? tryParagraph(int pIdx) {
      if (pIdx >= 0 && pIdx < segments.length) {
        final para = segments[pIdx];
        final paraTrim = para.text.trim();
        if (paraTrim.isNotEmpty) {
          final start = para.offset + para.text.indexOf(paraTrim);
          return (start: start, end: start + paraTrim.length);
        }
      }
      return null;
    }

    // Try paragraphIndex, or paragraphIndex - 1 if title was prepended
    var range = tryParagraph(item.paragraphIndex);
    if (range == null && item.paragraphIndex - 1 >= 0) {
      range = tryParagraph(item.paragraphIndex - 1);
    }
    if (range != null) return range;

    final speechOffset = resolveActiveSpeechOffset(
      item: item,
      content: content,
    );
    if (speechOffset != null) {
      final before = content.substring(0, speechOffset);
      final prevBreak = before.lastIndexOf(RegExp(r'\n\s*\n'));
      final rawStart = prevBreak >= 0 ? prevBreak : 0;
      final paraPart = content.substring(rawStart, speechOffset);
      final trimOffset = paraPart.indexOf(RegExp(r'\S'));
      final start = trimOffset >= 0 ? rawStart + trimOffset : rawStart;

      final after = content.substring(speechOffset);
      final nextBreak = after.indexOf(RegExp(r'\n\s*\n'));
      final end = nextBreak >= 0 ? speechOffset + nextBreak : content.length;
      return (start: start, end: end);
    }
    return null;
  }

  /// Returns true if the currently narrated sentence is within the scrollable
  /// viewport with at least [margin] breathing room on top and bottom.
  bool isSentenceVisible({
    required BuildContext context,
    required GlobalKey textKey,
    required SpeechItem? activeSpeechItem,
    required String content,
    double margin = 24.0,
  }) {
    final info = _activeSentenceViewport(
      context: context,
      textKey: textKey,
      activeSpeechItem: activeSpeechItem,
      content: content,
    );
    if (info == null) return false;
    final (_, caretGlobalTop, _, _, vpTop, vpBottom) = info;
    return caretGlobalTop >= vpTop + margin &&
        caretGlobalTop <= vpBottom - margin;
  }

  /// Scrolls the nearest [Scrollable] so the narrated sentence is in view.
  void revealSentence({
    required BuildContext context,
    required GlobalKey textKey,
    required SpeechItem? activeSpeechItem,
    required String content,
    required VoidCallback onAnimatingStart,
    required VoidCallback onAnimatingEnd,
    required void Function(bool outOfSync) onReportSync,
  }) {
    if (isSentenceVisible(
      context: context,
      textKey: textKey,
      activeSpeechItem: activeSpeechItem,
      content: content,
    )) {
      onReportSync(false);
      return;
    }

    final idx = resolveActiveSpeechOffset(
      item: activeSpeechItem,
      content: content,
    );
    final scrollable = Scrollable.maybeOf(context);
    final render = findRenderParagraph(textKey);
    final viewport = render != null
        ? RenderAbstractViewport.maybeOf(render)
        : null;

    if (activeSpeechItem == null ||
        idx == null ||
        idx < 0 ||
        scrollable == null ||
        render == null ||
        viewport == null) {
      return;
    }

    final edge = render
        .getOffsetForCaret(TextPosition(offset: idx), Rect.zero)
        .dy;
    final revealed = viewport.getOffsetToReveal(
      render,
      0.0,
      rect: Rect.fromLTWH(0, edge, 0, 0),
    );
    final position = scrollable.position;
    const margin = 24.0;
    final target = (revealed.offset - margin).clamp(
      0.0,
      position.maxScrollExtent,
    );

    onAnimatingStart();
    onReportSync(false);
    position
        .animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        )
        .whenComplete(onAnimatingEnd);
  }

  /// Inverse of [renderOffsetFromContentOffset]: maps a render offset back
  /// to a content offset using the same segment map. Used for tap-to-skip.
  int contentOffsetFromRenderOffset(
    int renderOffset,
    List<(int, int, int)>? map,
  ) {
    if (map == null || map.isEmpty) return renderOffset;
    for (final (rStart, rEnd, cStart) in map) {
      if (renderOffset >= rStart && renderOffset < rEnd) {
        return cStart + (renderOffset - rStart);
      }
    }
    for (final (rStart, _, _) in map) {
      if (renderOffset < rStart) return 0;
    }
    final last = map.last;
    return last.$3 + (last.$2 - last.$1);
  }

  /// Translates a character offset in [content] to the corresponding character
  /// offset in the laid-out [RenderParagraph], using the segment map generated
  /// by [ChapterSpanBuilder.buildSegmentedSpans].
  int renderOffsetFromContentOffset(
    int contentOffset,
    List<(int, int, int)>? map,
  ) {
    if (map == null || map.isEmpty) return contentOffset;
    for (final (rStart, rEnd, cStart) in map) {
      final len = rEnd - rStart;
      if (contentOffset >= cStart && contentOffset < cStart + len) {
        return rStart + (contentOffset - cStart);
      }
    }
    for (final (rStart, _, cStart) in map) {
      if (cStart >= contentOffset) {
        return rStart;
      }
    }
    return map.last.$2;
  }

  /// One-shot exact position restore: jumps to [restoreCharOffset].
  void revealRestoreOffset({
    required BuildContext context,
    required GlobalKey textKey,
    required int? restoreCharOffset,
    required String content,
    required VoidCallback onRestored,
    List<(int, int, int)>? renderContentMap,
  }) {
    if (restoreCharOffset == null || restoreCharOffset < 0 || content.isEmpty) {
      return;
    }

    final scrollable = Scrollable.maybeOf(context);
    final render = findRenderParagraph(textKey);
    final viewport = render != null
        ? RenderAbstractViewport.maybeOf(render)
        : null;
    if (scrollable == null || render == null || viewport == null) return;

    final targetOffset = renderOffsetFromContentOffset(
      restoreCharOffset,
      renderContentMap,
    );
    final textLength = render.text.toPlainText().length;
    final edge = render
        .getOffsetForCaret(
          TextPosition(offset: targetOffset.clamp(0, textLength)),
          Rect.zero,
        )
        .dy;
    final revealed = viewport.getOffsetToReveal(
      render,
      0.0,
      rect: Rect.fromLTWH(0, edge, 0, 0),
    );
    final position = scrollable.position;
    final target = (revealed.offset - 24.0).clamp(
      0.0,
      position.maxScrollExtent,
    );
    position.jumpTo(target);
    onRestored();
  }

  (int, double, RenderParagraph, RenderAbstractViewport, double, double)?
  _activeSentenceViewport({
    required BuildContext context,
    required GlobalKey textKey,
    required SpeechItem? activeSpeechItem,
    required String content,
  }) {
    if (activeSpeechItem == null) return null;
    final idx = resolveActiveSpeechOffset(
      item: activeSpeechItem,
      content: content,
    );
    if (idx == null || idx < 0) return null;

    final scrollable = Scrollable.maybeOf(context);
    final render = findRenderParagraph(textKey);
    if (scrollable == null || render == null) return null;
    final viewport = RenderAbstractViewport.maybeOf(render);
    final viewportBox =
        scrollable.position.context.storageContext.findRenderObject()
            as RenderBox?;
    if (viewport == null || viewportBox == null) return null;

    final caretTop = render
        .getOffsetForCaret(TextPosition(offset: idx), Rect.zero)
        .dy;
    final caretGlobalTop = render.localToGlobal(Offset(0, caretTop)).dy;
    final vpTop = viewportBox.localToGlobal(Offset.zero).dy;
    final vpBottom = vpTop + viewportBox.size.height;
    return (idx, caretGlobalTop, render, viewport, vpTop, vpBottom);
  }
}
