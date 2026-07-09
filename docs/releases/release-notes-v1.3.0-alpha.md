# 智阅 v1.3.0-alpha Release Notes

**发布日期**：2026-07-01
**性质**：feature（批量导出范围筛选）
**Tag**：`v1.3.0-alpha`
**对应里程碑**：M2.3 — Batch Export Range Filter

## 为什么有这个 release

v1.1.0-alpha（M2.1）加了「Markdown 批量导出」，但范围是「全库」——导出时一次性把所有书都生成 Markdown。这个版本让用户先开筛选页，按标签（OR）/ 按导入时间 / 按最近阅读三个维度组合筛选，实时预览匹配书单 + 高亮总数，底部按钮直接显示「导出 N 本」。

## 主要变更

### Added

- `app/lib/features/library/models/book_filter.dart`（T1）— `@immutable` 值类（`Set<String> tags` + 2 个 TimeWindow 字段；`SetEquality` 深相等）。
- `app/lib/features/library/services/book_filter_applicator.dart`（T2）— 纯函数 `applyBookFilter({books, filter, tagsByBookId, now})`；OR 语义、5 段预设区间。
- `app/lib/data/local/daos/book_tags_dao.dart`（T3）— 新增 `allTagsByBook()` 单 SELECT bulk。
- `app/lib/features/notes/services/vault_exporter.dart`（T4）— 把"判断 BookNote 是否有内容"内联逻辑提取为 `static bool hasContent(BookNote n)` 公开方法（保证「预览数 = 实际导出数」不变量）。
- 13 个新 i18n key（中英双语）。
- `app/lib/features/library/pages/export_filter_page.dart`（T6，281 行）— 独立筛选页 StatefulWidget。

### Changed

- `LibraryAppBar._startBatchExport` 改写：fetch notes → 空短路 → fetch tags → `showDialog<BookFilter?>` → `applyBookFilter` → file_picker + `BatchExportDialog`。

### 不变量保证（核心）

**预览 = 实际导出**：`VaultExporter.hasContent` 提为 static public，筛选页和实际导出复用同一判断逻辑——筛选页说「导出 N 本」就一定真的是 N 本，不会出现「点了导出却少一本」的偏差。

## Commit 清单

13 个 commit：

- docs：`d958352` spec、`1c8d520` plan、`cdf8270` release checklist + bump、`fffae47` README finalize
- feat：`89cbb3a` BookFilter + TimeWindow enum、`a166600` BookFilterApplicator、`2520d3b` allTagsByBook、`290fc66` VaultExporter.hasContent static、`4809635` i18n keys、`013306f` ExportFilterPage、`746a4df` wire into library
- fix：`5b94b3e` review I2/I4/M1
- test：`a1c5362` boundary day test、`65a9a77` filter-page navigation test

## Technical

- 30 个新测试（全量 812 pass + 3 skipped）。
- subagent-driven development: T1-T9 每 task 双阶段 review；T2 boundary test 抓住 off-by-one risk（lastN 窗口的边界 day）。

## 升级指南

无破坏性变更。库 AppBar「导出为 Markdown」按钮现在先开筛选页，老用户可直接点「全部导出」复刻旧行为。
