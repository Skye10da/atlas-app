import 'package:drift/drift.dart';

class Characters extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get name => text()();
  TextColumn get aliases => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get role => text().nullable()();
  TextColumn get firstAppearance => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Index> get indexes => [Index('idx_characters_book', 'bookId')];
}
