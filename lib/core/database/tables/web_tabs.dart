import 'package:drift/drift.dart';

class WebTabs extends Table {
  TextColumn get id => text()();
  TextColumn get url => text().nullable()();
  TextColumn get title => text().nullable()();
  IntColumn get order => integer()();
  DateTimeColumn get lastActiveAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
