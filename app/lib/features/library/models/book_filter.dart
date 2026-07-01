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

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// 预设时间窗口。`any` 表示不筛；其余按字面 [Duration] 含义。
/// "今年"按 [DateTime.year] 相等判断，不是固定天数。
enum TimeWindow { any, last7Days, last30Days, last90Days, thisYear }

/// 批量导出筛选条件。三维度 AND 组合：
/// - [tags]：多选，书与选中标签取交集非空即通过（OR 语义）
/// - [addedAtWindow]：单选
/// - [lastReadAtWindow]：单选；null lastReadAt 在 any 外的窗口都不过
@immutable
class BookFilter {
  final Set<String> tags;
  final TimeWindow addedAtWindow;
  final TimeWindow lastReadAtWindow;

  const BookFilter({
    this.tags = const <String>{},
    this.addedAtWindow = TimeWindow.any,
    this.lastReadAtWindow = TimeWindow.any,
  });

  /// 三维度全部默认值 = 等价于"不筛"。
  bool get isEmpty =>
      tags.isEmpty &&
      addedAtWindow == TimeWindow.any &&
      lastReadAtWindow == TimeWindow.any;

  BookFilter copyWith({
    Set<String>? tags,
    TimeWindow? addedAtWindow,
    TimeWindow? lastReadAtWindow,
  }) =>
      BookFilter(
        tags: tags ?? this.tags,
        addedAtWindow: addedAtWindow ?? this.addedAtWindow,
        lastReadAtWindow: lastReadAtWindow ?? this.lastReadAtWindow,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookFilter &&
          const SetEquality<String>().equals(tags, other.tags) &&
          addedAtWindow == other.addedAtWindow &&
          lastReadAtWindow == other.lastReadAtWindow);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(tags),
        addedAtWindow,
        lastReadAtWindow,
      );
}
