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

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Index> get indexes => [
        Index('idx_dict_word', 'word'),
        Index('idx_dict_lang', 'language'),
      ];
}
