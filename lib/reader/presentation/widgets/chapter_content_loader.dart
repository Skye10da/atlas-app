import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_styles.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';

class ChapterContentLoader extends ConsumerWidget {
  const ChapterContentLoader({
    super.key,
    required this.chapter,
    required this.fontSize,
    this.fontFamily,
    required this.lineHeight,
    required this.letterSpacing,
    required this.vt,
    this.textAlignment = TextAlignment.left,
    this.marginPreset = MarginPreset.normal,
    this.scrollable = true,
    this.chapterStyle,
  });

  final ChapterEntity chapter;
  final double fontSize;
  final String? fontFamily;
  final double lineHeight;
  final double letterSpacing;
  final ReadingViewTheme vt;
  final TextAlignment textAlignment;
  final MarginPreset marginPreset;
  final bool scrollable;
  final ChapterStyle? chapterStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync =
        ref.watch(readerChapterContentProvider(chapter.contentPath));

    return contentAsync.when(
      loading: () => const AppLoading(),
      error: (err, _) => Center(
        child: Text('Could not load chapter.',
            style: TextStyle(color: vt.text)),
      ),
      data: (content) => Container(
        color: vt.background,
        child: ChapterView(
          content: content,
          fontSize: fontSize,
          fontFamily: fontFamily,
          lineHeight: lineHeight,
          letterSpacing: letterSpacing,
          theme: vt,
          textAlignment: textAlignment,
          marginPreset: marginPreset,
          scrollable: scrollable,
          dropCapStyle: chapterStyle?.dropCapStyle,
        ),
      ),
    );
  }
}
