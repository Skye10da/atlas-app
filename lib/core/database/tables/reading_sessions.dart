import 'package:drift/drift.dart';

class ReadingSessions extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get durationSeconds => integer()();
  IntColumn get chaptersRead => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get sessionDate => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

