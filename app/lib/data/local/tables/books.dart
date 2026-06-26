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
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastReadAt => dateTime().nullable()();

  /// M3.1：手动排序顺序；null = 不参与手动排序，按默认排序。
  IntColumn get sortOrder => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
