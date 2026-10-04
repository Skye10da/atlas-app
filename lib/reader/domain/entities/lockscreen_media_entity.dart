// ignore_for_file: sort_constructors_first
import 'dart:io';

/// Domain model for lockscreen / notification widget (mobile + desktop SMTC / MPRIS).
/// Driver-agnostic — maps to `MediaItem` + `PlaybackState` in data layer.
class LockscreenMediaEntity {
  const LockscreenMediaEntity({
    required this.bookId,
    required this.bookTitle,
    required this.chapterTitle,
    required this.author,
    this.coverPath,
    this.artUri,
    this.duration,
    this.position,
    required this.isPlaying,
    required this.playbackSpeed,
  });

  final String bookId;
  final String bookTitle;
  final String chapterTitle;
  final String author;
  final String? coverPath;
  final String? artUri;
  final Duration? duration;
  final Duration? position;
  final bool isPlaying;
  final double playbackSpeed;

  Uri? get artUriParsed {
    if (artUri != null) return Uri.tryParse(artUri!);
    if (coverPath != null && File(coverPath!).existsSync()) {
      return Uri.file(coverPath!);
    }
    return null;
  }

  LockscreenMediaEntity copyWith({
    String? bookId,
    String? bookTitle,
    String? chapterTitle,
    String? author,
    String? coverPath,
    String? artUri,
    Duration? duration,
    Duration? position,
    bool? isPlaying,
    double? playbackSpeed,
  }) {
    return LockscreenMediaEntity(
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      author: author ?? this.author,
      coverPath: coverPath ?? this.coverPath,
      artUri: artUri ?? this.artUri,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'bookTitle': bookTitle,
        'chapterTitle': chapterTitle,
        'author': author,
        if (coverPath != null) 'coverPath': coverPath,
        if (artUri != null) 'artUri': artUri,
        if (duration != null) 'durationMs': duration!.inMilliseconds,
        if (position != null) 'positionMs': position!.inMilliseconds,
        'isPlaying': isPlaying,
        'playbackSpeed': playbackSpeed,
      };

  factory LockscreenMediaEntity.fromJson(Map<String, dynamic> json) {
    return LockscreenMediaEntity(
      bookId: json['bookId'] as String,
      bookTitle: json['bookTitle'] as String,
      chapterTitle: json['chapterTitle'] as String,
      author: json['author'] as String,
      coverPath: json['coverPath'] as String?,
      artUri: json['artUri'] as String?,
      duration: json['durationMs'] != null ? Duration(milliseconds: json['durationMs'] as int) : null,
      position: json['positionMs'] != null ? Duration(milliseconds: json['positionMs'] as int) : null,
      isPlaying: json['isPlaying'] as bool? ?? false,
      playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
    );
  }

  String get mediaId => 'tts_$bookId';
}
