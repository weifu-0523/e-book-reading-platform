# 智阅 v1.10.0-alpha Release Notes

**发布日期**：2026-07-11
**性质**：Mobile MVP Spiral 3 — 5 工作流交付（WS1-5），25 任务
**Tag**：`v1.10.0-alpha`
**桌面稳定锚点**：`desktop-stable-pre-mobile`（保持）
**Schema 版本**：v13（沿用，无变更）

## 概述

Spiral 3 围绕移动端上手测试期间暴露的 4 类问题展开，分 5 个工作流并行推进：

| 工作流 | 主题 | 任务范围 | 关键交付 |
|---|---|---|---|
| WS1 | WebDAV 同步健壮性 | T1-T5 | 坚果云 MKCOL 409 PROPFIND 区分 |
| WS2 | 移动生命周期同步 UI | T6-T9 | SyncButton + ConflictListTile + MobileLifecycleSyncController |
| WS3 | S2 Part 2 残留 | T10-T16 | 3 plugin compileSdk 36 + ReaderUiState equality + PlatformInfo |
| WS4 | AI 流式优化 | T17-T21 | 两阶段渲染 + auto-scroll 锁 + cancel + dispose SSE 修复 |
| WS5 | TTS 可行性调研 | T22 | 1198 字研究文档（S4 分阶段路径） |

无 schema 变更、无新依赖（plugin 升级在版本范围内）、桌面端行为 byte-for-byte 保持。

## 修复

### WS1：坚果云 MKCOL 409 disambiguation（T1-T3）

- **症状**：用户报告坚果云某些场景下 `MKCOL` 返回 `409 Conflict`，但代码原本裸
  catch 所有 409 视作 "重试 ensureAncestors"——这与 v1.9.0-alpha 的 `AncestorsNotFound`
  修复冲突（"AncestorsNotFound" 和 "Already Exists" 都返回 409，body 不同）。
- **根因**：坚果云对已存在目录的 MKCOL 返回 409（与 RFC 4918 推荐的 405 不同）。
- **修复**：MKCOL 409 后用 PROPFIND depth=0 验证目标是否真实存在——存在即视为
  "Already Exists"，不存在即视为 "AncestorsNotFound" 触发 ensureAncestors 链。
- **辅助**：`ensureAncestors` 每个 segment 加状态日志（T3），便于用户排查路径权限问题。

### T16：auto-hide timer 在 re-show 时不重启

- **症状**：移动端用户 tap 唤出 chrome 后，原 3s 自动隐藏 timer 不会重启。
  用户原话："tap 出来后只能再 tap 隐藏，不能等 3 秒自动隐藏。"
- **根因**：`AutoHideChromeTimer` 的 cancel 是单向的——第一次 tap cancel 后，
  再次 show 不会 schedule 新 timer。
- **修复**：`reader_scaffold` 加 `ref.listen<ReaderUiState>` 监听 chromeVisible
  边沿，false → true 时触发 `_startAutoHideTimerIfNeeded()`。T6-2 测试同步更新
  反映新契约（重新显示 = fresh 3s window）。

### T20：dispose 时 LLM SSE 流泄漏

- **症状**：用户在 AI 流式响应中途关闭抽屉，HTTP 请求不会取消——服务端继续推送
  30s+ 直到自然结束（deepseek 等），浪费流量 + 连接数。
- **根因**：`ChatSessionController.dispose()` 只 cancel 了 `_msgSub`（DB watch），
  未取消在飞的 LLM HTTP 请求。
- **修复**：dispose 调 `_llmCache?.cancel()`。`_llmCache` 在 `selectSession` 时
  eager 缓存——避免 dispose 时 `_ref.read(chatLlmClientProvider)` 读已销毁的
  `ProviderContainer` 抛 "Bad state: Tried to read a provider from a
  ProviderContainer that was already disposed"。
- **副效益**：T19 cancelStreaming 复用同一缓存路径，逻辑收敛。

## 新增

### WS2：移动生命周期同步 UI（T6-T9）

- **`SyncButton`**（T8）：rotating icon 动画 + retry 状态。in-flight 时图标旋转，
  failed 时变红 + tap 重试。
- **`ConflictListTile`**（T7）：移动端宽度守护——文本 ellipsis + 紧凑布局，
  防止 conflict 描述溢出导致布局错乱。widget test 锁定 compact 布局契约。
- **`MobileLifecycleSyncController`**（T9）：接入 main.dart。app 进入 paused
  时不触发；resumed 时若距上次同步 > 5 分钟则触发 syncNow。
- **`SyncController` AppLifecycleState 回归 guard**（T6）：防止 mobile 端
  repeated pause/resume 期间重复 trigger 同步（用户切应用 + 返回场景）。

### WS3：S2 Part 2 残留（T10-T16）

- **T10 plugin 升级**：3 个直接依赖升级到 compileSdk 36 默认——
  `connectivity_plus` 6→7、`file_picker` 8→10、`flutter_secure_storage` 9→10。
  升级后只需对 2 个 transitive plugin 做 pub-cache `sed` 补丁（`just_audio` /
  `webview_flutter_android`），原先 5 个。`file_picker` 10.3.9 移除了
  `FilePicker.platform`，所以 pin 在 `>=10.3.3 <10.3.9`（上界 exclusive）。
- **T13 `ReaderUiState` value equality**：实现 `==` + `hashCode`，防止 Riverpod
  spurious rebuild（同一个 state 值不应触发 listener）。
- **T14 `PlatformInfo` 抽象统一**：5 个 `defaultTargetPlatform == TargetPlatform.windows`
  等比较点收敛到 `PlatformInfo.isDesktop` / `PlatformInfo.isMobile`。`PlatformInfo`
  尊重 `debugDefaultTargetPlatformOverride`，便于 widget test。

### WS4：AI 流式优化（T17-T21）

- **T17 `AiMessage` 两阶段渲染**：流式中渲染 `Text`（廉价），完成后切换
  `MarkdownBody`（昂贵）。MarkdownBody 每次 token 都需要解析整棵 markdown 树，
  流式高频更新时 CPU 占用显著。`streamingMessageId` 字段控制当前哪条消息是流式。
- **T18 chat auto-scroll 尊重用户 pinned 状态**：用户上滑阅读历史时，新增消息
  不应"yank 回到底部"。`_userPinned` flag（距底部 > 80px 视为 pinned）+ `didUpdateWidget`
  检查 `_userPinned` 跳过 jumpTo。
- **T19 `cancelStreaming()` + 停止按钮**：`Icons.send` 在 streaming 时切换为
  `Icons.stop`，tap 路由到 `ChatSessionController.cancelStreaming()`（路由到
  `ChatLlmClient.cancel()` 协作取消 SSE）。
- **T21 drift 并发回归 guard**：2 个 drift-level 测试——同步引擎写 outbox + AI
  流式写 chat_messages 并发不 deadlock；appendContentToMessage 在并发 sync 写
  下不丢失首 chunk。

### WS5：TTS 可行性调研（T22）

- 1198 字文档：`docs/superpowers/research/2026-07-11-tts-feasibility.md`。
- 6 节覆盖：plugin 选型对比 / 使用场景对比 / 高亮跟随可行性 / 后台播放 + 锁屏 /
  平台限制 / S4 分阶段推荐路径。
- **关键结论**：
  - Phase 1（AI 响应朗读）：3-5 天，低风险，推荐 S4.1 立即实现。
  - Phase 2（EPUB 章节朗读 + sentence highlight）：2-3 周。
  - Phase 3（`audio_service` 后台 + 锁屏）：移动端 1-2 周，桌面端不集成。
- **关键风险**：Samsung Android 15 限制 Samsung TTS 引擎仅 Samsung apps 可用，
  需引导用户切到 Google TTS 引擎；iOS 后台 audio entitlement 可能触发 App Store
  审核。

## 重构 / No-op（plan bug 修正）

- **T11 IME 深度审计**：plan bug #4——plan 路径 `features/ai/widgets/ai_input_composer.dart`
  错误，真实在 `features/ai_chat/widgets/`。`AiInputComposer` 已正确管理 `FocusNode`
  生命周期。No-op，文档化决策。
- **T12 全屏 SafeArea 审计**：用户已验证现有覆盖足够。No-op。
- **T15 `TypographyPersister` 去重审计**：plan bug #6——plan 描述的
  `persister.apply(settings)` 和 `fakeEngine.setTypographyCalls` API 不存在。
  现有 subscription 模式已含 dedup guard（lines 55/61），T1.2 测试已覆盖。No-op。

## Commit 清单（v1.9.2-alpha 之后）

完整 23 commit：

### WS1 WebDAV（5）
- `f83976b` docs(plan): S3 implementation plan — 25 tasks across 5 work streams
- `4f46bc7` docs(research): jianguoyun MKCOL 409 AncestorsNotFound investigation
- `d76aca8` fix(sync): disambiguate MKCOL 409 via PROPFIND
- `9a4e7e5` feat(sync): ensureAncestors per-segment status logging
- `167c065` docs(sync): jianguoyun first-time setup + troubleshooting
- `a0c04e5` test(sync): integration regression for jianguoyun first-push 409 chain

### WS2 移动同步 UI（4）
- `c777a47` test(sync): SyncController AppLifecycleState regression guard
- `320202b` feat(sync): ConflictListTile mobile overflow guard + widget test
- `70b4647` feat(sync): SyncButton widget with rotation + retry states
- （T9 接入 main.dart 合并到 T8 commit）

### WS3 S2 Part 2 残留（7）
- `0c47b1b` chore(deps): upgrade 3 direct plugins to compileSdk 36 (T10)
- `9d6a9fb` docs(plan): T11 IME depth audit — no-op (plan bug #4)
- `d7e8b1e` docs(plan): T12 fullscreen SafeArea audit — no-op (user verified)
- `a3d58ee` feat(reader): ReaderUiState value equality + hashCode (I1, T13)
- `6bb4c4a` refactor(core): use PlatformInfo for desktop/mobile branches (I2, T14)
- `7d838d8` docs(plan): T15 TypographyPersister audit — no-op (plan bug #6)
- `836b4db` fix(reader): auto-hide chrome timer restarts on re-show (I4, T16)

### WS4 AI 流式（5）
- `493e6f4` feat(ai): AiMessage two-phase render — Text while streaming, MarkdownBody when done (T17)
- `87e955f` test(ai): T18 lock auto-scroll respects user-pinned state
- `3975c45` feat(ai): T19 cancel streaming via ChatLlmClient.cancel + stop-button UX
- `cbc03fd` fix(ai): T20 dispose cancels in-flight LLM SSE stream
- `c26e677` test(integration): T21 concurrent sync + AI stream no-deadlock regression

### WS5 TTS 调研（1）
- `d791ecd` docs(research): T22 TTS feasibility investigation for S4 planning

## 测试覆盖

新增 ~26 测试（v1.9.2-alpha 之后）：

- **WS1**（1）：`web_dav_sync_engine_test.dart` — jianguoyun first-push 409 chain
  integration regression。
- **WS2**（3）：`SyncController` AppLifecycleState regression guard +
  `ConflictListTile` widget test + `SyncButton` widget test。
- **WS3**（10）：3 plugin upgrade 相关 + 6 ReaderUiState equality + 1 T16
  auto-hide restart。
- **WS4**（11）：4 T17 two-phase render + 2 T18 pinned auto-scroll + 4 T19 stop
  button + 1 T19 cancelStreaming controller + 1 T20 dispose SSE leak。
  - 注：T21（2 个 drift 并发回归）位于 `app/test/integration/`，单独计数。
- **WS5**（0）：研究文档无测试。
- **Integration**（2）：T21 drift concurrent writes regression。

完整回归：**~1293 pass / 3 skip / 10 baseline fail**（pre-existing，沿用 v1.9.2-alpha
基线）。本版无新增失败、无新增 skip。

## 已知问题

### Pre-existing baseline（10 个，与 v1.9.2-alpha 相同）

- `router_test` 1
- `reader_page_test` 4
- `reader_flow_integration` timeout 1
- `reader_page_pdf_integration` load 1
- `reader_ai_drawer_integration` load 1（实际为 skip placeholder，统计口径差）
- `library_golden_test` 2（pre-existing 字体漂移）

### 本版新增（已知）

- **Regenerate 延后**：T19 plan Step 4 spec 含 placeholder（`/* relative to message */`、
  未定义 `onRegenerate` 回调），需产品决策 truncate-and-rewrite vs fresh-append 语义。
  下版（S4 或独立 hotfix）跟进。
- **Word-level TTS highlight 延后**：Phase 2.5，待 sentence-level UX 验证后启动。

### 沿用 v1.9.2-alpha

- iOS 仍为 scaffold（无 Mac 无法 build）。
- APK 单包不拆 ABI（50-80 MB release，含 PDFium）。
- 2 个 transitive plugin pub-cache `sed` 补丁仍需手动执行（`just_audio` /
  `webview_flutter_android`）—— S2 升级 transitive 依赖需要 publisher 发新版本。
- Golden 测试不覆盖 Android 渲染。

## 升级指南

- **桌面**：直接覆盖安装，无 schema 变更（v13 沿用）。
- **Android**：sideload 新 APK；无 schema 变更。
- **WebDAV**：协议未变。如之前在某些边界场景遇到 MKCOL 409 误判（ Already Exists
  被识别为 AncestorsNotFound 触发无谓 ensureAncestors），本次升级后会通过 PROPFIND
  正确区分。

## 下载

> 待 build 产出 artifact 后补充链接；T25 tag 后 Gitee Release 页生效。

- Windows 安装包：`zhiyue-setup-1.10.0-alpha.exe`
- Android APK：`zhiyue-1.10.0-alpha.apk`

## 下一节点

- **S4.1 TTS Phase 1**（AI 响应朗读，3-5 天）：引入 `flutter_tts` + `TtsService`
  抽象 + AiMessageList 长按菜单"朗读" + 设置页语音/语速/音量。
- **Regenerate 独立 hotfix**：T19 遗留的 AI 长按重生成功能（产品决策后跟进）。
- **iOS scaffold build**（CI 后续）：MVP 阶段 iOS 仅占位，后续单独立项。

→ v1.11.0-alpha。
