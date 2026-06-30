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

/// EPUB 位置编解码（zhiyue 简化格式）。
///
/// 格式：`<chapterIndex>:<charOffset>`，例如 `4:1024`。
///
/// 这**不是** EPUB CFI 规范（`epubcfi(/6/4!/4/10/3:10)`）——
/// pivot 到 epubx 后没有库生成规范 CFI，自研格式仅需 round-trip 一致。
/// 章节索引自 0 开始，字符偏移自 0 开始，分隔符固定为半角冒号 `:`。
///
/// 纯函数模块，无 Flutter 依赖，单测极快。

/// 把 (chapterIndex, charOffset) 编码为 cfi 字符串。
String encode(int chapterIndex, int charOffset) {
  if (chapterIndex < 0 || charOffset < 0) {
    throw ArgumentError(
      'chapterIndex and charOffset must be non-negative: '
      'chapterIndex=$chapterIndex, charOffset=$charOffset',
    );
  }
  return '$chapterIndex:$charOffset';
}

/// 把 cfi 字符串解码为 (chapterIndex, charOffset)。
///
/// 解析失败返回 null（容错，不抛异常）—— 调用方在 Task 12 处理 null
/// 时回退到 chapter 0 offset 0。
({int chapterIndex, int charOffset})? decode(String cfi) {
  final parts = cfi.split(':');
  if (parts.length != 2) return null;
  final chapter = int.tryParse(parts[0]);
  final offset = int.tryParse(parts[1]);
  if (chapter == null || offset == null) return null;
  if (chapter < 0 || offset < 0) return null;
  return (chapterIndex: chapter, charOffset: offset);
}

/// 验证 cfi 字符串是否合法。
bool isValid(String cfi) => decode(cfi) != null;
