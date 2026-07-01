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

import '../../../data/models/book.dart';
import '../models/book_filter.dart';

/// 把 [filter] 应用到 [books]，返回匹配子集。
///
/// - [tagsByBookId]：预查询的 per-book tag 集合；缺失视为空集。
/// - [now]：注入的"当前时间"，用于 TimeWindow 比较。生产用 `DateTime.now()`，
///   测试用固定值。
///
/// 返回顺序与 [books] 一致（不重排，排序由 VaultExporter 既有 title 字母序负责）。
List<Book> applyBookFilter({
  required List<Book> books,
  required BookFilter filter,
  required Map<String, Set<String>> tagsByBookId,
  required DateTime now,
}) {
  return books.where((b) {
    if (!_matchesTags(filter.tags, tagsByBookId[b.id] ?? const <String>{})) {
      return false;
    }
    if (!_withinWindow(b.addedAt, filter.addedAtWindow, now)) return false;
    if (!_withinNullableWindow(b.lastReadAt, filter.lastReadAtWindow, now)) {
      return false;
    }
    return true;
  }).toList();
}

bool _matchesTags(Set<String> selected, Set<String> bookTags) {
  if (selected.isEmpty) return true; // 不筛
  return selected.intersection(bookTags).isNotEmpty; // OR
}

bool _withinWindow(DateTime dt, TimeWindow w, DateTime now) {
  switch (w) {
    case TimeWindow.any:
      return true;
    case TimeWindow.last7Days:
      return now.difference(dt).inDays <= 7;
    case TimeWindow.last30Days:
      return now.difference(dt).inDays <= 30;
    case TimeWindow.last90Days:
      return now.difference(dt).inDays <= 90;
    case TimeWindow.thisYear:
      return dt.year == now.year;
  }
}

/// [dt] 为 null（从未读）时：`any` 通过；其他窗口一律不通过。
bool _withinNullableWindow(DateTime? dt, TimeWindow w, DateTime now) {
  if (dt == null) return w == TimeWindow.any;
  return _withinWindow(dt, w, now);
}
