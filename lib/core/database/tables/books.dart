import 'package:drift/drift.dart';

class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get format => text()();
  TextColumn get filePath => text()();
  TextColumn get itemType => text().withDefault(const Constant('book'))();
  IntColumn get fileSize => integer().nullable()();
  IntColumn get totalChapters => integer()();
  TextColumn get language => text().nullable()();
  TextColumn get tags => text().nullable()();
  TextColumn get sourceName => text().nullable()();
  TextColumn get sourceId => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  RealColumn get rating => real().nullable()();
  TextColumn get status => text().nullable()();

  /// Update tracking (ongoing novels): whether periodic checks should run.
  BoolColumn get updateTrackingEnabled =>
      boolean().withDefault(const Constant(true))();

  /// Last time an update check was performed for this book.
  DateTimeColumn get lastCheckedAt => dateTime().nullable()();

  /// Number of newly discovered chapters not yet acknowledged by opening
  /// the book.
  IntColumn get newChapterCount => integer().withDefault(const Constant(0))();

  /// True when new chapters were found since the book was last opened.
  BoolColumn get hasUpdate => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
