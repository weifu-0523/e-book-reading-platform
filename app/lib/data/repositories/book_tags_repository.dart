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

import '../../services/sync/sync_recorder.dart';
import '../local/database.dart';
import '../local/daos/book_tags_dao.dart';

/// Repository contract over the `book_tags` drift table (M2.8, 2026-07-12).
///
/// Wraps [BookTagsDao] to emit sync records on every mutation via
/// [SyncRecorder]. Read methods delegate to the DAO. Mirrors the
/// [FreeformNotesRepository] pattern: every write persists locally first,
/// then enqueues a sync record into the outbox.
abstract class BookTagsRepository {
  Future<List<String>> tagsOfBook(String bookId);
  Future<Set<String>> allTags();
  Future<List<String>> bookIdsWithTag(String tag);

  Future<void> addTag({required String bookId, required String tag});
  Future<void> removeTag({required String bookId, required String tag});
  Future<void> replaceTagsForBook({
    required String bookId,
    required List<String> tags,
  });
}

class LocalBookTagsRepository implements BookTagsRepository {
  LocalBookTagsRepository(
    AppDatabase database, {
    SyncRecorder? syncRecorder,
  })  : _tagsDao = BookTagsDao(database),
        _syncRecorder = syncRecorder;

  final BookTagsDao _tagsDao;
  final SyncRecorder? _syncRecorder;

  @override
  Future<List<String>> tagsOfBook(String bookId) =>
      _tagsDao.tagsOfBook(bookId);

  @override
  Future<Set<String>> allTags() => _tagsDao.allTags();

  @override
  Future<List<String>> bookIdsWithTag(String tag) =>
      _tagsDao.bookIdsWithTag(tag);

  @override
  Future<void> addTag({required String bookId, required String tag}) async {
    await _tagsDao.addTag(bookId: bookId, tag: tag);
    await _syncRecorder?.recordBookTag(bookId: bookId, tag: tag);
  }

  @override
  Future<void> removeTag({
    required String bookId,
    required String tag,
  }) async {
    await _tagsDao.removeTag(bookId: bookId, tag: tag);
    await _syncRecorder?.recordBookTagDeletion(bookId: bookId, tag: tag);
  }

  @override
  Future<void> replaceTagsForBook({
    required String bookId,
    required List<String> tags,
  }) async {
    // Diff against existing to emit minimal sync records: add only new
    // tags, tombstone only removed tags. Naively mirroring the DAO's
    // delete-all-then-insert would emit tombstones for unchanged tags,
    // causing flicker on the receiver when the next pull applies them.
    final existing = (await _tagsDao.tagsOfBook(bookId)).toSet();
    final newSet = tags.toSet();
    final toAdd = newSet.difference(existing);
    final toRemove = existing.difference(newSet);

    await _tagsDao.replaceTagsForBook(bookId: bookId, tags: tags);

    for (final t in toAdd) {
      await _syncRecorder?.recordBookTag(bookId: bookId, tag: t);
    }
    for (final t in toRemove) {
      await _syncRecorder?.recordBookTagDeletion(bookId: bookId, tag: t);
    }
  }
}
