import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether a chapter group accordion is expanded.
/// Key format: "$bookId:$groupIndex"
final chapterGroupExpandedProvider =
    StateProvider.family.autoDispose<bool, String>((ref, key) {
  // Defaults to expanded for first group (index 0)
  final parts = key.split(':');
  final index = int.tryParse(parts.last) ?? 0;
  return index == 0;
});

