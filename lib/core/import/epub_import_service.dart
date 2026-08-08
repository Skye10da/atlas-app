import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:epub_plus/epub_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart' as xml;

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';

class EpubImportService {
  const EpubImportService(this._db);

  final AppDatabase _db;

  /// Prompts the user to pick an EPUB and imports it. Returns the imported
  /// book id, or `null` when the picker was cancelled (a success result).
  Future<Result<String?>> pickAndImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return const Success(null);
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        return const Failure(ValidationException('Could not read file'));
      }

      return _importFromBytes(bytes, file.name);
    } on Exception catch (e) {
      return Failure(ValidationException('Failed to pick file: $e'));
    }
  }

  /// Imports an EPUB from raw bytes. Public entry point so the pipeline can be
  /// exercised without the file picker. Resolves to the imported book id.
  Future<Result<String>> importBytes(List<int> bytes, String fileName) {
    return _importFromBytes(bytes, fileName);
  }

  Future<Result<String>> _importFromBytes(List<int> bytes, String fileName) async {
    try {
      final book = await _readBookResilient(bytes);

      final title = book.title ?? fileName.replaceAll('.epub', '');
      final author = book.author ?? 'Unknown Author';
      final bookId = _normalizeId(title);

      final meta = book.schema?.package?.metadata;
      final description = meta?.description;
      final language = meta?.languages.isNotEmpty == true ? meta!.languages.first : null;
      final tags = meta?.subjects.isNotEmpty == true ? meta!.subjects : null;
      final sourceUrl = meta?.sources.isNotEmpty == true ? meta!.sources.first : null;

      final existing = await (_db.select(_db.books)..where((b) => b.id.equals(bookId))).get();
      if (existing.isNotEmpty) {
        return const Failure(DuplicateBookException('Book already exists'));
      }

      final dir = await getApplicationDocumentsDirectory();
      final bookDir = Directory(p.join(dir.path, 'books', bookId));
      if (!await bookDir.exists()) {
        await bookDir.create(recursive: true);
      }

      String? coverPath;
      final manifest = book.schema?.package?.manifest;
      final items = manifest?.items ?? [];
      final metaItems = book.schema?.package?.metadata?.metaItems ?? [];

      EpubManifestItem? coverItem;
      for (final item in items) {
        if (item.id?.toLowerCase() == 'cover-image') {
          coverItem = item;
          break;
        }
      }
      if (coverItem == null) {
        for (final meta in metaItems) {
          if (meta.name?.toLowerCase() == 'cover' && meta.content != null) {
            final cid = meta.content!.toLowerCase();
            for (final item in items) {
              if (item.id?.toLowerCase() == cid) {
                coverItem = item;
                break;
              }
            }
            if (coverItem != null) break;
          }
        }
      }
      if (coverItem == null) {
        for (final item in items) {
          if ((item.properties ?? '').toLowerCase().contains('cover-image')) {
            coverItem = item;
            break;
          }
        }
      }
      if (coverItem?.href != null) {
        final href = coverItem!.href!;
        final imageFile = book.content?.images[href];
        if (imageFile?.content != null) {
          final ext = switch (coverItem.mediaType) {
            'image/jpeg' || 'image/jpg' => 'jpg',
            'image/png' => 'png',
            'image/gif' => 'gif',
            'image/webp' => 'webp',
            _ => 'jpg',
          };
          coverPath = p.join(bookDir.path, 'cover.$ext');
          await File(coverPath).writeAsBytes(imageFile!.content!);
        }
      }

      var chapterIndex = 0;
      final flatChapters = _flattenChapters(book.chapters);

      if (flatChapters.isNotEmpty) {
        for (final epubChapter in flatChapters) {
          final html = epubChapter.htmlContent;
          if (html == null) continue;

          final text = _stripHtml(html).trim();
          if (text.isEmpty) continue;

          final chTitle = epubChapter.title ?? 'Chapter ${chapterIndex + 1}';
          chapterIndex = await _writeChapter(bookId, bookDir, chTitle, text, chapterIndex);
        }
      }

      if (chapterIndex == 0) {
        final content = book.content;
        if (content != null) {
          for (final entry in content.html.entries) {
            final raw = entry.value.content;
            if (raw == null) continue;
            final text = _stripHtml(raw).trim();
            if (text.isEmpty) continue;
            chapterIndex = await _writeChapter(bookId, bookDir, 'Chapter ${chapterIndex + 1}', text, chapterIndex);
          }
        }
      }

      if (chapterIndex == 0) {
        return const Failure(ValidationException('No readable content found'));
      }

      await _db.into(_db.books).insert(BooksCompanion(
        id: Value(bookId),
        title: Value(title),
        author: Value(author),
        description: description != null ? Value(description) : const Value(null),
        language: language != null ? Value(language) : const Value(null),
        tags: tags != null ? Value(tags.join(',')) : const Value(null),
        sourceUrl: sourceUrl != null ? Value(sourceUrl) : const Value(null),
        format: const Value('epub'),
        itemType: const Value('book'),
        filePath: Value(bookDir.path),
        totalChapters: Value(chapterIndex),
        coverPath: coverPath != null ? Value(coverPath) : const Value(null),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      return Success(bookId);
    } on Exception catch (e) {
      return Failure(ValidationException('Failed to import epub: $e'));
    }
  }

  Future<int> _writeChapter(String bookId, Directory bookDir, String title, String text, int index) async {
    final chapterId = '${bookId}_ch$index';
    final contentPath = p.join(bookDir.path, '$chapterId.txt');
    await File(contentPath).writeAsString(text);
    await _db.into(_db.chapters).insert(ChaptersCompanion(
      id: Value(chapterId),
      bookId: Value(bookId),
      index: Value(index),
      title: Value(title),
      contentPath: Value(contentPath),
      wordCount: Value(text.split(RegExp(r'\s+')).length),
      pageCount: Value((text.length / 2000).ceil()),
      createdAt: Value(DateTime.now()),
    ));
    return index + 1;
  }

  List<EpubChapter> _flattenChapters(List<EpubChapter> chapters) {
    final flat = <EpubChapter>[];
    for (final ch in chapters) {
      flat.add(ch);
      flat.addAll(_flattenChapters(ch.subChapters));
    }
    return flat;
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<head>.*?</head>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<script.*?>.*?</script>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<style.*?>.*?</style>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeId(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  /// Reads an EPUB, preferring the strict epub_plus parser. Some EPUB3 files
  /// omit `properties="nav"` on their navigation item (including older Atlas
  /// exports), which makes [EpubReader.readBook] throw "TOC item not found".
  /// Those fall back to [EpubReader]-independent parsing driven by the spine.
  Future<EpubBook> _readBookResilient(List<int> bytes) async {
    try {
      return await EpubReader.readBook(bytes);
    } on Exception {
      return _readBookFromSpine(bytes);
    }
  }

  /// Parses an EPUB from its package document + spine order, ignoring the
  /// navigation file entirely, so TOC-less or non-standard EPUB3 books import.
  EpubBook _readBookFromSpine(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final containerEntry = _archiveFile(archive, 'META-INF/container.xml');
    if (containerEntry == null) {
      throw const FormatException('EPUB container.xml not found');
    }
    final containerDoc = xml.XmlDocument.parse(utf8.decode(containerEntry.content));
    final rootFilePath = containerDoc
        .findAllElements('rootfile')
        .firstOrNull
        ?.getAttribute('full-path');
    if (rootFilePath == null || rootFilePath.isEmpty) {
      throw const FormatException('EPUB rootfile not found');
    }
    final rootDir = rootFilePath.contains('/')
        ? '${rootFilePath.substring(0, rootFilePath.lastIndexOf('/'))}/'
        : '';
    final opfEntry = _archiveFile(archive, rootFilePath);
    if (opfEntry == null) {
      throw const FormatException('EPUB package document not found');
    }
    final opfDoc = xml.XmlDocument.parse(utf8.decode(opfEntry.content));

    // Metadata elements are typically dc:-prefixed (dc:title, dc:creator), so
    // match on local name (namespace: '*') rather than the qualified name that
    // findAllElements defaults to.
    final metaNode = opfDoc.findAllElements('metadata').firstOrNull;
    final title = metaNode?.findAllElements('title', namespace: '*').firstOrNull?.innerText;
    final author = metaNode?.findAllElements('creator', namespace: '*').firstOrNull?.innerText;
    final description =
        metaNode?.findAllElements('description', namespace: '*').firstOrNull?.innerText;
    final language =
        metaNode?.findAllElements('language', namespace: '*').firstOrNull?.innerText;
    final subjects = metaNode
        ?.findAllElements('subject', namespace: '*')
        .map((e) => e.innerText)
        .toList();
    final source = metaNode?.findAllElements('source', namespace: '*').firstOrNull?.innerText;

    final items = <String, _ManifestItem>{};
    final manifestItems = <EpubManifestItem>[];
    final html = <String, EpubTextContentFile>{};
    final images = <String, EpubByteContentFile>{};

    for (final item in opfDoc.findAllElements('item')) {
      final id = item.getAttribute('id');
      if (id == null) continue;
      final href = item.getAttribute('href') ?? '';
      final mediaType = item.getAttribute('media-type') ?? '';
      items[id] = _ManifestItem(
        href: href,
        mediaType: mediaType,
        properties: item.getAttribute('properties'),
      );
      manifestItems.add(
        EpubManifestItem(
          id: id,
          href: href,
          mediaType: mediaType,
          properties: item.getAttribute('properties'),
        ),
      );
      if (href.isEmpty) continue;
      final entry = _archiveFile(archive, rootDir + href);
      if (entry == null) continue;
      if (mediaType.contains('xhtml')) {
        html[href] = EpubTextContentFile(
          fileName: href,
          contentMimeType: mediaType,
          content: utf8.decode(entry.content),
        );
      } else if (mediaType.startsWith('image/')) {
        images[href] = EpubByteContentFile(
          fileName: href,
          contentMimeType: mediaType,
          content: entry.content,
        );
      }
    }

    final spineOrder = <String>[];
    for (final itemRef in opfDoc.findAllElements('itemref')) {
      final idRef = itemRef.getAttribute('idref');
      if (idRef != null) spineOrder.add(idRef);
    }

    final chapters = <EpubChapter>[];
    for (final idRef in spineOrder) {
      final item = items[idRef];
      if (item == null || !item.mediaType.contains('xhtml')) continue;
      final contentFile = html[item.href];
      if (contentFile?.content == null) continue;
      chapters.add(
        EpubChapter(
          title: _chapterTitleFromHtml(contentFile!.content!) ??
              'Chapter ${chapters.length + 1}',
          contentFileName: item.href,
          htmlContent: contentFile.content,
        ),
      );
    }

    if (chapters.isEmpty) {
      throw const FormatException('No readable chapters found in EPUB');
    }

    return EpubBook(
      title: title ?? 'Untitled',
      author: author ?? 'Unknown Author',
      authors: author != null ? [author] : const [],
      schema: EpubSchema(
        contentDirectoryPath: rootDir.isEmpty ? null : rootDir.substring(0, rootDir.length - 1),
        package: EpubPackage(
          version: EpubVersion.epub3,
          metadata: EpubMetadata(
            titles: title != null ? [title] : const [],
            creators: [
              EpubMetadataCreator(creator: author ?? 'Unknown Author', role: 'aut'),
            ],
            description: description,
            subjects: subjects ?? const [],
            sources: source != null ? [source] : const [],
            languages: language != null ? [language] : const [],
          ),
          manifest: EpubManifest(items: manifestItems),
        ),
      ),
      content: EpubContent(
        html: html,
        images: images,
        allFiles: {...html, ...images},
      ),
      chapters: chapters,
    );
  }

  String? _chapterTitleFromHtml(String htmlContent) {
    final match = RegExp(
      r'<title[^>]*>(.*?)</title>',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(htmlContent);
    final raw = match?.group(1);
    if (raw == null) return null;
    final cleaned = _stripHtml(raw).trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  ArchiveFile? _archiveFile(Archive archive, String name) {
    for (final file in archive.files) {
      if (file.name == name) return file;
    }
    return null;
  }
}

class _ManifestItem {
  const _ManifestItem({required this.href, required this.mediaType, this.properties});

  final String href;
  final String mediaType;
  final String? properties;
}
