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

import 'package:drift/drift.dart';

class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get format => text()(); // 'epub' | 'pdf'
  TextColumn get filePath => text()();
  TextColumn get fileHash => text()();
  IntColumn get fileSizeBytes => integer()();
  TextColumn get coverPath => text().nullable()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastReadAt => dateTime().nullable()();

  /// M3.1：手动排序顺序；null = 不参与手动排序，按默认排序。
  IntColumn get sortOrder => integer().nullable()();

  /// M2.8: Timestamp (ms since epoch) when the book's binary file was
  /// successfully uploaded to WebDAV. NULL = not yet uploaded (or download
  /// pending on receiver side). Receiver uses this + local file_path ==
  /// '__needs_download__' to decide whether to fetch the binary.
  IntColumn get fileSyncedAt => integer().nullable()();

  /// TTS resume cursor: JSON-encoded {chapterIdx, sentenceIdx, updatedAt}.
  /// NULL = book never read aloud (or reset). See LastTtsPosition model (T10).
  TextColumn get lastTtsPosition => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
