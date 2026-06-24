import 'package:drift/drift.dart';

class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get format => text()(); // 'epub' | 'pdf'
  TextColumn get filePath => text()();
  TextColumn get fileHash => text()();
  IntColumn get fileSizeBytes => integer()();
  TextColumn get coverPath => text().nullable()();
  DateTimeColumn get addedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastReadAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
