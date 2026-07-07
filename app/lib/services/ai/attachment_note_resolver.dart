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

import '../../data/local/daos/book_notes_dao.dart';

/// Immutable snapshot of a [BookNote] captured at the moment a user attaches
/// it (via `@note`) to a chat message.
///
/// The snapshot is what gets persisted to
/// `chat_messages.attachment_note_snapshot` so historical messages remain
/// readable even if the underlying [BookNote] is later edited or deleted.
///
/// Field mapping (M2.7 / 2026-07-07):
/// - [id]   ← `BookNote.id`
/// - [title]← `BookNote.title`
/// - [content] ← `BookNote.summary`（书的整体摘要被当作附件正文）
class NoteSnapshot {
  const NoteSnapshot({
    required this.id,
    required this.title,
    required this.content,
  });

  final String id;
  final String title;
  final String content;

  @override
  String toString() => 'NoteSnapshot(id=$id, title=$title)';
}

/// Resolves a `book_notes.id` to a [NoteSnapshot] for chat attachment.
///
/// Returns `null` for missing notes (rather than throwing) so callers can
/// decide whether to skip the attachment, show an error, or fall back to a
/// placeholder when the referenced note has been deleted.
class AttachmentNoteResolver {
  AttachmentNoteResolver(this._notesDao);

  final BookNotesDao _notesDao;

  /// Look up [noteId] and return an immutable snapshot, or `null` if the row
  /// no longer exists.
  Future<NoteSnapshot?> resolve(String noteId) async {
    final row = await _notesDao.findById(noteId);
    if (row == null) return null;
    return NoteSnapshot(
      id: row.id,
      title: row.title,
      content: row.summary,
    );
  }
}
