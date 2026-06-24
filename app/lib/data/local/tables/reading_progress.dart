import 'package:drift/drift.dart';

import 'books.dart';

class ReadingProgressTable extends Table {
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get locator => text()(); // JSON
  RealColumn get percent => real()();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {bookId};
}
