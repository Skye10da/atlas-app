import 'package:drift/drift.dart';

class Chapters extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get index => integer()();
  TextColumn get title => text()();
  TextColumn get contentPath => text()();
  IntColumn get wordCount => integer()();
  IntColumn get contentState => integer().withDefault(const Constant(0))();
  IntColumn get pageCount => integer()();
  DateTimeColumn get createdAt => dateTime()();

  /// Content versioning (CDA v2.2): bumped whenever the chapter's content
  /// changes after a re-fetch.
  IntColumn get version => integer().withDefault(const Constant(1))();

  /// sha256(content) of the currently stored content.
  TextColumn get checksum => text().nullable()();

  /// Id of the previous content version, if this chapter has been re-fetched.
  TextColumn get previousVersionRef => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Index> get indexes => [Index('idx_chapters_book', 'bookId')];
}
