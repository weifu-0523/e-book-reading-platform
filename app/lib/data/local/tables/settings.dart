import 'package:drift/drift.dart';

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()(); // JSON-encoded

  @override
  Set<Column> get primaryKey => {key};
}
