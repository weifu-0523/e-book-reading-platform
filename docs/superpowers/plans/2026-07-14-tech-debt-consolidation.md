# 智阅 技术债与未修复项总账（2026-07-14）

> **本文档不是 TDD 实施计划**，而是累积未开发/未修复内容的总账。每条都标注来源 memory + 优先级 + 建议处理时机。可按类别抽签子，单独写实施 plan。

**截至**：v1.11.6-alpha（master `0ef07b1`，2026-07-13）
**统计**：43 项待办（A 类 10 + B 类 5 + C 类 9 + D 类 2 + E 类 6 + F 类 3 + G 类 2 + 用户手动 6）

---

## 总览（按优先级）

| 优先级 | 数量 | 说明 |
|---|---|---|
| **P0**（阻塞/数据丢失） | 1 | Bug #1 书签红屏根因未定位 |
| **P1**（必修，下个 sweep） | 14 | baseline fail + orphan QA + 截图 + plugin 升级 + 安全 |
| **P2**（应修，可延后） | 18 | 多为窄触发场景 / 设计气味 / 文档漂移 |
| **P3**（机会主义） | 4 | perf baseline / e2e migration test |
| **用户手动** | 6 | Gitee Release 页面 + 截图重捕 + APK 实测 |

---

## A. Baseline test failures（10 项，P1）

**来源**：v1.11.6-alpha release notes + 多次 review 记录。每次发版都背 10 个 pre-existing fail，文档反复提及「下次修」，从未集中处理。

| # | 测试文件 | 失败原因 | 修复路径 |
|---|---|---|---|
| A1 | `reader_page_test.dart`（5 case） | widget 测试 compile error | 读 compile error，按错误信息逐 case 修 |
| A2 | `reader_ai_drawer_integration_test.dart`（1 case） | skip 参数类型错 | 改 `skip:` 参数类型 |
| A3 | `reader_drawer_test.dart`（1 case） | 构造参数错（缺 bookId） | 补 bookId 参数 |
| A4 | `router_test.dart`（1 case） | 待查 | 读错误定位 |
| A5 | `book_import_service_test.dart`（1 case） | 待查 | 读错误定位 |
| A6 | 其他 widget compile error（1 case） | 待查 | 读错误定位 |

**建议**：开一个独立 `2026-07-XX-baseline-test-repair.md` 子 plan，集中 2-3 天清零。每修一个 case 独立 commit。修完后 README + CHANGELOG 的「baseline fail」表述可全删。

**阻塞**：无。但每次 review/release 都得重复标注「pre-existing」，文档噪音大。

---

## B. 已知未修代码 bug（5 项，P1）

### B1. M2.7 orphan QA 代码删除（P1，大改动）

**来源**：`project_zhiyue_2026_07_08_review_fixups.md` + `docs/reviews/2026-07-08-project-review.md`

**问题**：M2.7 把 Q&A 重构为 AI chat + per-book sessions，schema v11→v12 DROP `qa_history` 表，但生产代码里仍残留旧 Q&A 实现：
- `QaAskDialog` / `QaController` / `BookQaService` / `QaHistoryDao` / `qa_citation_parser`
- `QaHistory` table 注册（drift schema 已 DROP，但 Dart 类还在）
- `AttachmentNoteResolver` 死代码用错 DAO（用 BookNotes 而非 Annotations）

**为何延后**：涉及 build_runner 重生成 + 多文件删除 + 跨包引用清理。

**修复路径**：
1. grep 所有 `Qa*` 引用
2. 删 `QaAskDialog` / `QaController` / `BookQaService` / `QaHistoryDao` / `qa_citation_parser` / `QaHistory` table class
3. 删 `AttachmentNoteResolver`（用错 DAO，零调用）
4. 跑 `dart run build_runner build --delete-conflicting-outputs`
5. analyze + 全量测试

### B2. Bug #1 书签红屏精准根因（P0）

**来源**：`project_zhiyue_m2_6_complete.md` T8（2026-07-03 防御性修复）

**问题**：M2.5/v1.5.0-alpha 用户报「书签点击红屏」。T8 在 `gotoLocator` 包了 try-catch + SnackBar 防御性兜底（commit `45a0f02`），但**根因仍未定位**。用户未提供 stack trace。

**为何延后**：无 stack trace 无法精准修。防御性兜底已避免 crash。

**修复路径**：
- 等用户复现时提供 stack trace
- 或主动添加 logging（`stderr.writeln('[bookmark-redscreen] $e\n$stack')`），用户复现后取日志

### B3. PDF 双页 toggle 持久化（P2，per-book）

**来源**：`project_zhiyue_m2_6_complete.md` T2 决策 A1（延后 v1.5.2）

**问题**：v1.5.1-alpha 起 PDF 双页 toggle 是独立按钮（不耦合宽度），但**不持久化**——重开 PDF 书后恢复单页。

**为何延后**：M2.6 后 PDF 路线暂缓，移动端优先。

**修复路径**：
- per-book `pdf_dual_page_{bookId}` SharedPreferences key
- `PdfReaderEngine.dualPageMode` setter 同步写入
- 打开 PDF 时读 prefs 初始化

### B4. m4.8 调试改动恢复（P2，in-progress work 丢失）

**来源**：`project_zhiyue_2026_07_08_review_fixups.md` T4c subagent 误 stash+drop

**问题**：M2.7 review 时 T4c subagent 用 `git stash` 验证 pre-existing failure，但 stash 与其他并行 subagent 的 in-progress 改动冲突，subagent 只 checkout 自己的 5 个文件后 drop 了 stash → **m4.8 调试改动丢失**：
- `reader_engine_epub_view/lib/epubx_renderer.dart`
- `html_to_inline_span_converter.dart`
- `selectable_page_view.dart`
- `concrete_reader_engine.dart` 的 paginationMode getter
- 5 个 `epubx_renderer_*test.dart` 文件

**为何延后**：m4.8 已 tag complete，丢失的是 in-progress 调试改动，不影响发布。

**修复路径**：
- 检查 `git reflog` 是否还能找到 stash（30 天内）
- 若找不回，等下次需要 epubx 调试时重做
- 教训已记 memory：并行 subagent 不要用 stash

### B5. AI baseUrl 无 HTTPS 校验（P1，安全）

**来源**：`project_zhiyue_2026_07_02_review_fixups.md` AI P1-3

**问题**：OpenAI-compatible client 接受任意 baseUrl，用户填 `http://evil.com` 即泄露 API key + 对话内容（MITM/钓鱼风险）。

**为何延后**：涉及 UX 决策（弹窗文案、localhost 豁免、内网部署场景）。

**修复路径**：
- 默认强制 HTTPS
- localhost / 127.0.0.1 / 192.168.x.x 内网豁免
- 非 HTTPS 弹窗警告 + 二次确认

---

## C. P2 延后代码问题（9 项，P2）

**来源**：跨多个 review 记录的 P2 延后集合。多为窄触发场景或设计气味，不阻塞功能。

| # | 问题 | 来源 | 触发条件 |
|---|---|---|---|
| C1 | LIKE 通配符 escape（CJK 触发概率低） | 2026-07-08 Agent C | 用户搜索含 `%` 或 `_` 字符 |
| C2 | `_WindowCloseHandler` 强引用 | 2026-07-08 Agent D | window_manager 内部 List 强引用（依赖第三方库行为） |
| C3 | `app/README.md` CHANGELOG 相对链接断裂 | 2026-07-08 Agent D | 任何打开 app/README 的人 |
| C4 | pushOnly 404 兜底（坚果云目录预创建） | 2026-07-08 Agent D | 坚果云根目录 `/zhiyue/` 未创建时 |
| C5 | Q&A 无去重/并发/限流（重复扣费） | 2026-07-02 AI P1-4 | 用户快速重复点「询问 AI」 |
| C6 | pushOnly read-modify-write 非原子 | 2026-07-02 Sync P0-1 | deviceId 备份/还原触发 |
| C7 | RemoteRecordApplier 可变 deviceId 字段 | 2026-07-02 Sync P1-1 | 设计气味，实际难触发 |
| C8 | book fileHash 去重 / listFiles 目录区分 | 2026-07-02 Sync P1-2/P1-3 | 窄触发场景 |
| C9 | Gitee create_release 脚本不幂等（409 噪音） | 2026-07-10 round-2 review | 重跑发版脚本时 |

**建议**：C5（AI 去重/限流）和 C6（pushOnly 原子性）影响真实用户场景，下个 stable 前应优先；其余可在 refactor sweep 中顺手清。

---

## D. Mobile S2 升级（2 项，P1）

**来源**：`project_zhiyue_mobile_mvp_s1_review_fixups.md` 推 S2 部分

### D1. 5 plugin pub cache sed 补丁升级

**问题**：v1.8.0-alpha 起 5 个 plugin 默认 `compileSdk 34`，但 Android SDK 36 要求 `compileSdk 36`。当前 workaround 是 clone 后跑 sed 改 plugin 源码（已文档化在 `setup-android-sdk.md`），但任何人 clone 后必须手动跑补丁才能 build。

**5 个 plugin**：
- `connectivity_plus`
- `file_picker`
- `flutter_secure_storage`
- `just_audio`
- `webview_flutter_android`

**修复路径**：
- 升级 5 plugin 到默认 compileSdk 36 的版本
- 移除 pub cache sed 补丁
- 更新 `setup-android-sdk.md` + `release-procedure.md`

**风险**：plugin major 版本升级可能引入 breaking change，需逐个验证。

### D2. reader_body tap-toggle widget test

**问题**：M2.5/T9 实现了 reader_body tap-toggle（点中央空白区显隐 chrome），S1 round-2 review 发现原 widget test 是 false-positive harness mirror（复制逻辑到 harness 而非 pump `ReaderBody`），已删除（commit pending）。

**为何延后**：完整 pump `ReaderBody` 需要适配 AI drawer 等 S2 改动，单独做成本高。

**修复路径**：S2 AI 适配时一并补完整 pump 的 widget test。

---

## E. 文档/截图/发布卫生（6 项，P1-P2）

### E1. 截图补齐 + 重捕（P1，用户手动）

**当前状态**：`docs/screenshots/` 只有 `library.png`（M2.5 前过时）+ `epub_reader.png`，缺 `pdf_reader.png` 和 `notes.png`。

**需要**：
- 重捕 `library.png`（M2.5 后 sidebar/fullscreen/dual-page UI 变化）
- 重捕 `epub_reader.png`（同上）
- 新捕 `pdf_reader.png`
- 新捕 `notes.png`（高亮 + 笔记页）

**路径**：`docs/screenshots/README.md` 已有详细捕获步骤，用户手动跑。

### E2. AGPLv3 SPDX 头补齐（P2）

**来源**：`project_zhiyue_2026_07_02_review_fixups.md` 测试覆盖空白段

**问题**：production code 全覆盖，但 `test/` 目录 209 个文件缺 SPDX 头（177 app/test + 32 reader_engine*/test）。

**为何延后**：不阻塞 release；test 目录合规优先级低。

**修复路径**：`tool/add_license_header.dart` 已幂等可复跑，扩展到 test 目录。

### E3. drift onUpgrade e2e 测试（P2）

**来源**：`project_zhiyue_2026_07_02_review_fixups.md`

**问题**：现有 5 个 migration 测试只覆盖 fresh-install，没有真实 from-v1-to-v14 升级覆盖。2026-07-02 review 误报 P0-1（onUpgrade 缺基础表）即因此而来。

**修复路径**：用 drift 的 `schema_v1.dart` + `schema_v14.dart` 写 e2e migration test。

### E4. PDF/EPUB 异常路径测试（P2）

**来源**：`project_zhiyue_2026_07_02_review_fixups.md`

**问题**：malformed epub、加密 PDF、超大 PDF（>100MB）测试薄。

**修复路径**：建 `test/fixtures/malformed/` 目录，写异常路径单元测试。

### E5. reader_body.dart 拆分（P2）

**来源**：`project_zhiyue_release_hygiene_sweep.md`

**问题**：M1.6 polish sweep 目标 ≤300 行，实际 608 行仍未拆。

**为何延后**：reader_body 是核心 UX 文件，拆分风险高。

**修复路径**：按职责拆 reader_chrome_layer / reader_gesture_layer / reader_progress_layer / reader_ai_layer。

### E6. CHANGELOG / README 数字漂移（P2）

**问题**：每次发版后 README 测试数 + baseline fail 数容易忘记 bump。M2.5 时 README.md:110 漏 bump 242 个测试（2026-07-03 review 修）。

**修复路径**：在 `release-checklist.md` 加强制步骤：发版前 grep `passed` / `failed` 实测数回填。

---

## F. 性能 baseline（3 项，P3，用户手动）

**来源**：`project_zhiyue_release_hygiene_sweep.md`

| # | 指标 | 目标 | 测量方式 |
|---|---|---|---|
| F1 | 冷启动时间 | < 2s | DevTools Timeline |
| F2 | 5MB EPUB 翻页帧率 | ≥ 55fps | DevTools Performance |
| F3 | v1.6 GA 前 perf baseline 复测 | 全指标回填 `maintainers-runbook §9.4` | 同上 |

**为何延后**：需用户用 DevTools 手动测。alpha 阶段允许延到 GA 前。

---

## G. 用户手动任务（6 项，无 Claude 协作通道）

### G1. Gitee Release 页面创建（多版本累积）

**待创建**：
- v1.0.0（GA）
- v1.1.0-alpha 至 v1.11.6-alpha（约 15 个版本）
- 每个版本上传 Windows installer + portable zip + APK 三件套

**为何延后**：无 Gitee API token，必须浏览器手动。

### G2. 手机端 APK 实测（v1.11.6-alpha）

**验证点**：
- 手机竖屏 chrome 横向拖动正常
- 所有按钮（返回/书架/字号±/目录/排版/翻页/笔记/书签/AI/全屏）可访问
- 横屏（≥600dp）切换到 AppBar 三段布局 + ReaderClock 居中
- 平板保持现有 AppBar 不变

### G3. Bug #1 复现 + stack trace

**任务**：用户复现「书签点击红屏」，复制黄色英文报错文本，提供给 Claude 精准修复。

### G4. m4.8 调试改动 reflog 恢复

**任务**：用户跑 `git reflog | grep -i stash` 查 30 天内 stash 记录，若能找到 m4.8 调试 stash 即恢复。

### G5. 截图捕获（见 E1）

### G6. perf baseline 测量（见 F）

---

## 推荐执行顺序

### 阶段 1：清零 baseline（1-2 天，P1）
- A1-A6：10 个 pre-existing test failure 全部修复
- 完成后 README + CHANGELOG「baseline fail」表述可全删

### 阶段 2：Mobile S2 升级（2-3 天，P1）
- D1：5 plugin 升级到 compileSdk 36（移除 sed 补丁）
- D2：补 reader_body 完整 pump widget test
- 顺带发布 v1.12.0-alpha（mobile s2）

### 阶段 3：Tech debt sweep（3-5 天，P1+P2）
- B1：orphan QA 代码删除（含 build_runner 重生成）
- B5：AI baseUrl HTTPS 校验
- C5：AI 去重/并发/限流
- C6：pushOnly 原子性（ETag 配合）
- E2：AGPLv3 test 目录补齐
- E3：drift onUpgrade e2e 测试
- E6：CHANGELOG/README 数字漂移 fix

### 阶段 4：用户协作（按需）
- G3：Bug #1 stack trace 收集 → B2 精准修复
- G4：m4.8 stash 恢复 → B4 恢复调试改动
- G5：截图重捕 → E1 闭环
- G6：perf baseline 测量 → F1-F3 回填 runbook

### 阶段 5：v1.0.0 GA 前必做
- 所有 P0/P1 清零
- F1-F3 perf baseline 达标
- G1 Gitee Release 页面全部补齐

---

## 关联

- `docs/reviews/2026-07-08-project-review.md` — 最近一次全项目 review
- `docs/releases/release-notes-v1.11.6-alpha.md` — 最新版本 baseline 明细
- `docs/releases/release-checklist.md` — 发版前 checklist
- `maintainers-runbook.md` §9.4 — perf baseline 决策记录
- Memory files：`project_zhiyue_*` 系列
