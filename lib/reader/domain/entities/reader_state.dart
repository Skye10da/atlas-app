import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';

enum ReadingTheme { light, dark, sepia }

class ReaderState {
  const ReaderState({
    required this.book,
    required this.currentChapter,
    required this.chapters,
    this.scrollPosition = 0.0,
    this.progress = 0.0,
    this.fontSize = 18.0,
    this.theme = ReadingTheme.light,
    this.isLoading = false,
  });

  final BookEntity book;
  final ChapterEntity currentChapter;
  final List<ChapterEntity> chapters;
  final double scrollPosition;
  final double progress;
  final double fontSize;
  final ReadingTheme theme;
  final bool isLoading;

  ReaderState copyWith({
    BookEntity? book,
    ChapterEntity? currentChapter,
    List<ChapterEntity>? chapters,
    double? scrollPosition,
    double? progress,
    double? fontSize,
    ReadingTheme? theme,
    bool? isLoading,
  }) {
    return ReaderState(
      book: book ?? this.book,
      currentChapter: currentChapter ?? this.currentChapter,
      chapters: chapters ?? this.chapters,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      progress: progress ?? this.progress,
      fontSize: fontSize ?? this.fontSize,
      theme: theme ?? this.theme,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  int get currentChapterIndex => chapters.indexOf(currentChapter);
  bool get hasNextChapter => currentChapterIndex < chapters.length - 1;
  bool get hasPrevChapter => currentChapterIndex > 0;
}
