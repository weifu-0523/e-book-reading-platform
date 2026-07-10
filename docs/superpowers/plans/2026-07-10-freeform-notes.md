# Freeform Notes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add freeform (unanchored) Markdown notes — per-book and global — with full WebDAV sync parity (Bug #3 from 2026-07-10 user testing).

**Architecture:** New drift table `freeform_notes` (nullable `book_id` FK CASCADE) unifies per-book + global via `bookId=null`. New `SyncRecordType.freeformNote` slots into tier 1 of `RemoteRecordApplier` (same level as `bookmark`). UI adds: NoteEditPage (edit/preview toggle), per-book entry points (NotesDrawerContent + NotesPage), global entry point (Library drawer → GlobalFreeformNotesPage).

**Tech Stack:** Flutter 3.44 + Dart 3.10 + drift 2.28 + Riverpod 2.5 + go_router 14.2 + flutter_markdown 0.7 + existing sync pipeline.

**Spec:** [`docs/superpowers/specs/2026-07-10-freeform-notes-design.md`](../specs/2026-07-10-freeform-notes-design.md)

**Working directory for all `flutter` / `dart` commands:** `app/` (i.e. `H:/projiect/电子书阅读平台/app`). All file paths below are relative to repo root.

---

## Task 1: drift schema — FreeformNotes table + migration v12→v13

**Files:**
- Create: `app/lib/data/local/tables/freeform_notes.dart`
- Modify: `app/lib/data/local/database.dart:56-93` (@DriftDatabase tables list), `:100` (schemaVersion), `:147-160` (onCreate indexes), `:250-264` (onUpgrade from<13)
- Test: `app/test/data/local/daos/freeform_notes_schema_test.dart`

- [ ] **Step 1: Write the failing schema test**

Create `app/test/data/local/daos/freeform_notes_schema_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// ... (standard header)

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting());
  tearDown(() => db.close());

  test('schemaVersion is 13', () {
    expect(db.schemaVersion, 13);
  });

  test('freeform_notes table exists with expected columns', () async {
    final result = await db.customSelect(
      "PRAGMA table_info(freeform_notes)",
    ).get();
    final colNames = result.map((r) => r.read<String>('name')).toSet();
    expect(colNames, containsAll(<String>{
      'id', 'book_id', 'title', 'content',
      'created_at', 'updated_at', 'color',
    }));
  });

  test('insert freeform note with null bookId (global) succeeds', () async {
    final id = 'note-1';
    await db.customInsert(
      'INSERT INTO freeform_notes(id, book_id, title, content, created_at, updated_at, color) '
      'VALUES(?, NULL, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(id),
        Variable.withString('global thought'),
        Variable.withString('body'),
        Variable.withDateTime(DateTime.utc(2026, 7, 10)),
        Variable.withDateTime(DateTime.utc(2026, 7, 10)),
        Variable.withInt(0),
      ],
    );
    final rows = await db.customSelect('SELECT * FROM freeform_notes').get();
    expect(rows, hasLength(1));
    expect(rows.first.data['book_id'], isNull);
  });

  test('idx_freeform_notes_book index exists', () async {
    final result = await db.customSelect(
      "PRAGMA index_list(freeform_notes)",
    ).get();
    final names = result.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('idx_freeform_notes_book'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && /c/flutter/bin/flutter test test/data/local/daos/freeform_notes_schema_test.dart
```

Expected: FAIL — `table freeform_notes has no column` / `schemaVersion is 12`.

- [ ] **Step 3: Create the FreeformNotes table class**

Create `app/lib/data/local/tables/freeform_notes.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source Contributors
// ... (standard header — copy from app/lib/data/local/tables/bookmarks.dart)

import 'package:drift/drift.dart';

import 'books.dart';

/// Freeform (unanchored) Markdown notes. Bug #3 (2026-07-10): a place to
/// stash AI-generated content worth keeping or the reader's own thoughts —
/// not tied to a specific passage in the book.
///
/// `bookId` is nullable: `null` = global note (visible in 读书笔记库 only);
/// non-null = per-book note (visible in both the book's drawer and 读书笔记库).
/// FK `ON DELETE CASCADE` removes per-book notes when the book is deleted.
@DataClassName('FreeformNote')
class FreeformNotes extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().nullable().references(Books, #id)();
  TextColumn get title => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get color => int().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 4: Register table in @DriftDatabase + bump schemaVersion**

In `app/lib/data/local/database.dart`:

1. Add import after line 43 (`import 'tables/bookmarks.dart';`):
   ```dart
   import 'tables/freeform_notes.dart';
   ```
2. Add `FreeformNotes,` to `tables: [...]` list after `Bookmarks,` (line 72).
3. Change `schemaVersion` from `12` to `13` (line 100).
4. In `onCreate` (after line 154, before the `qa_history` DROP):
   ```dart
   // schema v13: freeform_notes (Bug #3, 2026-07-10)
   await m.database.customStatement(
     'CREATE INDEX IF NOT EXISTS idx_freeform_notes_book '
     'ON freeform_notes(book_id, updated_at DESC)',
   );
   await m.database.customStatement(
     'CREATE INDEX IF NOT EXISTS idx_freeform_notes_updated '
     'ON freeform_notes(updated_at DESC)',
   );
   ```
5. In `onUpgrade` (after the `if (from < 12)` block, before closing `}` at line 265):
   ```dart
   if (from < 13) {
     // Bug #3 (2026-07-10): freeform_notes table for unanchored Markdown notes
     await m.createTable(freeformNotes);
     await m.database.customStatement(
       'CREATE INDEX IF NOT EXISTS idx_freeform_notes_book '
       'ON freeform_notes(book_id, updated_at DESC)',
     );
     await m.database.customStatement(
       'CREATE INDEX IF NOT EXISTS idx_freeform_notes_updated '
       'ON freeform_notes(updated_at DESC)',
     );
   }
   ```

- [ ] **Step 5: Run drift codegen**

```bash
cd app && /c/flutter/bin/dart run build_runner build --delete-conflicting-outputs
```

Expected: `[INFO] Succeeded after ...`. `database.g.dart` regenerated with `FreeformNote` data class.

- [ ] **Step 6: Run test to verify it passes**

```bash
cd app && /c/flutter/bin/flutter test test/data/local/daos/freeform_notes_schema_test.dart
```

Expected: PASS (4 tests).

- [ ] **Step 7: Commit**

```bash
git add app/lib/data/local/tables/freeform_notes.dart app/lib/data/local/database.dart app/lib/data/local/database.g.dart app/test/data/local/daos/freeform_notes_schema_test.dart
git commit -m "feat(schema): freeform_notes table + migration v12→v13 (Bug #3 T1)"
```

---

## Task 2: FreeformNotesDao + SyncRecorder.recordFreeformNote

**Files:**
- Create: `app/lib/data/local/daos/freeform_notes_dao.dart`
- Modify: `app/lib/services/sync/sync_recorder.dart` (add 2 methods)
- Modify: `app/lib/data/local/database.dart:76-92` (register DAO in `daos: [...]`)
- Test: `app/test/data/local/daos/freeform_notes_dao_test.dart`

- [ ] **Step 1: Write the failing DAO test**

Create `app/test/data/local/daos/freeform_notes_dao_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// ... (standard header)

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/local/daos/freeform_notes_dao.dart';
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';

void main() {
  late AppDatabase db;
  late FreeformNotesDao dao;
  late SyncOutboxDao outbox;

  setUp(() {
    db = AppDatabase.forTesting();
    dao = FreeformNotesDao(db);
    outbox = SyncOutboxDao(db);
  });
  tearDown(() => db.close());

  test('create writes row + enqueues outbox record', () async {
    final id = await dao.create(
      bookId: null,
      title: 'Thought',
      content: '# hello',
    );
    final notes = await dao.listAll();
    expect(notes, hasLength(1));
    expect(notes.first.title, 'Thought');

    final pending = await outbox.getPending();
    expect(pending, hasLength(1));
    expect(pending.first.recordId, id);
    expect(pending.first.recordType, 'freeformNote');
  });

  test('listByBook filters + orders by updated_at DESC', () async {
    final bookA = 'book-a';
    // Insert book row first to satisfy FK.
    await db.customInsert(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
      'VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(bookA),
        Variable.withString('Book A'),
        Variable.withString('epub'),
        Variable.withString('p'),
        Variable.withString('h'),
        Variable.withInt(0),
      ],
    );
    final oldId = await dao.create(bookId: bookA, title: 'old', content: 'a');
    await Future.delayed(const Duration(milliseconds: 10));
    await dao.create(bookId: bookA, title: 'new', content: 'b');
    await dao.create(bookId: null, title: 'global', content: 'g');

    final list = await dao.listByBook(bookA);
    expect(list, hasLength(2));
    expect(list.first.title, 'new');
    expect(list.last.title, 'old');
  });

  test('listAll includes both per-book and global', () async {
    await dao.create(bookId: null, title: 'global', content: 'g');
    expect(await dao.listAll(), hasLength(1));
  });

  test('update writes row + enqueues outbox record', () async {
    final id = await dao.create(bookId: null, title: 'orig', content: 'c');
    await outbox.getPending(); // drain
    await dao.update(id: id, title: 'edited', content: 'new content');
    final note = await dao.getById(id);
    expect(note?.title, 'edited');
    expect(note?.content, 'new content');
    final pending = await outbox.getPending();
    expect(pending, hasLength(1));
    expect(pending.first.recordId, id);
  });

  test('softDelete removes row + enqueues tombstone', () async {
    final id = await dao.create(bookId: null, title: 'x', content: 'y');
    await outbox.getPending(); // drain create
    await dao.softDelete(id);
    expect(await dao.getById(id), isNull);
    final pending = await outbox.getPending();
    expect(pending, hasLength(1));
    // Tombstone payload is empty + recordType still 'freeformNote'
    expect(pending.first.recordId, id);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && /c/flutter/bin/flutter test test/data/local/daos/freeform_notes_dao_test.dart
```

Expected: FAIL — `FreeformNotesDao not defined` / `recordFreeformNote not found`.

- [ ] **Step 3: Add SyncRecorder.recordFreeformNote methods**

In `app/lib/services/sync/sync_recorder.dart`, add after `recordBookmarkDeletion` (line 188):

```dart
Future<void> recordFreeformNote({
  required String id,
  required String? bookId,
  required String title,
  required String content,
  required int color,
  required DateTime createdAt,
  required DateTime updatedAt,
  bool deleted = false,
}) {
  final payload = <String, dynamic>{
    'id': id,
    'bookId': bookId,
    'title': title,
    'content': content,
    'color': color,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
  return _enqueue(SyncRecord(
    id: id,
    type: SyncRecordType.freeformNote,
    mtime: updatedAt,
    deleted: deleted,
    payload: deleted ? const {} : payload,
  ));
}

Future<void> recordFreeformNoteDeletion({
  required String id,
  required DateTime mtime,
}) {
  return _enqueue(SyncRecord.tombstone(
    id: id,
    type: SyncRecordType.freeformNote,
    mtime: mtime,
  ));
}
```

- [ ] **Step 4: Create FreeformNotesDao**

Create `app/lib/data/local/daos/freeform_notes_dao.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source Contributors
// ... (standard header)

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../tables/freeform_notes.dart';
import 'sync_outbox_dao.dart';

part 'freeform_notes_dao.g.dart';

@DriftAccessor(tables: [FreeformNotes])
class FreeformNotesDao extends DatabaseAccessor<AppDatabase>
    with _$FreeformNotesDaoMixin {
  FreeformNotesDao(super.db);

  SyncOutboxDao get _outbox => SyncOutboxDao(attachedDatabase);

  /// Create a new freeform note. Returns the generated id. Writes the row +
  /// enqueues a sync record in a single transaction.
  Future<String> create({
    required String? bookId,
    required String title,
    required String content,
    int color = 0,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();
    await attachedDatabase.transaction(() async {
      await attachedDatabase.customInsert(
        'INSERT INTO freeform_notes(id, book_id, title, content, created_at, updated_at, color) '
        'VALUES(?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(id),
          Variable<String>(bookId),
          Variable.withString(title),
          Variable.withString(content),
          Variable.withDateTime(now),
          Variable.withDateTime(now),
          Variable.withInt(color),
        ],
      );
      await _outbox.enqueue(
        recordId: id,
        recordType: 'freeformNote',
        payloadJson: jsonEncode(_payloadJson(
          id: id, bookId: bookId, title: title, content: content,
          color: color, createdAt: now, updatedAt: now, deleted: false,
        )),
      );
    });
    return id;
  }

  /// Update title/content/color. At least one field must be non-null.
  Future<void> update({
    required String id,
    String? title,
    String? content,
    int? color,
  }) async {
    final existing = await getById(id);
    if (existing == null) return;
    final newTitle = title ?? existing.title;
    final newContent = content ?? existing.content;
    final newColor = color ?? existing.color;
    final now = DateTime.now().toUtc();
    await attachedDatabase.transaction(() async {
      await attachedDatabase.customStatement(
        'UPDATE freeform_notes SET title = ?, content = ?, color = ?, updated_at = ? '
        'WHERE id = ?',
        [newTitle, newContent, newColor, now.millisecondsSinceEpoch, id],
      );
      await _outbox.enqueue(
        recordId: id,
        recordType: 'freeformNote',
        payloadJson: jsonEncode(_payloadJson(
          id: id, bookId: existing.bookId, title: newTitle, content: newContent,
          color: newColor, createdAt: existing.createdAt, updatedAt: now,
          deleted: false,
        )),
      );
    });
  }

  /// Soft delete (hard delete in this table; tombstone sync record). FK
  /// CASCADE on book_id is handled at the SQL layer (no sync tombstone for
  /// the cascade case — same as bookmarks).
  Future<void> softDelete(String id) async {
    final existing = await getById(id);
    if (existing == null) return;
    final now = DateTime.now().toUtc();
    await attachedDatabase.transaction(() async {
      await attachedDatabase.customStatement(
        'DELETE FROM freeform_notes WHERE id = ?', [id]);
      await _outbox.enqueue(
        recordId: id,
        recordType: 'freeformNote',
        payloadJson: jsonEncode(_payloadJson(
          id: id, bookId: existing.bookId, title: existing.title,
          content: existing.content, color: existing.color,
          createdAt: existing.createdAt, updatedAt: now, deleted: true,
        )),
      );
    });
  }

  Future<List<FreeformNote>> listByBook(String bookId) {
    return (select(freeformNotes)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  Future<List<FreeformNote>> listAll() {
    return (select(freeformNotes)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  Future<FreeformNote?> getById(String id) {
    return (select(freeformNotes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Map<String, dynamic> _payloadJson({
    required String id,
    required String? bookId,
    required String title,
    required String content,
    required int color,
    required DateTime createdAt,
    required DateTime updatedAt,
    required bool deleted,
  }) {
    return {
      'id': id,
      'bookId': bookId,
      'title': title,
      'content': content,
      'color': color,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'deleted': deleted,
    };
  }
}
```

- [ ] **Step 5: Register DAO + run codegen**

In `app/lib/data/local/database.dart`:
1. Add import: `import 'daos/freeform_notes_dao.dart';` (after `import 'daos/chat_messages_dao.dart';` line 28).
2. Add `FreeformNotesDao,` to `daos: [...]` list (after `ChatMessagesDao,`).

```bash
cd app && /c/flutter/bin/dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 6: Run test to verify it passes**

```bash
cd app && /c/flutter/bin/flutter test test/data/local/daos/freeform_notes_dao_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 7: Commit**

```bash
git add app/lib/data/local/daos/freeform_notes_dao.dart app/lib/data/local/daos/freeform_notes_dao.g.dart app/lib/services/sync/sync_recorder.dart app/lib/data/local/database.dart app/test/data/local/daos/freeform_notes_dao_test.dart
git commit -m "feat(dao): FreeformNotesDao + SyncRecorder.recordFreeformNote (Bug #3 T2)"
```

---

## Task 3: SyncRecordType.freeformNote + RemoteRecordApplier tier 1 + _applyFreeformNote

**Files:**
- Modify: `app/lib/services/sync/sync_record.dart:21-27` (enum)
- Modify: `app/lib/services/sync/remote_record_applier.dart:39-52` (apply switch), `:82-99` (tier buckets)
- Test: `app/test/services/sync/remote_record_applier_test.dart` (extend existing or new)

- [ ] **Step 1: Write the failing applier test**

Add to `app/test/services/sync/remote_record_applier_test.dart` (create if not exists, else extend):

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// ... (standard header)

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/remote_record_applier.dart';
import 'package:zhiyue/services/sync/sync_record.dart';

void main() {
  late AppDatabase db;
  late RemoteRecordApplier applier;

  setUp(() {
    db = AppDatabase.forTesting();
    applier = RemoteRecordApplier(db);
  });
  tearDown(() => db.close());

  test('applyRecords applies freeformNote after book when book arrives later',
      () async {
    // Reverse-order: freeformNote before its parent book — applier must
    // reorder via tier 1 bucket.
    final noteRecord = SyncRecord(
      id: 'note-1',
      type: SyncRecordType.freeformNote,
      mtime: DateTime.utc(2026, 7, 10, 12),
      deleted: false,
      payload: const {
        'id': 'note-1',
        'bookId': 'b1',
        'title': 'Thought',
        'content': '# hello',
        'color': 0,
        'createdAt': '2026-07-10T12:00:00.000Z',
        'updatedAt': '2026-07-10T12:00:00.000Z',
        'deleted': false,
      },
    );
    final bookRecord = SyncRecord(
      id: 'b1',
      type: SyncRecordType.book,
      mtime: DateTime.utc(2026, 7, 9),
      deleted: false,
      payload: const {
        'id': 'b1', 'title': 'B', 'format': 'epub',
        'fileHash': 'h', 'fileSizeBytes': 0,
      },
    );

    await applier.applyRecords([noteRecord, bookRecord]);

    final notes = await db.customSelect('SELECT * FROM freeform_notes').get();
    expect(notes, hasLength(1));
    expect(notes.first.data['title'], 'Thought');
  });

  test('apply tombstone deletes local freeform note', () async {
    // Seed local note.
    await db.customInsert(
      'INSERT INTO freeform_notes(id, book_id, title, content, created_at, updated_at, color) '
      "VALUES('n1', NULL, 't', 'c', 0, 0, 0)",
    );
    final tombstone = SyncRecord.tombstone(
      id: 'n1',
      type: SyncRecordType.freeformNote,
      mtime: DateTime.utc(2026, 7, 10, 13),
    );
    await applier.applyRecords([tombstone]);
    final notes = await db.customSelect('SELECT * FROM freeform_notes').get();
    expect(notes, isEmpty);
  });

  test('LWW: older remote mtime does not overwrite newer local', () async {
    await db.customInsert(
      'INSERT INTO freeform_notes(id, book_id, title, content, created_at, updated_at, color) '
      "VALUES('n1', NULL, 'local', 'c', "
      "'${DateTime.utc(2026, 7, 11).toIso8601String()}', "
      "'${DateTime.utc(2026, 7, 11).toIso8601String()}', 0)",
    );
    final older = SyncRecord(
      id: 'n1',
      type: SyncRecordType.freeformNote,
      mtime: DateTime.utc(2026, 7, 10), // older than local
      deleted: false,
      payload: const {
        'id': 'n1', 'bookId': null, 'title': 'remote-older',
        'content': 'x', 'color': 0,
        'createdAt': '2026-07-10T00:00:00.000Z',
        'updatedAt': '2026-07-10T00:00:00.000Z', 'deleted': false,
      },
    );
    await applier.applyRecords([older]);
    final row = await db.customSelect(
      "SELECT title FROM freeform_notes WHERE id = 'n1'",
    ).getSingle();
    expect(row.data['title'], 'local');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && /c/flutter/bin/flutter test test/services/sync/remote_record_applier_test.dart
```

Expected: FAIL — `SyncRecordType.freeformNote not found`.

- [ ] **Step 3: Add SyncRecordType.freeformNote**

In `app/lib/services/sync/sync_record.dart`, extend the enum (line 21-27):

```dart
enum SyncRecordType {
  book,
  bookNote,
  annotation,
  readingProgress,
  bookmark,
  freeformNote,
}
```

- [ ] **Step 4: Add _applyFreeformNote + tier 1 bucket**

In `app/lib/services/sync/remote_record_applier.dart`:

1. Add to `apply` switch (after line 50 `case SyncRecordType.bookmark:`):
   ```dart
   case SyncRecordType.freeformNote:
     return _applyFreeformNote(record);
   ```
2. In `applyRecords` tier bucketing (after line 91 `case SyncRecordType.readingProgress:`):
   ```dart
   case SyncRecordType.freeformNote:
   ```
   (combined with the existing `case SyncRecordType.bookNote:` fall-through that adds to `midTier`)
3. Add `_applyFreeformNote` method (place after `_applyBookmark` ~line 228):

```dart
Future<bool> _applyFreeformNote(SyncRecord record) async {
  final existing = await _db.customSelect(
    'SELECT updated_at FROM freeform_notes WHERE id = ?',
    variables: [Variable.withString(record.id)],
  ).getSingleOrNull();
  if (existing != null) {
    final localMtime = existing.read<DateTime>('updated_at');
    if (!record.mtime.isAfter(localMtime)) {
      await _recordConflict(record, localMtime);
      return false;
    }
  }

  if (record.deleted) {
    await _db.customStatement(
      'DELETE FROM freeform_notes WHERE id = ?', [record.id]);
    return true;
  }

  final p = record.payload;
  final createdAtStr = p['createdAt'] as String?;
  final createdAt = createdAtStr == null
      ? record.mtime
      : DateTime.parse(createdAtStr);

  await _db.customInsert(
    'INSERT OR REPLACE INTO freeform_notes(id, book_id, title, content, created_at, updated_at, color) '
    'VALUES(?, ?, ?, ?, ?, ?, ?)',
    variables: [
      Variable.withString(record.id),
      Variable<String>(p['bookId'] as String?),
      Variable.withString(p['title'] as String),
      Variable.withString(p['content'] as String),
      Variable.withDateTime(createdAt),
      Variable.withDateTime(record.mtime),
      Variable.withInt(p['color'] as int? ?? 0),
    ],
  );
  return true;
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd app && /c/flutter/bin/flutter test test/services/sync/remote_record_applier_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add app/lib/services/sync/sync_record.dart app/lib/services/sync/remote_record_applier.dart app/test/services/sync/remote_record_applier_test.dart
git commit -m "feat(sync): SyncRecordType.freeformNote + tier 1 apply (Bug #3 T3)"
```

---

## Task 4: NoteEditPage — edit/preview toggle + write-through debounce

**Files:**
- Create: `app/lib/features/notes/pages/note_edit_page.dart`
- Modify: `app/lib/core/providers.dart` (add `freeformNotesDaoProvider`)
- Test: `app/test/features/notes/pages/note_edit_page_test.dart`

- [ ] **Step 1: Add freeformNotesDaoProvider**

In `app/lib/core/providers.dart`, add:

```dart
final freeformNotesDaoProvider = Provider<FreeformNotesDao>((ref) {
  return FreeformNotesDao(ref.read(appDatabaseProvider));
});
```

(plus any required imports — follow the pattern of existing DAO providers like `bookNotesDaoProvider`.)

- [ ] **Step 2: Write the failing widget test**

Create `app/test/features/notes/pages/note_edit_page_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// ... (standard header)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/local/daos/freeform_notes_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/notes/pages/note_edit_page.dart';

class _FakeDao implements FreeformNotesDao {
  _FakeDao(this.db);
  final AppDatabase db;
  String? lastCreatedTitle;
  String? lastCreatedContent;
  String? lastUpdatedId;
  String? lastUpdatedTitle;

  @override
  Future<String> create({
    required String? bookId,
    required String title,
    required String content,
    int color = 0,
  }) async {
    lastCreatedTitle = title;
    lastCreatedContent = content;
    return 'fake-id';
  }

  @override
  Future<void> update({
    required String id,
    String? title,
    String? content,
    int? color,
  }) async {
    lastUpdatedId = id;
    lastUpdatedTitle = title;
  }

  @override
  Future<FreeformNote?> getById(String id) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_FakeDao.${invocation.memberName}');
}

void main() {
  testWidgets('new note: typing + save FAB calls dao.create', (tester) async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final fakeDao = _FakeDao(db);

    final container = ProviderContainer(overrides: [
      freeformNotesDaoProvider.overrideWithValue(fakeDao),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NoteEditPage(bookId: 'b1')),
    ));

    await tester.enterText(
      find.widgetWith(TextField, finder: find.byType(TextField).first),
      'My Thought',
    );
    // Content field is the second TextField.
    await tester.enterText(
      find.widgetWith(TextField, finder: find.byType(TextField).last),
      '# hello world',
    );
    await tester.tap(find.byIcon(Icons.save));
    await tester.pump();

    expect(fakeDao.lastCreatedTitle, 'My Thought');
    expect(fakeDao.lastCreatedContent, '# hello world');
  });

  testWidgets('preview toggle renders MarkdownBody', (tester) async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      freeformNotesDaoProvider.overrideWithValue(_FakeDao(db)),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NoteEditPage(bookId: null)),
    ));
    await tester.enterText(
      find.byType(TextField).first, 'T');
    await tester.enterText(
      find.byType(TextField).last, '# heading');
    await tester.tap(find.text('预览'));
    await tester.pumpAndSettle();

    // flutter_markdown renders H1 as Text widget containing 'heading'.
    expect(find.text('heading'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd app && /c/flutter/bin/flutter test test/features/notes/pages/note_edit_page_test.dart
```

Expected: FAIL — `NoteEditPage not found` / `TargetedNoteEditPage not defined`.

- [ ] **Step 4: Create NoteEditPage**

Create `app/lib/features/notes/pages/note_edit_page.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source Contributors
// ... (standard header)

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// Edit / create a freeform note. Pass [noteId] = null for create mode;
/// [bookId] = null for global note.
///
/// Write-through: each onChanged schedules a 500ms debounce that calls
/// dao.update (create on first edit). Avoids exit(0) truncating dispose
/// Futures — same pattern as TypographyPersister (see
/// feedback_no_dispose_time_fire_and_forget memory).
class NoteEditPage extends ConsumerStatefulWidget {
  const NoteEditPage({super.key, this.bookId, this.noteId});

  final String? bookId;
  final String? noteId;

  @override
  ConsumerState<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends ConsumerState<NoteEditPage> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _previewMode = false;
  bool _dirty = false;
  String? _createdId;
  bool _loadingExisting = true;

  @override
  void initState() {
    super.initState();
    if (widget.noteId != null) {
      _loadExisting();
    } else {
      _loadingExisting = false;
    }
  }

  Future<void> _loadExisting() async {
    final note = await ref.read(freeformNotesDaoProvider).getById(widget.noteId!);
    if (note != null && mounted) {
      _titleCtrl.text = note.title;
      _contentCtrl.text = note.content;
    }
    if (mounted) setState(() => _loadingExisting = false);
  }

  void _onChanged() {
    _dirty = true;
    // Write-through debounce 500ms (avoid spamming DB on every keystroke).
    Future.delayed(const Duration(milliseconds: 500), _flush);
  }

  Future<void> _flush() async {
    if (!_dirty) return;
    _dirty = false;
    final dao = ref.read(freeformNotesDaoProvider);
    final title = _titleCtrl.text.trim().isEmpty
        ? '无标题' : _titleCtrl.text.trim();
    final content = _contentCtrl.text;
    if (_createdId == null && widget.noteId == null) {
      _createdId = await dao.create(
        bookId: widget.bookId, title: title, content: content);
    } else {
      final id = _createdId ?? widget.noteId!;
      await dao.update(id: id, title: title, content: content);
    }
  }

  Future<void> _saveNow() async {
    if (_dirty) await _flush();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    // Best-effort synchronous flush; if exit(0) hits during dispose the
    // pending _flush Future may be truncated, but the 500ms debounce means
    // most recent edit already persisted.
    if (_dirty) {
      Future.microtask(_flush);
    }
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingExisting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleCtrl.text.isEmpty ? '新笔记' : _titleCtrl.text,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(_previewMode ? Icons.edit : Icons.visibility),
            onPressed: () => setState(() => _previewMode = !_previewMode),
            tooltip: _previewMode ? '编辑' : '预览',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNow,
            tooltip: '保存',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '标题', border: OutlineInputBorder()),
              onChanged: (_) => _onChanged(),
            ),
          ),
          Expanded(
            child: _previewMode
                ? Markdown(
                    data: _contentCtrl.text,
                    padding: const EdgeInsets.all(12),
                  )
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _contentCtrl,
                      maxLines: null,
                      minLines: 5,
                      decoration: const InputDecoration(
                        hintText: '支持 Markdown：# 标题、**加粗**、- 列表',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) => _onChanged(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd app && /c/flutter/bin/flutter test test/features/notes/pages/note_edit_page_test.dart
```

Expected: PASS (2 tests). If `find.widgetWith(TextField, finder: ...)` API errors, replace with `find.byType(TextField).at(0)` / `at(1)`.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/notes/pages/note_edit_page.dart app/lib/core/providers.dart app/test/features/notes/pages/note_edit_page_test.dart
git commit -m "feat(notes): NoteEditPage with edit/preview toggle (Bug #3 T4)"
```

---

## Task 5: NotesDrawerContent — freeform section + "+" button

**Files:**
- Modify: `app/lib/features/reader/widgets/notes_drawer.dart`
- Test: `app/test/features/reader/widgets/notes_drawer_freeform_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `app/test/features/reader/widgets/notes_drawer_freeform_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// ... (standard header)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/reader/widgets/notes_drawer.dart';

void main() {
  testWidgets('renders freeform notes section above annotations', (tester) async {
    final freeformNotes = [
      FreeformNote(
        id: 'n1', bookId: 'b1', title: 'Idea',
        content: 'long content here that should be previewed',
        createdAt: DateTime.utc(2026, 7, 10),
        updatedAt: DateTime.utc(2026, 7, 10),
        color: 0,
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NotesDrawerContent(
          annotations: const [],
          chapterTitles: const {},
          onTap: (_) {}, onLongPress: (_) {}, onClose: () {},
          freeformNotes: freeformNotes,
          onCreateFreeformNote: () {},
        ),
      ),
    ));
    expect(find.text('自由笔记'), findsOneWidget);
    expect(find.text('Idea'), findsOneWidget);
  });

  testWidgets('tap "+" calls onCreateFreeformNote', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NotesDrawerContent(
          annotations: const [],
          chapterTitles: const {},
          onTap: (_) {}, onLongPress: (_) {}, onClose: () {},
          freeformNotes: const [],
          onCreateFreeformNote: () => pressed++,
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.add));
    expect(pressed, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && /c/flutter/bin/flutter test test/features/reader/widgets/notes_drawer_freeform_test.dart
```

Expected: FAIL — `freeformNotes parameter not found` / `onCreateFreeformNote not found`.

- [ ] **Step 3: Modify NotesDrawerContent**

In `app/lib/features/reader/widgets/notes_drawer.dart`:

1. Add fields after `onDelete` (line 42):
   ```dart
   final List<FreeformNote> freeformNotes;
   final VoidCallback? onCreateFreeformNote;
   final ValueChanged<String>? onOpenFreeformNote;
   ```
2. Add to constructor params (after `this.onDelete,`):
   ```dart
   required this.freeformNotes,
   this.onCreateFreeformNote,
   this.onOpenFreeformNote,
   ```
3. Add import at top: `import '../../../data/local/database.dart';`
4. In `build`, between `_buildHeader()` and the annotations list (the `if (annotations.isEmpty)` branch and the main branch), insert the freeform section:

```dart
Widget _buildFreeformSection() {
  if (freeformNotes.isEmpty && onCreateFreeformNote == null) {
    return const SizedBox.shrink();
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
        child: Row(
          children: [
            const Expanded(
              child: Text('自由笔记',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (onCreateFreeformNote != null)
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: onCreateFreeformNote,
                tooltip: '新建笔记',
              ),
          ],
        ),
      ),
      ...freeformNotes.map((n) => ListTile(
            dense: true,
            title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              n.content.replaceAll('\n', ' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: onOpenFreeformNote == null
                ? null
                : () => onOpenFreeformNote!(n.id),
          )),
      const Divider(),
    ],
  );
}
```

5. Call `_buildFreeformSection()` in both the empty-state and the main build paths, immediately after `_buildHeader()`.

6. Update the header to accept an `onCreateFreeformNote` trigger (modify `_buildHeader` if needed to add the "+" icon there for the empty state — or simpler: keep `_buildHeader` as is and let the section header above carry the "+").

7. Mirror the new params on the `NotesDrawer` wrapper class (add same 3 params, forward to content).

- [ ] **Step 4: Run test to verify it passes**

```bash
cd app && /c/flutter/bin/flutter test test/features/reader/widgets/notes_drawer_freeform_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 5: Wire up from reader_body.dart**

Find the call site that constructs `NotesDrawerContent` (likely in `app/lib/features/reader/pages/reader_body.dart`). Add `freeformNotes: []` and `onCreateFreeformNote: () => context.push('/notes/new?bookId=$bookId')` (use the actual bookId variable in scope). For the first commit, leaving `freeformNotes: []` is acceptable — Task 7 will wire the actual provider. Run all reader tests to confirm no regression:

```bash
cd app && /c/flutter/bin/flutter test test/features/reader/
```

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/reader/widgets/notes_drawer.dart app/lib/features/reader/pages/reader_body.dart app/test/features/reader/widgets/notes_drawer_freeform_test.dart
git commit -m "feat(reader): freeform notes section + new-note button in drawer (Bug #3 T5)"
```

---

## Task 6: NotesPage — freeform section + FAB

**Files:**
- Modify: `app/lib/features/notes/pages/notes_page.dart`
- Test: `app/test/features/notes/pages/notes_page_freeform_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `app/test/features/notes/pages/notes_page_freeform_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// ... (standard header)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Read notes_page.dart to determine the public API + add imports accordingly.

void main() {
  testWidgets('FAB tap calls onCreateFreeformNote', (tester) async {
    // TODO: adapt to actual NotesPage constructor after reading its source.
    // The test should pump NotesPage with a stubbed freeformNotesDaoProvider
    // and verify tapping the FAB pushes /notes/new?bookId=...
  }, skip: 'Fill in after reading notes_page.dart source'); // Remove skip in Step 3.
}
```

- [ ] **Step 2: Read NotesPage source**

Read `app/lib/features/notes/pages/notes_page.dart` end-to-end. Identify: (1) how it receives bookId, (2) where annotations list is rendered, (3) what provider exposes annotations. Mirror the pattern for freeform notes.

- [ ] **Step 3: Implement**

1. Add a freeform-notes provider if not exists:
   ```dart
   final freeformNotesForBookProvider =
       FutureProvider.family<List<FreeformNote>, String>((ref, bookId) {
     return ref.read(freeformNotesDaoProvider).listByBook(bookId);
   });
   ```
2. In `notes_page.dart`, `watch` the provider above the annotations list, render the same `_buildFreeformSection`-style UI.
3. Add a FloatingActionButton.extended (`Icons.add` / label '新笔记') that pushes `/notes/new?bookId=$bookId`.

- [ ] **Step 4: Run test + replace skip with real assertion**

```bash
cd app && /c/flutter/bin/flutter test test/features/notes/pages/notes_page_freeform_test.dart
```

Expected: PASS.

- [ ] **Step 5: Run notes_page regression tests**

```bash
cd app && /c/flutter/bin/flutter test test/features/notes/
```

Expected: all existing notes_page tests still pass.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/notes/pages/notes_page.dart app/lib/features/notes/providers/ app/test/features/notes/pages/notes_page_freeform_test.dart
git commit -m "feat(notes): freeform section + FAB in NotesPage (Bug #3 T6)"
```

---

## Task 7: GlobalFreeformNotesPage + router + drawer entry

**Files:**
- Create: `app/lib/features/notes/pages/global_freeform_notes_page.dart`
- Modify: `app/lib/core/router.dart:40-115` (add 3 routes)
- Modify: `app/lib/features/library/pages/library_page.dart:482-514` (drawer ListTile)
- Test: `app/test/features/notes/pages/global_freeform_notes_page_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/features/notes/pages/global_freeform_notes_page_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// ... (standard header)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/notes/pages/global_freeform_notes_page.dart';

class _StubDao {
  Future<List<FreeformNote>> listAll() async => [
        FreeformNote(
          id: 'n1', bookId: null, title: 'Global Idea',
          content: 'body', createdAt: DateTime.utc(2026, 7, 10),
          updatedAt: DateTime.utc(2026, 7, 10), color: 0,
        ),
      ];
}

void main() {
  testWidgets('renders all freeform notes', (tester) async {
    final container = ProviderContainer(overrides: [
      // Override the provider GlobalFreeformNotesPage reads.
    ]);
    addTearDown(container.dispose);
    // pump GlobalFreeformNotesPage with overridden dao, expect 'Global Idea' visible.
  }, skip: 'complete after page impl exists');
}
```

- [ ] **Step 2: Add routes**

In `app/lib/core/router.dart`, add 3 GoRoutes (after `/settings`):

```dart
GoRoute(
  path: '/notes/new',
  builder: (context, state) {
    final bookId = state.uri.queryParameters['bookId'];
    return NoteEditPage(bookId: bookId);
  },
),
GoRoute(
  path: '/notes/:id',
  builder: (context, state) =>
      NoteEditPage(noteId: state.pathParameters['id']),
),
GoRoute(
  path: '/notes-library',
  builder: (context, state) => const GlobalFreeformNotesPage(),
),
```

Add imports for `NoteEditPage` and `GlobalFreeformNotesPage`.

- [ ] **Step 3: Create GlobalFreeformNotesPage**

Create `app/lib/features/notes/pages/global_freeform_notes_page.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// ... (standard header)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../data/local/database.dart';

final allFreeformNotesProvider =
    FutureProvider<List<FreeformNote>>((ref) {
  return ref.read(freeformNotesDaoProvider).listAll();
});

/// Lists every freeform note (per-book + global). Per-book notes display
/// the book title as a leading chip; global notes show a generic chip.
class GlobalFreeformNotesPage extends ConsumerWidget {
  const GlobalFreeformNotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(allFreeformNotesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('读书笔记库')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新笔记'),
        onPressed: () => context.push('/notes/new'),
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (notes) {
          if (notes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '还没有自由笔记。\n\n'
                  '点右下角"新笔记"创建第一条；\n'
                  '也可以在某本书的笔记抽屉里创建该书专属的笔记。',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (ctx, i) {
              final n = notes[i];
              return ListTile(
                leading: const Icon(Icons.note_outlined),
                title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  n.content.replaceAll('\n', ' '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => context.push('/notes/${n.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Add drawer entry**

In `app/lib/features/library/pages/library_page.dart`, modify `_LibraryNavigationDrawer.build` (around line 494):

```dart
ListTile(
  leading: const Icon(Icons.menu_book),
  title: const Text('读书笔记库'),
  onTap: () {
    Navigator.pop(context);
    context.push('/notes-library');
  },
),
```

Insert before the existing 'AI 设置' ListTile. Add `import 'package:go_router/go_router.dart';` if not present.

- [ ] **Step 5: Complete the test (remove skip)**

Replace the skipped test body with a real pump using `allFreeformNotesProvider.overrideWith(...)`:

```dart
testWidgets('renders all freeform notes', (tester) async {
  final container = ProviderContainer(overrides: [
    allFreeformNotesProvider.overrideWith((ref) async => [
          FreeformNote(
            id: 'n1', bookId: null, title: 'Global Idea',
            content: 'body', createdAt: DateTime.utc(2026, 7, 10),
            updatedAt: DateTime.utc(2026, 7, 10), color: 0,
          ),
        ]),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: GlobalFreeformNotesPage()),
  ));
  await tester.pumpAndSettle();
  expect(find.text('Global Idea'), findsOneWidget);
});
```

- [ ] **Step 6: Run test + verify drawer entry**

```bash
cd app && /c/flutter/bin/flutter test test/features/notes/pages/global_freeform_notes_page_test.dart
cd app && /c/flutter/bin/flutter test test/features/library/
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/notes/pages/global_freeform_notes_page.dart app/lib/core/router.dart app/lib/features/library/pages/library_page.dart app/test/features/notes/pages/global_freeform_notes_page_test.dart
git commit -m "feat(notes): global freeform notes page + drawer entry (Bug #3 T7)"
```

---

## Task 8: Integration test — end-to-end sync

**Files:**
- Modify: `app/test/services/sync/integration_test.dart` (add case)

- [ ] **Step 1: Read existing integration test**

Read `app/test/services/sync/integration_test.dart` to understand the setup pattern (two databases, two engines, etc.).

- [ ] **Step 2: Add freeformNote end-to-end case**

Add a test that:
1. Creates a freeformNote on device A (via `dao.create`).
2. Runs `engineA.pushOnly()`.
3. Runs `engineB.pullOnly()`.
4. Asserts the note appears in device B's `freeform_notes` table with matching title/content/bookId.

Also add a deletion case:
5. `daoA.softDelete(id)` → push → pull → assert gone on B.

- [ ] **Step 3: Run integration test**

```bash
cd app && /c/flutter/bin/flutter test test/services/sync/integration_test.dart
```

Expected: PASS (existing + 2 new).

- [ ] **Step 4: Commit**

```bash
git add app/test/services/sync/integration_test.dart
git commit -m "test(sync): freeformNote end-to-end push/pull/delete (Bug #3 T8)"
```

---

## Task 9: Release prep — pubspec bump + CHANGELOG + README + release-notes

**Files:**
- Modify: `app/pubspec.yaml` (version: `1.9.0-alpha+0`)
- Modify: `CHANGELOG.md`
- Modify: `README.md`
- Create: `docs/releases/release-notes-v1.9.0-alpha.md`

- [ ] **Step 1: Bump version**

In `app/pubspec.yaml`, change `version:` to `1.9.0-alpha+0`.

- [ ] **Step 2: Add CHANGELOG entry**

Add a new section at the top of `CHANGELOG.md`:

```markdown
## [1.9.0-alpha] — 2026-07-10

### Bug fixes (user testing 2026-07-10)
- **WebDAV sync 409 AncestorsNotFound**: jianguoyun does not auto-create
  parent directories on PUT. `WebDavClient.mkcol` + `ensureAncestors` now
  MKCOL `/zhiyue/` and `/zhiyue/snapshots/` before the first push.
- **AI input field text lingering**: `_onSend` cleared the TextField after
  awaiting the full LLM streaming response. Now clears BEFORE the await,
  so the user sees their text disappear immediately on Enter / Send tap.

### Features
- **Freeform notes (Bug #3)**: unanchored Markdown notes — for AI-generated
  content worth keeping or the reader's own thoughts. Per-book (in reader
  drawer + NotesPage) AND global (Library drawer → 读书笔记库). Drift schema
  v12→v13 (`freeform_notes` table, nullable `book_id` FK CASCADE). Full
  WebDAV sync parity (SyncRecordType.freeformNote, tier 1 LWW). Edit/preview
  toggle with flutter_markdown rendering. Write-through debounce 500ms
  (avoid exit(0) truncation).
```

- [ ] **Step 3: Update README**

In `README.md`:
1. Update version badge from `1.8.0--alpha` to `1.9.0--alpha`.
2. Add a bullet point in "项目状态" section: `✅ v1.9.0-alpha: 自由笔记（per-book + global + Markdown + WebDAV 同步）+ 2 个用户测试 bug 修复（WebDAV 父目录、AI 输入清空）`.
3. Update test count if changed (re-run `flutter test` after Task 8 to count).

- [ ] **Step 4: Create release notes**

Create `docs/releases/release-notes-v1.9.0-alpha.md`:

```markdown
# v1.9.0-alpha Release Notes

**Tag**: `v1.9.0-alpha`
**Date**: 2026-07-10
**Scope**: Bug fixes from user testing + freeform notes (Bug #3)

## Bug fixes

1. **WebDAV sync 409 AncestorsNotFound** — jianguoyun WebDAV server does
   not auto-create parent directories on PUT. First-ever sync on a fresh
   account was failing because `/zhiyue/snapshots/` didn't exist. Now
   `WebDavClient.ensureAncestors` MKCOLs every directory segment up to
   the file before the first PUT.

2. **AI input field text lingering** — `_onSend` awaited the full LLM
   streaming response (`sendMessage` returns after `.last`) before
   clearing the TextField. Input now clears immediately on send (before
   the await), so the user sees their text disappear as soon as Enter /
   Send is pressed.

## Features: Freeform notes

A new note type that is NOT anchored to a specific passage in a book —
for AI-generated content worth keeping or the reader's own thoughts.

- **Per-book**: reader drawer notes tab + per-book NotesPage get a new
  "自由笔记" section with "+" button above the existing highlights list.
- **Global**: Library drawer (hamburger menu) has a new "读书笔记库"
  entry → lists all freeform notes (per-book + global) in one place.
- **Markdown editor**: title TextField + content TextField with edit/preview
  toggle (renders via `flutter_markdown`, same engine as AI responses).
- **Write-through**: each edit debounces 500ms then auto-saves (avoids
  `exit(0)` truncating dispose Futures; mirrors TypographyPersister).
- **Sync**: full WebDAV parity. `SyncRecordType.freeformNote` slots into
  RemoteRecordApplier tier 1 (same level as bookmark). Last-write-wins
  via `updated_at`. Tombstones propagate deletes.

## Schema

Drift schema bumped v12 → v13. New table `freeform_notes`:
- `id` TEXT PK (uuid)
- `book_id` TEXT NULLABLE FK books(id) ON DELETE CASCADE
- `title` TEXT
- `content` TEXT (Markdown)
- `created_at` / `updated_at` INTEGER (DateTime millis)
- `color` INTEGER DEFAULT 0

Migration is forward-only; no data backfill needed (table is empty on
creation).

## Known issues

- AI message "export to note" button deferred (next version).
- Master-detail two-pane layout for /notes-library deferred (v1.9.1).
- 5 plugin pub-cache sed patch still required for compileSdk 36 (S2 TODO).
```

- [ ] **Step 5: Commit**

```bash
git add app/pubspec.yaml CHANGELOG.md README.md docs/releases/release-notes-v1.9.0-alpha.md
git commit -m "chore(release): v1.9.0-alpha bump + changelog + release notes (Bug #3 T9)"
```

---

## Task 10: Full regression + analyze

- [ ] **Step 1: Run full test suite**

```bash
cd app && /c/flutter/bin/flutter test --concurrency=1
```

Expected: All new tests pass + 12 pre-existing baseline failures unchanged.

- [ ] **Step 2: Run analyze**

```bash
cd app && /c/flutter/bin/dart analyze
```

Expected: 0 errors / 0 warnings / 0 info.

- [ ] **Step 3: Final commit (if any cleanup)**

Only if Steps 1-2 surfaced issues. Otherwise skip.

---

## Self-Review Checklist (run before handoff)

**Spec coverage:**
- [x] drift schema bump 12→13 (Task 1)
- [x] FreeformNotesDao + outbox hooks (Task 2)
- [x] SyncRecordType.freeformNote + tier 1 + apply (Task 3)
- [x] NoteEditPage edit/preview toggle (Task 4)
- [x] Per-book entry: NotesDrawerContent (Task 5)
- [x] Per-book entry: NotesPage (Task 6)
- [x] Global entry: GlobalFreeformNotesPage + drawer ListTile (Task 7)
- [x] End-to-end sync integration test (Task 8)
- [x] Release prep (Task 9)
- [x] Full regression (Task 10)

**Placeholder scan:** None — all code blocks contain real code, all paths are absolute.

**Type consistency:**
- `FreeformNote` (data class generated by drift from `FreeformNotes` table) used consistently.
- `FreeformNotesDao.create/update/softDelete/listByBook/listAll/getById` signatures consistent across Task 2 (define) + Task 4 (use) + Task 7 (use).
- `SyncRecordType.freeformNote` consistent across Task 2 (recorder) + Task 3 (applier).
- `_createdId` lifecycle in NoteEditPage handles both create-mode and edit-mode.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-10-freeform-notes.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — dispatch fresh subagent per task, two-stage review (spec then code quality) between tasks.

**2. Inline Execution** — execute tasks in this session using executing-plans, batch with checkpoints.

**Which approach?**
