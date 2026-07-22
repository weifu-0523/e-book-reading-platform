# v1.15.5-alpha

**发布日期**：2026-07-22
**类型**：hotfix（v1.15.4-alpha SherpaOnnx 句间卡顿真根因修复）
**上一版本**：v1.15.4-alpha

## 摘要

用户测试 v1.15.4-alpha 后报告"还是很卡顿，读完一句后要听几秒才开始下一句"。systematic-debugging Phase 1 代码分析发现 v1.15.1-alpha 的修复基于错误前提，未实际解决问题。本次 hotfix 修复真正的完成检测路径。

## 真因 + 修复

### Bug：句间卡顿（v1.15.0/v1.15.1 同一根因，v1.15.4 prefetch 救不了）

**真因**（代码源码证据）：

- `audioplayers 5.2.1/lib/src/audioplayer.dart:145-156` 显示 `PlayerState.completed` **只在** `_onPlayerCompleteStreamSubscription`（即 `onPlayerComplete` stream）里被 set
- `onPlayerComplete` 最终走 `WrappedPlayer.onCompletion()`（`audioplayers_android 4.0.3/player/WrappedPlayer.kt:287`），依赖 Android `MediaPlayer.OnCompletionListener`
- 该 listener 在**荣耀 ROM + `BytesSource(WAV)` 模式下不触发**——与 v1.15.0-alpha 是**同一个根因**

v1.15.1-alpha 改用 `onPlayerStateChanged.listen` 监听 `PlayerState.completed`，**基于错误前提**——以为 `onPlayerStateChanged` 是独立信号源，实际上 `PlayerState.completed` 仍由 `onPlayerComplete` 路径触发。改完看似"有声音了"只是因为加了 safety timeout 让 `play()` 能返回，但**每句 gap ≈ safety timeout - 实际音频 ≈ 5-10 秒**。

v1.15.4-alpha prefetch pipeline 设计正确，但因为 `speakSentence` 一直卡在 timeout 等 `play()` 返回，cache 命中也救不了——下一句的 `speakSentence` 永远要等上句 timeout 才被调度。

**修复**（`sherpa_onnx_audio_player.dart`）：

抽 `awaitCompletion` static method —— 用纯 `Timer`（expectedMs + 200ms buffer）作为完成信号，**完全不依赖 audioplayers completion event**：

```dart
final timer = createTimer(
  Duration(milliseconds: expectedDurationMs + 200),
  () { doneCompleter.complete(); },
);
```

监听 `PlayerState.stopped` 仅作为 user stop 的 fast-path（`audioplayers.stop()` 同步 set state，emit 是可靠的）。Safety timeout（2x expected + 5s）兜底极端情况。

修复后：
- `play(N)` 在 N 播完后立即返回（不再等 broken completion event）
- controller 立即调 `_speakCurrent(N+1)`
- `speakSentence(N+1)` cache 命中 → 立即 play(N+1)
- **句间 gap ≈ 0**（核心目标达成）

### 缓存失效策略（v1.15.4-alpha 保留）

- `setSpeechRate` rate 变化清缓存
- `stop` 清 hint + cache

## 测试步骤（用户）

### 测试 1：句间平滑（核心修复验证）

1. 装 v1.15.5-alpha APK
2. 切到 SherpaOnnx 引擎
3. 完全关闭 app，重新打开
4. 长按选中一段多句文字，点选区弹片的「朗读」按钮
5. **应感觉到句与句之间无明显停顿**（v1.15.4 是每句后等 5-10 秒）
6. 首次启动延迟 1-3 秒（asset 拷贝 + ONNX 加载）属正常

### 测试 2：TTS 调试日志确认新机制

1. 朗读一段 5+ 句的话
2. 设置 → 朗读 → 「TTS 调试日志」
3. AudioPlayer 区应显示：
   ```
   [AudioPlayer] play start samples=N sampleRate=R durationMs=D
   [AudioPlayer] play() returned, awaiting expected duration
   [AudioPlayer] expected-duration timer fired — completing
   [AudioPlayer] play done stopped=false
   ```
4. **`expected-duration timer fired` 出现 = 新机制工作**
5. **`safety timeout` 字样不应出现**（如出现说明 Timer 有问题）

### 测试 3：prefetch 命中率（v1.15.4 prefetch 现在能起作用）

1. 朗读多句后看 TTS 调试日志的 `prefetchHitCount`
2. 应该 > 0（v1.15.4 因 speakSentence 卡 timeout 导致 prefetch 没用，本次修复后能真正命中）

### 测试 4：stop 立即生效

1. 朗读中点 mini control 关闭按钮
2. 立即停止，日志应显示 `state=stopped (early termination)`
3. 再次朗读 → 从新位置开始，无 stale 音频

### 测试 5：startup 不被国产 ROM kill（v1.12.3 防护未破坏）

1. 冷启动 app
2. 应正常进入 library 页面（不应闪退回桌面）

## 升级路径

直接装 v1.15.5-alpha 覆盖 v1.15.4 或更早版本。

- drift schema v15 不变
- versionCode 2017 > v1.15.4 的 2016
- 默认 TTS 引擎仍是「系统（默认）」

## Breaking Change

无。

## 关于 MeloTTS 单声音 + 价值对比

用户问"MeloTTS 只有一个声音吗？比荣耀系统 TTS 没证明优化多少"。诚实回答：

- **MeloTTS-zh_en VITS 模型确实只有单说话人**（sid=0），不支持运行时变声
- 中文音质：MeloTTS 中等水平，荣耀系统 TTS（华为/荣耀自研神经 TTS）在中文上**可能听感相当甚至更自然**
- **SherpaOnnx 真正价值**：完全离线（隐私）+ 不依赖 ROM TTS availability + 理论可换模型（如 aishell3 VITS、Piper zh）
- **如果用户的核心诉求是"音质胜过荣耀系统 TTS"**：MeloTTS-zh_en 在当前 POC 范围内无法证明价值
- **本次 hotfix 后**：先让 SherpaOnnx 体验正常（无卡顿），用户再决定是否继续投资（换模型/放弃）
