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
    if (item.paragraphIndex >= segments.length) return null;
    final para = segments[item.paragraphIndex];
    final paraTrim = para.text.trim();
    if (paraTrim.isEmpty) return null;
    final paraOffsetInSeg = para.text.indexOf(paraTrim);

    final spans = const SentenceSplitter().splitParagraphSpans(paraTrim);
    if (spans.isEmpty) return null;
    final span = spans[item.sentenceIndex.clamp(0, spans.length - 1)];
    final start = para.offset + paraOffsetInSeg + span.offset;

    if (content.startsWith(item.text, start)) return start;

    final inParagraph = paraTrim.indexOf(item.text);
    if (inParagraph >= 0) return para.offset + paraOffsetInSeg + inParagraph;
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
    if (item.paragraphIndex >= 0 && item.paragraphIndex < segments.length) {
      final para = segments[item.paragraphIndex];
      final paraTrim = para.text.trim();
      if (paraTrim.isNotEmpty) {
        final start = para.offset + para.text.indexOf(paraTrim);
        return (start: start, end: start + paraTrim.length);
      }
    }

    final speechOffset = resolveActiveSpeechOffset(item: item, content: content);
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
    final viewport =
        render != null ? RenderAbstractViewport.maybeOf(render) : null;

    if (activeSpeechItem == null ||
        idx == null ||
        idx < 0 ||
        scrollable == null ||
        render == null ||
        viewport == null) {
      return;
    }

    final edge =
        render.getOffsetForCaret(TextPosition(offset: idx), Rect.zero).dy;
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

  /// One-shot exact position restore: jumps to [restoreCharOffset].
  void revealRestoreOffset({
    required BuildContext context,
    required GlobalKey textKey,
    required int? restoreCharOffset,
    required String content,
    required VoidCallback onRestored,
  }) {
    if (restoreCharOffset == null ||
        restoreCharOffset < 0 ||
        content.isEmpty) {
      return;
    }

    final scrollable = Scrollable.maybeOf(context);
    final render = findRenderParagraph(textKey);
    final viewport =
        render != null ? RenderAbstractViewport.maybeOf(render) : null;
    if (scrollable == null || render == null || viewport == null) return;

    final edge = render
        .getOffsetForCaret(
          TextPosition(offset: restoreCharOffset.clamp(0, content.length)),
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

    final caretTop =
        render.getOffsetForCaret(TextPosition(offset: idx), Rect.zero).dy;
    final caretGlobalTop = render.localToGlobal(Offset(0, caretTop)).dy;
    final vpTop = viewportBox.localToGlobal(Offset.zero).dy;
    final vpBottom = vpTop + viewportBox.size.height;
    return (idx, caretGlobalTop, render, viewport, vpTop, vpBottom);
  }
}
