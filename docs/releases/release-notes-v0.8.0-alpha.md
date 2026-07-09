# 智阅 v0.8.0-alpha Release Notes

**发布日期**：2026-06-29
**性质**：feature（同步冲突可见性 + 后台定时器）
**Tag**：`v0.8.0-alpha`
**对应里程碑**：M2.0b — Sync Conflict Visibility + Background Timer

## 为什么有这个 release

M2.0a（v0.6.0-alpha）交付了 WebDAV 单向 push/pull MVP，但 last-write-wins（LWW）的决策是「黑盒」——本地赢了就赢了，远程被覆盖了用户毫不知情。这个版本把同步冲突暴露出来，并加了后台定时器让同步不用每次手动按。

## 主要变更

### Added

- **Conflict log**：LWW 决策可见。远程记录输给本地时，写入新 `sync_conflicts` 表（含 winner/loser device IDs、timestamps、200-char payload preview）。
- **Sync Status 页**（`/settings/sync/status`）：三段——当前状态 / 后台间隔 picker（1/5/15/30 min 或 off）/ 滚动 30 天的冲突日志。
- **后台调度器**：`BackgroundSyncScheduler` 跑 `Timer.periodic`（默认 5 min），带 `skipIfRunning` guard、错误后 5-min cooldown、lifecycle 感知（pause on background、resume 即时同步）。
- **连通性检测**：`connectivity_plus` 集成，快速 offline 提示（非阻塞——Windows 虚拟网卡报告异常时 fail-open）。
- **Rolling cleanup**：outbox 7 天清理；conflicts 30 天清理，每次成功 `syncNow()` 后自动跑。

### Migration

Drift schema v7 → v8。已有用户下次启动 app 自动 `sync_conflicts` 表 + `idx_sync_conflicts_detected_at` 索引。

### Compatibility

所有 M2.0a sync 测试保持绿色。`NullConflictSink` 是默认注入，所以任何不带 sink 构造 `RemoteRecordApplier` 的代码继续工作不变。

## Commit 清单

21 个 commit（spec/plan + 19 个 TDD 任务）：

- docs：`a30aad2` spec、`5114513` plan
- data：`b315332` sync_conflicts 表、`e53e26c` SyncConflictsDao、`780cbf5` schema v8 migration
- core：`f9d1e44` ConflictSink interface + Null/List 实现、`193793c` DaoConflictSink、`558d3e5` applier 发冲突事件、`fdeb077` engine 接 ConflictSink + deviceId
- scheduler：`8212e0d` BackgroundSyncScheduler（cooldown + skipIfRunning）、`13a0f22` ConnectivityService、`85a37d0` SyncIntervalPref、`b5f0554` SyncController owns scheduler + lifecycle
- UI：`cfd1cf0` i18n 18 keys、`a01e214` IntervalPickerDialog、`812066b` ConflictListTile、`53785f6` SyncStatusPage、`a624ee2` 路由 + 入口
- chore：`996b063` wire providers、`f9ffd9d` schema 断言 7→8、`980823b` bump v0.8.0-alpha

## 测试

subagent-driven development（每 task 双阶段 review），自修 10 个 plan bug（spec 偏差如 `withLength` drift 语法 / `DatabaseConnectionUser.delete` 名字冲突等）。详细记录在 `project_zhiyue_m2_0b_complete.md`。
