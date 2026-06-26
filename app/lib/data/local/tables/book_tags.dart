import 'package:drift/drift.dart';

class BookTags extends Table {
  TextColumn get bookId => text()
      .customConstraint('REFERENCES books(id) ON DELETE CASCADE')();
  TextColumn get tag => text()();

  @override
  Set<Column> get primaryKey => {bookId, tag};
}
