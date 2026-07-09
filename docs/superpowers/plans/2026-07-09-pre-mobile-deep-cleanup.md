# 智阅 移动端前置深度清理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把仓库整理到「桌面稳定 + 文档齐全 + 测试全绿 + tag/release 对齐」的干净起点，作为移动端 MVP 开发的起点。

**Architecture:** 七阶段串行清理（A gitignore → E 测试 → C 文档归档 → F memory → D 发版 → B release-notes → G tag），每阶段独立 commit，桌面端可见行为 100% 保留。

**Tech Stack:** Git / Flutter 3.44 / Dart 3.10 / Inno Setup 6 / Gitee Web UI

**Spec:** `docs/superpowers/specs/2026-07-09-pre-mobile-deep-cleanup-design.md`

---

## File Structure

| 文件 | 操作 | 责任 |
|------|------|------|
| `.gitignore` | Modify | 扩展忽略规则 |
| `1.png.png`、`2.png` | Delete | 临时截图 |
| `docs/superpowers/plans/2026-07-09-*.md` × 3 | Commit (已存在未跟踪) | 历史 plan 入库 |
| `app/test/data/local/migration_v4_test.dart` | Fix | 测试修复 |
| `app/test/data/repositories/notes_repository_test.dart` | Fix | 测试修复 |
| `app/test/features/library/library_golden_test.dart` | Fix (regen goldens) | 5 个 golden 失败 |
| `app/test/features/settings/typography_profile_repository_test.dart` | Fix | 测试修复 |
| `app/test/goldens/reader_ui_golden_test.dart` | Fix (regen goldens) | 1 个 golden 失败 |
| `app/test/goldens/typography_golden_test.dart` | Fix (regen goldens) | 1 个 golden 失败 |
| `app/test/services/book_open_bridge_test.dart` | Fix | 测试修复 |
| `app/test/features/library/goldens/*.png` × 5 | Regenerate | golden 快照 |
| `app/test/goldens/goldens/*.png` × 2 | Regenerate | golden 快照 |
| `docs/superpowers/reviews/2026-07-02-review-fixups.md` | Create | review 报告归档 |
| `docs/superpowers/reviews/2026-07-03-review-fixups.md` | Create | review 报告归档 |
| `docs/superpowers/reviews/2026-07-08-review-fixups.md` | Create | review 报告归档 |
| `README.md` | Modify | badge + 项目状态 |
| `CHANGELOG.md` | Modify | [Unreleased] → [1.7.1-alpha] |
| `app/pubspec.yaml` | Modify | version bump |
| `app/windows/installer/zhiyue.iss` | Modify | MyAppVersion bump |
| `docs/releases/release-notes-v0.4.0.md` ~ `v1.7.0-alpha.md` × 11 | Create | 补齐 release notes |
| `docs/releases/release-notes-v1.7.1-alpha.md` | Create | 新版本 notes |
| `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_2026_07_09_typography_persistence_fix.md` | Create | memory |
| `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_mobile_mvp_kickoff.md` | Create | memory |
| `C:\Users\1\.claude\projects\H--projiect--------\memory\MEMORY.md` | Modify | 索引更新 |

---

## Release-Notes Template

所有 release-notes 文件遵循此模板（参考已有 `docs/releases/release-notes-v1.5.1-alpha.md`）：

```markdown
# 智阅 v<VERSION> Release Notes

**发布日期**：<YYYY-MM-DD>
**性质**：<feature / fix / refactor / release>
**Tag**：`v<VERSION>`

## 主要变更

<从 CHANGELOG.md 对应 [VERSION] 条目提取，保留小节标题与要点>

## Commit 清单

<从 `git log <prev_tag>..<tag> --oneline` 提取，按类别分组>

## 已知问题

<从 memory / review 报告提取，如适用；无则写"无已知阻塞问题">

## 升级指南

<如适用；无则省略此节>
```

**数据源**：
- CHANGELOG.md：`grep -n "\[<VERSION>\]" CHANGELOG.md` 定位条目
- git log：`git log <prev_tag>..<tag> --oneline`（prev_tag 是上一个 v* tag）
- memory：`C:\Users\1\.claude\projects\H--projiect--------\memory\` 下对应里程碑文件

---

## Phase A: Git 仓库整理

### Task 1: 扩展 .gitignore + 删除临时截图

**Files:**
- Modify: `.gitignore`
- Delete: `1.png.png`、`2.png`

- [ ] **Step 1: 删除根目录临时截图**

```bash
cd H:/projiect/电子书阅读平台
rm "1.png.png" "2.png"
```

- [ ] **Step 2: 扩展 .gitignore**

在 `.gitignore` 末尾追加（如已存在则跳过对应行）：

```gitignore

# === Claude Code 工作目录（本地产物） ===
.claude/

# === 根目录临时截图 ===
/*.png
!docs/screenshots/**

# === 日志与输出 ===
*.log
custom_lint.log
pub_get_output.txt
flutter_01.log

# === 测试失败产物（扩展 golden 到全部 failures 目录） ===
**/failures/
```

- [ ] **Step 3: 验证 gitignore 不误伤源码**

```bash
git status --ignored
```

Expected: `.claude/`、日志文件等出现在 ignored，源码文件不出现。

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore(gitignore): expand rules for .claude/, root *.png, logs, **/failures/"
```

---

### Task 2: Commit 3 个未跟踪 plan 文件

**Files:**
- Commit: `docs/superpowers/plans/2026-07-09-bug-fix-batch-3.md`
- Commit: `docs/superpowers/plans/2026-07-09-per-book-typography-persistence.md`
- Commit: `docs/superpowers/plans/2026-07-09-typography-persistence-exit-crash.md`

- [ ] **Step 1: 确认文件存在且内容完整**

```bash
cd H:/projiect/电子书阅读平台
ls -la docs/superpowers/plans/2026-07-09-*.md
```

Expected: 3 个文件，大小 > 0。

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/plans/2026-07-09-bug-fix-batch-3.md \
        docs/superpowers/plans/2026-07-09-per-book-typography-persistence.md \
        docs/superpowers/plans/2026-07-09-typography-persistence-exit-crash.md
git commit -m "docs(plans): add 2026-07-09 typography persistence + bug-fix-batch-3 plans"
```

- [ ] **Step 3: 验证 working tree clean**

```bash
git status
```

Expected: `nothing to commit, working tree clean`（除 `.claude/` 等 ignored）。

---

## Phase E: 测试卫生

### Task 3: 确认完整失败 + skipped 列表

**Files:**
- Read: `app/test/` 下多个文件

**当前已知 11 failed**：

| # | 文件 | 测试名 | 类型 |
|---|------|--------|------|
| 1 | `test/data/local/migration_v4_test.dart` | fresh install creates annotations_fts virtual table | 非 golden |
| 2 | `test/data/repositories/notes_repository_test.dart` | watchAnnotations emits initial empty when no BookNote exists | 非 golden |
| 3 | `test/features/library/library_golden_test.dart` | library_empty | golden |
| 4 | 同上 | library_loaded_grid | golden |
| 5 | 同上 | library_loaded_list | golden |
| 6 | 同上 | library_selecting | golden |
| 7 | 同上 | library_searching | golden |
| 8 | `test/features/settings/typography_profile_repository_test.dart` | seedDefaultIfEmpty creates exactly one default profile when empty | 非 golden |
| 9 | `test/goldens/reader_ui_golden_test.dart` | TocDrawer golden | golden |
| 10 | `test/goldens/typography_golden_test.dart` | TypographyPanel renders across themes | golden |
| 11 | `test/services/book_open_bridge_test.dart` | BookOpenBridge.isSupportedBookPath rejects non-book extensions | 非 golden |

**4 skipped 候选**（需运行时确认）：
- `test/features/reader/widgets/reader_ai_drawer_integration_test.dart:43` (skip: true)
- `test/features/reader/reader_page_pdf_integration_test.dart:60` (skip: true)
- `test/features/settings/font_import_service_test.dart:187` (skip: 'FontLoader behavior...')
- `test/features/notes/services/vault_exporter_test.dart:102` (skip: 'requires file system mock...')

- [ ] **Step 1: 跑全量测试确认失败列表**

```bash
cd H:/projiect/电子书阅读平台/app
/c/flutter/bin/flutter.bat test --reporter expanded 2>&1 | grep "\[E\]$" > /tmp/test-failures.txt
cat /tmp/test-failures.txt
```

Expected: 11 行 `[E]` 结尾的失败测试，和上表一致。

- [ ] **Step 2: 确认 skipped 列表**

```bash
/c/flutter/bin/flutter.bat test 2>&1 | grep "~4"
```

Expected: 末行含 `~4`。如不是 4，更新本 task 的 skipped 候选列表。

- [ ] **Step 3: 记录结果**

无 commit，仅确认数据。如失败列表与上表不符，更新后续 task。

---

### Task 4: 修复 migration_v4_test — annotations_fts virtual table

**Files:**
- Investigate: `app/test/data/local/migration_v4_test.dart`
- Investigate: `app/lib/data/local/` 下 migration 定义

- [ ] **Step 1: 跑单个测试看完整错误**

```bash
cd H:/projiect/电子书阅读平台/app
/c/flutter/bin/flutter.bat test test/data/local/migration_v4_test.dart --reporter expanded 2>&1 | tail -50
```

- [ ] **Step 2: 分析根因**

读取测试文件和对应 migration 代码。判断：
- 是测试期望过期（migration 逻辑变了但测试没更新）→ 更新测试
- 是 migration 代码坏了（FTS 虚表创建逻辑有 bug）→ 修代码
- 是测试隔离问题（其他 migration 污染了 db）→ 修测试 setup

- [ ] **Step 3: 应用最小修复**

根据 Step 2 分析，修测试或修代码。**只改这一处，不连带清理**。

- [ ] **Step 4: 验证单个测试通过**

```bash
/c/flutter/bin/flutter.bat test test/data/local/migration_v4_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: 跑全量测试确认无回归**

```bash
/c/flutter/bin/flutter.bat test 2>&1 | tail -5
```

Expected: 失败数从 11 → 10（仅这一个修好），无新失败。

- [ ] **Step 6: Commit**

```bash
cd H:/projiect/电子书阅读平台
git add app/test/data/local/migration_v4_test.dart app/lib/data/local/
git commit -m "test(migration): fix annotations_fts virtual table test

<一行根因说明>"
```

---

### Task 5: 修复 notes_repository_test — watchAnnotations 初始空发射

**Files:**
- Investigate: `app/test/data/repositories/notes_repository_test.dart`
- Investigate: `app/lib/data/repositories/notes_repository.dart`

- [ ] **Step 1: 跑单个测试看完整错误**

```bash
cd H:/projiect/电子书阅读平台/app
/c/flutter/bin/flutter.bat test test/data/repositories/notes_repository_test.dart --reporter expanded 2>&1 | tail -50
```

- [ ] **Step 2: 分析根因**

`watchAnnotations emits initial empty when no BookNote exists` — 检查：
- 测试是否期望 `watchAnnotations` 在无数据时立即发射 `[]`
- 实际行为是否是等第一条数据才发射（missing initial emit）
- drift Stream query 的行为是否变化

- [ ] **Step 3: 应用最小修复**

修测试期望或修 repository 的 watch 逻辑。

- [ ] **Step 4: 验证单个测试通过**

```bash
/c/flutter/bin/flutter.bat test test/data/repositories/notes_repository_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: 跑全量测试确认无回归**

```bash
/c/flutter/bin/flutter.bat test 2>&1 | tail -5
```

Expected: 失败数 10 → 9。

- [ ] **Step 6: Commit**

```bash
cd H:/projiect/电子书阅读平台
git add app/test/data/repositories/notes_repository_test.dart app/lib/data/repositories/
git commit -m "test(notes): fix watchAnnotations initial empty emit

<一行根因说明>"
```

---

### Task 6: 修复 typography_profile_repository_test — seedDefaultIfEmpty

**Files:**
- Investigate: `app/test/features/settings/typography_profile_repository_test.dart`
- Investigate: `app/lib/features/settings/` 或 `app/lib/data/repositories/` 下 TypographyProfileRepository

- [ ] **Step 1: 跑单个测试看完整错误**

```bash
cd H:/projiect/电子书阅读平台/app
/c/flutter/bin/flutter.bat test test/features/settings/typography_profile_repository_test.dart --reporter expanded 2>&1 | tail -50
```

- [ ] **Step 2: 分析根因**

`seedDefaultIfEmpty creates exactly one default profile when empty` — 检查：
- seedDefaultIfEmpty 是否被调用多次导致创建多个默认 profile
- 是否有 race condition（并发调用）
- 测试 setup 是否清理了上一轮的 seed

- [ ] **Step 3: 应用最小修复**

- [ ] **Step 4: 验证单个测试通过**

```bash
/c/flutter/bin/flutter.bat test test/features/settings/typography_profile_repository_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: 跑全量测试确认无回归**

```bash
/c/flutter/bin/flutter.bat test 2>&1 | tail -5
```

Expected: 失败数 9 → 8。

- [ ] **Step 6: Commit**

```bash
cd H:/projiect/电子书阅读平台
git add app/test/features/settings/typography_profile_repository_test.dart app/lib/
git commit -m "test(typography): fix seedDefaultIfEmpty creates exactly one default

<一行根因说明>"
```

---

### Task 7: 修复 book_open_bridge_test — rejects non-book extensions

**Files:**
- Investigate: `app/test/services/book_open_bridge_test.dart`
- Investigate: `app/lib/services/book_open_bridge.dart`

- [ ] **Step 1: 跑单个测试看完整错误**

```bash
cd H:/projiect/电子书阅读平台/app
/c/flutter/bin/flutter.bat test test/services/book_open_bridge_test.dart --reporter expanded 2>&1 | tail -50
```

- [ ] **Step 2: 分析根因**

`BookOpenBridge.isSupportedBookPath rejects non-book extensions` — 检查：
- `.txt` 是否被加入支持列表（之前 memory 提到 .txt 扩展测试失败）
- 测试期望 `.txt` 被拒绝但代码现在支持 `.txt`，或反之
- M4.5 引入 Markdown/TXT 支持后是否更新了此测试

- [ ] **Step 3: 应用最小修复**

- [ ] **Step 4: 验证单个测试通过**

```bash
/c/flutter/bin/flutter.bat test test/services/book_open_bridge_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: 跑全量测试确认无回归**

```bash
/c/flutter/bin/flutter.bat test 2>&1 | tail -5
```

Expected: 失败数 8 → 7（剩余 7 个全是 golden）。

- [ ] **Step 6: Commit**

```bash
cd H:/projiect/电子书阅读平台
git add app/test/services/book_open_bridge_test.dart app/lib/services/book_open_bridge.dart
git commit -m "test(book_open_bridge): fix isSupportedBookPath non-book extension test

<一行根因说明>"
```

---

### Task 8: 重新生成 7 个 golden 快照

**Files:**
- Regenerate: `app/test/features/library/goldens/library_empty.png`
- Regenerate: `app/test/features/library/goldens/library_loaded_grid.png`
- Regenerate: `app/test/features/library/goldens/library_loaded_list.png`
- Regenerate: `app/test/features/library/goldens/library_selecting.png`
- Regenerate: `app/test/features/library/goldens/library_searching.png`
- Regenerate: `app/test/goldens/goldens/toc_drawer.png`
- Regenerate: `app/test/goldens/goldens/typography_panel_*.png`

**判断**：7 个 golden 失败的 diff 都很小（0.19%-1.05%），是字体渲染/抗锯齿漂移，不是回归。重新生成即可。

- [ ] **Step 1: 跑 golden 失败的测试看 diff 详情**

```bash
cd H:/projiect/电子书阅读平台/app
/c/flutter/bin/flutter.bat test test/features/library/library_golden_test.dart --reporter expanded 2>&1 | grep "Pixel test failed"
```

Expected: 5 行 `Pixel test failed, X.XX%, Ypx diff detected`，diff < 1.1%。

- [ ] **Step 2: 检查 failures 目录的对比图**

```bash
ls app/test/features/library/failures/ 2>/dev/null
ls app/test/goldens/failures/ 2>/dev/null
```

GoldenToolkit 会在 failures/ 下生成 `<name>_maskedDiff.png` 和 `<name>_masterImage.png`，人眼对比确认漂移是字体级而非布局级。

- [ ] **Step 3: 重新生成 goldens**

```bash
/c/flutter/bin/flutter.bat test --update-goldens --tags golden
```

如 `--tags golden` 不工作（dart_test.yaml 里 golden tag 默认不 skip），跑：

```bash
/c/flutter/bin/flutter.bat test --update-goldens test/features/library/library_golden_test.dart test/goldens/reader_ui_golden_test.dart test/goldens/typography_golden_test.dart
```

- [ ] **Step 4: 验证 golden 测试通过**

```bash
/c/flutter/bin/flutter.bat test test/features/library/library_golden_test.dart test/goldens/reader_ui_golden_test.dart test/goldens/typography_golden_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: 跑全量测试确认全绿**

```bash
/c/flutter/bin/flutter.bat test 2>&1 | tail -5
```

Expected: `+1171 ~4`（0 failed，4 skipped 留 Task 9 处理）。

- [ ] **Step 6: Commit 重新生成的 goldens**

```bash
cd H:/projiect/电子书阅读平台
git add app/test/features/library/goldens/ app/test/goldens/goldens/
git commit -m "test(goldens): regenerate 7 golden snapshots (font rendering drift <1.1%)

library_empty/library_loaded_grid/library_loaded_list/library_selecting/
library_searching/toc_drawer/typography_panel — diff 均 <1.1%，
确认为字体抗锯齿漂移而非布局回归。"
```

---

### Task 9: 处理 4 个 skipped tests

**Files:**
- Investigate: `app/test/features/reader/widgets/reader_ai_drawer_integration_test.dart`
- Investigate: `app/test/features/reader/reader_page_pdf_integration_test.dart`
- Investigate: `app/test/features/settings/font_import_service_test.dart`
- Investigate: `app/test/features/notes/services/vault_exporter_test.dart`

- [ ] **Step 1: 逐个评估 skip 理由**

对每个 skipped test：

```bash
cd H:/projiect/电子书阅读平台/app
/c/flutter/bin/flutter.bat test test/features/reader/widgets/reader_ai_drawer_integration_test.dart --reporter expanded 2>&1 | tail -20
```

读取测试文件 skip 上下文，判断：
- **reader_ai_drawer_integration_test** (skip: true, 注释"本任务用 skipped placeholder 占位，真实测试由 T26 落地")：T26 是否已完成？如完成 → 取消 skip 跑测试；如未完成 → 保留 skip 加注释
- **reader_page_pdf_integration_test** (skip: true)：PDF 集成测试是否还需要？保留 → 加注释说明；取消 → 跑测试修失败
- **font_import_service_test** (skip: 'FontLoader behavior on non-font bytes is environment-dependent')：环境依赖，保留 skip 但确认注释清晰
- **vault_exporter_test** (skip: 'requires file system mock; not implemented in plan')：是否已实现 file system mock？如已实现 → 取消 skip；如未实现 → 保留

- [ ] **Step 2: 对每个 skip 做决策**

| 决策 | 操作 |
|------|------|
| 保留 skip | 在 skip 字符串里补充理由 + 关联 issue/plan（如 `skip: 'deferred to M3 (see docs/.../plan.md T26)'`） |
| 取消 skip | 删除 `skip:` 参数，跑测试，如失败则修 |
| 删除测试 | 如测试已无意义（如被其他测试覆盖），删除整个 test case |

- [ ] **Step 3: 跑受影响测试确认**

```bash
/c/flutter/bin/flutter.bat test test/features/reader/widgets/reader_ai_drawer_integration_test.dart test/features/reader/reader_page_pdf_integration_test.dart test/features/settings/font_import_service_test.dart test/features/notes/services/vault_exporter_test.dart
```

Expected: 保留的 skip 正常跳过，取消的 skip 通过。

- [ ] **Step 4: 跑全量测试**

```bash
/c/flutter/bin/flutter.bat test 2>&1 | tail -5
```

Expected: `+1171 ~N` 其中 N ≤ 4，每个 skip 有清晰理由。

- [ ] **Step 5: Commit**

```bash
cd H:/projiect/电子书阅读平台
git add app/test/
git commit -m "test: clarify skip reasons for 4 deferred tests

<逐个列出决策：保留/取消/删除>"
```

---

## Phase C: 文档归档

### Task 10: 归档 2026-07-02 review 报告

**Files:**
- Create: `docs/superpowers/reviews/2026-07-02-review-fixups.md`
- Source: `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_2026_07_02_review_fixups.md`

- [ ] **Step 1: 读取 memory 源文件**

```bash
cat "C:/Users/1/.claude/projects/H--projiect--------/memory/project_zhiyue_2026_07_02_review_fixups.md"
```

- [ ] **Step 2: 检查是否有 subagent review 报告残留**

```bash
cd H:/projiect/电子书阅读平台
grep -r "2026-07-02" docs/superpowers/reviews/ 2>/dev/null
ls .claude/ 2>/dev/null | head
```

如已有独立报告文件，复制内容；如无，从 memory 重建。

- [ ] **Step 3: 创建归档报告**

按以下结构写入 `docs/superpowers/reviews/2026-07-02-review-fixups.md`：

```markdown
# 2026-07-02 Review Fixups 报告

**日期**：2026-07-02
**触发**：cron 凌晨整项目 review
**范围**：全项目
**对应 commit**：<从 memory 提取>

## P0/P1 修复清单

<从 memory 提取，含：
- syncNow 重入
- SSE 跨包
- selection cache chapterTitle
- qa_history 容错>

## 延后项

<从 memory 提取的 5 个延后>

## 误报澄清

<从 memory 提取的 5 个误报>

## 教训

subagent 深度 review + 主线程验证 = 高效。
```

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/reviews/2026-07-02-review-fixups.md
git commit -m "docs(review): archive 2026-07-02 review fixups report"
```

---

### Task 11: 归档 2026-07-03 review 报告

**Files:**
- Create: `docs/superpowers/reviews/2026-07-03-review-fixups.md`
- Source: `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_2026_07_03_review_fixups.md`

- [ ] **Step 1: 读取 memory 源文件**

```bash
cat "C:/Users/1/.claude/projects/H--projiect--------/memory/project_zhiyue_2026_07_03_review_fixups.md"
```

- [ ] **Step 2: 创建归档报告**

按 Task 10 同结构写入 `docs/superpowers/reviews/2026-07-03-review-fixups.md`，内容含：
- 1 P0 sync 漏写（updateNote 不写 outbox 致 M2.1 章节回顾不跨设备）
- 2 P1 代码（mtime drift / dualPageMode re-snap）
- 8 P1 docs（NOTICE window_manager + runbook milestones + checklist 矛盾 + CHANGELOG caveat）
- commit `68eba4b`

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/reviews/2026-07-03-review-fixups.md
git commit -m "docs(review): archive 2026-07-03 review fixups report (1 P0 + 2 P1 + 8 P1 docs)"
```

---

### Task 12: 归档 2026-07-08 review 报告

**Files:**
- Create: `docs/superpowers/reviews/2026-07-08-review-fixups.md`
- Source: `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_2026_07_08_review_fixups.md`

- [ ] **Step 1: 读取 memory 源文件**

```bash
cat "C:/Users/1/.claude/projects/H--projiect--------/memory/project_zhiyue_2026_07_08_review_fixups.md"
```

- [ ] **Step 2: 创建归档报告**

按 Task 10 同结构写入 `docs/superpowers/reviews/2026-07-08-review-fixups.md`，内容含：
- 1 P0（readerEngineForBookProvider 缓存关闭引擎）
- 8 P1（reader stream leak / recap cache highlights / book delete sync / markPushed atomicity / about 版本 / orphan qa_* / pubspec any）
- 7 P2
- 修 5 commits 含 autoDispose + isClosed 防御
- m4.8 调试改动被 T4c subagent stash+drop 丢失

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/reviews/2026-07-08-review-fixups.md
git commit -m "docs(review): archive 2026-07-08 review fixups report (1 P0 + 8 P1 + 7 P2)"
```

---

### Task 13: 检查 5 个核心文档新鲜度

**Files:**
- Read: `docs/01-research.md`
- Read: `docs/maintainers-runbook.md`
- Read: `docs/release-procedure.md`
- Read: `docs/setup-android-sdk.md`
- Read: `docs/screenshots/README.md`

- [ ] **Step 1: 逐个读取并检查**

对每个文档，检查：
- 技术栈版本号是否最新（Flutter 3.44 / Dart 3.10 / drift 2.18 等）
- 平台支持是否反映现状（Windows + Android，Mac 后期）
- 流程是否覆盖当前（release-procedure 是否含 Android build？maintainers-runbook 是否含子代理派遣规则？）
- 截图清单是否准确（screenshots/README.md 列出的图是否都存在）

- [ ] **Step 2: 记录发现**

如发现问题，逐个修。如无问题，跳过 commit。

- [ ] **Step 3: 应用修复（如有）**

针对每个文档的过时点，应用最小修改。

- [ ] **Step 4: Commit（如有修改）**

```bash
git add docs/
git commit -m "docs: refresh <doc-name> for <what-changed>

<列出每个文档的修改点>"
```

如无修改，记录"5 个核心文档均新鲜，无需修改"。

---

## Phase F: Memory 更新

### Task 14: 补 typography persistence 修复 memory

**Files:**
- Create: `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_2026_07_09_typography_persistence_fix.md`
- Modify: `C:\Users\1\.claude\projects\H--projiect--------\memory\MEMORY.md`

- [ ] **Step 1: 创建 memory 文件**

写入 `project_zhiyue_2026_07_09_typography_persistence_fix.md`：

```markdown
---
name: zhiyue-2026-07-09-typography-persistence-fix
description: 2026-07-09 修 typography persistence bug（exit(0) 截断 fire-and-forget），4 commits，TypographyPersister 即时落盘
metadata:
  type: project
---

2026-07-09 修复用户报告的 typography persistence bug：调整字体设为默认后退出重开仍恢复预设。

**根因**：第一轮修复（commit `2ebd379`）用 `ref.onDispose` + fire-and-forget `saveForBook`，被 `main.dart` 的 `exit(0)` 同步截断（绕 PDFium 死锁的设计，见 [[no-dispose-time-fire-and-forget]]）。

**修复**：引入 `TypographyPersister`（`app/lib/features/reader/services/typography_persister.dart`），订阅 `engine.state$` stream，debounce 500ms 后即时 `repository.saveForBook`，参照 `ProgressPersister` 模式。

**4 commits**：
- `436b35f` TypographyPersister + 5 unit tests
- `216f70b` wire into reader_page lifecycle
- `ecb0f26` 移除 engine provider 里的 dispose-time saveForBook + 测试调整
- `85c94f8` PDF setTypography emit state$ 保持契约一致 + 3 wiring tests

**Why:** exit(0) 截断 dispose-time Future 是设计约束（PDFium 死锁），任何 dispose 回调里的持久化都必丢。

**How to apply:** 新持久化需求参照 ProgressPersister/TypographyPersister 模式（stream + debounce + 即时 save）。详见 [[no-dispose-time-fire-and-forget]]。

关联：[[zhiyue-2026-07-08-review-fixups]]、[[zhiyue-design-context]]
```

- [ ] **Step 2: 更新 MEMORY.md 索引**

在 `MEMORY.md` 末尾追加：

```markdown
- [智阅 2026-07-09 Typography 持久化修复](project_zhiyue_2026_07_09_typography_persistence_fix.md) — 2026-07-09 用户报告字体设定丢失，根因 exit(0) 截断 dispose Future；TypographyPersister 即时落盘修复（4 commits 436b35f→85c94f8）
```

- [ ] **Step 3: 验证 memory 可被 future session 加载**

```bash
cat "C:/Users/1/.claude/projects/H--projiect--------/memory/MEMORY.md" | tail -5
```

Expected: 末行是新追加的 typography 修复索引。

---

### Task 15: 添加移动端启动 memory

**Files:**
- Create: `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_mobile_mvp_kickoff.md`
- Modify: `C:\Users\1\.claude\projects\H--projiect--------\memory\MEMORY.md`

- [ ] **Step 1: 创建 memory 文件**

写入 `project_zhiyue_mobile_mvp_kickoff.md`：

```markdown
---
name: zhiyue-mobile-mvp-kickoff
description: 2026-07-09 移动端 MVP 启动：Android 优先 + iOS CI 后续，同代码库 + PlatformChromeController 抽象层，MVP 范围阅读+AI+WebDAV
metadata:
  type: project
---

2026-07-09 启动移动端 MVP 开发，前置节点为深度清理（见 `docs/superpowers/specs/2026-07-09-pre-mobile-deep-cleanup-design.md`）。

**平台策略**：
- Android 优先（手机 + 平板，Material 3 window size class 三档响应式：compact < 600 / medium 600-840 / expanded ≥ 840）
- iOS 后续用 GitHub Actions macOS runner CI 拉起（用户本机 Windows，无 macOS）
- 桌面端可见行为 100% 保留（1100px 双页阈值、hover、exit(0) 时序）

**代码库策略**：同代码库 + 平台抽象层（方案 A）
- `PlatformChromeController` 抽象（桌面用 window_manager，移动用 SystemUiMode）
- `ResponsiveLayoutBuilder` 自研 80 行
- 不 fork、不平台分支

**MVP 范围**：
- 阅读（导入 + EPUB/PDF + 高亮 + 笔记 + 目录 + 书签 + 设置）
- AI 导读（三模式 + 苏格拉底 + per-book 多会话 + slash + @-note）
- WebDAV sync（push + pull + conflict）
- **不含**：学习回顾、章节回顾、Markdown 批量导出

**桌面稳定锚点**：tag `desktop-stable-pre-mobile`（深度清理完成后打）

**Why:** 桌面端功能已冻结（v1.7.0-alpha GA），用户需求转向移动端。Flutter 多端框架，Android 已 scaffold 90% 就绪。

**How to apply:** 移动端开发期间所有改动不得破坏桌面行为；每个 task 独立 commit + 全量测试；iOS 接入只补 `ios/` 目录 + CI 配置，代码层零改动。

关联：[[zhiyue-design-context]]、[[zhiyue-dev-env-quirks]]、[[no-dispose-time-fire-and-forget]]
```

- [ ] **Step 2: 更新 MEMORY.md 索引**

在 `MEMORY.md` 末尾追加：

```markdown
- [智阅 移动端 MVP 启动](project_zhiyue_mobile_mvp_kickoff.md) — 2026-07-09 Android 优先 + iOS CI 后续，同代码库 + PlatformChromeController 抽象层；MVP=阅读+AI+WebDAV；桌面稳定锚点 desktop-stable-pre-mobile
```

- [ ] **Step 3: 验证**

```bash
cat "C:/Users/1/.claude/projects/H--projiect--------/memory/MEMORY.md" | tail -3
```

---

### Task 16: 抽查历史 memory 准确性

**Files:**
- Read: `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_m2_7_complete.md`
- Read: `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_2026_07_08_review_fixups.md`
- Read: `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_release_hygiene_sweep.md`
- Read: `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_dev_env_quirks.md`

- [ ] **Step 1: 逐个读取并对照代码现状**

对每个 memory 文件，验证：
- **m2_7_complete**：commit 数 + 测试数是否准确（memory 说 32 tasks / 1122 tests，实际现在 1171+4+11=1186，测试增加了，memory 没过期但需补注"后续有增长"）
- **2026_07_08_review_fixups**：m4.8 调试改动被 stash+drop 丢失 — 确认是否已恢复（git log 看 m4.8 相关 commit）
- **release_hygiene_sweep**：2026-07-01 的 sweep，3 截图 + 2 Gitee Release 是否已完成（本 plan 的 Phase B 会闭环）
- **dev_env_quirks**：Flutter 中文路径约束是否还成立（C:\zhiyue_build worktree 还在用）

- [ ] **Step 2: 修订过期内容**

如发现过期：
- 更新对应 memory 文件
- 更新 `description` frontmatter 字段如需

- [ ] **Step 3: 验证修订后 memory 一致**

```bash
ls -lt "C:/Users/1/.claude/projects/H--projiect--------/memory/" | head -10
```

Expected: 抽查的文件 mtime 更新到当前。

---

## Phase D: 发版 v1.7.1-alpha

### Task 17: 更新 README badge + 项目状态

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 读取当前 README**

```bash
cd H:/projiect/电子书阅读平台
head -30 README.md
```

- [ ] **Step 2: 更新 badge 版本**

将：
```markdown
[![Version](https://img.shields.io/badge/version-1.6.0--alpha-blue.svg)](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.6.0-alpha)
```

改为：
```markdown
[![Version](https://img.shields.io/badge/version-1.7.1--alpha-blue.svg)](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.7.1-alpha)
```

- [ ] **Step 3: 检查"项目状态"章节**

读取 README "项目状态"段落，确认是否需更新：
- 当前最新版本号
- 平台支持（Windows 已发，Android 开发中）
- 下一步规划（移动端 MVP）

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs(readme): bump badge to v1.7.1-alpha + update project status"
```

---

### Task 18: 补充 CHANGELOG [Unreleased]

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: 读取当前 [Unreleased] 段**

```bash
cd H:/projiect/电子书阅读平台
sed -n '8,15p' CHANGELOG.md
```

Expected: `## [Unreleased]` 后只有一句"v1.7.0-alpha 之后的新变更将记在此处。"

- [ ] **Step 2: 提取 v1.7.0-alpha 之后的 commits**

```bash
git log v1.7.0-alpha..HEAD --oneline
```

Expected 输出（截至本 plan 写作时）：
```
67f36c4 docs(spec): pre-mobile deep cleanup design
85c94f8 fix(reader): close final-review gaps in typography persistence
ecb0f26 fix(reader): remove fire-and-forget saveForBook from engine provider
216f70b fix(reader): wire TypographyPersister into reader_page lifecycle
436b35f fix(reader): add TypographyPersister for immediate per-book save
95cfcee chore(installer): drop chinesesimp language from Inno Setup script
```

（如本 plan 已部分执行，还会有更多 commit。只取用户面变更，docs/chore 可省略。）

- [ ] **Step 3: 替换 [Unreleased] 内容**

将 `## [Unreleased]` 段替换为：

```markdown
## [Unreleased]

v1.7.1-alpha 之后的新变更将记在此处。

## [1.7.1-alpha] — 2026-07-09

### 修复

- **reader**: per-book typography persistence 修复 — 用户调整字体设为默认后退出重开仍恢复预设的 bug
  - 根因：dispose-time fire-and-forget `saveForBook` 被 `exit(0)` 同步截断
  - 修复：引入 `TypographyPersister`，订阅 `engine.state$` stream + debounce 500ms 即时落盘
  - PDF 路径补充 `setTypography` emit state$ 保持契约一致
  - commits: `436b35f` / `216f70b` / `ecb0f26` / `85c94f8`

### 杂项

- installer: 移除 Inno Setup chinesesimp language（`95cfcee`）
- docs: 移动端前置深度清理 spec（`67f36c4`）
```

- [ ] **Step 4: 更新底部 link 段**

在 CHANGELOG 底部 `[Unreleased]: ...` 行下方添加：

```markdown
- [1.7.1-alpha]: https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.7.1-alpha
```

- [ ] **Step 5: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs(changelog): add v1.7.1-alpha entry (typography persistence fix)"
```

---

### Task 19: Bump v1.7.1-alpha (pubspec + iss + release-notes + tag)

**Files:**
- Modify: `app/pubspec.yaml` (line 4: `version: 1.7.0-alpha` → `1.7.1-alpha`)
- Modify: `app/windows/installer/zhiyue.iss` (line 7: `#define MyAppVersion "1.5.1"` → `"1.7.1-alpha"`)
- Create: `docs/releases/release-notes-v1.7.1-alpha.md`

- [ ] **Step 1: Bump pubspec version**

```bash
cd H:/projiect/电子书阅读平台
```

编辑 `app/pubspec.yaml` 第 4 行：
```yaml
version: 1.7.1-alpha
```

- [ ] **Step 2: Bump installer version（修正历史遗留）**

编辑 `app/windows/installer/zhiyue.iss` 第 7 行：
```inno-setup
#define MyAppVersion "1.7.1-alpha"
```

（历史遗留：iss 一直停在 1.5.1，本次一并修正到当前版本。）

- [ ] **Step 3: 创建 release-notes**

写入 `docs/releases/release-notes-v1.7.1-alpha.md`：

```markdown
# 智阅 v1.7.1-alpha Release Notes

**发布日期**：2026-07-09
**性质**：fix（用户面 bug 修复）
**Tag**：`v1.7.1-alpha`

## 主要变更

### 修复

- **reader**: per-book typography persistence 修复
  - **现象**：用户调整字体设为默认后退出软件，重新打开加载书籍，字体恢复预设而非用户设定
  - **根因**：第一轮修复用 `ref.onDispose` + fire-and-forget `saveForBook`，被 `main.dart` 的 `exit(0)` 同步截断（绕 PDFium 死锁的设计）
  - **修复**：引入 `TypographyPersister`，订阅 `engine.state$` stream，debounce 500ms 后即时 `repository.saveForBook`，参照 `ProgressPersister` 模式
  - **PDF 补丁**：`PdfRenderer.setTypography` 补充 `stateController.add(ReaderEngineReady())` emit，保持与 `EpubxRenderer` 契约一致
  - **架构约束**：dispose 回调里的 fire-and-forget Future 必丢（exit(0) 截断），新持久化需求必须参照 ProgressPersister/TypographyPersister 即时落盘模式

### 杂项

- installer: 移除 Inno Setup chinesesimp language
- docs: 移动端前置深度清理 spec

## Commit 清单

- `436b35f` fix(reader): add TypographyPersister for immediate per-book save
- `216f70b` fix(reader): wire TypographyPersister into reader_page lifecycle
- `ecb0f26` fix(reader): remove fire-and-forget saveForBook from engine provider
- `85c94f8` fix(reader): close final-review gaps in typography persistence
- `95cfcee` chore(installer): drop chinesesimp language from Inno Setup script
- `67f36c4` docs(spec): pre-mobile deep cleanup design

## 已知问题

无已知阻塞问题。

## 升级指南

直接覆盖安装即可，无 schema 迁移。
```

- [ ] **Step 4: Commit 版本号 + release-notes**

```bash
git add app/pubspec.yaml app/windows/installer/zhiyue.iss docs/releases/release-notes-v1.7.1-alpha.md
git commit -m "chore(release): bump v1.7.0-alpha → v1.7.1-alpha

- pubspec.yaml version bump
- zhiyue.iss MyAppVersion 1.5.1 → 1.7.1-alpha (历史遗留修正)
- release-notes-v1.7.1-alpha.md 新建"
```

- [ ] **Step 5: 打 tag（不 push，等 G 阶段统一）**

```bash
git tag v1.7.1-alpha
```

- [ ] **Step 6: 验证**

```bash
git tag -l v1.7.1-alpha
grep "^version:" app/pubspec.yaml
grep "MyAppVersion" app/windows/installer/zhiyue.iss
ls docs/releases/release-notes-v1.7.1-alpha.md
```

Expected: tag 存在，version=1.7.1-alpha，MyAppVersion="1.7.1-alpha"，文件存在。

---

## Phase B: 补 11 个缺失 release-notes

### Task 20: release-notes v0.4.0、v0.5.0、v0.7.0-alpha

**Files:**
- Create: `docs/releases/release-notes-v0.4.0.md`
- Create: `docs/releases/release-notes-v0.5.0.md`
- Create: `docs/releases/release-notes-v0.7.0-alpha.md`

- [ ] **Step 1: 提取 v0.4.0 数据**

```bash
cd H:/projiect/电子书阅读平台
git log v0.4.0^1..v0.4.0 --oneline
grep -n "\[0.4.0\]" CHANGELOG.md
```

从 CHANGELOG 提取 [0.4.0] 条目内容。v0.4.0 对应 M7（平台适配：图标/显示名/deep-link/签名）。

- [ ] **Step 2: 创建 release-notes-v0.4.0.md**

应用 §Release-Notes Template，填入 v0.4.0 数据。

- [ ] **Step 3: 提取 v0.5.0 数据并创建文件**

```bash
git log v0.5.0^1..v0.5.0 --oneline
grep -n "\[0.5.0\]" CHANGELOG.md
```

v0.5.0 对应 M8（Windows 单实例 + 安装器 + Inno Setup + 截图）。

- [ ] **Step 4: 提取 v0.7.0-alpha 数据并创建文件**

```bash
git log v0.7.0-alpha^1..v0.7.0-alpha --oneline
grep -n "\[0.7.0-alpha\]" CHANGELOG.md
```

v0.7.0-alpha 对应 M1.5a（AI MVP：OpenAI-compatible LLM + 三模式导读 + 摘要缓存）。

- [ ] **Step 5: Commit**

```bash
git add docs/releases/release-notes-v0.4.0.md docs/releases/release-notes-v0.5.0.md docs/releases/release-notes-v0.7.0-alpha.md
git commit -m "docs(releases): add release-notes for v0.4.0 (M7) + v0.5.0 (M8) + v0.7.0-alpha (M1.5a)"
```

---

### Task 21: release-notes v0.8.0-alpha、v0.9.0-alpha、v0.9.1-alpha

**Files:**
- Create: `docs/releases/release-notes-v0.8.0-alpha.md`
- Create: `docs/releases/release-notes-v0.9.0-alpha.md`
- Create: `docs/releases/release-notes-v0.9.1-alpha.md`

- [ ] **Step 1: 提取数据**

```bash
cd H:/projiect/电子书阅读平台
for tag in v0.8.0-alpha v0.9.0-alpha v0.9.1-alpha; do
  echo "=== $tag ==="
  git log ${tag}^1..${tag} --oneline | head -10
  grep -n "\[${tag#v}\]" CHANGELOG.md
done
```

- v0.8.0-alpha 对应 M2.0b（同步冲突 + 后台定时）
- v0.9.0-alpha 对应 M1.5b+c（导入即批处理 + 同书 Q&A + [ch=N] 跳转）
- v0.9.1-alpha 对应 M1.5b+c review fixups（C1 内存泄漏 + I1-I5 spec 偏差）

- [ ] **Step 2: 逐个创建 release-notes 文件**

应用 §Release-Notes Template。

- [ ] **Step 3: Commit**

```bash
git add docs/releases/release-notes-v0.8.0-alpha.md docs/releases/release-notes-v0.9.0-alpha.md docs/releases/release-notes-v0.9.1-alpha.md
git commit -m "docs(releases): add release-notes for v0.8.0-alpha (M2.0b) + v0.9.0-alpha (M1.5bc) + v0.9.1-alpha (review fixups)"
```

---

### Task 22: release-notes v1.0.0、v1.2.0-alpha、v1.3.0-alpha

**Files:**
- Create: `docs/releases/release-notes-v1.0.0.md`
- Create: `docs/releases/release-notes-v1.2.0-alpha.md`
- Create: `docs/releases/release-notes-v1.3.0-alpha.md`

- [ ] **Step 1: 提取数据**

```bash
cd H:/projiect/电子书阅读平台
for tag in v1.0.0 v1.2.0-alpha v1.3.0-alpha; do
  echo "=== $tag ==="
  git log ${tag}^1..${tag} --oneline | head -10
  grep -n "\[${tag#v}\]" CHANGELOG.md
done
```

- v1.0.0 对应 M1.6（polish sweep + GA）
- v1.2.0-alpha 对应 M2.2（EPUB 自动章节结束提示）
- v1.3.0-alpha 对应 M2.3（批量导出范围筛选）

- [ ] **Step 2: 逐个创建 release-notes 文件**

应用 §Release-Notes Template。v1.0.0 是 GA 版本，性质标 `release (GA)`。

- [ ] **Step 3: Commit**

```bash
git add docs/releases/release-notes-v1.0.0.md docs/releases/release-notes-v1.2.0-alpha.md docs/releases/release-notes-v1.3.0-alpha.md
git commit -m "docs(releases): add release-notes for v1.0.0 (M1.6 GA) + v1.2.0-alpha (M2.2) + v1.3.0-alpha (M2.3)"
```

---

### Task 23: release-notes v1.6.0-alpha、v1.7.0-alpha

**Files:**
- Create: `docs/releases/release-notes-v1.6.0-alpha.md`
- Create: `docs/releases/release-notes-v1.7.0-alpha.md`

- [ ] **Step 1: 提取数据**

```bash
cd H:/projiect/电子书阅读平台
for tag in v1.6.0-alpha v1.7.0-alpha; do
  echo "=== $tag ==="
  git log ${tag}^1..${tag} --oneline | head -15
  grep -n "\[${tag#v}\]" CHANGELOG.md
done
```

- v1.6.0-alpha 对应 M2.5（阅读体验大修：双页对开 + 排版 + 字体 + 交互）— 内容多，从 CHANGELOG 完整条目提取
- v1.7.0-alpha 对应 M2.7（AI 抽屉重构：5 入口 → 1 抽屉 + 章节级 subagent + 苏格拉底 + /命令）— 内容多

- [ ] **Step 2: 逐个创建 release-notes 文件**

应用 §Release-Notes Template。这两个版本内容多，从 CHANGELOG 完整提取小节结构。

- [ ] **Step 3: Commit**

```bash
git add docs/releases/release-notes-v1.6.0-alpha.md docs/releases/release-notes-v1.7.0-alpha.md
git commit -m "docs(releases): add release-notes for v1.6.0-alpha (M2.5 UX overhaul) + v1.7.0-alpha (M2.7 AI panel refactor)"
```

---

### Task 24: 创建 Gitee Releases（手动）

**Files:**
- Manual: Gitee Web UI

- [ ] **Step 1: 确认所有 release-notes 文件就绪**

```bash
cd H:/projiect/电子书阅读平台
ls docs/releases/release-notes-*.md | wc -l
```

Expected: 16（4 已有 + 11 本阶段新建 + 1 v1.7.1-alpha）。

- [ ] **Step 2: Push 所有 commits + tags**

```bash
git push origin master
git push origin v1.7.1-alpha
```

- [ ] **Step 3: 逐个创建 Gitee Release**

对以下 12 个版本（11 历史 + 1 新发），在 Gitee Web UI 创建 Release：
- v0.4.0、v0.5.0、v0.7.0-alpha、v0.8.0-alpha、v0.9.0-alpha、v0.9.1-alpha
- v1.0.0、v1.2.0-alpha、v1.3.0-alpha
- v1.6.0-alpha、v1.7.0-alpha、v1.7.1-alpha

URL：`https://gitee.com/weifu0523/e-book-reading-platform/releases/new?tag=v<VERSION>`

每个 Release：
- 标题：`智阅 v<VERSION>`
- 内容：粘贴 `docs/releases/release-notes-v<VERSION>.md` 全文
- 附件：v1.5.0+ 版本附 Windows installer（如 Task 25 build 出的 `zhiyue-setup-1.7.1-alpha.exe` 附 v1.7.1-alpha；历史 installer 如无则省略）

- [ ] **Step 4: 验证 Gitee Releases 页面**

访问 `https://gitee.com/weifu0523/e-book-reading-platform/releases`，确认 16 个 Release（4 已有 + 12 新建）全部列出。

- [ ] **Step 5: 记录完成状态**

无 commit（Gitee Web 操作不产生 git commit）。在本地记录"Gitee Releases 已补齐 16 个"。

---

## Phase G: Tag + Build

### Task 25: 重 build v1.7.1-alpha Windows installer

**Files:**
- Build: `C:\zhiyue_build\app\build\installer\zhiyue-setup-1.7.1-alpha.exe`

- [ ] **Step 1: 同步 worktree 到最新 master**

```bash
cd /c/zhiyue_build
git pull origin master
git log --oneline -3
```

Expected: HEAD 是 v1.7.1-alpha 的 commit 或更晚。

- [ ] **Step 2: Flutter build windows**

```bash
cd /c/zhiyue_build/app
/c/flutter/bin/flutter.bat build windows --release
```

Expected: `build\windows\x64\runner\Release\zhiyue.exe` 生成，build 成功无错误。

- [ ] **Step 3: Inno Setup 编译 installer**

```bash
/c/Users/1/InnoSetup/ISCC.exe /c/zhiyue_build/app/windows/installer/zhiyue.iss
```

Expected: 输出 `build\installer\zhiyue-setup-1.7.1-alpha.exe`，编译成功。

- [ ] **Step 4: 验证 installer**

```bash
ls -lh /c/zhiyue_build/app/build/installer/zhiyue-setup-1.7.1-alpha.exe
```

Expected: 文件存在，大小约 46 MB。

- [ ] **Step 5: 上传到 Gitee v1.7.1-alpha Release**

在 Task 24 Step 3 创建的 v1.7.1-alpha Release 页面，编辑并上传 `zhiyue-setup-1.7.1-alpha.exe` 作为附件。

- [ ] **Step 6: （可选）补 v1.7.0-alpha installer 附件**

如 Gitee v1.7.0-alpha Release 还没有 installer 附件，且 `C:\zhiyue_build\app\build\installer\zhiyue-setup-1.5.1.exe`（历史遗留 v1.7.0-alpha 代码）还存在：

```bash
cp /c/zhiyue_build/app/build/installer/zhiyue-setup-1.5.1.exe \
   /c/zhiyue_build/app/build/installer/zhiyue-setup-1.7.0-alpha.exe
```

上传到 v1.7.0-alpha Release。

- [ ] **Step 7: 记录完成**

无 commit（build 产物不入 git）。记录"v1.7.1-alpha installer 已 build + 上传 Gitee"。

---

### Task 26: 打 desktop-stable-pre-mobile tag + push

**Files:**
- Tag: `desktop-stable-pre-mobile`

- [ ] **Step 1: 确认前置条件全部满足**

```bash
cd H:/projiect/电子书阅读平台
git status                                    # clean
git log --oneline -1                          # HEAD 是 v1.7.1-alpha commit 或后续
cd app && /c/flutter/bin/flutter.bat test 2>&1 | tail -3   # 全绿
```

Expected:
- working tree clean
- 测试 `+1186 ~N` 其中 N ≤ 4，0 failed
- v1.7.1-alpha tag 已存在

- [ ] **Step 2: 打 tag**

```bash
cd H:/projiect/电子书阅读平台
git tag desktop-stable-pre-mobile -a -m "桌面端稳定锚点 — 移动端开发起点

v1.7.1-alpha
- 1171+ tests passing (4 skipped with reasons)
- 16 Gitee Releases with release-notes
- desktop behavior 100% preserved

移动端开发期间如发现桌面回归，可 git checkout desktop-stable-pre-mobile 快速回滚。"
```

- [ ] **Step 3: Push tag**

```bash
git push origin desktop-stable-pre-mobile
```

- [ ] **Step 4: 验证**

```bash
git tag -l desktop-stable-pre-mobile
git ls-remote --tags origin | grep desktop-stable-pre-mobile
```

Expected: 本地 + 远端都有该 tag。

- [ ] **Step 5: 记录里程碑**

无 commit。在 memory `project_zhiyue_mobile_mvp_kickoff.md` 末尾追加：

```markdown

**桌面稳定锚点已打**：`desktop-stable-pre-mobile`（<YYYY-MM-DD>）
- v1.7.1-alpha
- 1186 tests (1171 passed + 4 skipped with reasons + 0 failed)
- 16 Gitee Releases
```

---

## Self-Review Checklist

完成所有 task 后，逐项验证：

- [ ] **A 类完成**：`git status` clean，`.gitignore` 含 `.claude/`、`/*.png`、`*.log`、`**/failures/`
- [ ] **E 类完成**：`flutter test` 输出 `+1186 ~N` 其中 N ≤ 4，0 failed；每个 skip 有清晰理由
- [ ] **C 类完成**：`docs/superpowers/reviews/` 有 4 个文件（1 已有 + 3 新归档）；5 个核心文档检查完成
- [ ] **F 类完成**：memory 文件数 36 → 38（+typography fix + mobile kickoff）；MEMORY.md 索引含两条新条目
- [ ] **D 类完成**：README badge 显示 1.7.1-alpha；CHANGELOG 含 [1.7.1-alpha] 条目；pubspec version=1.7.1-alpha；iss MyAppVersion="1.7.1-alpha"
- [ ] **B 类完成**：`docs/releases/` 有 16 个 release-notes 文件；Gitee Releases 页面有 16 个 Release
- [ ] **G 类完成**：`v1.7.1-alpha` tag + `desktop-stable-pre-mobile` tag 都已 push；installer `zhiyue-setup-1.7.1-alpha.exe` 已 build + 上传 Gitee

## 工期与产出

**预计工期**：6-10 小时

**产出物**：
- ~25 个 commit
- 2 个新 tag（`v1.7.1-alpha`、`desktop-stable-pre-mobile`）
- 12 个新 release-notes 文件
- 3 个新 review 报告
- 2 个新 memory 文件
- 1 个新 Windows installer（v1.7.1-alpha）
- 16 个 Gitee Releases（含 12 新建）

## 后续

清理完成 → 进入移动端 MVP spec 编写（`docs/superpowers/specs/2026-07-XX-mobile-mvp-design.md`），覆盖 brainstorming Section 1-7：
1. 平台抽象层架构（`PlatformChromeController` + `ResponsiveLayoutBuilder`）
2. 依赖适配清单
3. 响应式 UX 重构
4. AI 模块移动端适配
5. WebDAV sync 移动端适配
6. iOS CI/CD 策略
7. MVP 任务拆分 + 测试策略
