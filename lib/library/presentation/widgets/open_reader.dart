import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';

Future<void> openReader({
  required String bookId,
  required WidgetRef ref,
  required BuildContext context,
  required BookEntity book,
  required List<ChapterEntity> chapters,
  String? lastReadChapterId,
  String? chapterId,
  VoidCallback? onReturn,
}) async {
  final navigator = GoRouter.of(context);
  final libRepo = DriftLibraryRepository(ref.read(databaseProvider));
  await libRepo.markAsOpened(bookId);
  final base = '/reader/${book.id}';
  final params = <String, String>{};

  if (book.format == 'pdf') {
    final target = chapterId ?? lastReadChapterId;
    final chapter = chapters.where((c) => c.id == target).firstOrNull;
    if (chapter != null && chapter.pageCount > 0) {
      params['page'] = '${chapter.pageCount}';
    }
  } else {
    final id = chapterId ?? lastReadChapterId;
    if (id != null) {
      params['chapterId'] = id;
    }
    if (book.progress != null && book.progress! > 0) {
      params['progress'] = (book.progress! / 100).toStringAsFixed(4);
    }
  }

  final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
  final route = query.isNotEmpty ? '$base?$query' : base;
  await navigator.push(route);
  if (context.mounted) {
    onReturn?.call();
  }
}
