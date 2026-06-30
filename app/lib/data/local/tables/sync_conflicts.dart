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
