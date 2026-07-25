import 'package:drift/drift.dart';

class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get format => text()();
  TextColumn get filePath => text()();
  IntColumn get fileSize => integer().nullable()();
  IntColumn get totalChapters => integer()();
  TextColumn get language => text().nullable()();
  TextColumn get tags => text().nullable()();
  RealColumn get rating => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
