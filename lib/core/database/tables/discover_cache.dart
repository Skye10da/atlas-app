import 'package:drift/drift.dart';

class DiscoverCache extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get category => text()();
  TextColumn get dataJson => text()();
  DateTimeColumn get fetchedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column> get primaryKey => {cacheKey};
}

