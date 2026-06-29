import 'package:drift/drift.dart';

/// One row per chunked passage of a book's chapter text.
///
/// Populated by BookPreprocessor (T5) in Phase 1 (chunking). Read by
/// BookQaService (T10) via BookPassagesDao.searchFts for same-book Q&A
/// retrieval. The companion book_passages_fts virtual table mirrors
/// content_text for future relevance-ranking; current retrieval uses
/// substring LIKE (CJK-friendly).
class BookPassages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();
  IntColumn get chapterIndex => integer()();
  IntColumn get charOffset => integer()();
  IntColumn get charLength => integer()();
  TextColumn get contentText => text()();
  IntColumn get tokenEstimate => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
