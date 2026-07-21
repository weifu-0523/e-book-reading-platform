# v1.15.2-alpha

**发布日期**：2026-07-21
**类型**：diagnostic（SherpaOnnx in-app 调试日志）
**上一版本**：v1.15.1-alpha

## 摘要

用户报告 v1.15.0-alpha SherpaOnnx 朗读无声音 + mini control 不能关闭后，v1.15.1-alpha 已修最可能根因（audioplayers onPlayerComplete 不 emit + 内部 lock + driveStop 顺序）。但用户**没有 adb 没法抓 logcat**，无法验证是否真修好或定位仍有问题时的卡点。v1.15.2-alpha 扩展原有 v1.13.1-alpha「TTS 调试日志」按钮支持 SherpaOnnxTtsService，让用户在 app 内查看 init / speak / play / state-change / stop 全链路日志，截图或复制文本贴回即可。

## 新增功能

### 1. SherpaOnnxTtsService 内存日志 ring buffer

- `_debugLogs` List<String>，cap 200 行（按时间戳顺序）
- `_log(message)` helper：加 `[HH:mm:ss.SSS]` 时间戳 + `debugPrint` + 写 buffer
- `getDebugState()` 返回状态 map（engine / initialized / bindingsReady / initDurationMs / speakCount / speakFailCount / rate / volume / currentSentenceIndex / stopped / serviceDebugLogs）
- init / speakSentence / stop 全路径改用 `_log` 替换 `debugPrint`
- 记录 `_initStartedAt` / `_initFinishedAt` / `_initError` / `_speakCount` / `_speakFailCount`

### 2. SherpaOnnxAudioPlayer 日志钩子

- `static void Function(String)? onDebugLog` callback
- service.init 时 `SherpaOnnxAudioPlayer.onDebugLog = _log;` wire 起来
- play / state-change / stop / error 全路径日志 forward 到同一 buffer
- debugPrint 仍触发，adb 路径不破坏

### 3. 设置页调试日志 SherpaOnnx 分支

- `_showTtsDebugLogs` 检测 `service is SherpaOnnxTtsService` 走新分支
- **不强制 re-init**（170MB asset 拷贝慢），直接 dump 当前状态
- `_prettySherpaDebugState` 渲染 dialog：
  ```
  === SherpaOnnx Engine ===
  engine           : SherpaOnnx / MeloTTS-zh_en
  initialized      : true
  bindingsReady    : true
  initStartedAt    : 2026-07-21T21:08:12.345
  initFinishedAt   : 2026-07-21T21:08:14.876
  initDurationMs   : 2531 (asset copy + FFI bind + ONNX load)
  initError        : (none)
  modelLoadMs      : 2531

  === Playback ===
  speakCount       : 3
  speakFailCount   : 0
  currentIdx       : 0
  stopped          : false
  rate             : 0.0
  volume           : 1.0

  === Service debugLogs (ring buffer, latest 200) ===
  [21:08:12.345] init start
  [21:08:12.350] supportDir=/data/user/0/dev.zhiyue.app/files
  [21:08:12.412] copying asset model.onnx …
  [21:08:13.876] model.onnx copied (170429550 bytes)
  [21:08:13.878] copying asset lexicon.txt …
  [21:08:13.923] lexicon.txt copied (6837671 bytes)
  [21:08:13.925] copying asset tokens.txt …
  [21:08:13.926] tokens.txt copied (655 bytes)
  [21:08:13.927] initBindings() …
  [21:08:13.945] initBindings OK
  [21:08:13.946] OfflineTts ctor (loading ONNX) …
  [21:08:14.875] OfflineTts OK
  [21:08:14.876] init done in 2531ms
  [21:09:01.234] speakSentence idx=0 len=12 initialized=true
  [21:09:01.845] generate OK in 523ms samples=44100 sampleRate=22050
  [21:09:01.846] [AudioPlayer] play start samples=44100 sampleRate=22050 durationMs=2000
  [21:09:01.852] [AudioPlayer] play() returned, awaiting state
  [21:09:01.953] [AudioPlayer] state=PlayerState.playing
  [21:09:03.855] [AudioPlayer] state=PlayerState.completed
  [21:09:03.856] [AudioPlayer] play done stopped=false
  [21:09:03.857] audioPlayer.play returned stopped=false
  ```

## 测试步骤（用户）

### 测试 1：查看 SherpaOnnx 调试日志

1. 装 v1.15.2-alpha APK（覆盖 v1.15.1）
2. 设置 → 朗读 → 「TTS 引擎（实验）」→ 选 SherpaOnnx MeloTTS
3. 出现 SnackBar「引擎已切换，重启朗读生效」
4. **重启 app**
5. 设置 → 朗读 → 「TTS 调试日志」按钮
6. **应弹出 SherpaOnnx 调试面板**，包含：
   - engine / initialized / bindingsReady 等状态
   - 至少几行 init 日志（如果后台 init 已触发）
7. 长按选段朗读，**应能听到 SherpaOnnx 朗读**（v1.15.1 已修）
8. 再次点「TTS 调试日志」 → 应看到 speakSentence / generate / play / state-change 完整链路

### 测试 2：复制日志贴回

1. 测试 1 完成后，调试面板内的 SelectableText 长按可选中
2. 全选 + 复制
3. 贴回给开发者

### 测试 3：mini control 关闭按钮（v1.15.1 修复验证）

1. 触发朗读
2. 点 mini control「关闭」按钮
3. **应立即消失**（v1.15.0 卡住，v1.15.1+ 修复）

### 测试 4：故障诊断

如果 v1.15.2 仍朗读无声音：

1. 设置 → 朗读 → 「TTS 调试日志」
2. 查看日志最后一行停在哪个步骤：
   - 停在 `OfflineTts ctor` → ONNX 加载失败（内存不足？磁盘满？）
   - 停在 `[AudioPlayer] play() returned, awaiting state` 且没有 `state=` → audioplayers 仍不 emit state change（v1.15.1 修失败）
   - 停在 `state timeout after` → 触发了 v1.15.1 timeout 兜底
   - 看到 `[AudioPlayer] state=PlayerState.completed` 但仍无声音 → 设备静音/音量问题
3. 复制日志贴回给开发者

## 升级路径

直接装 v1.15.2-alpha 覆盖 v1.15.1-alpha 或更早版本。

- drift schema v15 不变
- versionCode 2014 > v1.15.1 的 2013
- 默认 TTS 引擎仍是「系统（默认）」

## Breaking Change

无。
