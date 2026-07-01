# 智阅 M2.3 — 批量导出范围筛选 设计文档

> **版本**：1.0
> **创建日期**：2026-07-01
> **前置**：v1.2.0-alpha（tag `m2.2-complete` + `v1.2.0-alpha`，commit `6ef4d03`）
> **后续 tag**：`m2.3-complete` + `v1.3.0-alpha`
> **协议**：AGPLv3
> **状态**：设计已与用户确认，待写实施 plan

---

## 1. 背景

`docs/reviews/2026-07-01-project-review.md` §5.4 把"批量导出筛选（按 tag / 时间）"列为推后项。当前 `_startBatchExport()`（`app/lib/features/library/pages/library_page.dart:314`）把**所有书**塞给 `VaultExporter`，零筛选能力。M2.3 补齐这一层。

## 2. 范围与非目标

### 2.1 范围

- 在 Library 溢出菜单"导出为 Markdown" 与既有 `BatchExportDialog` 之间，插入一个**独立筛选页**
- 支持三个筛选维度（用户在 brainstorm 中选定）：
  - **按标签**：多选 chip cloud，OR 语义（书的 tag 集合 ∩ 选中 tags 非空即通过）
  - **按导入时间**：单选预设区间（全部 / 近 7 天 / 近 30 天 / 近 90 天 / 今年）
  - **按最近阅读**：单选预设区间（同上）
- 三维度之间 AND 关系
- 实时预览：匹配书目数 + 高亮总数 + 完整书单卡片
- 底部"导出 N 本"按钮，空匹配时 disabled

### 2.2 非目标（明确不做）

- 按 format（epub/pdf）筛选 — brainstorm 中用户未选
- 按 progress（阅读进度）筛选 — 数据不在 Book model 主字段，超出本次范围
- 任意日期区间（日历选择器）— 用户选了预设区间选项
- AND/OR 可切换语义 — 用户选了固定 OR
- 筛选条件跨会话持久化 — 用户选了"不记忆"，每次默认全选
- PDF 端特殊路径 — VaultExporter 本就支持 PDF BookNote，筛选层无差别
- 筛选页内嵌"搜索书名"框 — YAGNI
- 筛选页内嵌"排序"控件 — 沿用 VaultExporter 既有 title 字母序
- 在 Reader 或 NotesPage 入口加导出快捷方式 — 仅 Library 入口

## 3. 总体架构

M2.3 在 M2.1 既有的 `VaultExporter` 之上加一层**纯函数筛选**。用户点"导出为 Markdown" → 进独立筛选页 → 实时预览匹配书单 → 点"导出 N 本" → 选文件夹 → 既有 `BatchExportDialog` + `VaultExporter` 跑（**零改动**）。

```
[Library 溢出菜单] → "导出为 Markdown"
        ↓ click
library_page._startBatchExport()  ← 改造点
        ↓
预取：books / notesByBookId / tagsByBookId
        ↓
showDialog<BookFilter?>(ExportFilterPage(...))
        ↓ 用户配置 + 点底部"导出 N 本"
回值 BookFilter  →  Navigator.pop
        ↓
applyBookFilter(...)  →  filteredBooks
        ↓
filteredBooks.isEmpty ? 短路 : file_picker.getDirectoryPath()
        ↓
BatchExportDialog（既有，零改动）
        ↓
VaultExporter.export（既有，零改动）
        ↓
SnackBar 反馈（沿用 _summarizeBatchResult）
```

**零改动**：`VaultExporter` / `BatchExportDialog` / `MarkdownExporter`。仅在 `VaultExporter` 中把 `_hasContent` 从私有函数抽为 `static bool`（公开给筛选页调用，保证预览数 = 导出数）。

**新增依赖**：无（`flutter/material` + `package:meta` + `dart:async` 已在 pubspec）。

## 4. 组件详细设计

### 4.1 `BookFilter` 值类

文件：`app/lib/features/library/models/book_filter.dart`

```dart
import 'package:meta/meta.dart';

/// 预设时间窗口。`any` 表示不筛；其余按字面 [Duration] 含义。
/// "今年"按 [DateTime.year] 相等判断，不是固定天数。
enum TimeWindow { any, last7Days, last30Days, last90Days, thisYear }

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
  }) => BookFilter(
        tags: tags ?? this.tags,
        addedAtWindow: addedAtWindow ?? this.addedAtWindow,
        lastReadAtWindow: lastReadAtWindow ?? this.lastReadAtWindow,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookFilter &&
          setEquals(tags, other.tags) &&
          addedAtWindow == other.addedAtWindow &&
          lastReadAtWindow == other.lastReadAtWindow);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(tags),
        addedAtWindow,
        lastReadAtWindow,
      );
}

// setEquals 来自 package:collection；如果项目未直接依赖，用 Object.hashAllUnordered
// + 手动深比也行。需在 plan 里说明。
```

### 4.2 `BookFilterApplicator`

文件：`app/lib/features/library/services/book_filter_applicator.dart`

```dart
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

### 4.3 `VaultExporter` 微调

文件：`app/lib/features/notes/services/vault_exporter.dart`

把现有的私有 hasContent 判断：

```dart
// 现状（行 107-110）
final hasContent = n.summary.isNotEmpty ||
    n.keyTakeaways.isNotEmpty ||
    n.annotations.isNotEmpty;
```

抽为：

```dart
/// 公开给筛选页调用，保证"筛选页预览的书 = 实际会被导出的书"。
static bool hasContent(BookNote n) =>
    n.summary.isNotEmpty ||
    n.keyTakeaways.isNotEmpty ||
    n.annotations.isNotEmpty;
```

并替换原 `final hasContent = ...` 为 `final hasContent = hasContent(n);`。

### 4.4 `BookTagsDao` 新增 bulk 方法

文件：`app/lib/data/local/daos/book_tags_dao.dart`

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

### 4.5 `ExportFilterPage`

文件：`app/lib/features/library/pages/export_filter_page.dart`

**构造函数签名**：

```dart
class ExportFilterPage extends StatefulWidget {
  const ExportFilterPage({
    super.key,
    required this.books,
    required this.notesByBookId,
    required this.tagsByBookId,
    required this.allTags,  // 全集 tag 列表（用于渲染 chip cloud）
  });

  final List<Book> books;
  final Map<String, BookNote> notesByBookId;
  final Map<String, Set<String>> tagsByBookId;
  final List<String> allTags;  // 已按字母序排好

  @override
  State<ExportFilterPage> createState() => _ExportFilterPageState();
}
```

**布局**（`CustomScrollView` + `SliverFillRemaining`，或简单 `Column` + `Expanded(ListView)`）：

```
AppBar
  title: "筛选导出范围"
  actions: [IconButton(icon: Icons.refresh, tooltip: "重置", onPressed: _reset)]

Body:
  - Section "按标签" (if allTags.isNotEmpty)
      Wrap<FilterChip>:
        - "全部" chip（selected = _selectedTags.isEmpty）
          点击 → _selectedTags.clear()
        - 每个 tag 一个 FilterChip（selected = _selectedTags.contains(tag)）
          点击 → toggle

  - Section "按导入时间"
      Column<RadioListTile<TimeWindow>>: any / last7 / last30 / last90 / thisYear

  - Section "按最近阅读"
      同上

  - Divider

  - "匹配 N 本 · 共 M 条高亮" 文本

  - Expanded:
      ListView.builder: 每项 BookCard（封面缩略图 + 书名 + 作者 + tag chips + "X 高亮 / Y 笔记"）
      只显示 _filteredBooks 中的书

Bottom Bar:
  FilledButton:
    onPressed: _filteredBooks.isEmpty ? null : () => Navigator.of(context).pop(_currentFilter())
    child: _filteredBooks.isEmpty
            ? Text("无匹配书目")
            : Text("导出 ${_filteredBooks.length} 本")
```

**State 字段**：
- `Set<String> _selectedTags = {}`
- `TimeWindow _addedAtWindow = TimeWindow.any`
- `TimeWindow _lastReadAtWindow = TimeWindow.any`

**派生计算**（每次 `build` 都跑，无需 memo；N 通常 ≤ 几百本）：
- `_currentFilter()` → `BookFilter(tags: _selectedTags, ...)`
- `_filteredBooks` = `applyBookFilter(books, _currentFilter(), tagsByBookId, DateTime.now())` 然后**再过滤** `VaultExporter.hasContent(notesByBookId[b.id])`（保证预览 = 实际）
- `_totalHighlights` = `_filteredBooks.fold(0, (sum, b) => sum + (notesByBookId[b.id]?.annotations.length ?? 0))`

### 4.6 `library_page._startBatchExport()` 改造

```dart
Future<void> _startBatchExport() async {
  final books = await ref.read(bookRepositoryProvider).getAll();
  final notesByBookId = <String, BookNote>{};
  for (final book in books) {
    final note = await ref.read(notesRepositoryProvider).getNoteByBook(book.id);
    if (note != null) notesByBookId[book.id] = note;
  }
  if (!mounted) return;

  // M2.3 新增：预取 tag 数据
  final bookTagsDao = ref.read(bookTagsDaoProvider);
  final tagsByBookId = await bookTagsDao.allTagsByBook();
  final allTags = (await bookTagsDao.allTags()).toList()..sort();
  if (!mounted) return;

  final l10n = AppLocalizations.of(context)!;

  // 沿用既有短路：没有任何 note
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

  // M2.3 新增：弹筛选页
  final filter = await showDialog<BookFilter?>(
    context: context,
    builder: (ctx) => ExportFilterPage(
      books: books,
      notesByBookId: notesByBookId,
      tagsByBookId: tagsByBookId,
      allTags: allTags,
    ),
  );
  if (filter == null) return;  // 用户取消
  if (!mounted) return;

  // 应用筛选
  final filteredBooks = applyBookFilter(
    books: books,
    filter: filter,
    tagsByBookId: tagsByBookId,
    now: DateTime.now(),
  );
  // 预览页已经保证 filteredBooks 都有非空 note，这里不再二次过滤

  // 之后流程完全不变（仅 books 改为 filteredBooks）
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
  // ... 既有 SnackBar 反馈
}
```

## 5. 数据流

### 5.1 状态机（用户视角）

```
[初始] 全部默认 → 预览 = 所有非空 note 书
        ↓ 用户改 tag/时间
[变更] 预览实时更新
        ↓ 用户点"重置"
[初始] 回到全部默认
        ↓ 用户点"导出 N 本"
[完成] Navigator.pop(BookFilter) → library_page 拿到 filter
        ↓ 用户点返回箭头
[取消] Navigator.pop(null) → library_page 静默中止
```

### 5.2 数据库查询频率

| 调用点 | DAO 方法 | 频率 |
|---|---|---|
| `_startBatchExport()` 进入 | `BookRepository.getAll()` | 1 |
| 同上 | `NotesRepository.getNoteByBook(id)` | N（N = 总书数）|
| 同上 | `BookTagsDao.allTagsByBook()` | 1（**新**） |
| 同上 | `BookTagsDao.allTags()` | 1（**新**） |

筛选页本身**无数据库访问**：所有数据通过构造函数注入，build 时纯内存计算。

### 5.3 内存开销

N = 几百本、每本 1-10 个 tag、每本 0-100 条 annotation：
- `books` List：~50 KB
- `notesByBookId` Map：~500 KB（含所有 annotation）
- `tagsByBookId` Map：~20 KB

筛选页存活期间内存峰值 ≈ 1 MB（远低于 Reader 打开一本 EPUB 的开销）。可接受。

## 6. 错误处理与边界情况

### 6.1 库本身无任何 note（沿用既有短路）

`_startBatchExport()` 进入时已经 `if (notesByBookId.isEmpty) → 弹"暂无可导出内容"对话框`。M2.3 保留这个短路，**在跳筛选页之前**。

### 6.2 筛选结果为空

筛选页底部按钮直接 disabled + 文案"无匹配书目"。用户**不能**从这里走到 file_picker。用户可选：
- 点"重置"恢复默认
- 点返回箭头取消整个流程

### 6.3 tag 数据缺失

某些早期书可能没在 `book_tags` 表里。`tagsByBookId[book.id]` 缺失时默认空集。OR 语义下：
- 用户**未选** tag 时 → 通过
- 用户**选了** tag 时 → 排除

正确语义，无需特殊处理。

### 6.4 `lastReadAt` 为 null

`lastReadAt = null` 表示从未读过：
- `lastReadAtWindow = any` → 通过
- `lastReadAtWindow != any` → 排除（"近 30 天读过"显然不含"从未读过"）

`_withinNullableWindow` 函数处理此分支。

### 6.5 时区/DST

`DateTime.now()` 与 `book.addedAt` 都是 local time（既有数据约定）。`now.difference(addedAt).inDays` 是绝对秒数差，无 DST 问题。

"今年"窗口用 `dt.year == now.year`，简单无歧义。

### 6.6 用户在 file_picker 取消

筛选页 → 用户点"导出" → 系统弹文件夹选择 → 用户取消 → 静默中止，无 SnackBar（既有行为）。

### 6.7 预览数 vs 实际导出数的一致性

**关键不变量**：筛选页底部显示"导出 N 本"时，实际 `VaultExporter` 跑完必出 N 个文件。

实现：`_filteredBooks` 在 `applyBookFilter` 之后再加一道 `VaultExporter.hasContent(notesByBookId[b.id])` 过滤。这样：
- 预览只显示**会导出**的书
- 实际导出列表 = 预览列表

`hasContent` 抽为 public static 是这个不变量的基石。

### 6.8 用户点"重置"的精确语义

把三维度恢复到默认：`_selectedTags.clear()` + `_addedAtWindow = TimeWindow.any` + `_lastReadAtWindow = TimeWindow.any`。**不**弹确认对话框（操作可逆，无需确认）。

## 7. 测试策略

### 7.1 单元测试 `book_filter_applicator_test.dart`

约 15 个测试，覆盖矩阵：

| Suite | 测试点 |
|---|---|
| 不筛 | `BookFilter()` 默认 → 全部通过 |
| Tag 单选 | 选 `{"AI"}` → 含 `#AI` 的通过，不含的排除 |
| Tag 多选 OR | 选 `{"AI", "哲学"}` → 含任一的通过 |
| Tag 集合不交 | 选 `{"AI", "哲学"}`，书 tags = `{"历史"}` → 排除 |
| Tag 缺数据 | `tagsByBookId` 缺该 book → 用户已选 tag 时排除 |
| addedAt.any | 通过 |
| addedAt.last7Days | 6 天前通过、8 天前排除 |
| addedAt.last30Days | 29 天前通过、31 天前排除 |
| addedAt.last90Days | 类似边界 |
| addedAt.thisYear | 跨年：now=2026-07-01, addedAt=2025-12-31 → 排除；2026-01-01 → 通过 |
| lastReadAt null | any 通过；其他窗口排除 |
| lastReadAt.last30Days | 边界 |
| 组合 1 | tag + addedAt（两维度都需满足）|
| 组合 2 | 三维度全部应用 |
| 顺序保持 | 输入 books 顺序 = 输出顺序 |

`now` 全部用固定 `DateTime(2026, 7, 1)`，无真实 `DateTime.now()`。

### 7.2 Widget 测试 `export_filter_page_test.dart`

约 8 个测试：

- 初始状态：底部按钮显示"导出 N 本"（N = 注入 books 数）
- 点击一个 tag chip → 预览数减少、按钮文案更新
- 点击"全部" chip → 恢复全集
- 切换 addedAt RadioListTile → 预览更新
- 切换 lastReadAt RadioListTile → 预览更新
- 点"重置" → 三维度恢复默认 + 预览恢复
- 空匹配场景（注入 books 都不符合某 filter）→ 按钮 disabled + 文案"无匹配书目"
- 点底部按钮 → `Navigator.pop` 收到的 `BookFilter` 与 state 一致

注入数据用 in-memory `books` / `notesByBookId` / `tagsByBookId`，无需数据库。

### 7.3 集成测试 `library_page_batch_export_test.dart`（扩展现有）

加 1-2 个：
- 点击"导出为 Markdown" → 跳到 `ExportFilterPage`（不再直接弹确认对话框）
- 用户在筛选页点"导出" → 接下来的 BatchExportDialog 流程不变（既有测试已覆盖）

不重测 VaultExporter（11 个既有测试零改动）。

### 7.4 不测的部分

- `BookFilter.==` / `hashCode`：标准 boilerplate
- `TimeWindow` enum：普通枚举
- `BookTagsDao.allTagsByBook()`：仿 `allTags()` 既有模式；可在 DAO 既有测试文件加 1 个 happy-path 测试

## 8. 文件清单

### 8.1 新增（5）

| 文件 | 责任 |
|---|---|
| `app/lib/features/library/models/book_filter.dart` | `BookFilter` 值类 + `TimeWindow` enum |
| `app/lib/features/library/services/book_filter_applicator.dart` | `applyBookFilter()` 纯函数 |
| `app/lib/features/library/pages/export_filter_page.dart` | 独立筛选页 StatefulWidget |
| `app/test/features/library/services/book_filter_applicator_test.dart` | 单测 ~15 个 |
| `app/test/features/library/pages/export_filter_page_test.dart` | widget 测试 ~8 个 |

### 8.2 改动（4 + 2 arb + 2 docs）

| 文件 | 改动 |
|---|---|
| `app/lib/features/library/pages/library_page.dart` | `_startBatchExport()` 重写为先弹 `ExportFilterPage`；预取 tag 数据 |
| `app/lib/features/notes/services/vault_exporter.dart` | 把 `_hasContent` 逻辑抽为 `static bool hasContent(BookNote)` |
| `app/lib/data/local/daos/book_tags_dao.dart` | +`allTagsByBook()` 方法 |
| `app/test/.../library_page_batch_export_test.dart` | 既有测试适配新流程（导航到 ExportFilterPage） |
| `app/lib/l10n/app_zh.arb` + `app_en.arb` | +9 keys（页面 title / 三个 section title / "全部" chip / 重置 tooltip / 导出按钮 / 无匹配 / 帮助文本）|
| `README.md` | +v1.3.0-alpha section |
| `docs/releases/release-checklist.md` | +v1.3.0-alpha 待办行 |

### 8.3 l10n keys（详细）

```
exportFilterTitle: "筛选导出范围" / "Filter Export Range"
exportFilterSectionTags: "按标签" / "By Tag"
exportFilterSectionAddedAt: "按导入时间" / "By Import Time"
exportFilterSectionLastReadAt: "按最近阅读" / "By Last Read Time"
exportFilterAllTagsChip: "全部" / "All"
exportFilterResetTooltip: "重置" / "Reset"
exportFilterEmptyResult: "无匹配书目" / "No matching books"
exportFilterActionExport: "导出 {count} 本" / "Export {count} book(s)"
exportFilterPreviewSummary: "匹配 {books} 本 · 共 {highlights} 条高亮" /
  "{books} book(s) match · {highlights} highlight(s) total"
exportFilterTimeWindowAny: "全部" / "Any time"
exportFilterTimeWindowLast7Days: "近 7 天" / "Last 7 days"
exportFilterTimeWindowLast30Days: "近 30 天" / "Last 30 days"
exportFilterTimeWindowLast90Days: "近 90 天" / "Last 90 days"
exportFilterTimeWindowThisYear: "今年" / "This year"
```

（13 keys；之前 §6 写 9 是概数。）

## 9. 验收

- `dart analyze` 4 包全 clean（既有 49 info 不变）
- `flutter test --concurrency=1` 全部通过：既有 782 + 3 skip + 新增 ~23 = **约 805 passed**
- 手测：用 development DB（含 5+ 本带 tag 的书）走完筛选 → 导出流程，确认：
  - 筛选页正确预览
  - 导出文件数 = 预览数
  - index.md / 各书 .md 内容与 M2.1 一致
- Tag `m2.3-complete` + `v1.3.0-alpha` 推送 origin
- README + release-checklist 更新
- 写 memory `project_zhiyue_m2_3_complete.md`

## 10. 工期估算

| Phase | 估算 |
|---|---|
| 写 spec + plan | 0.5 天 |
| TDD 实现（5 新文件 + 4 改动 + 测试）| 1 天 |
| subagent-driven dev + 双 review | 0.5 天 |
| 手测 + 文档 + tag | 0.5 天 |
| **合计** | **~2.5 天** |

## 11. 开放问题

无。所有关键决策都已在 brainstorm 阶段闭环：
- 筛选维度：tag / addedAt / lastReadAt（不含 format / progress）
- Tag 多选语义：OR
- 时间 UI：预设区间选项
- UI 形态：独立筛选页
- 预览：完整书单卡片
- 持久化：不记
- 架构：纯函数 + 复用既有 VaultExporter

## 12. 风险

| # | 风险 | 等级 | 缓解 |
|---|---|---|---|
| R1 | 预览数 ≠ 实际导出数 | HIGH | 抽 `VaultExporter.hasContent` 为 static public；筛选页同一函数过滤 |
| R2 | `setEquals` 来自 `package:collection`，确认 pubspec 已依赖 | LOW | 检查 pubspec；fallback 手写 setEquals |
| R3 | 标签 chip cloud 在小屏溢出 | MEDIUM | 用 `Wrap` 而非 `Row`，自动换行 |
| R4 | 既有 `library_page_batch_export_test.dart` 改流程后挂 | LOW | 测试已在改动列表，会同步更新 |
| R5 | `BookTagsDao.allTagsByBook` 性能（万级 tag） | LOW | 单次 `select.get()` + 内存 group，可接受；不做分页 |
