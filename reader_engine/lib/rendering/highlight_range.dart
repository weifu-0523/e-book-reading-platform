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

import 'package:meta/meta.dart';

/// 高亮区间数据（plain text 坐标）。
/// 由 EpubxRenderer 把 Annotation 适配为此类型，传给 HtmlHighlightInjector。
///
/// [startOffset]/[endOffset] 是**章节内** 0-based plain text 偏移（与
/// `currentChapterPlainText` 同坐标）。它们只在所属章节 [chapterIndex] 的
/// 坐标空间里有效——跨章渲染时必须用 chapterIndex 过滤，否则不同章的相同
/// offset 范围会被误匹配，产生"幽灵高亮"（M2.11/问题3 根因）。
@immutable
class HighlightRange {
  final int startOffset;
  final int endOffset;
  final String colorRgba;
  final bool hasNote;

  /// M2.11/问题3：此高亮所属的章节索引（0-based flatChapters）。
  /// 默认 -1 表示"未指定/不分章"（向后兼容旧调用方与 scroll 模式整章注入）。
  /// paged 模式渲染某章时，只取 chapterIndex == 当前章的高亮，避免跨章泄漏。
  final int chapterIndex;
  const HighlightRange(
    this.startOffset,
    this.endOffset,
    this.colorRgba, {
    this.hasNote = false,
    this.chapterIndex = -1,
  });

  /// 复制并改写 chapterIndex（供 localizeHighlights 把全局高亮平移到页面
  /// 本地坐标时保留所属章信息）。
  HighlightRange copyWithChapterLocal(int localStart, int localEnd) =>
      HighlightRange(
        localStart,
        localEnd,
        colorRgba,
        hasNote: hasNote,
        chapterIndex: chapterIndex,
      );
}
