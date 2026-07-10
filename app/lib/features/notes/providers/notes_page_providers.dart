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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart'
    show freeformNotesRepositoryProvider, notesRepositoryProvider;
import '../../../data/local/database.dart' hide Annotation, BookNote;
import '../../../data/models/annotation.dart';
import '../../../data/models/book_note.dart';

/// 反应式订阅本书全部 Annotation，供 [NotesPage] 使用。
///
/// `autoDispose` 让离开页面时关闭 Stream。family 按 bookId 分流。
final notesPageAnnotationsProvider =
    StreamProvider.autoDispose.family<List<Annotation>, String>(
  (ref, bookId) =>
      ref.watch(notesRepositoryProvider).watchAnnotations(bookId),
);

/// 一次性读取 BookNote 头部（标题/摘要/核心知识点），供 AppBar 标题与
/// Markdown 导出使用。
final notesPageBookNoteProvider =
    FutureProvider.autoDispose.family<BookNote?, String>(
  (ref, bookId) => ref.watch(notesRepositoryProvider).getNoteByBook(bookId),
);

/// Bug #3 (2026-07-10)：反应式订阅本书自由笔记。
/// 供 [NotesPage] 与 reader drawer 使用。
final bookFreeformNotesProvider =
    StreamProvider.autoDispose.family<List<FreeformNote>, String>(
  (ref, bookId) =>
      ref.watch(freeformNotesRepositoryProvider).watchForBook(bookId),
);

/// Bug #3 (2026-07-10)：反应式订阅全部自由笔记（global 视图）。
/// 供 GlobalFreeformNotesPage 使用。
final allFreeformNotesProvider =
    StreamProvider.autoDispose<List<FreeformNote>>(
  (ref) => ref.watch(freeformNotesRepositoryProvider).watchAll(),
);
