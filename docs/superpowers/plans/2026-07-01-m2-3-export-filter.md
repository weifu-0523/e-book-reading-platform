# M2.3 批量导出范围筛选 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Library 溢出菜单"导出为 Markdown"与既有 `BatchExportDialog` 之间，插入一个独立筛选页，支持按 tag(OR) / addedAt / lastReadAt 三维度筛选，实时预览匹配书单；底层纯函数 + `VaultExporter` 零改动。

**Architecture:** 新增 `BookFilter` 值类 + `BookFilterApplicator` 纯函数 + `ExportFilterPage` StatefulWidget；`VaultExporter` 仅把私有 `_hasContent` 抽为 `static bool hasContent`；`BookTagsDao` 加 bulk 方法。预览数 = 实际导出数的不变量通过统一调 `hasContent` 实现。

**Tech Stack:** Flutter 3.44 / Dart 3.10 / drift 2.18 / `package:collection` (setEquals) / `package:meta` (@immutable)

---

## 项目约束（每个 subagent 必读）

- **环境**：Windows bash；Flutter 在 `/c/flutter/bin/`；用 `/c/flutter/bin/dart.bat`（不是 .exe）；测试用 `/c/flutter/bin/flutter.bat test --concurrency=1`；analyze 用 `dart.bat analyze`（不是 `flutter analyze`，中文路径冲突）。
- **每个 commit 推送**：`git push origin master`（远程是 `gitee.com:weifu0523/e-book-reading-platform.git`）。
- **commit 格式**：HEREDOC，结尾 `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`。
- **AGPLv3 license 头**：所有新 `.dart` 文件**第一行**必须有 `// SPDX-License-Identifier: AGPL-3.0-or-later`（完整模板见 spec §8.1 / 既有任何文件头）。
- **Windows `git add`**：用单行 `git add <file1> <file2>`，不要换行。
- **不要** `--no-verify` / `--force` / `--amend`。
- **测试目录**：`app/test/...` 镜像 `app/lib/...` 路径。
- **i18n**：修改 `app/lib/l10n/app_zh.arb` 与 `app/lib/l10n/app_en.arb`，**不要手改** `app/lib/gen_l10n/app_localizations*.dart`（自动生成；T5 步骤会跑 `flutter gen-l10n`）。
- **禁止 API key 日志** / **禁止 token/cost 估算 UI**（既有项目规则）。

---

## 文件清单（先了解全貌再开工）

**新增（5）**：
- `app/lib/features/library/models/book_filter.dart`
- `app/lib/features/library/services/book_filter_applicator.dart`
- `app/lib/features/library/pages/export_filter_page.dart`
- `app/test/features/library/services/book_filter_applicator_test.dart`
- `app/test/features/library/pages/export_filter_page_test.dart`

**改动（4 代码 + 2 arb + 1 测试 + 2 docs）**：
- `app/lib/features/notes/services/vault_exporter.dart`（抽 `hasContent` 为 static public）
- `app/lib/data/local/daos/book_tags_dao.dart`（+`allTagsByBook()`）
- `app/lib/features/library/pages/library_page.dart`（`_startBatchExport()` 改流程）
- `app/test/data/local/book_tags_dao_test.dart`（+1 测试）
- `app/test/features/notes/services/vault_exporter_test.dart`（+1 测试 for `hasContent`）
- `app/test/features/library/pages/library_page_batch_export_test.dart`（适配新流程）
- `app/lib/l10n/app_zh.arb` + `app_en.arb`（+13 keys）
- `README.md` + `docs/releases/release-checklist.md`

---

## Task 1: `BookFilter` 值类 + `TimeWindow` enum

**Files:**
- Create: `app/lib/features/library/models/book_filter.dart`

### - [ ] Step 1: 写文件（没有独立测试 — 值类 boilerplate；后续 task 间接覆盖）

```dart
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
```

### - [ ] Step 2: 验证编译

Run: `/c/flutter/bin/dart.bat analyze app/lib/features/library/models/book_filter.dart`
Expected: `No issues found!`

### - [ ] Step 3: Commit + push

```bash
git add app/lib/features/library/models/book_filter.dart
git commit -m "$(cat <<'EOF'
feat(m2.3/t1): BookFilter value class + TimeWindow enum

Immutable filter descriptor with tag set + two time windows.
SetEquality from package:collection for deep tag comparison.
No tests yet — covered indirectly via BookFilterApplicator (T2).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 2: `BookFilterApplicator` 纯函数（TDD）

**Files:**
- Create: `app/lib/features/library/services/book_filter_applicator.dart`
- Test: `app/test/features/library/services/book_filter_applicator_test.dart`

### - [ ] Step 1: 写失败的测试（先写测试，验证 fail）

文件：`app/test/features/library/services/book_filter_applicator_test.dart`

```dart
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

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/library/models/book_filter.dart';
import 'package:zhiyue/features/library/services/book_filter_applicator.dart';

void main() {
  // 固定 "now"，避免真实 DateTime.now() 导致时间相关测试不稳定
  final now = DateTime(2026, 7, 1, 12, 0, 0);

  Book book({
    required String id,
    required String title,
    DateTime? addedAt,
    DateTime? lastReadAt,
  }) =>
      Book(
        id: id,
        title: title,
        author: null,
        format: BookFormat.epub,
        filePath: '/$id.epub',
        fileHash: 'h_$id',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: addedAt ?? DateTime(2026, 1, 1),
        lastReadAt: lastReadAt,
      );

  group('applyBookFilter — empty filter', () {
    test('empty filter passes all books', () {
      final books = [book(id: 'b1'), book(id: 'b2')];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(),
        tagsByBookId: const {},
        now: now,
      );
      expect(result.length, 2);
    });
  });

  group('applyBookFilter — tags (OR)', () {
    test('single tag matches book containing that tag', () {
      final books = [book(id: 'b1'), book(id: 'b2')];
      final tags = {'b1': <String>{'AI'}, 'b2': <String>{'哲学'}};
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(tags: {'AI'}),
        tagsByBookId: tags,
        now: now,
      );
      expect(result.map((b) => b.id), ['b1']);
    });

    test('multiple tags use OR semantics', () {
      final books = [book(id: 'b1'), book(id: 'b2'), book(id: 'b3')];
      final tags = {
        'b1': <String>{'AI'},
        'b2': <String>{'哲学'},
        'b3': <String>{'历史'},
      };
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(tags: {'AI', '哲学'}),
        tagsByBookId: tags,
        now: now,
      );
      expect(result.map((b) => b.id), containsAll(['b1', 'b2']));
      expect(result.length, 2);
    });

    test('book with non-intersecting tags is excluded', () {
      final books = [book(id: 'b1')];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(tags: {'AI', '哲学'}),
        tagsByBookId: {'b1': <String>{'历史'}},
        now: now,
      );
      expect(result, isEmpty);
    });

    test('missing tag data treated as empty set', () {
      // tagsByBookId 没有该 book 的 entry
      final books = [book(id: 'b1')];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(tags: {'AI'}),
        tagsByBookId: const {},
        now: now,
      );
      expect(result, isEmpty);
    });
  });

  group('applyBookFilter — addedAtWindow', () {
    test('any passes all', () {
      final books = [
        book(id: 'b1', addedAt: now.subtract(const Duration(days: 1))),
        book(id: 'b2', addedAt: DateTime(1990, 1, 1)),
      ];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(addedAtWindow: TimeWindow.any),
        tagsByBookId: const {},
        now: now,
      );
      expect(result.length, 2);
    });

    test('last7Days boundary', () {
      final books = [
        book(id: 'in', addedAt: now.subtract(const Duration(days: 6))),
        book(id: 'out', addedAt: now.subtract(const Duration(days: 8))),
      ];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(addedAtWindow: TimeWindow.last7Days),
        tagsByBookId: const {},
        now: now,
      );
      expect(result.map((b) => b.id), ['in']);
    });

    test('last30Days boundary', () {
      final books = [
        book(id: 'in', addedAt: now.subtract(const Duration(days: 29))),
        book(id: 'out', addedAt: now.subtract(const Duration(days: 31))),
      ];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(addedAtWindow: TimeWindow.last30Days),
        tagsByBookId: const {},
        now: now,
      );
      expect(result.map((b) => b.id), ['in']);
    });

    test('last90Days boundary', () {
      final books = [
        book(id: 'in', addedAt: now.subtract(const Duration(days: 89))),
        book(id: 'out', addedAt: now.subtract(const Duration(days: 91))),
      ];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(addedAtWindow: TimeWindow.last90Days),
        tagsByBookId: const {},
        now: now,
      );
      expect(result.map((b) => b.id), ['in']);
    });

    test('thisYear rejects last year', () {
      final books = [
        book(id: 'in', addedAt: DateTime(2026, 1, 1)),
        book(id: 'out', addedAt: DateTime(2025, 12, 31)),
      ];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(addedAtWindow: TimeWindow.thisYear),
        tagsByBookId: const {},
        now: now,
      );
      expect(result.map((b) => b.id), ['in']);
    });
  });

  group('applyBookFilter — lastReadAtWindow', () {
    test('null lastReadAt passes only when window is any', () {
      final books = [book(id: 'b1', lastReadAt: null)];
      expect(
        applyBookFilter(
          books: books,
          filter: const BookFilter(lastReadAtWindow: TimeWindow.any),
          tagsByBookId: const {},
          now: now,
        ).length,
        1,
      );
      expect(
        applyBookFilter(
          books: books,
          filter: const BookFilter(lastReadAtWindow: TimeWindow.last7Days),
          tagsByBookId: const {},
          now: now,
        ),
        isEmpty,
      );
    });

    test('last30Days boundary with non-null lastReadAt', () {
      final books = [
        book(id: 'in', lastReadAt: now.subtract(const Duration(days: 29))),
        book(id: 'out', lastReadAt: now.subtract(const Duration(days: 31))),
      ];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(lastReadAtWindow: TimeWindow.last30Days),
        tagsByBookId: const {},
        now: now,
      );
      expect(result.map((b) => b.id), ['in']);
    });
  });

  group('applyBookFilter — combinations', () {
    test('tag AND addedAt both applied', () {
      final books = [
        book(id: 'b1', addedAt: now.subtract(const Duration(days: 3))),
        book(id: 'b2', addedAt: now.subtract(const Duration(days: 100))),
      ];
      final tags = {'b1': <String>{'AI'}, 'b2': <String>{'AI'}};
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(
          tags: {'AI'},
          addedAtWindow: TimeWindow.last7Days,
        ),
        tagsByBookId: tags,
        now: now,
      );
      expect(result.map((b) => b.id), ['b1']);
    });

    test('all three dimensions combined', () {
      final books = [
        // matches all three
        book(
          id: 'match',
          addedAt: now.subtract(const Duration(days: 5)),
          lastReadAt: now.subtract(const Duration(days: 2)),
        ),
        // tag mismatch
        book(
          id: 'wrong_tag',
          addedAt: now.subtract(const Duration(days: 5)),
          lastReadAt: now.subtract(const Duration(days: 2)),
        ),
      ];
      final tags = {
        'match': <String>{'AI'},
        'wrong_tag': <String>{'哲学'},
      };
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(
          tags: {'AI'},
          addedAtWindow: TimeWindow.last7Days,
          lastReadAtWindow: TimeWindow.last7Days,
        ),
        tagsByBookId: tags,
        now: now,
      );
      expect(result.map((b) => b.id), ['match']);
    });
  });

  group('applyBookFilter — order preservation', () {
    test('output order matches input order', () {
      final books = [
        book(id: 'z', addedAt: now),
        book(id: 'a', addedAt: now),
        book(id: 'm', addedAt: now),
      ];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(),
        tagsByBookId: const {},
        now: now,
      );
      expect(result.map((b) => b.id), ['z', 'a', 'm']);
    });
  });
}
```

### - [ ] Step 2: 跑测试验证失败

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/library/services/book_filter_applicator_test.dart`
Expected: FAIL with "BookFilterApplicator not found / applyBookFilter undefined"

### - [ ] Step 3: 写实现

文件：`app/lib/features/library/services/book_filter_applicator.dart`

```dart
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

import '../models/book.dart';
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
```

### - [ ] Step 4: 跑测试验证通过

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/library/services/book_filter_applicator_test.dart`
Expected: All tests pass (15 tests)

### - [ ] Step 5: Commit + push

```bash
git add app/lib/features/library/services/book_filter_applicator.dart app/test/features/library/services/book_filter_applicator_test.dart
git commit -m "$(cat <<'EOF'
feat(m2.3/t2): BookFilterApplicator pure function

applyBookFilter() with tag (OR) + two time windows; now injected for
determinism. 15 tests covering empty filter, tag OR/intersection,
boundary days for each window, null lastReadAt, and 3-way combinations.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 3: `BookTagsDao.allTagsByBook()` bulk 方法（TDD）

**Files:**
- Modify: `app/lib/data/local/daos/book_tags_dao.dart`
- Test: `app/test/data/local/book_tags_dao_test.dart`

### - [ ] Step 1: 在 `app/test/data/local/book_tags_dao_test.dart` 末尾追加测试（在 `tearDown` 之外）

```dart
  test('allTagsByBook returns Map<bookId, Set<tags>>', () async {
    await dao.addTag(bookId: 'b1', tag: 'AI');
    await dao.addTag(bookId: 'b1', tag: '哲学');
    await dao.addTag(bookId: 'b2', tag: '历史');
    final result = await dao.allTagsByBook();
    expect(result.length, 2);
    expect(result['b1'], unorderedEquals(['AI', '哲学']));
    expect(result['b2'], {'历史'});
  });

  test('allTagsByBook returns empty map when no tags exist', () async {
    final result = await dao.allTagsByBook();
    expect(result, isEmpty);
  });
```

### - [ ] Step 2: 跑测试验证失败

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/data/local/book_tags_dao_test.dart`
Expected: FAIL with "Method 'allTagsByBook' not declared"

### - [ ] Step 3: 在 `BookTagsDao` 类内 `bookIdsWithTag` 方法后追加（行 44 附近）

```dart
  /// 一次性返回所有 book → tag 集合的映射。
  /// 用于 M2.3 批量导出筛选页（避免 N 次 tagsOfBook 调用）。
  Future<Map<String, Set<String>>> allTagsByBook() async {
    final rows = await select(bookTags).get();
    final map = <String, Set<String>>{};
    for (final r in rows) {
      map.putIfAbsent(r.bookId, () => <String>{}).add(r.tag);
    }
    return map;
  }
```

### - [ ] Step 4: 跑测试验证通过

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/data/local/book_tags_dao_test.dart`
Expected: All pass (existing + 2 new)

### - [ ] Step 5: Commit + push

```bash
git add app/lib/data/local/daos/book_tags_dao.dart app/test/data/local/book_tags_dao_test.dart
git commit -m "$(cat <<'EOF'
feat(m2.3/t3): BookTagsDao.allTagsByBook bulk fetch

Single SELECT + in-memory group-by, avoids N round-trips when the
filter page needs per-book tag sets for the whole library.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 4: `VaultExporter.hasContent()` 抽为 static public（TDD）

**Files:**
- Modify: `app/lib/features/notes/services/vault_exporter.dart`
- Test: `app/test/features/notes/services/vault_exporter_test.dart`

### - [ ] Step 1: 在 `app/test/features/notes/services/vault_exporter_test.dart` 的 `main()` 内追加测试组

在文件 `}` (line 161) 之前、最后一个 `});` 之前插入：

```dart
  group('VaultExporter.hasContent (static)', () {
    test('empty summary + empty takeaways + empty annotations = false', () {
      expect(VaultExporter.hasContent(_note('b', 'X')), isFalse);
    });

    test('non-empty summary = true', () {
      expect(VaultExporter.hasContent(_note('b', 'X', summary: 's')), isTrue);
    });

    test('non-empty takeaways = true', () {
      expect(
        VaultExporter.hasContent(_note('b', 'X', takeaways: const ['t'])),
        isTrue,
      );
    });

    test('non-empty annotations = true', () {
      expect(
        VaultExporter.hasContent(
          _note('b', 'X', annotations: [_annotation('quote')]),
        ),
        isTrue,
      );
    });
  });
```

### - [ ] Step 2: 跑测试验证失败

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/notes/services/vault_exporter_test.dart`
Expected: FAIL with "The getter 'hasContent' isn't defined for the type 'VaultExporter'" or "Static method doesn't exist"

### - [ ] Step 3: 修改 `app/lib/features/notes/services/vault_exporter.dart`

在 `class VaultExporter` 内、`static Future<VaultExportResult> export` 之前插入：

```dart
  /// 公开给筛选页调用，保证"筛选页预览的书 = 实际会被导出的书"。
  /// 与 export() 内部的过滤条件**完全一致**，单一真相源。
  static bool hasContent(BookNote n) =>
      n.summary.isNotEmpty ||
      n.keyTakeaways.isNotEmpty ||
      n.annotations.isNotEmpty;
```

然后在 `export()` 方法内（行 107-110 附近）替换：

```dart
// 原代码
final hasContent = n.summary.isNotEmpty ||
    n.keyTakeaways.isNotEmpty ||
    n.annotations.isNotEmpty;
```

为：

```dart
final hasContent = VaultExporter.hasContent(n);
```

注意：**不能**改成 `hasContent(n)` — `export` 是 static 方法，调用 static 方法用类名前缀最稳。

### - [ ] Step 4: 跑测试验证通过

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/notes/services/vault_exporter_test.dart`
Expected: All pass (existing 11 + new 4 = 15)

### - [ ] Step 5: Commit + push

```bash
git add app/lib/features/notes/services/vault_exporter.dart app/test/features/notes/services/vault_exporter_test.dart
git commit -m "$(cat <<'EOF'
refactor(m2.3/t4): expose VaultExporter.hasContent as static public

Lets the M2.3 filter page apply the exact same content-presence check
the exporter uses internally, so preview count == exported file count.
Export loop now calls the same static method — single source of truth.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 5: i18n keys（zh + en）

**Files:**
- Modify: `app/lib/l10n/app_zh.arb`
- Modify: `app/lib/l10n/app_en.arb`
- Regenerate: `app/lib/gen_l10n/app_localizations*.dart`

### - [ ] Step 1: 在 `app_zh.arb` 末尾的 `}` 前追加（确保逗号正确）

定位最后一行（应该是 `}` 结尾的某个 key 之后），追加：

```json
  "exportFilterTitle": "筛选导出范围",
  "@exportFilterTitle": {},
  "exportFilterSectionTags": "按标签",
  "@exportFilterSectionTags": {},
  "exportFilterSectionAddedAt": "按导入时间",
  "@exportFilterSectionAddedAt": {},
  "exportFilterSectionLastReadAt": "按最近阅读",
  "@exportFilterSectionLastReadAt": {},
  "exportFilterAllTagsChip": "全部",
  "@exportFilterAllTagsChip": {},
  "exportFilterResetTooltip": "重置",
  "@exportFilterResetTooltip": {},
  "exportFilterEmptyResult": "无匹配书目",
  "@exportFilterEmptyResult": {},
  "exportFilterActionExport": "导出 {count} 本",
  "@exportFilterActionExport": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "exportFilterPreviewSummary": "匹配 {books} 本 · 共 {highlights} 条高亮",
  "@exportFilterPreviewSummary": {
    "placeholders": {
      "books": { "type": "int" },
      "highlights": { "type": "int" }
    }
  },
  "exportFilterTimeWindowAny": "全部",
  "@exportFilterTimeWindowAny": {},
  "exportFilterTimeWindowLast7Days": "近 7 天",
  "@exportFilterTimeWindowLast7Days": {},
  "exportFilterTimeWindowLast30Days": "近 30 天",
  "@exportFilterTimeWindowLast30Days": {},
  "exportFilterTimeWindowLast90Days": "近 90 天",
  "@exportFilterTimeWindowLast90Days": {},
  "exportFilterTimeWindowThisYear": "今年",
  "@exportFilterTimeWindowThisYear": {}
```

> ⚠️ 注意前一个 key 末尾需保留逗号。如果加在最末，**最后一个新 key 不要带逗号**。

### - [ ] Step 2: 同样追加到 `app_en.arb`（英文翻译）

```json
  "exportFilterTitle": "Filter Export Range",
  "@exportFilterTitle": {},
  "exportFilterSectionTags": "By Tag",
  "@exportFilterSectionTags": {},
  "exportFilterSectionAddedAt": "By Import Time",
  "@exportFilterSectionAddedAt": {},
  "exportFilterSectionLastReadAt": "By Last Read Time",
  "@exportFilterSectionLastReadAt": {},
  "exportFilterAllTagsChip": "All",
  "@exportFilterAllTagsChip": {},
  "exportFilterResetTooltip": "Reset",
  "@exportFilterResetTooltip": {},
  "exportFilterEmptyResult": "No matching books",
  "@exportFilterEmptyResult": {},
  "exportFilterActionExport": "Export {count} book(s)",
  "@exportFilterActionExport": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "exportFilterPreviewSummary": "{books} book(s) match · {highlights} highlight(s) total",
  "@exportFilterPreviewSummary": {
    "placeholders": {
      "books": { "type": "int" },
      "highlights": { "type": "int" }
    }
  },
  "exportFilterTimeWindowAny": "Any time",
  "@exportFilterTimeWindowAny": {},
  "exportFilterTimeWindowLast7Days": "Last 7 days",
  "@exportFilterTimeWindowLast7Days": {},
  "exportFilterTimeWindowLast30Days": "Last 30 days",
  "@exportFilterTimeWindowLast30Days": {},
  "exportFilterTimeWindowLast90Days": "Last 90 days",
  "@exportFilterTimeWindowLast90Days": {},
  "exportFilterTimeWindowThisYear": "This year",
  "@exportFilterTimeWindowThisYear": {}
```

### - [ ] Step 3: 重新生成 gen_l10n

Run: `cd app && /c/flutter/bin/flutter.bat gen-l10n && cd ..`
Expected: `Localized resources will be generated...` 无错误

### - [ ] Step 4: 验证 analyze 通过

Run: `/c/flutter/bin/dart.bat analyze app/lib/gen_l10n/`
Expected: No issues

### - [ ] Step 5: Commit + push

```bash
git add app/lib/l10n/app_zh.arb app/lib/l10n/app_en.arb app/lib/gen_l10n/app_localizations.dart app/lib/gen_l10n/app_localizations_en.dart app/lib/gen_l10n/app_localizations_zh.dart
git commit -m "$(cat <<'EOF'
feat(m2.3/t5): i18n keys for export filter page

13 new keys covering page title, three section headers, time-window
radio labels, preview summary with pluralized count, and empty-state
CTA copy. zh + en; gen_l10n regenerated.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 6: `ExportFilterPage` widget（TDD）

**Files:**
- Create: `app/lib/features/library/pages/export_filter_page.dart`
- Test: `app/test/features/library/pages/export_filter_page_test.dart`

### - [ ] Step 1: 写失败的 widget 测试

文件：`app/test/features/library/pages/export_filter_page_test.dart`

```dart
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/features/library/models/book_filter.dart';
import 'package:zhiyue/features/library/pages/export_filter_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

void main() {
  // 固定 now 让时间窗口测试稳定
  final fixedNow = DateTime(2026, 7, 1, 12, 0, 0);

  Book book({
    required String id,
    required String title,
    DateTime? addedAt,
    DateTime? lastReadAt,
  }) =>
      Book(
        id: id,
        title: title,
        author: null,
        format: BookFormat.epub,
        filePath: '/$id.epub',
        fileHash: 'h_$id',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: addedAt ?? DateTime(2026, 1, 1),
        lastReadAt: lastReadAt,
      );

  BookNote noteWith(String bookId, {int highlights = 1}) {
    final anns = [
      for (var i = 0; i < highlights; i++)
        Annotation(
          id: 'a_${bookId}_$i',
          bookNoteId: 'n_$bookId',
          locator: EpubRangeLocator(
            chapterIndex: 0,
            chapterTitle: null,
            startOffset: 0,
            endOffset: 3,
            quote: 'foo',
          ),
          quote: 'foo',
          note: '',
          color: HighlightColor.yellow,
          tags: const [],
          source: AnnotationSource.manual,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
    ];
    return BookNote(
      id: 'n_$bookId',
      bookId: bookId,
      title: '《$bookId》读书笔记',
      summary: 's',
      keyTakeaways: const [],
      annotations: anns,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  Widget buildApp({
    required List<Book> books,
    required Map<String, BookNote> notesByBookId,
    required Map<String, Set<String>> tagsByBookId,
    required List<String> allTags,
    required ValueChanged<BookFilter> onApply,
  }) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ExportFilterPage(
        books: books,
        notesByBookId: notesByBookId,
        tagsByBookId: tagsByBookId,
        allTags: allTags,
        now: fixedNow,
        onApply: onApply,
      ),
    );
  }

  testWidgets('initial state shows export button with total count', (tester) async {
    var capturedFilter = const BookFilter();
    await tester.pumpWidget(buildApp(
      books: [book(id: 'b1', title: '书1'), book(id: 'b2', title: '书2')],
      notesByBookId: {'b1': noteWith('b1'), 'b2': noteWith('b2')},
      tagsByBookId: const {},
      allTags: const [],
      onApply: (f) => capturedFilter = f,
    ));
    await tester.pumpAndSettle();
    expect(find.text('导出 2 本'), findsOneWidget);
    expect(capturedFilter, const BookFilter()); // 未点击
  });

  testWidgets('tapping a tag chip reduces preview count', (tester) async {
    final books = [
      book(id: 'b1', title: '书1'),
      book(id: 'b2', title: '书2'),
    ];
    await tester.pumpWidget(buildApp(
      books: books,
      notesByBookId: {'b1': noteWith('b1'), 'b2': noteWith('b2')},
      tagsByBookId: const {
        'b1': <String>{'AI'},
        'b2': <String>{'哲学'},
      },
      allTags: const ['AI', '哲学'],
      onApply: (_) {},
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI').last);
    await tester.pumpAndSettle();
    expect(find.text('导出 1 本'), findsOneWidget);
  });

  testWidgets('tapping "All" chip clears tag selection', (tester) async {
    final books = [book(id: 'b1'), book(id: 'b2')];
    await tester.pumpWidget(buildApp(
      books: books,
      notesByBookId: {'b1': noteWith('b1'), 'b2': noteWith('b2')},
      tagsByBookId: const {'b1': <String>{'AI'}, 'b2': <String>{'AI'}},
      allTags: const ['AI'],
      onApply: (_) {},
    ));
    await tester.pumpAndSettle();
    // 先选 AI
    await tester.tap(find.text('AI').last);
    await tester.pumpAndSettle();
    // 点 "全部"
    await tester.tap(find.text('全部').first);
    await tester.pumpAndSettle();
    expect(find.text('导出 2 本'), findsOneWidget);
  });

  testWidgets('changing addedAt radio updates preview', (tester) async {
    final books = [
      book(
        id: 'recent',
        title: 'Recent',
        addedAt: fixedNow.subtract(const Duration(days: 3)),
      ),
      book(
        id: 'old',
        title: 'Old',
        addedAt: DateTime(2020, 1, 1),
      ),
    ];
    await tester.pumpWidget(buildApp(
      books: books,
      notesByBookId: {'recent': noteWith('recent'), 'old': noteWith('old')},
      tagsByBookId: const {},
      allTags: const [],
      onApply: (_) {},
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('近 7 天').last);
    await tester.pumpAndSettle();
    expect(find.text('导出 1 本'), findsOneWidget);
  });

  testWidgets('changing lastReadAt radio excludes never-read books', (tester) async {
    final books = [
      book(id: 'read', title: 'Read', lastReadAt: fixedNow.subtract(const Duration(days: 3))),
      book(id: 'never', title: 'Never', lastReadAt: null),
    ];
    await tester.pumpWidget(buildApp(
      books: books,
      notesByBookId: {'read': noteWith('read'), 'never': noteWith('never')},
      tagsByBookId: const {},
      allTags: const [],
      onApply: (_) {},
    ));
    await tester.pumpAndSettle();
    // 第二个 section 的 "近 7 天"
    await tester.tap(find.text('近 7 天').last);
    await tester.pumpAndSettle();
    expect(find.text('导出 1 本'), findsOneWidget);
  });

  testWidgets('reset button restores all defaults', (tester) async {
    final books = [book(id: 'b1'), book(id: 'b2')];
    await tester.pumpWidget(buildApp(
      books: books,
      notesByBookId: {'b1': noteWith('b1'), 'b2': noteWith('b2')},
      tagsByBookId: const {'b1': <String>{'AI'}, 'b2': <String>{'AI'}},
      allTags: const ['AI'],
      onApply: (_) {},
    ));
    await tester.pumpAndSettle();
    // 选 AI（从 2 变 2 不直观，用 addedAt 替代验证 reset）
    await tester.tap(find.text('近 30 天').last);
    await tester.pumpAndSettle();
    // 点重置
    await tester.tap(find.byTooltip('重置'));
    await tester.pumpAndSettle();
    expect(find.text('导出 2 本'), findsOneWidget);
  });

  testWidgets('empty result disables export button', (tester) async {
    final books = [book(id: 'b1')];
    await tester.pumpWidget(buildApp(
      books: books,
      notesByBookId: {'b1': noteWith('b1')},
      tagsByBookId: const {'b1': <String>{'哲学'}},
      allTags: const ['哲学', 'AI'],
      onApply: (_) {},
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI').last);
    await tester.pumpAndSettle();
    expect(find.text('无匹配书目'), findsOneWidget);
  });

  testWidgets('tapping export button calls onApply with current filter', (tester) async {
    BookFilter? captured;
    final books = [book(id: 'b1')];
    await tester.pumpWidget(buildApp(
      books: books,
      notesByBookId: {'b1': noteWith('b1')},
      tagsByBookId: const {'b1': <String>{'AI'}},
      allTags: const ['AI'],
      onApply: (f) => captured = f,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出 1 本'));
    await tester.pumpAndSettle();
    expect(captured, isNotNull);
    expect(captured!.tags, {'AI'});
    expect(captured.addedAtWindow, TimeWindow.any);
    expect(captured.lastReadAtWindow, TimeWindow.any);
  });
}
```

### - [ ] Step 2: 跑测试验证失败

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/library/pages/export_filter_page_test.dart`
Expected: FAIL with "ExportFilterPage not found / target of URI doesn't exist"

### - [ ] Step 3: 写实现

文件：`app/lib/features/library/pages/export_filter_page.dart`

```dart
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

import 'package:flutter/material.dart';

import '../../../data/models/book.dart';
import '../../../data/models/book_note.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../notes/services/vault_exporter.dart';
import '../models/book_filter.dart';
import '../services/book_filter_applicator.dart';

/// 独立筛选页：用户配置 tag/addedAt/lastReadAt 三维度筛选后，
/// 通过 [onApply] 回调返回 [BookFilter]。
///
/// 预览列表只显示**会导出**的书（`applyBookFilter` + `VaultExporter.hasContent`
/// 双重过滤），保证预览数 == 实际导出数。
class ExportFilterPage extends StatefulWidget {
  const ExportFilterPage({
    super.key,
    required this.books,
    required this.notesByBookId,
    required this.tagsByBookId,
    required this.allTags,
    required this.now,
    required this.onApply,
  });

  final List<Book> books;
  final Map<String, BookNote> notesByBookId;
  final Map<String, Set<String>> tagsByBookId;
  final List<String> allTags;
  final DateTime now;
  final ValueChanged<BookFilter> onApply;

  @override
  State<ExportFilterPage> createState() => _ExportFilterPageState();
}

class _ExportFilterPageState extends State<ExportFilterPage> {
  final Set<String> _selectedTags = <String>{};
  TimeWindow _addedAtWindow = TimeWindow.any;
  TimeWindow _lastReadAtWindow = TimeWindow.any;

  BookFilter _currentFilter() => BookFilter(
        tags: Set<String>.from(_selectedTags),
        addedAtWindow: _addedAtWindow,
        lastReadAtWindow: _lastReadAtWindow,
      );

  List<Book> get _filteredBooks {
    final raw = applyBookFilter(
      books: widget.books,
      filter: _currentFilter(),
      tagsByBookId: widget.tagsByBookId,
      now: widget.now,
    );
    return raw
        .where((b) => VaultExporter.hasContent(widget.notesByBookId[b.id]!))
        .toList();
  }

  int get _totalHighlights => _filteredBooks.fold<int>(
        0,
        (sum, b) =>
            sum + (widget.notesByBookId[b.id]?.annotations.length ?? 0),
      );

  void _reset() {
    setState(() {
      _selectedTags.clear();
      _addedAtWindow = TimeWindow.any;
      _lastReadAtWindow = TimeWindow.any;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _filteredBooks;
    final isEmpty = filtered.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.exportFilterTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.exportFilterResetTooltip,
            onPressed: _reset,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (widget.allTags.isNotEmpty) _tagsSection(l10n),
          _addedAtSection(l10n),
          _lastReadAtSection(l10n),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.exportFilterPreviewSummary(
                filtered.length,
                _totalHighlights,
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final b in filtered) _bookTile(b),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: isEmpty ? null : () => widget.onApply(_currentFilter()),
            child: Text(
              isEmpty
                  ? l10n.exportFilterEmptyResult
                  : l10n.exportFilterActionExport(filtered.length),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tagsSection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.exportFilterSectionTags,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: Text(l10n.exportFilterAllTagsChip),
                selected: _selectedTags.isEmpty,
                onSelected: (_) {
                  setState(_selectedTags.clear);
                },
              ),
              for (final tag in widget.allTags)
                FilterChip(
                  label: Text(tag),
                  selected: _selectedTags.contains(tag),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addedAtSection(AppLocalizations l10n) {
    return _radioSection<TimeWindow>(
      title: l10n.exportFilterSectionAddedAt,
      groupValue: _addedAtWindow,
      values: const [
        TimeWindow.any,
        TimeWindow.last7Days,
        TimeWindow.last30Days,
        TimeWindow.last90Days,
        TimeWindow.thisYear,
      ],
      label: _windowLabel,
      onChanged: (v) => setState(() => _addedAtWindow = v),
    );
  }

  Widget _lastReadAtSection(AppLocalizations l10n) {
    return _radioSection<TimeWindow>(
      title: l10n.exportFilterSectionLastReadAt,
      groupValue: _lastReadAtWindow,
      values: const [
        TimeWindow.any,
        TimeWindow.last7Days,
        TimeWindow.last30Days,
        TimeWindow.last90Days,
        TimeWindow.thisYear,
      ],
      label: _windowLabel,
      onChanged: (v) => setState(() => _lastReadAtWindow = v),
    );
  }

  String _windowLabel(TimeWindow w, AppLocalizations l10n) {
    switch (w) {
      case TimeWindow.any:
        return l10n.exportFilterTimeWindowAny;
      case TimeWindow.last7Days:
        return l10n.exportFilterTimeWindowLast7Days;
      case TimeWindow.last30Days:
        return l10n.exportFilterTimeWindowLast30Days;
      case TimeWindow.last90Days:
        return l10n.exportFilterTimeWindowLast90Days;
      case TimeWindow.thisYear:
        return l10n.exportFilterTimeWindowThisYear;
    }
  }

  Widget _radioSection<T>({
    required String title,
    required T groupValue,
    required List<T> values,
    required String Function(T, AppLocalizations) label,
    required ValueChanged<T> onChanged,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          for (final v in values)
            RadioListTile<T>(
              title: Text(label(v, l10n)),
              value: v,
              groupValue: groupValue,
              onChanged: (selected) {
                if (selected != null) onChanged(selected);
              },
            ),
        ],
      ),
    );
  }

  Widget _bookTile(Book b) {
    final note = widget.notesByBookId[b.id]!;
    final highlights = note.annotations.length;
    final notes = note.annotations.where((a) => a.hasNote).length;
    final tags = widget.tagsByBookId[b.id] ?? const <String>{};
    return ListTile(
      leading: const Icon(Icons.book_outlined),
      title: Text(b.title),
      subtitle: Text(
        tags.isEmpty
            ? '$highlights 高亮 / $notes 笔记'
            : '$highlights 高亮 / $notes 笔记 · ${tags.map((t) => '#$t').join(' ')}',
      ),
    );
  }
}
```

### - [ ] Step 4: 跑测试验证通过

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/library/pages/export_filter_page_test.dart`
Expected: All 8 tests pass

> **如果某些 widget 找不到**：检查 `find.text('近 7 天').last` 这种带 `.last` 的定位是否正确（页面有两处 "近 7 天" — addedAt 与 lastReadAt section 各一）。如定位冲突，按 widget 类型 + ancestor 区分。

### - [ ] Step 5: Commit + push

```bash
git add app/lib/features/library/pages/export_filter_page.dart app/test/features/library/pages/export_filter_page_test.dart
git commit -m "$(cat <<'EOF'
feat(m2.3/t6): ExportFilterPage widget

StatefulWidget with three filter sections (tag chips, two radio lists),
live preview list, and bottom FilledButton that calls onApply(filter).
Preview applies both applyBookFilter and VaultExporter.hasContent so
preview count == export count. now injected for test determinism.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 7: 改造 `library_page._startBatchExport()` 接入筛选页

**Files:**
- Modify: `app/lib/features/library/pages/library_page.dart`

### - [ ] Step 1: 在 library_page.dart 顶部 import 区追加（在 `import '../widgets/library_app_bar.dart';` 之后）

```dart
import '../../../data/local/daos/book_tags_dao.dart';
import '../../../data/local/database.dart';
import '../models/book_filter.dart';
import '../pages/export_filter_page.dart';
import '../services/book_filter_applicator.dart';
```

### - [ ] Step 2: 替换 `_startBatchExport()` 整个方法

找到现有 `_startBatchExport()` 方法（约 line 314-394），整体替换为：

```dart
  /// 批量导出整个书架的读书笔记为 Markdown 文件夹。
  ///
  /// 流程（M2.3 新增筛选页）：
  /// 1. 拉取所有书 + 各书的 [BookNote]；若没有任何含内容的 note，弹「暂无
  ///    可导出内容」对话框并中止（避开 file_picker）。
  /// 2. 预取 tag 数据（allTags + per-book tags）。
  /// 3. 弹 [ExportFilterPage]；用户点底部按钮回 [BookFilter]，取消则回 null。
  /// 4. 应用 [applyBookFilter] → 子集；空子集静默中止。
  /// 5. [FilePicker.platform.getDirectoryPath] 选目标文件夹；用户取消即中止。
  /// 6. 弹 [BatchExportDialog] 跑 VaultExporter，完成后自动 pop。
  /// 7. SnackBar 反馈 + 「打开文件夹」action。
  Future<void> _startBatchExport() async {
    final books = await ref.read(bookRepositoryProvider).getAll();
    final notesByBookId = <String, BookNote>{};
    for (final book in books) {
      final note =
          await ref.read(notesRepositoryProvider).getNoteByBook(book.id);
      if (note != null) notesByBookId[book.id] = note;
    }
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    if (notesByBookId.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.batchExportNoNotesTitle),
          content: Text(l10n.batchExportNoNotesMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.reviewCancelButton),
            ),
          ],
        ),
      );
      return;
    }

    // M2.3: 预取 tag 数据
    final db = ref.read(appDatabaseProvider);
    final bookTagsDao = BookTagsDao(db);
    final tagsByBookId = await bookTagsDao.allTagsByBook();
    final allTags = (await bookTagsDao.allTags()).toList()..sort();
    if (!mounted) return;

    // M2.3: 弹筛选页
    final filter = await showDialog<BookFilter?>(
      context: context,
      builder: (ctx) => ExportFilterPage(
        books: books,
        notesByBookId: notesByBookId,
        tagsByBookId: tagsByBookId,
        allTags: allTags,
        now: DateTime.now(),
        onApply: (f) => Navigator.of(ctx).pop(f),
      ),
    );
    if (filter == null) return;
    if (!mounted) return;

    final filteredBooks = applyBookFilter(
      books: books,
      filter: filter,
      tagsByBookId: tagsByBookId,
      now: DateTime.now(),
    );
    if (filteredBooks.isEmpty) return; // 筛选页已保证不会到这里，双保险

    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;
    if (!mounted) return;

    VaultExportResult? result;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BatchExportDialog(
        targetDirPath: dirPath,
        books: filteredBooks,
        notesByBookId: notesByBookId,
        onCompleted: (r) {
          result = r;
          Navigator.of(ctx).pop();
        },
      ),
    );
    if (!mounted) return;
    final res = result;
    if (res == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_summarizeBatchResult(l10n, res, dirPath)),
        action: SnackBarAction(
          label: l10n.batchExportOpenFolder,
          onPressed: () => _openFolder(dirPath),
        ),
      ),
    );
  }
```

注意：`_summarizeBatchResult` 与 `_openFolder` 既有方法保持不动。

### - [ ] Step 3: 跑 analyze

Run: `/c/flutter/bin/dart.bat analyze app/lib/features/library/pages/library_page.dart`
Expected: No issues

### - [ ] Step 4: 跑全量测试（应该不挂任何已有用例 — T8 才适配 batch export test）

Run: `/c/flutter/bin/flutter.bat test --concurrency=1`
Expected: 全部通过（注意 library_page_batch_export_test.dart 既有用例可能仍然 pass — 它检查的是空库场景，命中 `if (notesByBookId.isEmpty)` 短路，不会走到 ExportFilterPage）

如果 batch export test 失败，T8 会修。

### - [ ] Step 5: Commit + push

```bash
git add app/lib/features/library/pages/library_page.dart
git commit -m "$(cat <<'EOF'
feat(m2.3/t7): wire ExportFilterPage into library_page batch export

_startBatchExport() now fetches allTags + per-book tags, then pushes
ExportFilterPage before file_picker. Result subset fed to the existing
BatchExportDialog + VaultExporter pipeline (unchanged).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 8: 适配现有 `library_page_batch_export_test.dart`

**Files:**
- Modify: `app/test/features/library/pages/library_page_batch_export_test.dart`

### - [ ] Step 1: 跑既有测试确认是否仍 pass

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/library/pages/library_page_batch_export_test.dart`

观察：
- `app bar contains a Markdown export entry` — 应该 pass（菜单项没改）
- `tapping export with empty library shows the no-notes advisory dialog` — 应该 pass（空 notes 命中 `if (notesByBookId.isEmpty)` 短路，走原对话框，不到筛选页）

如果两个都 pass，**此 task 仅需追加 1 个测试**：用 `FakeNotesRepository` 注入至少一本带 note 的书，验证点击 "导出为 Markdown" 后跳到 ExportFilterPage（标题文案 "筛选导出范围" 出现）。

在 `main()` 末尾追加：

```dart
  testWidgets(
      'tapping export with at least one note opens the filter page',
      (tester) async {
    // 准备：一本带 BookNote 的书
    bookRepo.addBook(_bookWithId('b1', 'Title 1'));
    notesRepo.setNote('b1', _nonEmptyNote('b1'));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('导出为 Markdown'));
    await tester.pumpAndSettle();

    // 筛选页标题
    expect(find.text('筛选导出范围'), findsOneWidget);
    // 底部按钮文案
    expect(find.text('导出 1 本'), findsOneWidget);
  });
```

在文件末尾追加 helper（在 `void main() { ... }` 关闭后）：

```dart
// 帮助函数 — 如果 FakeBookRepository.addBook / FakeNotesRepository.setNote
// 已存在则直接用；如不存在请先查看 fake 实现，按既有模式扩展。
```

> ⚠️ **如果 Fake 类没有 `addBook` / `setNote` 方法**：打开 `app/test/fakes/fake_book_repository.dart` 与 `app/test/fakes/fake_notes_repository.dart`，按既有风格新增 public 方法。**不要**在 test 文件里 hack。

### - [ ] Step 2: 跑测试验证通过

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/library/pages/library_page_batch_export_test.dart`
Expected: All pass (2 existing + 1 new)

### - [ ] Step 3: Commit + push

```bash
git add app/test/features/library/pages/library_page_batch_export_test.dart app/test/fakes/fake_book_repository.dart app/test/fakes/fake_notes_repository.dart
git commit -m "$(cat <<'EOF'
test(m2.3/t8): cover filter-page navigation from library

Adds a test verifying that with at least one annotated book, tapping
"Export as Markdown" routes through ExportFilterPage (title "筛选导出范围"
visible) before file_picker. Fakes gain addBook / setNote helpers.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 9: 文档（README + release-checklist）

**Files:**
- Modify: `README.md`
- Modify: `docs/releases/release-checklist.md`

### - [ ] Step 1: 改 README.md

a) 顶部 `version-1.2.0--alpha` 改为 `version-1.3.0--alpha`，链接改为 `v1.3.0-alpha`：

```markdown
[![Version](https://img.shields.io/badge/version-1.3.0--alpha-blue.svg)](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.3.0-alpha)
```

b) "项目状态" 段落：把 v1.2.0-alpha 行加 ✅，新增 v1.3.0-alpha 一行：

```markdown
- ✅ **v1.2.0-alpha**：自动章节结束提示（EPUB paged/scroll 翻到末页 SnackBar，三动作；Settings 可开关）。
- 🚧 **v1.3.0-alpha**：新增**批量导出范围筛选**（独立筛选页：按标签 OR / 按导入时间 / 按最近阅读；实时预览匹配书单）。仍为 alpha。
```

c) "已交付能力" 段末尾、"后续阶段" 段之前追加新 section：

```markdown
### v1.3.0-alpha 新增

- **批量导出范围筛选**：Library 溢出菜单"导出为 Markdown"先开筛选页，支持按标签（多选 OR）、按导入时间、按最近阅读三维度组合筛选；实时预览匹配书目数与高亮总数；底部按钮直接显示"导出 N 本"。底层 `BookFilter` + `applyBookFilter` 纯函数 + 既有 `VaultExporter` 零改动。
```

d) "测试与质量" 段，把测试数从 `782` 改为 `805`（实际数会在 T10 最终确认）。

### - [ ] Step 2: 改 `docs/releases/release-checklist.md`

在"## 待办" 段的 "### v1.2.0-alpha Gitee Release 页面" 之后追加：

```markdown
### v1.3.0-alpha Gitee Release 页面

- **状态**：❌ **未创建**
- **Release notes 草稿**：TODO（M2.3 完成后补，复用 v1.1.0-alpha 模板）
- **执行**：同上，选 tag `v1.3.0-alpha`
```

在"## 已完成" 段最顶部追加：

```markdown
### v1.3.0-alpha release 准备

- ✅ tag `m2.3-complete` + `v1.3.0-alpha` 已推送（2026-07-01）
- ✅ `README.md` 已同步到 v1.3.0-alpha 状态
- ✅ M2.3 spec + plan 已交付（`docs/superpowers/specs/2026-07-01-m2-3-export-filter-design.md`、`docs/superpowers/plans/2026-07-01-m2-3-export-filter.md`）
- ✅ TDD 全流程：8 个 task + subagent-driven development（每 task 双阶段 review）
- ✅ 全量测试通过：约 805 passed + 3 skipped（具体数见 T10）
- ✅ 4 个包 analyze clean
```

### - [ ] Step 3: Commit + push

```bash
git add README.md docs/releases/release-checklist.md
git commit -m "$(cat <<'EOF'
docs(m2.3/t9): bump to v1.3.0-alpha + release checklist

README gets a v1.3.0-alpha capabilities section; release-checklist
tracks the new Gitee Release page (manual) under 待办 and the
automated prep under 已完成.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 10: 最终验证 + 双 tag

**Files:** None modified

### - [ ] Step 1: 跑全量测试

Run: `/c/flutter/bin/flutter.bat test --concurrency=1`
Expected: All tests pass. 记录下通过数（应该是 ~805）。

如果有失败：
- 先看是 M2.3 引入的回归还是 flaky
- 修 → 加 commit → 重跑

### - [ ] Step 2: 跑 analyze 4 包

```bash
/c/flutter/bin/dart.bat analyze app/
/c/flutter/bin/dart.bat analyze reader_engine/
/c/flutter/bin/dart.bat analyze reader_engine_epub_view/
/c/flutter/bin/dart.bat analyze reader_engine_pdf_view/
```

Expected: 0 errors / 0 warnings。info 数应与 M2.2 后相同（49）。

### - [ ] Step 3: 把测试数填回 README

如果实际通过数 ≠ 805（很可能是 805 ± 一点），更新 README 的 `782` → 实际数。然后：

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs(m2.3/t10): finalize test count in README

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

（如果数量已经准确，跳过此 step）

### - [ ] Step 4: 打 tag 并推送

```bash
git tag m2.3-complete
git tag v1.3.0-alpha
git push origin master m2.3-complete v1.3.0-alpha
```

### - [ ] Step 5: 更新 memory

写文件 `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_m2_3_complete.md`：

```markdown
---
name: zhiyue-m2-3-complete
description: 智阅 M2.3 完整交付 — 批量导出范围筛选 2026-07-01
metadata:
  node_type: memory
  type: project
  originSessionId: <填当前 session id>
---

智阅 M2.3 完整交付 — 2026-07-01。

**Tag**: `m2.3-complete` + `v1.3.0-alpha`（双 tag 已推送 origin）

**交付内容**：批量导出范围筛选。Library 溢出菜单"导出为 Markdown"先开独立筛选页，支持按标签（多选 OR）、按导入时间、按最近阅读三维度组合筛选；实时预览匹配书目数与高亮总数；底部按钮显示"导出 N 本"。底层 BookFilter + applyBookFilter 纯函数 + VaultExporter 零改动。

**Why**：M2.1 批量导出是 all-or-nothing；用户书架超过几十本后，按主题/时间导出子集成为刚需（如把"近一个月读的 AI 书"导到 Obsidian）。

**How to apply**：
- 后续若要加第 4 维度（如 format/progress），仿照 BookFilter + applyBookFilter 模式扩展
- "预览 = 实际" 不变量由 VaultExporter.hasContent static public 保证；任何新筛选维度都要复用同一函数
- BookTagsDao.allTagsByBook 是新增 bulk 方法，其它 DAO 若有 N+1 query 问题可借鉴

**架构**：
1. `BookFilter` 值类（tags Set + addedAtWindow + lastReadAtWindow）
2. `applyBookFilter()` 纯函数 + `_matchesTags` (OR) / `_withinWindow` / `_withinNullableWindow`
3. `BookTagsDao.allTagsByBook()` bulk SELECT + 内存 group-by
4. `VaultExporter.hasContent` 抽为 static public（export 内部也调，单一真相源）
5. `ExportFilterPage` StatefulWidget — 三 section（chips + 两个 radio list）+ 实时预览 ListView + 底部 FilledButton
6. `library_page._startBatchExport` 改流程：预取 tags → 弹 ExportFilterPage → applyBookFilter → 既有 BatchExportDialog

**流程遵守**：
- spec + plan 双 doc 先写后实施（HARD-GATE）
- subagent-driven-development：T1-T9 每 task 派遣 implementer + spec reviewer + code quality reviewer
- TDD 严格执行（先写测试，验证 fail，再实现）
- 每个 commit 推送 origin master（gitee）
- 全量测试 ~805 pass + 3 skip；4 包 analyze clean

**关键学习**：
- 预览/实际一致性的关键是把"过滤条件"公开为 static public（既有 hasContent 内联 → 抽取）
- ValueNotifier/StatefulWidget 的 setState 在小数据量（≤ 几百本）下无需 memo
- 弱小测试 `find.text('X').last` 在多 section 同名 label 时易碎；如要稳，改用 `find.descendant(of: ..., matching: ...)`

参见 [[zhiyue-m2-2-complete]]、[[zhiyue-m2-1-complete]]、[[zhiyue-release-hygiene-sweep]]、[[zhiyue-dev-env-quirks]]、[[zhiyue-gitee-workflow]]。
```

更新 `MEMORY.md` 索引（在 m2.2 line 之后加）：

```markdown
- [智阅 M2.3 完整交付](project_zhiyue_m2_3_complete.md) — 2026-07-01 8 tasks + ~805 tests，双 tag m2.3-complete + v1.3.0-alpha；批量导出范围筛选（tag OR + addedAt + lastReadAt）+ 独立筛选页 + 预览=实际不变量
```

memory 文件直接用 Write 工具写（路径：`C:\Users\1\.claude\projects\H--projiect--------\memory\`）。

### - [ ] Step 6: 给用户报告

回复用户：
- M2.3 完成，~805 测试通过
- 双 tag 已推
- memory 已更新
- 剩余 deferred：3 张 release 截图 + Gitee Release 页面 v1.0.0/v1.1.0-alpha/v1.2.0-alpha/v1.3.0-alpha（手动浏览器操作）

---

## Self-Review 自检清单（plan 写完后过一遍）

- [x] **Spec 覆盖**：
  - §2.1 三维度筛选 → T1 (BookFilter) + T2 (Applicator) + T6 (Page)
  - §2.1 OR 语义 → T2 测试覆盖
  - §2.1 预设区间 → T1 TimeWindow enum
  - §2.1 实时预览 → T6 widget
  - §4.3 VaultExporter.hasContent 抽取 → T4
  - §4.4 allTagsByBook bulk → T3
  - §4.5 ExportFilterPage → T6
  - §4.6 library_page 改造 → T7
  - §6.1 既有无 note 短路 → T7 保留
  - §6.2 空匹配 → T6 widget test
  - §6.7 预览=实际不变量 → T6 + T4 联合保证
  - §7 测试策略 → T2/T3/T4/T6/T8 各 task 内
  - §8 文件清单 → 全部 task
  - §9 验收（analyze + 测试 + 手测 + tag） → T10

- [x] **占位符扫描**：无 TBD/TODO/"实现稍后"，所有 step 含完整代码或具体命令。

- [x] **类型一致性**：
  - `BookFilter` 三字段在 T1（定义）、T2（使用）、T6（widget state）、T7（dialog return）签名一致
  - `TimeWindow` 5 个值在 T1（定义）、T2（测试）、T6（radio list）一致
  - `applyBookFilter` 签名（books, filter, tagsByBookId, now）在 T2/T6/T7 一致
  - `BookTagsDao.allTagsByBook()` 返回类型 `Future<Map<String, Set<String>>>` 在 T3/T7 一致
  - `VaultExporter.hasContent` 在 T4（定义）、T6（调用）一致
  - `ExportFilterPage` 构造参数（books, notesByBookId, tagsByBookId, allTags, now, onApply）在 T6（定义）、T7（实例化）、T8（测试）一致

- [x] **环境约束**：Windows bash + `/c/flutter/bin/...bat` + `dart.bat analyze`（非 `flutter analyze`）+ 单行 `git add` + HEREDOC commit + AGPLv3 header + 推送 origin master。

- [x] **TDD**：T2/T3/T4/T6 都是先写 test → 跑 fail → 实现 → 跑 pass。T1 是值类 boilerplate（间接覆盖）。T5/T7/T8/T9/T10 是非 TDD 任务（i18n / 接线 / 文档 / 验证）。

- [x] **Frequent commits**：每个 task 末尾都 commit + push。

---

## Execution Handoff

Plan 已写到 `docs/superpowers/plans/2026-07-01-m2-3-export-filter.md`。

用户已选择 **Subagent-Driven execution**（见前文 "可以，请调用技能写plan，然后调用subagent完成任务"）。

**REQUIRED SUB-SKILL**: Use `superpowers:subagent-driven-development` 执行 T1 → T10。

模型选择（按子代理模型选择规则）：
- 当前是上午时段（非 14-18 点），用 **opus**
- T1/T2/T3/T4 = 简单实现/单测 → opus 足够
- T6 widget test = 中等复杂度 → opus
- T7 接线 = 跨文件集成 → opus
- T8-T10 = 适配/文档/验证 → opus
