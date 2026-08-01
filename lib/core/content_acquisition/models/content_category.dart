enum ContentCategory {
  book,
  novel;

  static ContentCategory fromName(String? name) {
    return name == ContentCategory.novel.name ? ContentCategory.novel : ContentCategory.book;
  }
}
