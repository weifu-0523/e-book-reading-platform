# 智阅 v1.9.0-alpha Release Notes

**发布日期**：2026-07-10
**性质**：bugfix + feature（用户测试 3 bug 修复 + 自由笔记）
**Tag**：`v1.9.0-alpha`

## 主要变更

### 修复（用户测试 bug）

- **Bug #1 — 坚果云 WebDAV 同步报 `AncestorsNotFound` (409)**
  - **症状**：上传 snapshot 到 `/zhiyue/snapshots/<uuid>.json` 报
    `WebDavException(409): <s:exception>AncestorsNotFound</s:exception>`
  - **根因**：jianguoyun（坚果云）不像 Nextcloud 那样在 PUT 时自动创建
    父目录，必须显式 MKCOL
  - **修复**：`WebDavClient.mkcol`（幂等：201/200/405 视为成功）+
    `ensureAncestors(filePath)`；`pushOnly.firstPush` 在 `getString` 抛 404
    时触发 MKCOL 链后再 putString
  - **影响范围**：仅首次 push 路径，已有快照覆盖更新逻辑不变

- **Bug #2 — AI 聊天发送后输入框文字残留**
  - **症状**：用户在 AI 聊天界面回车或点发送按钮，消息进入聊天窗口，
    但输入框文字还在，必须手动删除
  - **修复**：`AiInputComposer._onSend` 先 capture text+attachment，
    `_controller.clear()` + `setState(_pendingAttachment=null)` 后再
    `await sendMessage(...)`，避免 async gap 让 UI 显示成"已发但还在"

### 新增

- **Bug #3 — 自由笔记（FreeformNote）**
  - 用户在阅读中可保存 AI 生成的金句、自己的感悟、跨书通用笔记
  - **入口（per-book）**：
    - reader drawer 头部「note_add」按钮 → 新建本书自由笔记
    - NotesPage FAB（右下）+ 顶部自由笔记 section
  - **入口（全局）**：library drawer →「全部自由笔记」
    → GlobalFreeformNotesPage 聚合所有书 + 全局
  - **编辑器**：NoteEditPage
    - 标题 + 内容（支持 Markdown）
    - 编辑/预览切换（visibility / edit icon）
    - 500ms write-through debounce（参照 TypographyPersister，
      避免 `main.dart exit(0)` 截断 dispose Future）
  - **数据层**：drift schema v12 → v13（FreeformNotes 表 +
    idx_freeform_notes_book + idx_freeform_notes_updated）
  - **跨设备同步**：
    - `SyncRecordType.freeformNote` 加入 RemoteRecordApplier tier 1
      （与 bookNote / bookmark 同级，books 之后 / annotations 之前）
    - LWW via `updated_at`，tombstone 支持删除
    - 全局笔记（bookId=null）不依赖 books FK，独立同步
  - **测试覆盖**：
    - schema migration v12 → v13（含 onCreate + onUpgrade）
    - FreeformNotesRepository CRUD + tombstone no-op
    - RemoteRecordApplier tier 1 排序 + LWW + 全局 note
    - 端到端 round-trip（create / update / delete）
    - NoteEditPage 创建 + 预览切换 widget test
    - NotesPage freeform section + FAB + tap 导航 widget test
    - GlobalFreeformNotesPage 4 用例（列表 + FAB + 空状态 + 编辑）
    - NotesDrawerContent 自由笔记 section + 向后兼容 widget test

## Commit 清单（v1.8.0-alpha 之后）

- `aee4daf` fix(sync): WebDavClient.mkcol + ensureAncestors (Bug #1)
- `aee4daf` fix(ai): clear input composer on send (Bug #2)
- `5475e16` docs(notes): freeform notes design spec (Bug #3 spec)
- `b8230fb` plan(notes): 10-task TDD plan for freeform notes
- `63e5351` feat(db): FreeformNotes table + schema v13 migration (T1)
- `24b9a5b` feat(repo): FreeformNotesRepository + SyncRecorder hooks (T2)
- `4702c0b` feat(sync): SyncRecordType.freeformNote + applier tier 1 (T3)
- `50afa19` feat(notes): NoteEditPage with edit/preview toggle (T4)
- `9f14087` feat(reader): freeform section in drawer + wire to NoteEditPage (T5)
- `2dc6644` feat(notes): NotesPage freeform section + FAB + StreamProviders (T6)
- `c1dc569` feat(notes): GlobalFreeformNotesPage + router + drawer entry (T7)
- `a4646b4` test(sync): freeform note end-to-end sync integration (T8)

## 已知问题

- iOS 仍为 scaffold（无 Mac 无法 build）
- APK 单包不拆 ABI（50-80 MB release，含 PDFium）
- 5 plugin pub-cache `sed` 补丁仍需手动执行（S2 升级 plugin 默认 compileSdk 36）
- Golden 测试不覆盖 Android 渲染
- 12 个 pre-existing 测试失败沿用 v1.8.0-alpha baseline

## 升级指南

- 桌面：直接覆盖安装，schema v12 → v13 自动迁移（drift onUpgrade）
- Android：sideload 新 APK；首次启动会执行 schema v13 迁移
- WebDAV：升级后再次 sync 会自动创建 `/zhiyue/snapshots/` 等父目录

## 下一节点

S2：5 plugin 升级 + IME/软键盘适配 → v1.10.0-alpha
