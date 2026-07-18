# v1.13.7-alpha

**发布日期**：2026-07-19
**类型**：hotfix（5 bug 修复：1 P0 + 4 P1）
**上一版本**：v1.13.6-alpha

## 摘要

v1.13.6-alpha 发布后用户测试发现：

1. **Bug 5 (P0)**：导入新书后只读一句（v1.13.0-v1.13.5 老症状重现）
2. **Bug 1**：通知栏暂停后无法继续
3. **Bug 2**：选段朗读触屏即停 + 缺控制台
4. **Bug 3**：AI 朗读完后自动切到正文
5. **Bug 4**：语速/语调/音量 Slider 无效

5 个 bug 全部修复。

## Bug 5 (P0)：导入新书后只读一句回归

v1.13.6-alpha 修好了"多句只读 queue[0]"的老症状（main thread post），但用户
测试发现导入新书后会再次复现。诊断日志矛盾：

- 5 个 emit counter 全部为 0（plugin_B 实例上）
- `debugLog` 累积 43 条 `EMIT_DROPPED channel_null`（plugin_A 实例上）

**真根因**：`ZhiYueTtsService.onCreate` 在 service 启动时缓存了
`eventEmitter = plugin::emitEvent` 方法引用。当 plugin rebinding
（Activity recreate / engine restart，例如导入新书触发）发生时，旧 plugin
已经被 detach（`channel = null`），但 service 仍然调用
`plugin_A.emitEvent`——全部事件 dropped，Dart 端 TTS 永远收不到任何
回调，所以"多句只读 queue[0]"重现。

**修复方向**：service `emit()` 方法不再缓存 plugin 引用，每次 emit 都走
`ZhiYueTtsPlugin.instance?.emitEvent(event)` 通过 companion object lookup
动态找到当前的 plugin 实例。这样 plugin rebinding 后，service 自动切到
新 plugin，emit 不再 stale。

## Bug 1：通知栏暂停后无法继续

`ZhiYueTtsService.handleResume()` 之前是空实现，源代码注释说
"Dart side re-sends SPEAK intent"，但 Dart 侧从未实现过——这是 v1.13.0
自研 plugin 时埋下的 stub。同时通知栏 PAUSED 状态下也只显示
pause/stop 按钮，没有 play 按钮，用户无法从通知栏恢复。

**修复**：

- `handleResume()` emit `resume_request` event → Dart `driveResume` 重发
  SPEAK
- 通知栏根据 `mediaSession.playbackState` 动态切换 pause/play 图标
  （PAUSED 显示 play，PLAYING 显示 pause）
- Dart `_onServiceState` 处理 paused state 状态切换
- Dart `_handleEvent` 加 `resume_request` 分支

## Bug 2：选段朗读缺控制台 + 触屏即停

T18 加的 `_onEngineLocation` listener 用户翻页/滚动时自动 pause TTS——但
没有任何控制台可以 resume，所以朗读"停了"就再也起不来。

**修复分两部分**：

- **part A**：移除 T18 auto-pause，`_onEngineLocation` body 改 no-op
- **part B**：`TtsMiniControls` 重构为公共组件（加 `onStopped` callback），
  挂到 `reader_body` Stack 顶层（`Positioned(bottom: 56, left: 16, right: 16)`）；
  3 个朗读入口（朗读本章 / 朗读选中 / AI 聊天）共用同一个 widget

## Bug 3：AI 朗读完后自动切到正文

`TtsReaderController._onPlaybackChange` 在 `phase == idle` 时不检查 scope
就调用 `_onChapterBoundaryReached`，导致 `TtsScopeAiMessage`（AI 朗读 /
PDF 选段）也触发续章——朗读完一句 AI 消息后自动切到正文。

**修复**：加 `_lastObservedScope` 快照（playback.scope 在 idle 时已被
reset 为 null 不能直接判），仅 `TtsScopeChapter` 触发续章。

## Bug 4：语速/语调/音量设置无效

v1.13.0 自研 plugin 时漏实现 settings 应用：

- Kotlin `setRate/setPitch/setVolume` 只 `success(null)` 不转发
- `handleSpeak` 不接收 rate/pitch/volume 参数

用户在 Settings 页改 Slider 完全无效果。

**修复**：

- Dart speak MethodChannel args 加 rate/pitch/volume
  （`_cachedRate/_cachedPitch/_cachedVolume` 字段）
- Kotlin speak Intent extras 透传到 Service
- `handleSpeak` 调用 `TextToSpeech.setSpeechRate/setPitch`
- volume 用 `AudioManager.STREAM_MUSIC` 等比缩放（Android TTS 无
  `setVolume` API）

### Known Limitations

- **volume 影响系统媒体音量**：Android `TextToSpeech` 无 `setVolume` API，
  volume 通过 `AudioManager.setStreamVolume(STREAM_MUSIC, ...)` 等比缩放
  实现——**会影响系统媒体音量**。长期方案是用 AudioTrack + WAV render
  实现 per-stream volume（不阻塞本次发布）。
- **in-flight 设置变更下一句生效**：当前句已锁定参数，下一句生效
  （Android `TextToSpeech.setSpeechRate` 在 utterance 进行中调用不影响
  当前播放）。

## 用户测试步骤

1. 装 v1.13.7-alpha（覆盖 v1.13.6-alpha，versionCode 2004 > 2003）
2. **回归 Bug 5**：导入新书 → 朗读本章 → 应能连续多句推进
3. **回归 Bug 1**：朗读中下拉通知栏 → 点暂停 → 再点继续按钮 → 应恢复播放
4. **回归 Bug 2**：选中文字 → 朗读选中 → 应浮现悬浮控制台；触屏翻页不应停止朗读
5. **回归 Bug 3**：AI 聊天页面长按消息朗读 → 播完聊天内容应停止，不切正文
6. **回归 Bug 4**：Settings → 朗读 → 改语速/语调/音量 Slider → 下一句朗读应应用新值

## 升级路径

直接装 `zhiyue-1.13.7-alpha-with-fgs.apk` 覆盖 v1.13.6-alpha。

- drift schema v15 不变（无 DB 迁移）
- TTS 设置不重置
- versionCode 2004 > v1.13.6 的 2003

## Breaking Change

无。
