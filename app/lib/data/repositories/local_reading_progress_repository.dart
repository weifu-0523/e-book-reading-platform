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

import 'dart:convert';

import '../../core/locator.dart';
import '../../services/sync/sync_recorder.dart';
import '../local/database.dart' as db;
import '../local/daos/reading_progress_dao.dart';
import '../models/reading_progress.dart';
import 'reading_progress_repository.dart';

class LocalReadingProgressRepository implements ReadingProgressRepository {
  final ReadingProgressDao _dao;
  final SyncRecorder? _syncRecorder;

  LocalReadingProgressRepository(
    db.AppDatabase database, {
    SyncRecorder? syncRecorder,
  })  : _dao = ReadingProgressDao(database),
        _syncRecorder = syncRecorder;

  @override
  Future<ReadingProgress?> get(String bookId) async {
    final row = await _dao.getByBookId(bookId);
    if (row == null) return null;
    return ReadingProgress(
      bookId: row.bookId,
      locator: Locator.fromJson(
        jsonDecode(row.locator) as Map<String, dynamic>,
      ),
      percent: row.percent,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<void> save(ReadingProgress progress) async {
    // 单次 now() 同时给 DB 和 recorder，避免 μs 漂移导致 cross-device
    // LWW 误判（"我在手机翻到第 100 页保存了，桌面端却显示第 80 页"）。
    final now = DateTime.now();
    final locatorJson = jsonEncode(progress.locator.toJson());
    await _dao.upsert(
      bookId: progress.bookId,
      locatorJson: locatorJson,
      percent: progress.percent,
      updatedAt: now,
    );
    await _syncRecorder?.recordReadingProgress(
      bookId: progress.bookId,
      locatorJson: locatorJson,
      percent: progress.percent,
      mtime: now,
    );
  }
}
