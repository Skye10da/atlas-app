import 'package:atlas_app/reader/speech/speech_models.dart';

/// Wraps the ordered list of SpeechItems for a chapter so cursor logic
/// lives in one place instead of being reimplemented (or subtly diverging)
/// wherever SpeechEngine would otherwise index a raw list directly.
class SpeechQueue {
  SpeechQueue(List<SpeechItem> items) : _items = List.unmodifiable(items);

  final List<SpeechItem> _items;
  int _cursor = 0;

  SpeechItem? get current => itemAt(_cursor);
  SpeechItem? itemAt(int i) => (i >= 0 && i < _items.length) ? _items[i] : null;

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  int get length => _items.length;
  int get cursor => _cursor;
  bool get isAtEnd => _cursor >= _items.length - 1;
  bool get isAtStart => _cursor <= 0;

  /// Advances the cursor and returns the new current item, or null if
  /// already at the end (queue exhausted — caller should treat this as
  /// "chapter finished", per ASA §7's ownership split).
  SpeechItem? next() {
    if (_cursor + 1 >= _items.length) return null;
    return itemAt(++_cursor);
  }

  SpeechItem? previous() {
    if (_cursor - 1 < 0) return null;
    return itemAt(--_cursor);
  }

  SpeechItem? peekNext() => itemAt(_cursor + 1);
  SpeechItem? peekPrevious() => itemAt(_cursor - 1);

  List<SpeechItem> remaining() => _items.sublist(_cursor);

  void reset() => _cursor = 0;

  /// Used on session restore (ASA §8, "Restore Queue") to jump straight to
  /// a checkpointed sentence index rather than replaying from the start.
  bool seekTo(int index) {
    if (index < 0 || index >= _items.length) return false;
    _cursor = index;
    return true;
  }

  /// True if [item] is the last SpeechItem belonging to its paragraph —
  /// i.e. the next item (if any) starts a new paragraph. Used by
  /// SpeechEngine to decide when to emit ParagraphFinished.
  bool isLastInParagraph(SpeechItem item) {
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx == -1) return false;
    final next = itemAt(idx + 1);
    return next == null || next.paragraphIndex != item.paragraphIndex;
  }
}
