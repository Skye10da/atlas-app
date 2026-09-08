import 'package:drift/drift.dart';

class ReadingGoals extends Table {
  TextColumn get id => text()();
  IntColumn get weeklyChapterTarget => integer().withDefault(const Constant(20))();
  IntColumn get dailyMinuteTarget => integer().withDefault(const Constant(30))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

