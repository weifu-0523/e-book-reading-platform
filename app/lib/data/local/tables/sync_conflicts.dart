import 'package:drift/drift.dart';

/// One row per sync conflict detected during pull.
///
/// A "conflict" means: remote record's mtime was NOT strictly after the
/// local row's mtime, so the applier skipped the replacement. We log it
/// so users can see which writes lost (LWW is silent otherwise).
///
/// Purge policy: rows older than 30 days are removed by SyncController
/// after each successful syncNow().
class SyncConflicts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recordId => text()();
  TextColumn get recordType => text()(); // 'annotation' | 'bookNote' | 'readingProgress'
  DateTimeColumn get localMtime => dateTime()();
  DateTimeColumn get remoteMtime => dateTime()();
  TextColumn get winnerDevice => text()(); // always local deviceId (LWW semantics)
  TextColumn get loserDevice => text()();  // remote snapshot source deviceId
  DateTimeColumn get detectedAt => dateTime()();
  TextColumn get payloadPreview => text()(); // remote payload JSON, truncated to 200 chars
}
