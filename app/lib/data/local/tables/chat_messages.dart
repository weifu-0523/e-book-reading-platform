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

import 'chat_sessions.dart';

/// role: 'user' | 'ai' | 'system'
/// presetSource: 'card.chapter' | 'card.socratic' | '/chapter' | '/socratic'
///   | '/recap' | null
/// attachmentNoteId/Snapshot: 单消息单附件（@笔记 mention）
class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(ChatSessions, #id)();
  TextColumn get role => text()();
  TextColumn get content => text()();
  TextColumn get presetSource => text().nullable()();
  TextColumn get attachmentNoteId => text().nullable()();
  TextColumn get attachmentNoteSnapshot => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
