# 智阅 v1.11.0-alpha Release Notes

**发布日期**：2026-07-12
**性质**：feature release——M2.8 跨端同步范围扩展
**Tag**：`v1.11.0-alpha`
**桌面稳定锚点**：`desktop-stable-pre-mobile`（保持）
**Schema 版本**：v14（v13 → v14，新增 `books.file_synced_at`）

## 概述

v1.10.1-alpha 修复了同步功能后，用户立即提出跨端续看续聊需求：

> 修改下同步内容，书籍本身，AI聊天历史，书籍标签 都需要同步。
> 我希望在电脑上看的书和聊天可以在手机上接着，同样的手机上看的书回到电脑上继续看继续聊天。

本版本交付 M2.8：新增 **AI 聊天历史同步** + **书籍标签同步** + **书籍 binary 文件同步**，
覆盖之前 metadata-only 同步未触及的三类核心数据。13 任务 TDD，~50 新测试，
schema v13 → v14。

## 新增功能

### 1. AI 聊天历史跨端同步

`chat_sessions` 和 `chat_messages` 表双向同步。用户在 A 设备发起的 AI 问答、
章节回顾、苏格拉底式追问等会话，sync 后在 B 设备的 AI 抽屉里完整可见，可以
继续追问。

**流式追加策略**：AI 响应是逐 token 流式追加的，一次响应可能触发 200+ 次
`appendContent`。为避免 outbox 行爆炸，`appendContent` 不写 outbox；新增
`ChatRepository.completeStreamingMessage(id)` 在 stream 结束时统一 emit 一次。
4 个 streaming use cases（chapter_guide / recap / socratic_bootstrap /
send_message）已加 stream-end hook。

### 2. 书籍标签跨端同步

`book_tags` 表双向同步。复合主键 `(bookId, tag)` 编码为 SyncRecord id
`"${bookId}__${tag}"`。删除通过 `record.deleted=true` tombstone。

新增 `TagEditor` widget，BookDetailPage 内联编辑标签。校验：
- 拒绝空字符串 / 仅空白
- 拒绝含 `__` 子串（与复合主键编码冲突）
- 拒绝长度 > 32
- 拒绝重复（case-insensitive）

### 3. 书籍 binary 文件跨端同步

新增 `BookFileSyncService`：

| 方法 | 用途 |
|---|---|
| `uploadBookFile(bookId)` | 上传单本 → `/zhiyue/files/<bookId>.<format>` + 标记 `file_synced_at` |
| `uploadPendingFiles()` | 扫描所有 `file_synced_at IS NULL` 的书，逐个上传；单本失败（如 507）不阻塞其余 |
| `downloadBookFile(bookId)` | 下载到本地 `<libraryDir>/<bookId>.<format>` + 更新 `file_path` + 标记 `file_synced_at` |
| `deleteRemoteFile(bookId)` | idempotent 删除远程 binary（404 swallowed） |

**WebDavClient 扩展**：`getBytes(path)` / `putBytes(path, bytes)` /
`listFilesWithSize(dirPath)` 三个新方法。

**Sentinel 机制**：receiver 收到一本书的 metadata 但 binary 还没下载时，
`books.file_path` 设为 `'__needs_download__'`。

### 4. Library UX：cloud-download 徽章 + 进度对话框

- `BookCard` / `BookListTile` 在 `file_path` 是 sentinel 时显示云下载图标。
- 用户点击时弹 `_BookDownloadDialog` 进度框 → `SyncController.downloadBookFile`
  → `BookFileSyncService.downloadBookFile` 写入本地 + 更新 `file_path` →
  跳转 reader。
- 失败 → SnackBar 错误报告。

## Schema 变更

**v13 → v14**：`books` 表新增列 `file_synced_at INTEGER`（nullable）。

```sql
ALTER TABLE books ADD COLUMN file_synced_at INTEGER;
```

Migration 走 `ALTER TABLE ADD COLUMN`（drift `customStatement`）。老数据 NULL =
未同步，`uploadPendingFiles` 会自动扫描并上传。

## 改进

- **`SyncRecord.fromJson` 容错**：未知 `type` 值从抛异常改为 skip。
  M2.8 forward-compat：老客户端 pull 到 M2.8 snapshot 不会 crash，只是忽略
  新类型记录。
- **`RemoteRecordApplier` tier 重排**：tier 1 加入 `bookTags` +
  `chatSessions`，tier 2 加入 `chatMessages`，保证 FK 安全。
- **`LocalBookRepository` 接受可选 `remoteFileDeleter` 钩子**：删除本地 row
  之前 best-effort 删除远程 binary。失败不阻塞本地删除（tombstone 仍走
  outbox）。

## 测试覆盖

- 19 新测试 `BookFileSyncService`（upload / download / delete / scan /
  localFileExists / getLocalPath）
- 4 新测试 `RemoteRecordApplier._applyBook`（sentinel + LWW + tombstone）
- 4 新测试 `LocalBookRepository` remoteFileDeleter hook
- 2 新测试 `WebDavSyncEngine` bookFileSync hook
- 3 新测试 `BookCard` / `BookListTile` needs-download overlay
- 2 新测试 cross-device chat continuation（A push → B pull）
- 2 新测试 cross-device book file transfer（A upload → B pull+download +
  tombstone propagation）

**总测试数**：v1.10.1-alpha 的 ~1383 → v1.11.0-alpha 的 **1422 pass + 3 skip
+ 10 baseline fail**（router/reader_page 老 baseline，与 v1.10.x 相同）。

## 已知限制

- **`__needs_download__` 不支持后台下载**：必须在 UI 前台完成。失败 → SnackBar
  错误。后续 v1.12+ 加后台下载 + 通知。
- **删除书籍时的远程 binary 清理为 best-effort**：若 WebDAV 不可达，远程
  binary 会成 orphan（空间泄漏，非正确性问题）。
- **配额管理 UI 不做**：用户决策（2026-07-12 AskUserQuestion 「全部同步，用户
  自负」）。WebDAV 507 错误从 BookFileSyncService 上浮，未来若用户反馈需要
  再加 UI。
- **流式 chat 中途被 cancel 不进入 outbox**：用户重发 → 走完整流程。接受
  这个 trade-off：实现简单 + 不破坏一致性。

## Commit 清单（v1.10.1-alpha 之后）

- `dad52f0` feat(sync): M2.8 T1 add chatSession/chatMessage/bookTag record types + tolerant fromJson
- `0c2cfa5` docs(plan): M2.8 sync scope expansion implementation plan
- `23f3b4b` feat(sync): M2.8 T3 streaming use cases call completeStreamingMessage on stream end
- `96d9158` feat(sync): M2.8 T4 BookTagsRepository + sync wiring
- `33b3fc2` feat(sync): M2.8 T5 RemoteRecordApplier real impls + tier reorder
- `5b46b04` feat(sync): M2.8 T6 BookDetailPage TagEditor with validation
- `642847a` refactor(library): M2.8 T6 self-review fixups - per-tag keyed delete icon + _addSuggestion dedupe
- `68989af` feat(db): M2.8 T7 schema v14 adds books.file_synced_at for binary file sync
- `bbea44a` feat(sync): M2.8 T8 WebDavClient bytes API
- `04562fe` feat(sync): M2.8 T9 BookFileSyncService upload/download/delete + scan pending
- `957a120` feat(sync): M2.8 T10 wire BookFileSyncService into apply/delete/sync-cycle
- `9e603b5` feat(library): M2.8 T11 BookCell needs-download overlay + tap-to-download
- `9cde0c4` test(sync): M2.8 T12 cross-device chat + book file transfer integration
- （本 release notes + CHANGELOG + README badge + version bump）

## 升级路径

- **桌面**：直接覆盖安装，schema v13 → v14 自动迁移（add nullable column）。
- **Android**：sideload APK，schema 自动迁移。
- **WebDAV 服务端**：第一次 sync 时自动 `MKCOL /zhiyue/files/` 创建目录。
- **老版本（v1.10.1-alpha 及以下）**：不识别 `chatSession` / `chatMessage`
  / `bookTag` 三种新 SyncRecordType。`SyncRecord.fromJson` 已改为容错，
  老客户端 pull 到 M2.8 snapshot 时会 skip 这些记录（不 crash）。

## 验收路径（用户决策 2026-07-12）

1. dev 机导入新书 → sync → 用户手机看到书 + tap → 下载完成 → 阅读 ✓
2. dev 机某书发起 AI 问答 → sync → 用户手机该书的 AI 抽屉看到完整对话 ✓
3. dev 机给书加 tag "AI" → sync → 用户手机该书显示 tag "AI" ✓
4. dev 机删除书 → sync → 用户手机该书 + 相关 chat 都消失 ✓
5. v1.10.1-alpha 老客户端 pull 到 M2.8 snapshot 不 crash ✓

## 下一节点

- TTS 集成（M2.9，已在 S4 路线图）
- 跨书 AI 伴读（v1.12+）
- iOS 端 binary 同步 + CI
- 后台下载 + 通知（若用户反馈需要）
