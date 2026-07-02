# 项目整体 Review（2026-07-03，M2.5 / v1.5.0-alpha 之后）

**触发**：用户 2026-07-03 「继续完成任务，然后对整个项目进行 review」。
**范围**：M2.5 交付完成后对全项目做 P0/P1 bug + spec drift + 测试覆盖 + lint/AGPLv3/文档 一致性扫描。
**方法**：4 个 opus subagent 并行 review（bugs / spec drift / test coverage / lint+docs），主线程汇总并验证关键 finding。

---

## P0 — 必修

### P0-1 `LocalNotesRepository.updateNote` 不写 sync outbox

**文件**：`app/lib/data/repositories/local_notes_repository.dart:75-81`

**症状**：`updateNote` 只调 `_notesDao.updateContent(...)`，从不调 `_syncRecorder?.recordBookNote(...)`。`recordBookNote` 在整个 app 代码库中**生产路径零调用方**（仅测试 + spec 引用）。

**用户面影响**：
- M2.1 「章节学习回顾」（`applyChapterReview` line 192-236）→ AI 生成的 summary + keyTakeaways 完全不跨设备同步
- AI 导读 sheet 「加入笔记」按钮（`BookNotesDao.appendKeyTakeaway`）→ 同样丢失

**修复**：在 `updateNote` 内，于 `_notesDao.updateContent` 之后查询行，调 `_syncRecorder?.recordBookNote(id, bookId, title, summary, keyTakeawaysJson, mtime: updatedAt)`。复用单个 `DateTime.now()` 同时传给 `updateContent(updatedAt:)` 与 recorder（参考 `bookmark_repository.dart:83-96` 已有正确模式）。

### P0-2 README.md 渲染 broken-image（2 张截图缺失）

**文件**：`docs/screenshots/pdf_reader.png`、`docs/screenshots/notes.png` 不存在；`README.md:39` 表格引用它们。

**用户面影响**：v1.5.0-alpha 公开仓库 README 在 Gitee/Web 上显示 2 个 broken image icon。

**修复**：用户现场操作——Windows release 构建 → 用 PDF 打开 → 截屏 → 同样对有高亮的 EPUB 打开 NotesPage 截屏 → 保存到 `docs/screenshots/`。Claude 不能替代。

### P0-3 README.md:110 测试数 824 vs 实际 1066（stale by 242）

**文件**：`README.md:110`

**修复**：把 `824 通过 + 3 skipped` 改为 `1066 通过 + 3 skipped`，与 `CHANGELOG.md:42` 和 `release-notes-v1.5.0-alpha.md:60` 一致。可同步补 package breakdown。

---

## P1 — 应修

### P1-1 阅读进度 sync mtime 比 DB `updated_at` 老 μs

**文件**：`app/lib/data/repositories/local_reading_progress_repository.dart:51-62` + `app/lib/data/local/daos/reading_progress_dao.dart:35-48`

**症状**：`_dao.upsert` 内部调一次 `DateTime.now()`（DAO:45），`recordReadingProgress` 又调一次（repo:61）。两个时间戳相差 μs，recorder 的 mtime 可能**早于** DB `updated_at`。

**用户面影响**：cross-device 同步时偶发"我在手机翻到第 100 页保存了，桌面端却显示第 80 页"。

**修复**：在 `LocalReadingProgressRepository.save` 抓一次 `final now = DateTime.now();`，把 `now` 同时传给 DAO 新增的 `upsert(..., updatedAt: now)` 重载和 `recordReadingProgress(mtime: now)`。

### P1-2 PDF 双页模式 toggle 不重新 snap `_currentPage`

**文件**：`reader_engine_pdf_view/lib/pdf_renderer.dart:162-179, 242-244`

**症状**：`dualPageMode` 是 plain field，外部（`reader_body.dart` LayoutBuilder）切换它时不会调 `setPage(_currentPage)`。若切换瞬间 `_currentPage` 是奇数（用户在单页模式下浏览到第 3 页），`_buildDualPage` 用 stale 的 `_currentPage=3` 推 `leftIdx=2`，下一帧才能修正。

**用户面影响**：窗口 resize 跨越 1200px 阈值时短暂显示错误 spread（左/右页错位）。

**修复**：把 `dualPageMode` 改为 private `_dualPageMode` + setter，setter 在变化时调 `setPage(_currentPage)` 重新 snap。

### P1-3 NOTICE 缺 9 个依赖（含 M2.5 新增 `window_manager`）

**文件**：`NOTICE`

**症状**：以下 runtime 依赖未列：
- `sqlite3` (^2.9.0) — 与 `sqlite3_flutter_libs` 是不同 package
- `http` (^1.2.0) — M2.0a sync dep
- `flutter_secure_storage` (^9.2.2) — M1.5a API key 存储
- `connectivity_plus` (^6.0.5) — M2.0b
- `flutter_localizations` (sdk) — M3.5 i18n
- **`window_manager` (^0.4.3) — M2.5/T9 新增，最关键遗漏**
- `meta` (^1.15.0)
- `flutter_widget_from_html` (any) — dev/test 但仍是 package

**修复**：补全上述条目，按字母序插入对应区段。dev deps 单独加一节「开发依赖」。

### P1-4 `release-procedure.md` 三处版本号/数字 stale

**文件**：`docs/release-procedure.md:23, 41, 42`

**症状**：仍写 `version: 1.3.0-alpha+0`、`131 info` lint、`≥ 812 + 3 skipped`。M2.4/T6 本应同步但跳过了。

**修复**：改为 `1.5.0-alpha+0`、`0 info`、`≥ 1066 + 3 skipped`。

### P1-5 `maintainers-runbook.md` §1 截止版本 stale + 缺 9.4.2 v1.5 perf row

**文件**：`docs/maintainers-runbook.md:52, §9.4.1`

**症状**：§1 milestone index 头写「截至 v0.9.1-alpha」，缺 M2.1/M2.2/M2.3/M2.4/M2.5 条目；§9.4.1 是 v1.4 perf 复测决策，v1.5 大量 reader 重构（sidebar / fullscreen / bookmarks / dual-page）按 §9.4 触发条件本应触发复测，但没补 §9.4.2。

**修复**：补全 §1 milestone 列表到 M2.5；§9.4 加 v1.5 决策行（建议复测，触发条件：M2.5 改 reader_engine + drift v9→v10）。

### P1-6 `screenshots/README.md` 状态表 stale

**文件**：`docs/screenshots/README.md:6, 11-13`

**症状**：表格仍标 `library.png` / `pdf_reader.png` / `notes.png` 为 pending，但 `library.png` 已存在（M2.5 之前捕获，过时但不缺）。`pdf_reader.png` / `notes.png` 真缺失。

**修复**：状态表反映磁盘实况 + 标注 v1.5 需重捕全部 4 张（M2.5 引入 sidebar/fullscreen/dual-page 后老截图不准）。

### P1-7 `release-checklist.md` 截图表格与正文自相矛盾

**文件**：`docs/releases/release-checklist.md:35-44`

**症状**：表格列 3 张截图全 ❌，但 `CHANGELOG.md:69`（v1.4 段）和 `README.md:41` 都说 v1.4 已补齐。

**修复**：flip 表格状态为 ✅（v1.4 已做），并加一行说明 v1.5 需重捕（与 line 71 已有备注呼应）。

### P1-8 `release-checklist.md:7-33` Gitee Release 页面状态矛盾

**症状**：「待办」段顶部列 4 个 Gitee Release 页面（v1.0.0/v1.1.0-alpha/v1.2.0-alpha/v1.3.0-alpha）❌ 未创建；但下方「已完成 v1.4.0-alpha release 准备」段内 `T9` 项又把这 4 个标 ⏳ 待执行。两处自相矛盾。

**修复**：核对 Gitee 实况，统一一处单点声明。

### P1-9 `maintainers-runbook.md:622` "v1.5 跨书 AI 伴读" trigger 行 stale

**症状**：perf trigger 表里写 `v1.5 跨书 AI 伴读`，但 v1.5 实际是 Reader UX Overhaul，跨书 AI 已推到 v1.6+。

**修复**：改为 `v1.6 跨书 AI 伴读` 或移除该行（drift v9→v10 已有独立行覆盖 schema bump trigger）。

### P1-10 `CHANGELOG.md:50` margin "Normal 16→24" 静默变化

**症状**：CHANGELOG 说 "Compact / Normal / Wide 索引不变 + 已存 margin 偏好保留"，但 Normal 用户的像素值从 16 跳到 24，没有 in-app notice。

**修复**：在 release-notes + CHANGELOG 加 caveat：「现有 Normal 用户阅读宽度会从 16px 增至 24px，可在 Settings → Typography 切回 Compact」。

---

## P2 — 记录为 issue，延后

### 测试覆盖空白

- **App-boot smoke**：缺 `ZhiYueApp` + empty DB 的 `runApp` 级测试（routing / provider wiring / l10n bootstrap）
- **AI 缓存高亮失效**：`book_reviewer_test.dart` 提到 hash 含高亮，但无显式测试覆盖"加/删高亮 → 缓存失效"
- **`[ch=N]` 跨书 Q&A 跳转**：单测覆盖了 `qa_citation_parser` + `qa_controller`，但没测点击 citation 真的跳回另一本书的 ReaderPage
- **Windows 单实例 mutex**：仅 `main.cpp` 静态代码，无 smoke test

### Flaky / fragile 测试

- `book_import_service_test.dart:77`「concurrent same file」用真 `Directory.systemTemp` + `Future.wait` race，Windows AV / 慢 CI 上不稳定 → 改用 controllable fake `FileStorage`
- 多处用 `Future.delayed(200ms-1s)` 等流发射（`highlight_lifecycle_integration_test.dart`、`notes_controller_test.dart`、`progress_persister_test.dart`、`qa_history_dao_test.dart`）→ 改用 `expectLater(emitInOrder)` 或 `container.listen`

### Skipped tests（3 个，合理）

- `reader_page_pdf_integration_test.dart:60` — 需 PDFium native lib，合理跳
- `integration_test/reader_flow_test.dart:89` — CFI restoration 跨重启，device-only 合理；可考虑 widget-level fake-engine 版本
- `font_import_service_test.dart:187` — FontLoader 非 font bytes 环境相关，合理跳

### 低价值测试

- `pdf_reader_engine_test.dart` 6 个断言只验证 stub 是 stub（"is empty"、"is null"、"always scroll"）
- `pdf_renderer_dual_page_test.dart:53,60,67` 三个测试只断言 `doesNotThrow`，不验证实际双页行为
- `reader_fullscreen_test.dart:91-93` 直接调 controller.toggleFullscreen，绕过 IconButton（comment 自承按钮 hit-test flaky）

---

## 已验证 clean（reviewer 报但代码无问题）

- Drift v9→v10 bookmarks migration：`database.dart:205-212` `m.createTable(bookmarks)` + index；fresh-install `onCreate:134-137` 也覆盖
- Bug #4 修复（`ref.listen` → `engine.injectHighlights`）：`reader_body.dart:212,221,239` 实测有效
- Bug #6 修复（`EpubxRenderer.gotoLocator` EpubRangeLocator 分支）：`epubx_renderer.dart:418,452` 完整
- EPUB 双页 API surface 端到端 wire：`epubx_renderer.dart:80` + `reader_body.dart:280,284` LayoutBuilder
- SSE 跨 TCP 包 line buffer：`open_ai_compatible_client.dart:117-157` carryover + final flush 都对，`[DONE]` 早返正确
- `BookmarkController` autoDispose + stream 生命周期：`dispose()` 取消 `_sub`，`if (!mounted) return` 防后 dispose 写入
- `ReaderUiController.toggleFullscreen` chrome 恢复：`reader_ui_controller.dart:112-125` 退出全屏正确恢复 isDesktop 默认
- `BackgroundSyncScheduler` 重入 + 5-min cooldown：`background_sync_scheduler.dart:83-100` `_isRunning` guard 正确
- `QaHistoryDao._toEntry` corrupted citations_json 容错：`qa_history_dao.dart:115-137` try/catch + 默认 `[]`
- M2.5 memory file 1066 tests / 15 tasks / dual tag 与 CHANGELOG 一致

---

## 建议执行顺序

1. **立刻**（Claude 可做）：P0-1 sync 修复 + P0-3 README 测试数 + P1-1/2 代码 + 全部 P1 docs/NOTICE drift
2. **用户操作**：P0-2 截图重捕（4 张）+ Gitee Release v1.5.0-alpha 页面 + build artifact
3. **下个 milestone**：P2 测试覆盖强化（建议 M2.6 hygiene sweep 一并做）

---

## Review 元数据

- **Review 日期**：2026-07-03
- **Review 时项目状态**：M2.5 / v1.5.0-alpha 已 tag（`m2.5-complete` + `v1.5.0-alpha`），1066 tests pass + 3 skipped
- **方法**：4 个 opus subagent 并行（bugs / spec drift / test coverage / lint+docs）+ 主线程汇总验证
- **置信度**：所有 P0/P1 都已直接 grep/read 验证，置信度 90+
