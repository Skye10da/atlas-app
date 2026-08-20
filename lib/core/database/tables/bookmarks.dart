import 'package:drift/drift.dart';

class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get chapterId => text()();
  IntColumn get position => integer()();
  TextColumn get note => text().nullable()();
  TextColumn get color => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Index> get indexes => [
    Index('idx_bookmarks_book', 'bookId'),
    Index('idx_bookmarks_chapter', 'chapterId'),
  ];
}
