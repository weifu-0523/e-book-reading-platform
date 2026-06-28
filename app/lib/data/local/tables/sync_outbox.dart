import 'package:drift/drift.dart';

/// Outbox of sync writes pending push to WebDAV.
/// Rows stay in the table after push (pushed_at non-null) so we can debug
/// and re-play if needed. A periodic cleanup task (out of scope for M2.0a MVP)
/// can prune rows older than 7 days.
class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recordId => text()();
  TextColumn get recordType => text()(); // 'book' | 'bookNote' | 'annotation' | 'readingProgress'
  TextColumn get payloadJson => text()();
  DateTimeColumn get queuedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get pushedAt => dateTime().nullable()(); // null = pending
}
