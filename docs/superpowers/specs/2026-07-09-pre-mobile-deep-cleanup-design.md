# 智阅 移动端开发前置深度清理 Design

> **创建日期**：2026-07-09
> **性质**：移动端开发（Android + iOS CI）启动前的仓库卫生整理节点
> **后续节点**：清理完成后打 `desktop-stable-pre-mobile` tag，然后进入移动端 MVP 开发

---

## 1. 目标

把当前仓库整理到「桌面端稳定 + 文档齐全 + 测试全绿 + tag/release 对齐」的状态，作为移动端开发的干净起点。

**核心约束**：
- 桌面端可见行为 100% 保留（不引入任何行为变化）
- 清理期间不混入移动端代码
- 每个清理项独立 commit，便于 bisect 和回滚

## 2. 范围

七类清理（A-G），全部执行：

| 类 | 内容 | 工期 |
|----|------|------|
| A | Git 仓库整理（gitignore + 临时文件 + 未跟踪 plan） | 30 min |
| B | 补 11 个缺失版本的 release-notes + Gitee Release | 2-3 h |
| C | 文档归档（review 报告 + 历史文档检查） | 1-2 h |
| D | README/CHANGELOG 更新 | 30 min |
| E | 测试卫生（11 failed + 4 skipped） | 2-4 h |
| F | Memory 更新（typography 修复 + 历史抽查） | 30 min |
| G | 打 `desktop-stable-pre-mobile` tag + 备份 installer | 30 min |
| **合计** | | **6-10 h** |

## 3. 详细执行清单

### A. Git 仓库整理

**A1: 删除临时截图**
- 删除 `1.png.png`、`2.png`（根目录临时截图）
- 这些不入 git（gitignore 已覆盖 `*.png` 但根目录的没被覆盖因为 gitignore 用的是 `/*.png` 还是 `*.png` 待确认——执行时检查）

**A2: 扩展 .gitignore**
- 加入 `.claude/`（Claude Code 工作目录，本地产物）
- 加入 `/*.png`（根目录截图，例外 `!docs/screenshots/**`）
- 加入 `*.log`（覆盖 `app/flutter_01.log`、`app/custom_lint.log`）
- 加入 `pub_get_output.txt`、`custom_lint.log`
- 扩展测试失败产物：现有 `app/test/goldens/failures/` → `**/failures/`（覆盖 `app/test/features/library/failures/`）

**A3: commit 未跟踪 plan 文件**
- `docs/superpowers/plans/2026-07-09-bug-fix-batch-3.md`
- `docs/superpowers/plans/2026-07-09-per-book-typography-persistence.md`
- `docs/superpowers/plans/2026-07-09-typography-persistence-exit-crash.md`

**验收**：`git status` 显示 working tree clean（除 intentionally untracked）

### B. 补 11 个缺失版本的 release-notes

**缺失版本**：v0.4.0、v0.5.0、v0.7.0-alpha、v0.8.0-alpha、v0.9.0-alpha、v0.9.1-alpha、v1.0.0、v1.2.0-alpha、v1.3.0-alpha、v1.6.0-alpha、v1.7.0-alpha

**已有 release-notes 文件**（4 个）：v1.1.0-alpha、v1.4.0-alpha、v1.5.0-alpha、v1.5.1-alpha

**B1: 为每个缺失版本创建 `docs/releases/release-notes-v<VERSION>.md`**

文件结构（参考已有 release-notes-v1.5.1-alpha.md）：
```markdown
# 智阅 v<VERSION> Release Notes

**发布日期**：<YYYY-MM-DD>（从 git tag 推）
**性质**：<feature / fix / refactor / release>

## 主要变更

<从 CHANGELOG.md 对应版本条目提取 + git log 重建>

## 已知问题

<从 memory + review 报告提取，如适用>

## 升级指南

<如适用>
```

**数据源**：
- `CHANGELOG.md` 对应版本的条目（已维护，主源）
- `git log <prev_tag>..<tag> --oneline` 补充 commit 级细节
- `docs/superpowers/specs/<date>-<milestone>-design.md` 提取设计动机
- memory 里对应里程碑的 complete 条目

**B2: 在 Gitee 上为每个 tag 创建 Release**
- 用 Gitee Web UI（无 CLI）逐个创建
- Release 内容 = release-notes-v<VERSION>.md 全文
- 附件：v1.5.0+ 版本附 Windows installer（如还有保留）
- **执行顺序**：从最早版本开始（v0.4.0），避免 release notes 引用未发布版本

**验收**：`docs/releases/` 有 15 个 release-notes 文件（4 已有 + 11 新建），Gitee Releases 页面对应 15 个 Release

### C. 文档归档

**C1: 归档 review 报告**

memory 提到 3 次 review fixups 但 `docs/superpowers/reviews/` 只有 1 个文件（2026-06-30 m1.5bc）：
- `2026-07-02` review fixups（memory: `project_zhiyue_2026_07_02_review_fixups.md`）
- `2026-07-03` review fixups（memory: `project_zhiyue_2026_07_03_review_fixups.md`）
- `2026-07-08` review fixups（memory: `project_zhiyue_2026_07_08_review_fixups.md`）

**问题**：这些 review 当时是否生成了独立报告文件？还是只在 memory 里记了？
- 如果有报告文件（可能在 subagent 输出里），归档到 `docs/superpowers/reviews/2026-07-02-review-fixups.md` 等
- 如果没有，从 memory 重建简版报告（含 P0/P1 清单 + 修复 commit hash + 延后项）

**C2: 检查核心文档新鲜度**

| 文档 | 检查点 |
|------|--------|
| `docs/01-research.md` | 是否还反映当前技术选型 |
| `docs/maintainers-runbook.md` | 已确认覆盖 Android（line 80），但 release 章节是否含 Android build？M7/M8 之后是否更新过？ |
| `docs/release-procedure.md` | 是否含 Android release 流程（keystore 签名、Play Store/Apk 分发）？目前看起来只覆盖 Windows installer |
| `docs/setup-android-sdk.md` | 是否最新 |
| `docs/screenshots/README.md` | 截图清单是否准确（M8 时延后 3 张，现在补了没？） |

**C3: plans/specs 历史归档决策**

现状：`docs/superpowers/plans/` 42 个 + `docs/superpowers/specs/` 39 个，全部平铺。

**决策**：保持平铺（不按月归档）。理由：
- 文件名带日期前缀（`2026-07-09-...`），自然有序
- 归档到子目录会破坏现有引用路径（memory、CHANGELOG、review 报告都引用了具体路径）
- 42+39 个文件量级可控，不需要归档

**验收**：`docs/superpowers/reviews/` 有 4 个文件（1 已有 + 3 新归档），核心文档检查清单完成

### D. README/CHANGELOG 更新

**D1: README.md badge 版本**
- `1.6.0-alpha` → `1.7.1-alpha`（清理后发新版本）

**D2: README.md "项目状态" 章节**
- 检查并更新到当前状态（v1.7.0-alpha 已发，移动端开发启动中）

**D3: CHANGELOG.md `[Unreleased]` 补充**

现有 `[Unreleased]` 是空的。补充 v1.7.0-alpha 之后的 5 个 commit：
```
- fix(reader): per-book typography persistence 修复（exit(0) 截断 fire-and-forget bug）
  - 436b35f TypographyPersister 即时落盘
  - 216f70b wire into reader_page lifecycle
  - ecb0f26 移除 engine provider 里的 dispose-time saveForBook
  - 85c94f8 PDF setTypography emit state$ 保持契约一致
- chore(installer): drop chinesessimp language from Inno Setup script (95cfcee)
```

**D4: 发新版本 v1.7.1-alpha**

理由：typography persistence 是用户面 bug 修复（v1.7.0-alpha 用户测试发现），值得独立 patch 版本。

操作：
- `app/pubspec.yaml` version: `1.7.0-alpha` → `1.7.1-alpha`
- `app/windows/installer/zhiyue.iss` MyAppVersion: `1.5.1` → `1.7.1-alpha`（注意：当前 iss 还是 1.5.1，是历史遗留，本次一并修正）
- CHANGELOG.md `[Unreleased]` → `[1.7.1-alpha] — 2026-07-09`
- 新建 `docs/releases/release-notes-v1.7.1-alpha.md`
- git tag `v1.7.1-alpha` + push

**验收**：README badge 1.7.1-alpha，CHANGELOG 含 1.7.1-alpha 条目，Gitee 有 v1.7.1-alpha Release

### E. 测试卫生

**当前状态**：1171 passed + 4 skipped + **11 failed** = 1186 total

**E1: 修复 11 个失败测试**

已知失败（从测试输出）：
1. `test/data/local/migration_v4_test.dart: fresh install creates annotations_fts virtual table`
2. `test/data/repositories/notes_repository_test.dart: watchAnnotations emits initial empty when no BookNote exists`
3. `test/features/library/library_golden_test.dart: library_empty`
4. `test/features/library/library_golden_test.dart: library_loaded_grid`
5-11. 还有 7 个（执行时跑 `flutter test` 拿完整列表）

**修复策略**：
- 先跑完整 `flutter test` 拿到全部 11 个失败
- 分类：是测试本身坏了（更新测试）还是代码坏了（修代码）还是环境/快照漂移（regenerate）
- golden 失败：`flutter test --update-goldens` 重新生成（确认视觉变化合理后）
- 每个修复独立 commit

**E2: 处理 4 个 skipped tests**

执行 `grep -rn "skip: true\|@Skip\|test\(.*skip:" test/` 找出 4 个 skipped。
- 评估每个 skip 的理由是否还成立
- 成立 → 保留 + 加注释说明为什么 skip
- 不成立 → 修复或删除

**验收**：`flutter test` 输出 `+1186 ~0`（全绿，无 skip 无 fail）或显式标注每个 skip 的理由

### F. Memory 更新

**F1: 补 typography persistence 修复 memory**

新建 `project_zhiyue_2026_07_09_typography_persistence_fix.md`：
- 修复内容：4 commits（436b35f/216f70b/ecb0f26/85c94f8）
- 根因：exit(0) 截断 dispose-time fire-and-forget
- 解决：TypographyPersister 即时落盘（stream + debounce 500ms）
- 关联：`[[no-dispose-time-fire-and-forget]]`、`[[zhiyue-2026-07-08-review-fixups]]`

**F2: 抽查历史 memory 准确性**

抽查清单（按重要性）：
- `project_zhiyue_m2_7_complete.md` — 最新里程碑，必须准确
- `project_zhiyue_2026_07_08_review_fixups.md` — m4.8 调试改动被 stash+drop 丢失，确认是否已恢复
- `project_zhiyue_release_hygiene_sweep.md` — 2026-07-01 的 sweep，3 截图 + 2 Gitee Release 是否已完成（本次清理会闭环）
- `project_zhiyue_dev_env_quirks.md` — Flutter 中文路径约束是否还成立

**F3: 添加移动端启动节点 memory**

新建 `project_zhiyue_mobile_mvp_kickoff.md`：
- 移动端 MVP 范围：阅读 + AI + WebDAV sync（不含学习回顾）
- 平台策略：Android 优先，iOS 后续 CI/CD
- 代码库策略：同代码库 + 平台抽象层（方案 A）
- 桌面端稳定 tag：`desktop-stable-pre-mobile`
- 关联：`[[zhiyue-design-context]]`、`[[no-dispose-time-fire-and-forget]]`

**验收**：memory 文件数 36 → 38（+typography fix + mobile kickoff），MEMORY.md 索引更新

### G. 移动端前置准备

**G1: 打 `desktop-stable-pre-mobile` tag**

在 E（测试全绿）+ D（v1.7.1-alpha 发版）完成后：
```bash
git tag desktop-stable-pre-mobile
git push origin desktop-stable-pre-mobile
```

**用途**：移动端开发期间如发现桌面回归，可 `git checkout desktop-stable-pre-mobile` 快速回滚。

**G2: 重新 build 并备份 v1.7.1-alpha Windows installer**

D4 已决定发 v1.7.1-alpha（pubspec 版本号变更），需重新 build installer 让 About 对话框显示新版本号：

```bash
# 在 C:\zhiyue_build worktree
cd /c/zhiyue_build && git pull origin master
cd app && flutter build windows --release
/c/Users/1/InnoSetup/ISCC.exe windows/installer/zhiyue.iss
# 产出：build/installer/zhiyue-setup-1.7.1-alpha.exe
```

上传到 Gitee v1.7.1-alpha Release 作为附件。

**v1.7.0-alpha installer 备份**（可选）：当前 `C:\zhiyue_build\app\build\installer\zhiyue-setup-1.5.1.exe` 实际是 v1.7.0-alpha 代码（版本号未改的历史遗留）。如 Gitee v1.7.0-alpha Release 还没有 installer 附件，把这个文件重命名为 `zhiyue-setup-1.7.0-alpha.exe` 上传补充。

**G3: 分支策略确认**

按推荐：**master 直干**（沿用现有习惯）。
- 移动端开发直接在 master commit
- 每个 task 独立 commit + push
- 不开 `feature/mobile-mvp` 长分支（避免长期 divergence + 合并冲突）

**验收**：`git tag -l desktop-stable-pre-mobile` 存在，Gitee 上有对应 tag + Release 含 installer 附件

## 4. 执行顺序

按依赖关系串行执行（部分可并行）：

```
1. A (gitignore + 临时文件)        ← 先清场
2. E (测试修复)                    ← 确保绿底
3. C1 (review 报告归档)            ← 依赖测试结果
4. F1/F3 (memory 更新)             ← 依赖清理结果
5. D3/D4 (CHANGELOG + 发 v1.7.1)   ← 依赖前面所有
6. B (补 11 个 release-notes)      ← 可与 D 并行
7. C2 (文档新鲜度检查)             ← 可与 B 并行
8. F2 (memory 抽查)                ← 可与 B/C2 并行
9. G (打 tag + 备份)               ← 最后
```

## 5. 风险与回滚

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 修测试时改坏桌面行为 | 中 | 高 | 每个修复独立 commit，跑全量测试 |
| gitignore 误伤源码 | 低 | 中 | 用 `git status --ignored` 检查 |
| release-notes 内容不准 | 低 | 低 | 从 CHANGELOG 提取（已维护） |
| 发 v1.7.1-alpha 后发现新 bug | 低 | 低 | 桌面端已稳定 1 周，概率低 |
| Gitee Release 创建失败 | 中 | 低 | tag 已 push，Release 可重试 |

**回滚策略**：
- 任何阶段出问题：`git reset --hard <last-good-commit>`
- 已发 v1.7.1-alpha 后出问题：发 v1.7.2-alpha 修复（不删 tag）
- `desktop-stable-pre-mobile` tag 一旦打就不可删除（是回滚锚点）

## 6. 验收标准

清理完成的标志：

1. ✅ `git status` clean（除 intentionally untracked 如 `.claude/`）
2. ✅ `flutter test` 全绿（0 failed，skipped 显式标注理由）
3. ✅ `docs/releases/` 有 15+1=16 个 release-notes（含 v1.7.1-alpha）
4. ✅ Gitee Releases 页面有 15+1=16 个 Release（含 installer 附件，v1.5.0+ 版本）
5. ✅ README badge 显示 1.7.1-alpha
6. ✅ CHANGELOG.md 含 [1.7.1-alpha] 条目
7. ✅ `docs/superpowers/reviews/` 有 4 个 review 报告
8. ✅ memory 文件数 38（+typography fix + mobile kickoff）
9. ✅ `desktop-stable-pre-mobile` tag 已 push
10. ✅ maintainers-runbook / release-procedure 检查清单完成

## 7. 工期与产出

**预计工期**：6-10 小时

**产出物**：
- ~20-30 个 commit（A 类 3-5 + B 类 11 + C 类 4 + D 类 3 + E 类 11+ + F 类 3 + G 类 2）
- 1 个新 tag `v1.7.1-alpha`
- 1 个新 tag `desktop-stable-pre-mobile`
- 11 个新 release-notes 文件
- 3 个新 memory 文件
- 1 个新 Windows installer（v1.7.1-alpha）

## 8. 后续节点

清理完成 → 进入移动端 MVP 开发：

1. 写移动端 spec（`docs/superpowers/specs/2026-07-XX-mobile-mvp-design.md`）
   - 涵盖 brainstorming Section 1-7：平台抽象层 / 依赖适配 / 响应式 UX / AI 适配 / sync 适配 / iOS CI / MVP 任务拆分
2. 用户 review 移动端 spec
3. 转 writing-plans 写实施 plan
4. subagent-driven-development 执行

**移动端 MVP 范围**（已确认）：
- 阅读（导入 + EPUB/PDF + 高亮 + 笔记 + 目录 + 书签 + 设置）
- AI 导读（三模式 + 苏格拉底 + per-book 多会话 + slash + @-note）
- WebDAV sync（push + pull + conflict）
- 不含：学习回顾、章节回顾、Markdown 批量导出

**平台策略**（已确认）：
- Android 优先（手机 + 平板）
- iOS 后续用 GitHub Actions macOS runner CI 拉起
- 同代码库 + `PlatformChromeController` 抽象层（方案 A）

---

## 附录：调研数据快照（2026-07-09）

### Git 状态
- 分支：master（up to date with origin/master）
- 未跟踪：`.claude/`、`1.png.png`、`2.png`、`app/test/features/library/failures/`、3 个 plan 文件
- 最新 commit：`85c94f8 fix(reader): close final-review gaps in typography persistence`

### Tag 清单
- 本地 30 个 tag（16 m* + 14 v*）
- 远端同步：是
- 最新 tag：`v1.7.0-alpha`（2026-07-08）

### 测试状态
- 1186 total：1171 passed + 4 skipped + 11 failed
- 失败列表（部分）：migration_v4_test、notes_repository_test、library_golden_test ×2 + 7 more

### 文档统计
- `docs/superpowers/plans/`：42 个
- `docs/superpowers/specs/`：39 个
- `docs/superpowers/reviews/`：1 个（缺 3 个）
- `docs/releases/`：5 个 release-notes（缺 11 个）

### Memory 统计
- 36 个 memory 文件
- 最新更新：2026-07-09 22:20（feedback_no_dispose_time_fire_and_forget.md）
- 缺：typography persistence 修复项目级 memory、移动端启动 memory
