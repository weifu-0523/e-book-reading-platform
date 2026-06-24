import 'package:drift/drift.dart';

class TypographyProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get settings => text()(); // JSON
  BoolColumn get isDefault =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
