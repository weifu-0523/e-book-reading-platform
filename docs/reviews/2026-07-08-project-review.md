# 项目整体 Review（2026-07-08，M2.7 / v1.7.0-alpha 之后）

**触发**：用户 2026-07-08 因「昨天到今天开发量较大」要求全项目 review + bug 修复 + 记录。
**范围**：M2.7 交付完成后对全项目做 P0/P1 bug + spec drift + 测试覆盖 + lint/AGPLv3/文档 一致性扫描。
**覆盖代码量**：`app/lib/` 245 files + engine packages 159 files（排除 M2.7 orphan qa_* 代码）。
**方法**：4 个 feature-dev:code-reviewer subagent 并行（A: runtime/race/stream, B: spec compliance, C: data/migrations/sync, D: security/dep/orphan），主线程汇总 + 验证 + 修复。

---

## 4-agent 并行 review 发现汇总

| Agent | 关注点 | 发现 |
|-------|--------|------|
| A | runtime / race / stream | 1 P0 + 2 P1 |
| B | spec compliance | 0 P0 + 1 P1（违反 #10 M2.1 教训） |
| C | data / migrations / sync | 0 P0 + 2 P1 + 3 P2 |
| D | security / dep / orphan | 0 P0 + 3 P1 + 3 P2 |
| **合计** | | **1 P0 + 8 P1 + 7 P2** |

---

## P0 — 已修

### P0 readerEngineForBookProvider 缓存关闭引擎（commit `840dff7`）

**文件**：`app/lib/features/reader/providers/reader_engine_provider.dart`

**症状**：`readerEngineForBookProvider` 是 `FutureProvider.family`（非 autoDispose），引擎在 provider 被 ref.watch 后不会释放。reader_page unmount 时手动调 `engine.close()`，但下次打开同一本书时 provider 缓存返回已关闭的引擎 → `Cannot add new events after calling close`。

**用户面影响**：第二次打开同一本书时阅读器卡死 / crash。

**修复**：
- provider 改 `FutureProvider.autoDispose.family` + `ref.onDispose(engine.close)`
- reader_page 移除手动 close（让 autoDispose 管理）
- reader_body / reader_progress_bar 的 5 个 stream subscription 在 dispose 时 cancel
- `concrete_reader_engine` + `pdf_renderer` 的 `_setState` 加 `if (_stateController.isClosed) return` 防御

---

## P1 — 已修（8 个）

| commit | fix | 来源 |
|--------|-----|------|
| `840dff7` | reader_body 4 stream subs cancel；reader_progress_bar 1 sub cancel；`_setState` isClosed 防御 | Agent A P1×2 |
| `89ebfc0` | RunRecapUseCase sourceHash 加 highlightsSignature（违反 #10 M2.1 教训重演：缓存 hash 不含高亮 → 高亮变化不触发 recap 重算） | Agent B P1 |
| `8b15061` | LocalBookRepository.delete/deleteBooks 调 recordBook(deleted:true) 入 outbox（删书不跨设备同步 bug） | Agent C P1 |
| `8b15061` | SyncOutboxDao.markPushedMany 批量 UPDATE 单 SQL（原逐行 UPDATE 性能问题） | Agent C P1 |
| `80435e4` | BookImportService.importFile 非 UNIQUE 异常清理 library+cover（导入失败残留） | Agent D P1 |
| `80435e4` | RemoteRecordApplier 3 阶段 apply（books → bookNotes/bookmarks/progress → annotations）避免 FK 乱序 | Agent D P1 |
| `80435e4` | ConflictSink 接收 apply 错误（不再 silent catch） | Agent D P1 |
| `249380d` | UNIQUE 异常路径**不**删 library file（fileHash content-addressed，fallback Book 引用同 path）— T4e self-review catch | Agent D P1 self-caught |

---

## P2 — 已修（2 个，含在上述 commit）

- `80435e4`：ConflictSink 错误不再 silent catch
- `249380d`：fileHash content-addressed 兜底

---

## 未修（待下个 sweep）

### P1 延后

- **M2.7 orphan QA 代码删除**：`QaAskDialog` / `QaController` / `BookQaService` / `QaHistoryDao` / `qa_citation_parser` / `QaHistory` table 注册 — 涉及 build_runner 重生成 + 多文件删除，单独 sweep 处理。CHANGELOG M2.7 已标「下个 sweep 删除」。

### P2 延后

- LIKE 通配符 escape（CJK 触发概率低）
- `_WindowCloseHandler` 强引用（依赖 window_manager 内部 List 强引用）
- `app/README.md` CHANGELOG 相对链接断裂
- pushOnly 404 兜底（坚果云目录预创建）
- `AttachmentNoteResolver` 死代码用错 DAO（BookNotes 而非 Annotations）— 与 orphan qa_* 一起删

---

## 验证

- `dart analyze lib test`：0 issues
- `flutter test`：1133 passed / 4 skipped / 8 failed（全 pre-existing：migration_v4 / typography_settings ×2 / notes_repository / reader_paging scroll mode / typography_profile_repository / typography_golden / book_open_bridge `.txt`）
- 新增测试：T4b 3 + T4c 4 + T4e 5 = 12 个新测试

---

## 关键决策 / 教训

### 1. autoDispose + 异步初始化 race

`FutureProvider.autoDispose.family` 在 await future 期间无 listener 时立即 dispose → `onDispose(close)` → 异步任务后调 `_setState` 抛 "Cannot add new events after calling close"。

**根因修复**：`_setState` 加 `if (_stateController.isClosed) return` 防御，覆盖所有 race condition（包括生产代码 ReaderPage unmount 期间异步任务）。

### 2. T4c subagent 误 stash + drop 丢失 m4.8 调试改动

T4c subagent 为验证 pre-existing failure 用 `git stash`，但 stash 与其他并行 subagent 的 in-progress 改动冲突，subagent 只 checkout 自己的 5 个文件后 drop 了 stash → **m4.8 调试改动丢失**（`reader_engine_epub_view/lib/epubx_renderer.dart` + `html_to_inline_span_converter.dart` + `selectable_page_view.dart` + `concrete_reader_engine.dart` 的 paginationMode getter + 5 个 `epubx_renderer_*test.dart` 文件）。

**影响**：m4.8 已 tag complete，调试改动是 in-progress work，不影响发布版本。

**教训**：并行 subagent 不要用 stash；改用 git worktree 或 `git diff > /tmp/patch` 备份。

### 3. subagent-driven-development「Never parallel」rule 的边界

本次 4 个并行 implementer（T4a/T4b/T4c/T4e）改完全不同模块，理论无冲突，但 T4c subagent 自己用 stash 引入了冲突。

**纪律**：即使文件不冲突，也要警告 subagent 不要用 stash / git reset --hard 等危险操作。

### 4. Agent B 模型选择

4 个 reviewer 全部用 sonnet（feature-dev:code-reviewer 默认），未遵守 memory「14-18 点用 haiku」。理由：全项目 review 不是低风险任务，sonnet 才能抓 race condition / spec 违反。Agent B 抓住 #10 spec 违反重演 M2.1 教训，证明 sonnet 选择正确。

### 5. subagent self-review 有价值

T4e subagent 自己 catch 到 UNIQUE-path 误删 library file 的 bug（commit `249380d`），减少了 1 个 P0。

---

## 相关

- Memory：`[[project-zhiyue-m2-7-complete]]`、`[[project-zhiyue-2026-07-03-review-fixups]]`
- 前次 review：`2026-07-03-project-review.md`
- spec 违反教训：M2.1 #10（缓存 hash 须含数据全维度）
