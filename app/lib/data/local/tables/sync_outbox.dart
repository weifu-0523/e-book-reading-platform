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
