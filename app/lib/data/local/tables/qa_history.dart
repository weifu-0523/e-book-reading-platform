import 'package:drift/drift.dart';

/// One row per Q&A interaction (question + answer + cited chapter indices).
///
/// citationsJson stores a JSON-encoded List<int> of chapter indices
/// parsed from [ch=N] markers in the LLM answer (e.g. "[3,5,8]").
class QaHistory extends Table {
  TextColumn get id => text()(); // uuid (36 chars)
  TextColumn get bookId => text()();
  TextColumn get question => text()();
  TextColumn get answer => text()();
  TextColumn get citationsJson => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
