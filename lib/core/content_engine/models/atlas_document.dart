/// Canonical post-normalization content model.
///
/// Every subsystem downstream of the Cleaner/Normalizer stage — Reader
/// rendering, Search Indexer, Dictionary Indexer, Character Extractor, AI
/// context retrieval — consumes [AtlasDocument], never raw HTML. HTML is a
/// Content Normalizer implementation detail.
class AtlasDocument {
  const AtlasDocument({
    required this.title,
    this.blocks = const [],
    this.annotations = const [],
    required this.metadata,
  });

  factory AtlasDocument.fromJson(Map<String, Object?> json) {
    final title = json['title'];
    final metadata = json['metadata'];
    return AtlasDocument(
      title: title is String ? title : '',
      blocks: _decodeList(json['blocks'], ContentBlock.fromJson),
      annotations: _decodeList(json['annotations'], Annotation.fromJson),
      metadata: metadata is Map<String, Object?>
          ? DocumentMetadata.fromJson(metadata)
          : const DocumentMetadata(),
    );
  }

  final String title;

  /// All content blocks in document order. This is the canonical reading
  /// surface — a renderer walks [blocks], it never re-parses HTML.
  final List<ContentBlock> blocks;

  /// Inline annotations (character extractor output, translator notes, ...).
  /// Not yet produced by the normalizer; reserved for future stages.
  final List<Annotation> annotations;

  final DocumentMetadata metadata;

  /// Text-bearing blocks (paragraphs, headings, quotes, lists, pre) in order.
  List<TextBlock> get textBlocks => blocks.whereType<TextBlock>().toList();

  List<ImageBlock> get images => blocks.whereType<ImageBlock>().toList();

  List<FootnoteBlock> get footnotes =>
      blocks.whereType<FootnoteBlock>().toList();

  int get wordCount => textBlocks.fold(
    0,
    (count, b) => count + b.text.split(RegExp(r'\s+')).length,
  );

  /// Interim plain-text serialization used to bridge [AtlasDocument] into the
  /// existing `ChapterModel.content` (String) contract until the structured
  /// JSON is persisted in Phase 0/2. Text blocks are joined by blank lines;
  /// images/footnotes are dropped for text rendering.
  String renderToText() => textBlocks.map((b) => b.text).join('\n\n').trim();

  Map<String, Object?> toJson() => {
    'title': title,
    'blocks': blocks.map((b) => b.toJson()).toList(),
    'annotations': annotations.map((a) => a.toJson()).toList(),
    'metadata': metadata.toJson(),
  };

  static List<T> _decodeList<T>(
    Object? raw,
    T Function(Map<String, Object?>) decode,
  ) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => decode(Map<String, Object?>.from(e)))
        .toList();
  }
}

/// A single unit of reading content in document order.
sealed class ContentBlock {
  factory ContentBlock.fromJson(Map<String, Object?> json) {
    switch (json['type']) {
      case 'paragraph':
        return ParagraphBlock.fromJson(json);
      case 'heading':
        return HeadingBlock.fromJson(json);
      case 'quote':
        return QuoteBlock.fromJson(json);
      case 'list':
        return ListBlock.fromJson(json);
      case 'pre':
        return PreBlock.fromJson(json);
      case 'image':
        return ImageBlock.fromJson(json);
      case 'footnote':
        return FootnoteBlock.fromJson(json);
      default:
        throw FormatException('Unknown ContentBlock type: ${json['type']}');
    }
  }
  const ContentBlock();

  Map<String, Object?> toJson();
}

/// Base class for text-bearing blocks (paragraphs, headings, quotes, lists,
/// pre-formatted blocks).
sealed class TextBlock extends ContentBlock {
  const TextBlock({required this.text});

  final String text;
}

class ParagraphBlock extends TextBlock {
  const ParagraphBlock({required super.text});

  factory ParagraphBlock.fromJson(Map<String, Object?> json) =>
      ParagraphBlock(text: (json['text'] as String?) ?? '');

  @override
  Map<String, Object?> toJson() => {'type': 'paragraph', 'text': text};
}

class HeadingBlock extends TextBlock {
  factory HeadingBlock.fromJson(Map<String, Object?> json) => HeadingBlock(
    text: (json['text'] as String?) ?? '',
    level: (json['level'] as num?)?.toInt() ?? 1,
  );
  const HeadingBlock({required super.text, required this.level});

  final int level;

  @override
  Map<String, Object?> toJson() => {
    'type': 'heading',
    'text': text,
    'level': level,
  };
}

class QuoteBlock extends TextBlock {
  const QuoteBlock({required super.text});

  factory QuoteBlock.fromJson(Map<String, Object?> json) =>
      QuoteBlock(text: (json['text'] as String?) ?? '');

  @override
  Map<String, Object?> toJson() => {'type': 'quote', 'text': text};
}

class ListBlock extends TextBlock {
  const ListBlock({required super.text});

  factory ListBlock.fromJson(Map<String, Object?> json) =>
      ListBlock(text: (json['text'] as String?) ?? '');

  @override
  Map<String, Object?> toJson() => {'type': 'list', 'text': text};
}

class PreBlock extends TextBlock {
  const PreBlock({required super.text});

  factory PreBlock.fromJson(Map<String, Object?> json) =>
      PreBlock(text: (json['text'] as String?) ?? '');

  @override
  Map<String, Object?> toJson() => {'type': 'pre', 'text': text};
}

class ImageBlock extends ContentBlock {
  factory ImageBlock.fromJson(Map<String, Object?> json) {
    final src = json['src'];
    final alt = json['alt'];
    final caption = json['caption'];
    return ImageBlock(
      src: src is String ? src : '',
      alt: alt is String ? alt : null,
      caption: caption is String ? caption : null,
    );
  }
  const ImageBlock({required this.src, this.alt, this.caption});

  final String src;
  final String? alt;
  final String? caption;

  @override
  Map<String, Object?> toJson() => {
    'type': 'image',
    'src': src,
    if (alt != null) 'alt': alt,
    if (caption != null) 'caption': caption,
  };
}

class FootnoteBlock extends ContentBlock {
  factory FootnoteBlock.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final text = json['text'];
    return FootnoteBlock(
      id: id is String ? id : '',
      text: text is String ? text : '',
    );
  }
  const FootnoteBlock({required this.id, required this.text});

  final String id;
  final String text;

  @override
  Map<String, Object?> toJson() => {'type': 'footnote', 'id': id, 'text': text};
}

class Annotation {
  factory Annotation.fromJson(Map<String, Object?> json) {
    final text = json['text'];
    final type = json['type'];
    final target = json['target'];
    return Annotation(
      text: text is String ? text : null,
      type: type is String ? type : null,
      target: target is String ? target : null,
    );
  }
  const Annotation({this.text, this.type, this.target});

  final String? text;
  final String? type;
  final String? target;

  Map<String, Object?> toJson() => {
    if (text != null) 'text': text,
    if (type != null) 'type': type,
    if (target != null) 'target': target,
  };
}

class DocumentMetadata {
  factory DocumentMetadata.fromJson(Map<String, Object?> json) {
    final publishedAt = json['publishedAt'];
    final tags = json['tags'];
    return DocumentMetadata(
      sourceUrl: json['sourceUrl'] as String?,
      sourceId: json['sourceId'] as String?,
      sourceName: json['sourceName'] as String?,
      language: json['language'] as String?,
      publishedAt: publishedAt is String
          ? DateTime.tryParse(publishedAt)
          : null,
      tags: tags is List ? tags.whereType<String>().toList() : const [],
      author: json['author'] as String?,
    );
  }
  const DocumentMetadata({
    this.sourceUrl,
    this.sourceId,
    this.sourceName,
    this.language,
    this.publishedAt,
    this.tags = const [],
    this.author,
  });

  final String? sourceUrl;
  final String? sourceId;
  final String? sourceName;
  final String? language;
  final DateTime? publishedAt;
  final List<String> tags;
  final String? author;

  Map<String, Object?> toJson() => {
    if (sourceUrl != null) 'sourceUrl': sourceUrl,
    if (sourceId != null) 'sourceId': sourceId,
    if (sourceName != null) 'sourceName': sourceName,
    if (language != null) 'language': language,
    if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
    'tags': tags,
    if (author != null) 'author': author,
  };
}
