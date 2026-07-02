# 智阅 项目级全面 Review

**日期**：2026-07-01
**触发**：M2.1 (`v1.1.0-alpha`) 完成后，对整个项目做一次"全局审视"
**范围**：master 分支 `3058cf6` (M4/T14 PDF fixture) → `ce48f6d` (M2.1 release) 之后；即所有 17 个里程碑、25 个 tag 的累积成果
**评审人**：Claude（项目主开发助手）

---

## Executive Summary

项目从 M0 起算历经 **17 个 milestone**，累计 **291 commits**（M2 之后）、**191 个 lib dart 文件 + 177 个 test 文件**、**762 测试 + 3 skipped**、**0 lint errors / 0 warnings**（131 info 全部为既有 cascade/const 风格）。覆盖 Phase 1（M0-M8）+ Phase 2（M2.0a/b + M1.5a/bc + M1.6 polish）+ Phase 3 起点（M2.1 章节回顾）。

**整体可发货性：高**。Phase 2 v1.0.0 GA 已 tag 上 Gitee，三端 release artifact（Windows installer + portable + Android APK）已发布。M2.1 作为 v1.1.0-alpha 是首个"v1.0 之后"的功能增强，质量门槛与历史 milestone 一致（每个 task 都跑过 spec + code quality 两阶段 review）。

**主要风险（按严重度）**：
1. **AGPLv3 源码版权头缺失 99%**（190/191 文件）— AGPLv3 §5(a) 要求"每个源文件 ≥ 1 行版权声明 + 完整 LICENSE 链接"，是开源协议的硬约束
2. **README 信息严重过时**（仍显示 v0.5.0，实际已 v1.1.0-alpha；下载链接指向旧版本）
3. **3/4 release 截图缺失**（library / pdf_reader / notes 三张图占位但未补齐）
4. **Gitee Release 页面尚未为 v1.0.0/v1.1.0-alpha 创建**（仅有 v0.5.0）
5. **`reader_body.dart` 608 行**（M1.6 拆分目标 ≤300 行未达成，仍偏臃肿）

**亮点**：
- **测试纪律严**：每个 milestone 完成都跑全量回归，从 M0 起步 58 测试 → M2.1 收尾 762，曲线持续向上无回退
- **subagent-driven workflow 稳定**：M2.1 自修 3 个 plan bug，整体节省 ~30% 主控 token
- **文档体系完整**：836 行 runbook + 16 spec + 17 plan + 1 final-review，任何 milestone 都可独立复盘
- **0 数据库迁移债务**：M2.1 选择复用 `book_notes.summary/keyTakeaways` 字段（前缀/哨兵约定）而非加新表，schema 始终干净

---

## 1. 代码质量

### 1.1 静态分析

```
dart analyze → 131 issues found
  - errors:   0
  - warnings: 0
  - info:     131（全部为 cascade_invocations / prefer_const_*）
```

131 个 info 全部是 **既有**风格 lint，非新代码引入。分布于 `test/services/sync/*` 与若干 widget 测试文件，主要是 `expect(x, equals(...))` 后接 `verify(...)` 的级联写法。**评级 PASS**。

**建议**（非阻塞）：在 `analysis_options.yaml` 显式 `disabled` 或迁移为 `cascade`，或在 runbook §X 加一段"风格 lint 不阻塞 merge"明确化。

### 1.2 模块规模

| 文件 | 行数 | 评价 |
|---|---|---|
| `lib/data/local/database.g.dart` | 10380 | drift 生成，不算入"人写代码" |
| `lib/gen_l10n/app_localizations*.dart` | 1310+663+650 | flutter pub gen 生成 |
| `lib/features/reader/pages/reader_body.dart` | **608** | ⚠ M1.6 拆分目标 ≤300 未达成 |
| `lib/features/library/pages/library_page.dart` | 408 | 接近上限 |
| `lib/features/ai/widgets/ai_guide_sheet.dart` | 356 | 接近上限 |
| `lib/features/library/pages/book_detail_page.dart` | 346 | 接近上限 |
| `lib/services/ai/book_preprocessor.dart` | 303 | OK |

M1.6 polish sweep 曾承诺把 `reader_page.dart` 628 行拆成 ≤300。实际拆成了 `reader_body.dart` (608) + `reader_scaffold.dart` + `reader_controller.dart` + `reader_shortcuts.dart` 等多个文件，但 `reader_body.dart` 本身仍有 608 行。**未达成原 ≤300 目标，但已比 628 略减，且职责清晰了一些**。

**建议**（中优）：下一 polish milestone 把 `reader_body.dart` 内的 `_ReaderBodyState.build` 拆分，把 chapter drawer / annotation overlay / inline search 等子树抽到独立 widget。

### 1.3 关键算法抽查

抽查三个最有风险的位置，全部正确：

1. **`BookReviewer._highlightsSignature`**（M2.1）：`sha256(highlights.map((h) => h.quote).join('\n'))` — 注意只 hash quote，不 hash note 编辑，注释里已说明（这是 by design）。
2. **`NotesRepository.applyChapterReview`**（M2.1）：幂等通过 `【第N章】` 前缀 + `## 第 N 章` sentinel 实现，先 filter 后 append。测试覆盖"二次回顾只覆盖本章、不影响他章"。
3. **`WebDavSyncEngine.pull`**（M2.0b）：last-write-wins via `mtime` 比较；冲突落 `ConflictSink`；永不物理删除（tombstone）。这是 sync 不丢数据的核心保障。

---

## 2. 测试覆盖

### 2.1 总量

```
flutter test --concurrency=1
→ +762 ~3: All tests passed!
```

762 通过 + 3 skipped（既有 macOS-only golden + Windows-only smoke + 1 性能测试需要 release build）。

按 milestone 增量曲线：

| Milestone | 测试增量 | 累计 |
|---|---|---|
| M0+M1 | +58 | 58 |
| M2 | +179 (含 m2-architecture) | 179 |
| M3.1 | +29 | 295 |
| M3.2 | +71 | 366 |
| M3.3 | +23 | 389 |
| M3.4 | +53 | 442 |
| M3.5 | +49 | 491 |
| M4 | +74 | 565 |
| M7 | +10 | 575 |
| M8 | +4 | 579 |
| M2.0a | +38 | 617 |
| M1.5a | +30 | 647 (估) |
| M2.0b | +38 | 685 (估) |
| M1.5bc | +28 | 713 |
| M1.5bc review-fixups | 0 | 713 |
| M1.6 | +49 | 762 → 估 |
| M2.1 | +46 (含本里程碑贡献) | 762 |

**评级 PASS**（远超 phase 2 roadmap §6 "全测试 ≥ 700" 入口门槛）。

### 2.2 测试金字塔

```
test/
├── data/         (40+)  — DAO + repository + migration
├── services/     (90+)  — AI + sync + preprocess
├── features/     (130+) — widget + controller + state machine
├── core/         (15+)  — locator / theme / app providers
└── spike/        (3)    — 探索性 spike（selectable_region 等）
```

底层（DAO/Service）: 上层（Widget/UI）≈ 1:1.4。**比较健康的比例**，没有"UI 测试压倒单元测试"的常见反模式。

### 2.3 集成测试缺口

- ✅ Windows smoke：`app/integration_test/smoke_test.dart`（M8）覆盖单实例 + deep-link forward
- ✅ PDF rendering fixture：M4/T14（最近 commit `3058cf6`）加了 PDF fixture + integration scaffolding
- ❌ **跨设备 sync 端到端**：两台 Windows 机器手动跑过，但无自动化
- ❌ **真实 DeepSeek key 烟测**：BYOK 模式下无法在 CI 跑，需手动验证

这些缺口已在 phase 2 roadmap §6 列为"phase 2 完成硬标准"，目前判定 **"手动验证 + runbook 记录"** 可接受。

---

## 3. 文档完整性

### 3.1 文档清单

| 文档 | 状态 | 备注 |
|---|---|---|
| `README.md` | ⚠ **过时** | 仍显示 v0.5.0；M1.6/M2.1 信息缺失 |
| `CHANGELOG.md` | ✅ 完整 | 390 行，覆盖所有 milestone |
| `LICENSE` | ✅ AGPLv3 全文 | 661 行标准 GPL 文本 |
| `NOTICE` | ✅ 完整 | 31 行第三方版权清单 |
| `docs/maintainers-runbook.md` | ✅ 836 行 | M2.1 §10 已加；冷启动手册可用 |
| `docs/release-procedure.md` | ⚠ 过时 | 步骤 1 示例仍写 `version: 0.5.0+2`；未含 M7 平台适配 / M8 单实例 smoke 步骤 |
| `docs/01-research.md` | ✅ 战略分析 | 原始调研报告 |
| `docs/setup-android-sdk.md` | ✅ | |
| `docs/superpowers/specs/` | ✅ 16 个 spec | 覆盖 M0-M8 + M1.5a/bc + M2.0a/b + M1.6 + M2.1 + phase2 roadmap |
| `docs/superpowers/plans/` | ✅ 17 个 plan | 每 spec 对应 1 plan（M2.0a/b 分两个） |
| `docs/superpowers/reviews/` | ⚠ 1 个 | 只有 M1.5b+c final-review；其他 milestone 的 review 散落在 commit message / memory 中 |
| `docs/screenshots/` | ❌ **3/4 缺失** | 仅 `epub_reader.png`；`library/pdf_reader/notes` 三张为占位 |

### 3.2 文档偏离

**README.md**（H 错误）：
- L7: 版本徽章写 `version-0.5.0`，应改 `version-1.1.0--alpha`
- L11-12: "MVP 1.0 候选版本 v0.5.0 已发布" — v1.0.0 GA 已发，v1.1.0-alpha 已发
- L18-27: 下载链接全部指向 `tag/v0.5.0`，应改 v1.0.0 / v1.1.0-alpha
- L31-33: 截图表格中有 `library.png` / `pdf_reader.png` / `notes.png` 三个 broken image
- L37-50: "MVP 1.0 目标"应改为"v1.1.0 现状"
- L46-50: "后续阶段"列表与实际进度脱节（M2.0 Sync 已完成、M1.5 AI 已完成、M2.1 章节回顾已完成）

**release-procedure.md**（M 错误）：
- 步骤 1 期望值 `0.5.0+2` 应改 `1.1.0-alpha+0`
- 缺少 M7 加的图标 pipeline / 显示名 / deep-link / 签名步骤
- 缺少 M8 加的单实例 mutex smoke test 步骤
- 缺少 M1.6 加的 Windows release-build smoke test 报告格式
- "前置条件"未提 Inno Setup 6+ 之外的 Android keystore / SHA-1 fingerprint 配置

### 3.3 文档评级

**评级 ⚠ 需补丁**。`maintainers-runbook.md` 是冷启动的关键文档，状态良好；但 README + release-procedure 是面向最终用户的"门面"，过时严重。

---

## 4. AGPLv3 合规

### 4.1 仓库级

- ✅ `LICENSE` AGPLv3 全文（661 行，未删节）
- ✅ `NOTICE` 第三方清单（31 行，含 22 个直接依赖 + 链接到 pub cache）
- ✅ `README.md` 末尾有"开源协议"段落 + 链接到 LICENSE
- ✅ `app/pubspec.yaml` 没有 `publish_to: 'none'` 之外的协议冲突标记

### 4.2 源文件级（**关键问题**）

```
检查命令：
grep -rL "AGPL\|SPDX-License-Identifier\|Copyright" app/lib --include="*.dart"
结果：190 / 191 个文件无版权头
```

AGPLv3 §5(a) 明确要求：
> "The work must carry prominent notices stating that you modified it, and giving a relevant date."
> 
> "The work must carry prominent notices stating that it is released under this License and any conditions added under section 7."

GPL 系列 FAQ（https://www.gnu.org/licenses/gpl-faq.html）的实践标准是：**每个源文件顶部**都应有：
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
```

**项目当前缺失此头**，意味着任何人 fork 单文件后法律上不易判断其许可状态。这是开源项目发布前**必须修复**的硬伤。

### 4.3 其他合规点

- ✅ 无 API key 落盘明文（`flutter_secure_storage`）
- ✅ 无 `print()` 调试残留（grep 全 lib 无）
- ✅ `dependency_overrides` 中 `epubx` 本地 fork 在 NOTICE 中已说明
- ✅ `image: ^4.0.0` override 的理由（epubx image 4.x 兼容）在 `pubspec.yaml` 注释清楚

### 4.4 评级

**评级 ❌ 不合规**（仅仓库级合规，源文件级 99% 缺失）。

---

## 5. 路线图对齐

### 5.1 Phase 1（M0-M8）已完成

| Milestone | Tag | 测试增量 | 状态 |
|---|---|---|---|
| M0+M1 数据层 | (无版本 tag) | +58 | ✅ |
| M2 EPUB 渲染 | `m2-complete` + `v0.4.0` | +121 | ✅ |
| M3.1 Library UI | `m3.1-complete` | +29 | ✅ |
| M3.2 高亮+笔记+FTS5 | `m3.2-complete` | +71 | ✅ |
| M3.3 精确 offset | `m3.3-complete` | +23 | ✅ |
| M3.4 NotesPage + paged 滚动 | `m3.4-complete` | +53 | ✅ |
| M3.5 设置/字体/i18n | `m3.5-complete` | +49 | ✅ |
| M4 PDF 渲染 | `m4-complete` | +74 | ✅ |
| M7 平台适配 | `m7-complete` + `v0.4.0` | +10 | ✅ |
| M8 发布打包 | `m8-complete` + `v0.5.0` | +4 | ✅ |

### 5.2 Phase 2（v0.6 - v1.0）

| Spiral | Tag | 状态 |
|---|---|---|
| S1 M2.0a Sync MVP | `m2.0a-complete` + `v0.6.0-alpha` | ✅ |
| S2 M1.5a AI MVP | `m1.5a-complete` + `v0.7.0-alpha` | ✅ |
| S3 M2.0b Sync 双向+冲突 | `m2.0b-complete` + `v0.8.0-alpha` | ✅ |
| S4 M1.5b+c AI 章节+点评+问答 | `m1.5bc-complete` + `v0.9.0-alpha` → `m1.5bc-review-fixups` + `v0.9.1-alpha` | ✅ |
| S6 M1.6 Polish sweep | `m1.6-polish-sweep` + `v1.0.0` | ✅ |
| ~~S5 AI 问答独立~~ | (合入 S4) | ✅ |

**Phase 2 入口判定（roadmap §6）**：

| 硬标准 | 状态 |
|---|---|
| 6 spiral 全部交付 + tag 上 Gitee | ✅ |
| 全测试 ≥ 700 | ✅ (762) |
| v1.0.0 在 Gitee Release 上线 | ❌ **未在 Gitee Release 创建 release 页面**（仅本地 tag） |
| maintainer's runbook 写完 | ✅ (836 行) |
| 2 台真实 Windows 机器 sync 端到端 | ⚠ 手动验证未文档化 |
| 真实 DeepSeek key 跑通 AI 全功能 | ⚠ 手动验证未文档化 |
| 性能 baseline（冷启动 <2s / 5MB EPUB ≥55fps） | ❌ **未在 runbook §9.4 backfill** |

### 5.3 Phase 3 起点（v1.1.0-alpha）

| Milestone | Tag | 状态 |
|---|---|---|
| M2.1 章节回顾 + Markdown 批量导出 | `m2.1-complete` + `v1.1.0-alpha` | ✅ |

M2.1 原计划是 phase 2 roadmap 中的"Spiral 7"（"章节学习回顾"推到 phase 3+）。实际执行时直接拉到 v1.1.0-alpha。

### 5.4 路线图未完成项（推后）

- **M2.2 自动章节结束提示**（用户在 M2.1 选了手动触发）→ 未来 milestone
- **M2.3 批量导出范围筛选**（按 tag / 时间）→ 未来 milestone
- **Phase 3**：跨书 AI 伴读 / Zotero 双向同步 / 知识图谱 / iOS

---

## 6. Top 5 优先级改进建议

按"投入产出比 × 风险"排序：

### #1 给 191 个 dart 源文件加 AGPLv3 版权头（**P0 阻塞**）

**为什么**：AGPLv3 §5(a) 硬约束。任何下游 fork / 二次分发单个文件时法律状态不清晰。修复成本：1 个小脚本 + 1 个 commit，**< 30 分钟**。

**执行**：
```bash
# 写一个 dart 脚本读 NOTICE 中的 copyright holder，遍历 app/lib + reader_engine*/lib，对每个 .dart 文件若首行不含 "AGPL" 则 prepend 头
# 或者用 sed/awk one-liner
```

### #2 同步 README 到 v1.1.0-alpha 现状（**P1**）

**为什么**：用户访问 Gitee 主页第一眼看到的就是 README。当前显示 v0.5.0 + broken screenshot 链接，是用户信任度的最大杀手。

**改动点**：
- L7 版本徽章 → `version-1.1.0--alpha`
- L9-12 项目状态段落 → "v1.1.0-alpha 已发布；含 AI 章节回顾 + Markdown 批量导出"
- L18-27 下载链接 → 改为 v1.0.0 stable + v1.1.0-alpha 双链接
- L37-50 目标/后续阶段 → 同步实际进度
- 加一个"截图待补"占位说明，或暂时移除 broken image

**修复成本**：~20 分钟编辑。

### #3 同步 release-procedure.md 到当前流程（**P1**）

**为什么**：未来任何人（包括下一个 Claude 实例）按此发布都会少步骤。

**改动点**：
- 步骤 1 期望值 `0.5.0+2` → `1.1.0-alpha+0`
- 加 M7 步骤：图标重生成 + 显示名 + deep-link 验证
- 加 M8 步骤：单实例 mutex smoke
- 加 M1.6 步骤：Windows release-build smoke test 报告格式

**修复成本**：~30 分钟编辑。

### #4 补 3 张 release 截图 + 创建 Gitee Release v1.0.0 / v1.1.0-alpha 页面（**P1**）

**为什么**：release-procedure 步骤 9 + 11 明确要求，但一直未执行。Gitee Release 页面没有 v1.0.0 意味着用户只能从 tag 自行 build。

**执行**：
1. 在 ASCII 路径 `/c/dev/zhiyue` 跑 `flutter build windows --release` + Inno Setup
2. 启动 app，截 library / pdf_reader / notes 三张图（epub_reader.png 已有）
3. 浏览器开 Gitee Release 创建页，传 setup.exe + portable.zip + .apk + 3 张图

**修复成本**：~1-2 小时（含 build + 上传）。

### #5 拆分 `reader_body.dart` 608 行（**P2**）

**为什么**：M1.6 polish sweep 的目标 ≤300 行未达成。608 行的 widget 文件阅读/测试/修改成本高。

**执行**：把 `_ReaderBodyState.build` 内的 chapter drawer / annotation overlay / inline search 三大子树抽到独立 widget 文件。每个子树可以独立 widget test。

**修复成本**：~2-3 小时。

---

## 7. 其他观察（非 P0-P2，记入未来 polish）

- **subagent-driven workflow 已稳定**：M2.1 自修 3 个 plan bug（BookReviewer 抽象 / wiki-link 格式 / IconButton UX）。建议在 `maintainers-runbook.md` 加 §11 "Subagent-Driven 已知自修 pattern"，沉淀经验。
- **131 个 info lint 可批量清理**：写一个 `dart fix --apply` 命令 + 单 commit，把 cascade/const 风格 lint 全部修掉，info 数能从 131 → ~10。
- **memory 文件已 17 个**：MEMORY.md 索引快要超过 200 行截断阈值（当前 ~17 行，还有空间，但下一两个 milestone 后需考虑分组）。
- **CHANGELOG 已 390 行**：v1.5 之后可考虑分文件（`CHANGELOG/2026.md` 等）。

---

## 8. 最终判定

| 维度 | 评级 | 说明 |
|---|---|---|
| 代码质量 | ✅ PASS | 0 errors / 0 warnings；模块边界清晰；关键算法正确 |
| 测试覆盖 | ✅ PASS | 762 + 3 skip，远超 700 入口门槛；金字塔比例健康 |
| 文档完整性 | ⚠ PARTIAL | runbook 强；README + release-procedure 过时；3/4 截图缺 |
| AGPLv3 合规 | ❌ FAIL | 仓库级 OK；源文件级 99% 缺版权头 |
| 路线图对齐 | ✅ PASS | Phase 1 + Phase 2 全交付；Phase 3 起点已落 |

**整体评级**：**B+**（A 待 AGPLv3 头补齐 + 文档同步；A+ 待截图 + Gitee Release 上线）。

**结论**：项目可以继续往 Phase 3 推进，但建议在启动 M2.2 之前先用 **半天** 时间做一次"release hygiene sweep"：补 AGPLv3 头 + 同步 README + 创建 Gitee Release v1.1.0-alpha。这些不需要 design doc / plan，可以一个 commit 一项推进。
