// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:zhiyue/data/local/database.dart';

const _databaseSourcePath = 'lib/data/local/database.dart';

void main() {
  group('schema v15 migration', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting());
    tearDown(() => db.close());

    test('schemaVersion is 15', () {
      expect(db.schemaVersion, 15);
    });

    test('fresh install creates books.last_tts_position column', () async {
      final cols = await db.customSelect('PRAGMA table_info(books)').get();
      final names = cols.map((r) => r.read<String>('name')).toSet();
      expect(names, contains('last_tts_position'));
    });

    test('last_tts_position is nullable TEXT (no NOT NULL constraint)',
        () async {
      final cols = await db.customSelect('PRAGMA table_info(books)').get();
      final col = cols
          .firstWhere((r) => r.read<String>('name') == 'last_tts_position');
      // notnull = 1 means NOT NULL; we expect nullable -> 0.
      expect(col.read<int>('notnull'), 0,
          reason:
              'last_tts_position must be nullable so existing rows survive migration');
      // type = TEXT (JSON-encoded {chapterIdx, sentenceIdx, updatedAt})
      expect(col.read<String>('type'), 'TEXT');
    });

    test('inserting a book without last_tts_position defaults to NULL',
        () async {
      await db.into(db.books).insert(BooksCompanion.insert(
            id: 'b-default',
            title: 't',
            format: 'epub',
            filePath: '/tmp/x.epub',
            fileHash: 'hash-default',
            fileSizeBytes: 1,
          ));
      final row = await db
          .customSelect(
              "SELECT last_tts_position FROM books WHERE id = 'b-default'")
          .getSingle();
      expect(row.readNullable<String>('last_tts_position'), isNull);
    });

    test(
        'inserting a book with last_tts_position round-trips the JSON payload',
        () async {
      const payload =
          '{"chapterIdx":3,"sentenceIdx":42,"updatedAt":1718236800000}';
      await db.into(db.books).insert(BooksCompanion.insert(
            id: 'b-set',
            title: 't2',
            format: 'pdf',
            filePath: '/tmp/y.pdf',
            fileHash: 'hash-set',
            fileSizeBytes: 2,
            lastTtsPosition: const Value(payload),
          ));
      final row = await db
          .customSelect(
              "SELECT last_tts_position FROM books WHERE id = 'b-set'")
          .getSingle();
      expect(row.read<String>('last_tts_position'), payload);
    });

    // Degraded fallback (matches migration_v4_test.dart pattern): drift's
    // SchemaVerifier requires schema_v*.json snapshots that this project does
    // not maintain. Verifying the onUpgrade source contains the expected
    // ALTER TABLE statement guarantees the v14->v15 path is wired.
    test(
        'v14 -> v15 onUpgrade wires ALTER TABLE books ADD COLUMN last_tts_position',
        () {
      final source = File(_databaseSourcePath).readAsStringSync();
      expect(source, contains('if (from < 15)'),
          reason:
              'onUpgrade must gate the last_tts_position column add behind schema < 15');
      expect(
        source,
        contains('ALTER TABLE books ADD COLUMN last_tts_position TEXT'),
        reason:
            'onUpgrade must add last_tts_position as a nullable TEXT column',
      );
    });
  });

  // Exercises the actual onUpgrade path by hand-creating a v14 schema file
  // (without the new column), then opening AppDatabase against it to trigger
  // the v14->v15 migration. Catches regressions where the migration branch
  // is forgotten even though fresh-install schema is correct.
  group('schema v15 onUpgrade from v14 file', () {
    test(
        'migrates existing books rows: last_tts_position column added and NULL',
        () async {
      final tmpDir =
          await Directory.systemTemp.createTemp('zhiyue_v15_migration_');
      final dbPath = '${tmpDir.path}/test.db';

      // Hand-create a minimal v14-shaped books table (no last_tts_position)
      // and insert one row. We use the raw sqlite3 bindings to avoid going
      // through drift's migration logic - the file must stay at v14 until
      // AppDatabase opens it.
      sqlite3.open(dbPath)
        ..execute(
          'CREATE TABLE books ('
          'id TEXT NOT NULL, '
          'title TEXT NOT NULL, '
          'author TEXT, '
          'format TEXT NOT NULL, '
          'file_path TEXT NOT NULL, '
          'file_hash TEXT NOT NULL, '
          'file_size_bytes INTEGER NOT NULL, '
          'cover_path TEXT, '
          'added_at INTEGER NOT NULL, '
          'last_read_at INTEGER, '
          'sort_order INTEGER, '
          'file_synced_at INTEGER, '
          'PRIMARY KEY (id))',
        )
        ..execute(
          'INSERT INTO books(id, title, format, file_path, file_hash, '
          'file_size_bytes, added_at) VALUES '
          "('test-book', 'Migration Book', 'epub', '/tmp/m.epub', 'hash-m', 42, 0)",
        )
        ..execute('PRAGMA user_version = 14')
        ..dispose();

      // Open with current code (v15) - triggers onUpgrade from 14 -> 15.
      final db = AppDatabase.forExecutor(NativeDatabase(File(dbPath)));
      addTearDown(() async {
        await db.close();
        await tmpDir.delete(recursive: true);
      });

      // Verify the column was added.
      final cols = await db.customSelect('PRAGMA table_info(books)').get();
      final names = cols.map((r) => r.read<String>('name')).toSet();
      expect(names, contains('last_tts_position'));

      // Verify the existing row's last_tts_position is NULL.
      final row = await db
          .customSelect(
              "SELECT last_tts_position FROM books WHERE id = 'test-book'")
          .getSingle();
      expect(row.readNullable<String>('last_tts_position'), isNull);

      // Verify schemaVersion was bumped to 15 in the file.
      final versionRow =
          await db.customSelect('PRAGMA user_version').getSingle();
      expect(versionRow.read<int>('user_version'), 15);
    });
  });
}
