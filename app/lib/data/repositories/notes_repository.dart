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

import '../models/annotation.dart';
import '../models/book_note.dart';

abstract class NotesRepository {
  Future<BookNote?> getNoteByBook(String bookId);
  Future<BookNote> createEmptyNote({
    required String id,
    required String bookId,
    required String bookTitle,
  });
  Future<void> updateNote(BookNote note);
  Future<List<Annotation>> listAnnotations(String noteId);
  Future<void> addAnnotation(Annotation annotation);
  Future<void> updateAnnotation(Annotation annotation);
  Future<void> deleteAnnotation(String id);
  Future<List<Annotation>> searchAnnotations(
    String query, {
    List<String>? tags,
    HighlightColor? color,
  });

  /// 用 AI 生成的回顾结果替换该章节的旧回顾内容。
  ///
  /// 幂等性：keyTakeaways 中 【第N章】 前缀的旧条目先删后加；
  ///        summary 中 `## 第 N 章` 段落先删后加。
  ///        用户手动添加的不带前缀的内容保留。
  /// BookNote 不存在则先 createEmptyNote。
  Future<void> applyChapterReview({
    required String bookId,
    required String bookTitle,
    required int chapterIndex,
    required String? chapterTitle,
    required String summary,
    required List<String> keyTakeaways,
  });

  /// 反应式订阅本书全部 Annotation。
  /// BookNote 不存在时立即 emit 空 list（让 UI 显示空状态而非 loading）。
  Stream<List<Annotation>> watchAnnotations(String bookId);
}
