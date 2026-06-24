import 'package:drift/drift.dart';

import 'books.dart';

class BookTypographyOverrides extends Table {
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get profileId => text().nullable()();
  TextColumn get customSettings => text().nullable()(); // JSON

  @override
  Set<Column> get primaryKey => {bookId};
}
