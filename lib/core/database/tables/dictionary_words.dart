import 'package:drift/drift.dart';

class DictionaryWords extends Table {
  TextColumn get id => text()();

  TextColumn get word => text()();

  TextColumn get language => text()();

  TextColumn get languageLabel => text()();

  TextColumn get phonetic => text().nullable()();

  TextColumn get partOfSpeech => text()();

  TextColumn get definition => text()();

  TextColumn get fullJson => text()();

  DateTimeColumn get savedAt => dateTime()();

  TextColumn get sourceSentence => text().nullable()();

  TextColumn get sourceTitle => text().nullable()();

  IntColumn get reviewLevel => integer().withDefault(const Constant(0))();

  IntColumn get reviewCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastReviewedAt => dateTime().nullable()();

  DateTimeColumn get nextReviewAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Index> get indexes => [
        Index('idx_dict_word', 'word'),
        Index('idx_dict_lang', 'language'),
      ];
}
