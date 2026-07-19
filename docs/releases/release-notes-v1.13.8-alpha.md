# v1.13.8-alpha

**发布日期**：2026-07-19
**类型**：hotfix（2 bug 修复：1 P0 + 1 UI）
**上一版本**：v1.13.7-alpha

## 摘要

v1.13.7-alpha 发布后用户测试发现：

1. **Bug 1 (UI)**：朗读悬浮控制台按钮太多（用户只要"播放/暂停 + 关闭"）
2. **Bug 2 (P0)**：选段朗读后"从头开始播放而不是选中的文字"

2 个 bug 全部修复。

## Bug 2 (P0)：选段朗读从头开始播放

**症状**：用户选段 → 朗读选中 → 但实际播放的是章节开头，不是选中的文字。
**间歇性**：用户反馈"很多时候"，符合 race condition 特征。

### 决定性诊断证据

用户提供的 v1.13.7 诊断日志关键序列：

```
[1784421646314] onCreate start                            ← service 创建
[1784421646325] handleSpeak textLen=11                    ← 立即 SPEAK
[1784421646327] setLanguage(zh-CN) -> -2 (NOT_SUPPORTED)  ← TTS 未完成 init
[1784421646327] speak() returned -1 (ERROR)               ← speak 失败！
[1784421646381] TTS init callback status=0                ← 54ms 后才 init 完成
...
[1784421729728] onCreate start                            ← service 第 2 次创建
[1784421729739] setLanguage(zh-CN) -> -2                  ← 同样 race
[1784421729739] speak() returned -1                       ← 同样失败
```

### 真根因

`TextToSpeech(ctx, listener)` 构造函数的 `listener.onInit()` 是**异步回调**。
Android framework 在 `onCreate` 后**立即**派发 `onStartCommand → handleSpeak`，
此时引擎未就绪：

- `setLanguage()` 返回 -2 (LANG_NOT_SUPPORTED)
- `tts.speak()` 返回 -1 (ERROR)
- `UtteranceProgressListener` 不触发任何回调（onStart/onDone/onError 都不来）

Dart 侧 MethodChannel 立即 `success(null)`（Kotlin 在 `startService(intent)` 后立即返回），
Dart `_speakCurrent` state 进入 `loading` 等待 `speaking` 永不到达。用户看不到反馈，
再次触发朗读 → `play(scope, sentences)` 重置 queue 从 0 开始 → 现象即"从头播放"。

**与"选段起点定位"无关**：三个朗读入口（朗读本章 / 选段 / 继续朗读）都受影响。
v1.13.7 修了 plugin rebinding（Bug 5 P0），**没修 service onCreate 内部 init race**——
本次补上。

### 修复

`ZhiYueTtsService.handleSpeak` 检测 `ttsInitStatus != TextToSpeech.SUCCESS` 时
把 intent 暂存到 `pendingSpeak` 字段，**不调 `tts.speak()`**。TTS init callback
`status == SUCCESS` 分支末尾检查 `pendingSpeak`，触发 `handleSpeak(it)` 并清空字段。

- `handleSpeak` 头部 init guard（不调 speak）
- TTS init callback 末尾 flush pendingSpeak
- `handleStop` 清空 pendingSpeak 避免 late-init resurrect
- companion field `pendingSpeakActive` 暴露到 `buildDebugState` 供运行时诊断
  （不暴露 Intent 对象本身，Intent 不可序列化）

### 边界情况覆盖

| 场景 | 行为 |
|---|---|
| onCreate + init success 后到达的 SPEAK | 立即 speak（happy path） |
| TTS init 前到达的 SPEAK | pendingSpeak 暂存，init 完成后 flush |
| 多次 SPEAK 在 init 前到达 | 后到的覆盖前（QUEUE_FLUSH 语义一致） |
| STOP 在 init 前到达 | pendingSpeak 清空，init 完成后不 flush |
| TTS init failed (status != SUCCESS) | pendingSpeak 不 flush（避免无限失败循环） |

## Bug 1：控制台按钮过多

用户反馈："朗读的控制台上不需要太多按钮，前进后退这本来就没用，只需要两个按钮，
一个是播放和暂停，另外一个是关闭。"

**修复**：`TtsMiniControls` 移除 `skip_previous` / `skip_next` / `stop` 三个 IconButton：

- **上一句/下一句**：多句朗读按 sentence 边界自动推进（onDone → queue+1），
  跳句按钮本就无意义。
- **停止 vs 关闭**：`TtsPlaybackController.stop` 已清 queue + reset phase 为 idle，
  两个按钮语义完全重复。合并为单一"关闭"按钮（onPressed 调 `stop()`）。

保留：pause/play 切换（一个按钮）+ 关闭 + counter。

### Known Limitations

- **TTS init 永久失败**：若 `TextToSpeech.onInit` 返回 ERROR（status != SUCCESS），
  pendingSpeak 不会 flush。预期行为——避免无限失败循环。debugLog 标
  `TTS init FAILED status=X`；用户重启 app 触发新 service 可能 init 成功。
- **volume 影响系统媒体音量**（v1.13.7 已知限制，仍然适用）：Android
  `TextToSpeech` 无 `setVolume` API，volume 通过 `AudioManager.STREAM_MUSIC`
  等比缩放实现——**会影响系统媒体音量**。

## 用户测试步骤

1. 装 v1.13.8-alpha（覆盖 v1.13.7-alpha，versionCode 2005 > 2004）
2. **回归 Bug 2（核心）**：彻底关闭 app → 启动 → 选段朗读 → 应**立即**播放选中句子（不是章节头），多句连续推进
3. **回归 Bug 2 变体**：朗读中点通知栏停止 → 等 5 秒 → 再次朗读本章 → 第一句应**立即**播放（不再卡 loading）
4. **回归 Bug 1**：朗读中观察悬浮控制台只有 2 个按钮（pause/play + 关闭）；点关闭 → 朗读立即停 + 控制台消失；点暂停 → 当前句停 + 再点恢复 → 继续

## 升级路径

直接装 `zhiyue-1.13.8-alpha-with-fgs.apk` 覆盖 v1.13.7-alpha。

- drift schema v15 不变（无 DB 迁移）
- TTS 设置不重置
- versionCode 2005 > v1.13.7 的 2004

## Breaking Change

无。
