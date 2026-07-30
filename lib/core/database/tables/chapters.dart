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

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Index> get indexes => [Index('idx_chapters_book', 'bookId')];
}
