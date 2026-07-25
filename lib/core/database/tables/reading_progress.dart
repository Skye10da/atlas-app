import 'package:drift/drift.dart';

class ReadingProgress extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get chapterId => text()();
  RealColumn get percentage => real()();
  IntColumn get position => integer()();
  IntColumn get totalPositions => integer()();
  DateTimeColumn get lastReadAt => dateTime()();
  IntColumn get readingTimeSeconds => integer()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Index> get indexes => [Index('idx_progress_book', 'bookId')];
}
