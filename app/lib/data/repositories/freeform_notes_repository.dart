// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source Contributors
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

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../services/sync/sync_recorder.dart';
import '../local/database.dart';

/// Repository contract for the `freeform_notes` drift table (Bug #3,
/// 2026-07-10). Mirrors the [BookmarkRepository] pattern: every write
/// method calls [SyncRecorder] to enqueue a sync record into the outbox.
abstract class FreeformNotesRepository {
  Future<String> create({
    required String? bookId,
    required String title,
    required String content,
    int color = 0,
  });

  Future<void> update({
    required String id,
    String? title,
    String? content,
    int? color,
  });

  Future<void> delete(String id);

  Future<FreeformNote?> get(String id);
  Future<List<FreeformNote>> listForBook(String bookId);
  Future<List<FreeformNote>> listAll();
  Stream<List<FreeformNote>> watchForBook(String bookId);
  Stream<List<FreeformNote>> watchAll();
}

class LocalFreeformNotesRepository implements FreeformNotesRepository {
  LocalFreeformNotesRepository(
    AppDatabase database, {
    SyncRecorder? syncRecorder,
  })  : _db = database,
        _syncRecorder = syncRecorder;

  final AppDatabase _db;
  final SyncRecorder? _syncRecorder;

  @override
  Future<String> create({
    required String? bookId,
    required String title,
    required String content,
    int color = 0,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    await _db.into(_db.freeformNotes).insertOnConflictUpdate(
          FreeformNotesCompanion.insert(
            id: id,
            bookId: Value<String?>(bookId),
            title: title,
            content: content,
            createdAt: now,
            updatedAt: now,
            color: Value(color),
          ),
        );
    await _syncRecorder?.recordFreeformNote(
      id: id,
      bookId: bookId,
      title: title,
      content: content,
      color: color,
      createdAt: now,
      updatedAt: now,
    );
    return id;
  }

  @override
  Future<void> update({
    required String id,
    String? title,
    String? content,
    int? color,
  }) async {
    final existing = await get(id);
    if (existing == null) return;
    final newTitle = title ?? existing.title;
    final newContent = content ?? existing.content;
    final newColor = color ?? existing.color;
    final now = DateTime.now();
    await (_db.update(_db.freeformNotes)..where((t) => t.id.equals(id))).write(
      FreeformNotesCompanion(
        title: Value(newTitle),
        content: Value(newContent),
        color: Value(newColor),
        updatedAt: Value(now),
      ),
    );
    await _syncRecorder?.recordFreeformNote(
      id: id,
      bookId: existing.bookId,
      title: newTitle,
      content: newContent,
      color: newColor,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
  }

  @override
  Future<void> delete(String id) async {
    final existing = await get(id);
    if (existing == null) return;
    await (_db.delete(_db.freeformNotes)..where((t) => t.id.equals(id))).go();
    await _syncRecorder?.recordFreeformNoteDeletion(
      id: id,
      mtime: DateTime.now(),
    );
  }

  @override
  Future<FreeformNote?> get(String id) {
    return (_db.select(_db.freeformNotes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<FreeformNote>> listForBook(String bookId) {
    return (_db.select(_db.freeformNotes)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  @override
  Future<List<FreeformNote>> listAll() {
    return (_db.select(_db.freeformNotes)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  @override
  Stream<List<FreeformNote>> watchForBook(String bookId) {
    return (_db.select(_db.freeformNotes)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  @override
  Stream<List<FreeformNote>> watchAll() {
    return (_db.select(_db.freeformNotes)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }
}
