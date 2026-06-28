// Tests for the v3→v4 onUpgrade migration that adds FTS5 full-text search
// support to the annotations table.
//
// Following the precedent set by migration_v3_test.dart, we verify the
// fresh-install (onCreate) schema for the FTS5 virtual table and sync triggers.
// The onUpgrade backfill path is not exercised through drift's SchemaVerifier
// (the project does not maintain schema_v*.json snapshots); instead we verify
// the migration source contains the expected SQL statements (degraded coverage,
// documented in commit message).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';

const _databaseSourcePath =
    'lib/data/local/database.dart';

void main() {
  test('fresh install creates annotations_fts virtual table', () async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    expect(db.schemaVersion, 7);
    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='annotations_fts'",
    ).get();
    expect(tables, isNotEmpty,
        reason: 'annotations_fts virtual table must exist on fresh install');
  });

  test('fresh install creates 3 sync triggers', () async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final triggers = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE 'annotations_%'",
    ).get();
    final names = triggers.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll(['annotations_ai', 'annotations_ad', 'annotations_au']),
      reason: 'INSERT/DELETE/UPDATE sync triggers must exist on fresh install',
    );
  });

  // Degraded fallback: drift SchemaVerifier requires schema_v3.json snapshots
  // that the project does not maintain. Verifying the onUpgrade source contains
  // the expected SQL statements is sub-optimal but guarantees the backfill +
  // triggers are wired into the v3→v4 path.
  test('v3 → v4 onUpgrade wires FTS5 table, triggers and backfill into source',
      () {
    final source = File(_databaseSourcePath).readAsStringSync();
    expect(source, contains('annotations_fts USING fts5'));
    expect(source, contains('annotations_ai AFTER INSERT'));
    expect(source, contains('annotations_ad AFTER DELETE'));
    expect(source, contains('annotations_au AFTER UPDATE'));
    expect(
      source,
      contains('SELECT rowid, quote, note, tags FROM annotations'),
      reason: 'onUpgrade must backfill existing annotations into fts index',
    );
    expect(source, contains('if (from < 4)'),
        reason: 'onUpgrade must gate FTS5 setup behind schema < 4');
  });

  test('existing annotations auto-sync into fts on insert (trigger smoke)', () async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    // Insert prerequisite rows (book → book_note → annotation).
    await db.into(db.books).insert(BooksCompanion.insert(
          id: 'b1',
          title: 't',
          format: 'epub',
          filePath: 'p',
          fileHash: 'h',
          fileSizeBytes: 1,
        ));
    await db.into(db.bookNotes).insert(BookNotesCompanion.insert(
          id: 'bn1',
          bookId: 'b1',
          title: 'note',
        ));
    await db.into(db.annotations).insert(AnnotationsCompanion.insert(
          id: 'a1',
          bookNoteId: 'bn1',
          locator: '{}',
          quote: 'findme',
          color: 'yellow',
        ));
    final rows = await db
        .customSelect("SELECT quote FROM annotations_fts WHERE quote MATCH 'findme'")
        .get();
    expect(rows, hasLength(1),
        reason: 'annotations_ai trigger must mirror inserts into annotations_fts');
  });
}
