import 'package:drift/drift.dart';

class WebHistory extends Table {
  TextColumn get id => text()();
  TextColumn get url => text()();
  TextColumn get title => text().nullable()();
  DateTimeColumn get visitedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Index> get indexes => [Index('idx_web_history_url', 'url')];
}