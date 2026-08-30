/// Utility for normalizing book titles into clean, filesystem-safe,
/// and collision-resistant identifiers.
///
/// Handles Unicode characters across alphabets and scripts (Latin, CJK,
/// Cyrillic, Arabic, etc.) without reducing non-ASCII titles to empty strings.
class BookIdNormalizer {
  const BookIdNormalizer._();

  static final _nonAlphaNum = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
  static final _multiUnderscore = RegExp(r'_+');
  static final _trimUnderscore = RegExp(r'^_+|_+$');

  /// Normalizes a [title] into a valid ID.
  ///
  /// Preserves Unicode letters and numbers across any writing system, strips
  /// filesystem-unsafe punctuation, and falls back to a deterministic hash
  /// if the title contains only punctuation or whitespace.
  static String normalize(String title) {
    var slug = title
        .trim()
        .toLowerCase()
        .replaceAll(_nonAlphaNum, '_')
        .replaceAll(_multiUnderscore, '_')
        .replaceAll(_trimUnderscore, '');

    if (slug.isEmpty) {
      slug = 'book_${title.trim().hashCode.abs()}';
    }

    if (slug.length > 48) {
      slug = '${slug.substring(0, 48)}_${slug.hashCode.abs()}';
    }

    return slug;
  }
}

