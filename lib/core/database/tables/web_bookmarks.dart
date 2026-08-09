import 'package:drift/drift.dart';

class WebBookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get url => text()();
  TextColumn get title => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Index> get indexes => [Index('idx_web_bookmarks_url', 'url')];
}