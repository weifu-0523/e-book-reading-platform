import 'package:drift/drift.dart';

import 'books.dart';

/// AI guide summary cache. One row per successful stream completion.
/// Hit rule: (book_id, mode, source_hash, prompt_version) all match.
class AiSummaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get mode => text()(); // 'full' | 'chapter' | 'selection'
  TextColumn get sourceHash => text()(); // sha256(truncatedSourceText)
  TextColumn get summaryText => text()();
  TextColumn get modelName => text()();
  TextColumn get baseUrl => text()();
  DateTimeColumn get generatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  IntColumn get promptVersion => integer()();
}
