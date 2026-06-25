import 'package:drift/drift.dart';

import 'book_notes.dart';

class Annotations extends Table {
  TextColumn get id => text()();
  TextColumn get bookNoteId => text().references(BookNotes, #id)();
  TextColumn get locator => text()(); // JSON
  TextColumn get quote => text()();
  TextColumn get note => text().nullable()();
  TextColumn get color =>
      text()(); // 'yellow' | 'green' | 'blue' | 'red' | 'purple'
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON 数组
  TextColumn get source =>
      text().withDefault(const Constant('manual'))(); // 'manual' | 'aiAssisted'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
