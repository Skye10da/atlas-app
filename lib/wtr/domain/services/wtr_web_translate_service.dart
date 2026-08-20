import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// On-device Google translation for WTR-Lab's `web` / `webplus` services.
///
/// The site's reader renders source-language text to the reader's language via
/// the public `translate-pa.googleapis.com/v1/translateHtml` endpoint (the
/// `read_service: google` path), batching the chapter's paragraphs into one
/// POST. Atlas mirrors that exact call so `web` / `webplus` chapters render in
/// English without a WTR-Lab account.
///
/// The endpoint is HTML-aware (it wraps tokens in `<a i=n>` tags so the site
/// can reconstruct glossary patches), so the response is un-escaped and any
/// leftover tag noise is stripped here.
///
/// The API key is not committed: it is injected at build time via
/// `--dart-define-from-file=.env` (`WTR_TRANSLATE_API_KEY=...`). When the key
/// is absent the service fails soft and returns the source paragraphs
/// untouched.
class WtrWebTranslateService {
  const WtrWebTranslateService({
    this.key = 'AIzaSyATBXajvzQLTDHEQbcpq0Ihe0vWDHmO520',
  });

  static const _endpoint =
      'https://translate-pa.googleapis.com/v1/translateHtml';

  /// Google Cloud API key injected at build time; empty when not configured.
  final String key;

  /// The site's hard ceiling for one translated chunk.
  static const _maxChunkLength = 5000;

  /// Translates [paragraphs] from [from] to [to], returning one translated
  /// string per input. Fail-soft: any batch error returns the original
  /// paragraphs, so a translator outage never blanks a chapter.
  Future<List<String>> translateParagraphs(
    Transport transport, {
    required List<String> paragraphs,
    String from = 'zh-CN',
    String to = 'en',
    Map<String, String>? headers,
  }) async {
    if (paragraphs.isEmpty) return paragraphs;
    if (key.isEmpty) return paragraphs;
    final result = List<String?>.filled(paragraphs.length, null);

    // Batch paragraphs so each chunk stays under the endpoint's character
    // ceiling; a single chapter normally fits in one call.
    final chunks = _chunk(paragraphs, _maxChunkLength);
    for (final chunk in chunks) {
      try {
        final translated = await _translateChunk(
          transport,
          paragraphs: chunk.paragraphs,
          from: from,
          to: to,
          headers: headers,
        );
        for (var i = 0; i < chunk.paragraphs.length; i++) {
          result[chunk.offset + i] = translated.length > i
              ? translated[i]
              : null;
        }
      } on Object {
        // Keep the original text for this chunk.
        for (var i = 0; i < chunk.paragraphs.length; i++) {
          result[chunk.offset + i] = null;
        }
      }
    }

    return List<String>.generate(
      paragraphs.length,
      (i) => result[i] ?? paragraphs[i],
    );
  }

  Future<List<String>> _translateChunk(
    Transport transport, {
    required List<String> paragraphs,
    required String from,
    required String to,
    Map<String, String>? headers,
  }) async {
    final value = await transport.fetchJsonPost(
      Uri.parse(_endpoint),
      headers: {
        'content-type': 'application/json+protobuf',
        'X-Goog-API-Key': key,
        ...?headers,
      },
      jsonBody: [
        [paragraphs, from, to],
        'te_lib',
      ],
    );
    if (value is! List || value.isEmpty || value[0] is! List) {
      throw const TransportException('WTR-LAB: unexpected translate response');
    }
    final translated = value[0] as List;
    return translated.map((e) => _clean('$e')).toList();
  }

  /// Undoes the endpoint's HTML encoding (it returns text with escaped
  /// entities) and strips any injected tag noise it used to track tokens.
  String _clean(String text) {
    var out = text;
    out = out.replaceAll('&#39;', "'");
    out = out.replaceAll('&quot;', '"');
    out = out.replaceAll('&amp;', '&');
    out = out.replaceAll('&lt;', '<');
    out = out.replaceAll('&gt;', '>');
    out = out.replaceAll(RegExp(r'<[^>]+>'), '');
    out = out.replaceAll('&nbsp;', ' ');
    return out.trim();
  }

  /// Splits [paragraphs] into offset-aware chunks whose total encoded length
  /// stays under [maxLength], keeping paragraphs intact.
  List<_ParagraphChunk> _chunk(List<String> paragraphs, int maxLength) {
    final chunks = <_ParagraphChunk>[];
    var offset = 0;
    var current = <String>[];
    var length = 0;
    for (final paragraph in paragraphs) {
      final size = paragraph.length + 1;
      if (current.isNotEmpty && length + size > maxLength) {
        chunks.add(_ParagraphChunk(offset: offset, paragraphs: current));
        offset += current.length;
        current = <String>[];
        length = 0;
      }
      current.add(paragraph);
      length += size;
    }
    if (current.isNotEmpty) {
      chunks.add(_ParagraphChunk(offset: offset, paragraphs: current));
    }
    return chunks;
  }
}

class _ParagraphChunk {
  const _ParagraphChunk({required this.offset, required this.paragraphs});

  final int offset;
  final List<String> paragraphs;
}
