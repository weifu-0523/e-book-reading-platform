# v1.15.1-alpha

**发布日期**：2026-07-21
**类型**：hotfix（v1.15.0-alpha SherpaOnnx 朗读 bug）
**上一版本**：v1.15.0-alpha

## 摘要

用户报告 v1.15.0-alpha 在 Android 真机切换 SherpaOnnx 引擎后，选段朗读**没声音**且**播放面板不能关闭**。代码分析 3 处共因（audioplayers `onPlayerComplete` 不 emit + 内部 lock 卡 stop + driveStop 顺序不当），全部修复。这是 SherpaOnnx POC 的首次真机 hotfix。

## 修复详情

### 1. SherpaOnnxAudioPlayer.play 用 onPlayerStateChanged 替代 onPlayerComplete

**症状链**：audioplayers Android 部分 ROM + `BytesSource(WAV)` 模式下 `onPlayerComplete` stream 不 emit（历史已知 bug）→ `await p.onPlayerComplete.first` 永远挂起 → `speakSentence()` 永远不返回 → `state.phase` 永远 `speaking`。

**修复**：监听 `onPlayerStateChanged`，等 `PlayerState.completed/stopped`。并加 timeout 兜底（2x 预期时长 + 5s），即使 audioplayers 完全 silent 也能 advance 不卡死。

### 2. SherpaOnnxAudioPlayer.stop fire-and-forget audioplayers.stop

**症状链**：当 play() 卡在 audioplayers 内部 lock 时，stop() 也 await 同一个 lock → 上层 `driveStop` 卡 → UI"关闭"按钮按下后 mini control 不消失。

**修复**：`unawaited(p.stop().catchError(...))`，stop() 立即返回，让 driveStop 不被引擎层卡住。

### 3. driveStop 先切 state 再 await service.stop

**症状链**：v1.15.0-alpha 顺序是 `await service.stop(); state = userStopped:true`。上述 (2) 让 driveStop 卡在 await → state 不切 → mini control 不消失。

**修复**：颠倒顺序，**先** `state = TtsPlaybackState(userStopped: true)` **再** `await service.stop()`。UI 立即响应。Service-level 错误不再 surface 为 `TtsPhase.error`（用户意图"关闭"优先于"引擎确认已停"）。

### 4. 诊断日志

`SherpaOnnxTtsService.init / speakSentence / stop` + `SherpaOnnxAudioPlayer.play / stop / state-change` 关键路径全部加 `debugPrint`：

```
[SherpaOnnxTtsService] init start
[SherpaOnnxTtsService] copying asset model.onnx …
[SherpaOnnxTtsService] model.onnx copied (170429550 bytes)
[SherpaOnnxTtsService] initBindings() …
[SherpaOnnxTtsService] initBindings OK
[SherpaOnnxTtsService] OfflineTts ctor (loading ONNX) …
[SherpaOnnxTtsService] OfflineTts OK
[SherpaOnnxTtsService] init done in 2345ms
[SherpaOnnxTtsService] speakSentence idx=0 len=12 initialized=true
[SherpaOnnxTtsService] generate OK in 523ms samples=44100 sampleRate=22050
[SherpaOnnxAudioPlayer] play start samples=44100 sampleRate=22050 durationMs=2000
[SherpaOnnxAudioPlayer] play() returned, awaiting state
[SherpaOnnxAudioPlayer] state=playing
[SherpaOnnxAudioPlayer] state=completed
[SherpaOnnxAudioPlayer] play done stopped=false
[SherpaOnnxTtsService] audioPlayer.play returned stopped=false
```

用户可用 `adb logcat -s flutter | grep SherpaOnnx` 抓真机日志，下次问题能快速定位。

## 重要限制（v1.15.0-alpha 已知 + v1.15.1-alpha 新增）

### v1.15.0-alpha 仍存在（与 v1.15.1 相同）

- **APK 体积**：~264 MB（MeloTTS 163MB ONNX asset 几乎不可压缩）
- **Windows SherpaOnnx 不可用**：sherpa_onnx_windows 1.13.4 ORT API v17/v27 mismatch，自动 fallback 到系统 SAPI5
- **首次切换引擎朗读 1-3 秒延迟**：170MB asset 拷贝 + ONNX 权重加载
- **盲听评估未完成**：POC report §2 §3 仍待真机数据填回

### v1.15.1-alpha 新增风险

- **真根因未在开发机复现**：`onPlayerComplete` 不 emit 是基于 audioplayers 历史 issue + 代码分析，未在 emulator 直接复现。修复基于最可能 hypothesis，如真机仍有问题需用日志深入定位。
- **audioplayers.stop fire-and-forget 副作用**：play() 卡死时 stop() 异步清理，下次 play() 可能仍受旧 AudioPlayer state 影响。如真机发现此类问题，Phase 2 切换到 just_audio 或 soundpool。

## 测试步骤（用户）

### 测试 1：Android SherpaOnnx 朗读（核心修复验证）

1. 卸载 v1.15.0-alpha，装 v1.15.1-alpha APK
2. 打开任意中文 EPUB
3. 设置 → 朗读 → 「TTS 引擎（实验）」→ 选 SherpaOnnx MeloTTS
4. 出现 SnackBar「引擎已切换，重启朗读生效」
5. 完全关闭 app（杀进程），重新打开
6. 长按选中一段文字，点选区弹片的「朗读」按钮
7. **应能听到 SherpaOnnx 女声普通话朗读**（首次启动有 1-3 秒延迟，因 asset 拷贝 + ONNX 加载）
8. 朗读完成后 mini control 应自动消失（state.phase=idle）

### 测试 2：mini control 关闭按钮

1. 测试 1 完成后，再次触发朗读
2. 朗读中点 mini control「关闭」按钮（× 图标）
3. **应立即消失**（旧版本会卡住不消失）
4. 朗读应停止（虽然 stop 是 fire-and-forget，但下一句不会自动开始）

### 测试 3：速率/音量调整

1. 切到 SherpaOnnx 引擎
2. 设置 → 朗读 → 语速 / 音量滑块 → 调整
3. 触发朗读，**应反映调整**
4. 音调滑块对 SherpaOnnx 无效（MeloTTS 不支持运行时调音调）

### 测试 4：切换回系统 TTS

1. 设置 → 朗读 → 「TTS 引擎（实验）」→ 选「系统（默认）」
2. 触发朗读，应回到原系统 TTS 声音

### 测试 5：adb logcat 抓日志（仅诊断用）

如测试 1 仍有问题，请抓 logcat：

```bash
# 在 PC 上用 adb（手机需开启 USB 调试）
adb logcat -c  # 清空旧日志
adb logcat -s flutter | tee sherpa_logcat.txt
# 触发朗读，30 秒后 Ctrl+C 停止
```

把 `sherpa_logcat.txt` 给我，根据 `[SherpaOnnxTtsService]` / `[SherpaOnnxAudioPlayer]` 标签的输出我能快速定位卡哪一步。

## 升级路径

直接装 v1.15.1-alpha 覆盖 v1.15.0-alpha 或更早版本。

- drift schema v15 不变（无 DB 迁移）
- versionCode 2013 > v1.15.0-alpha 的 2012
- 默认 TTS 引擎仍是「系统（默认）」，需手动切到 SherpaOnnx 才会启用新引擎

## Breaking Change

**driveStop 错误处理语义变化**（仅影响自定义 TtsService 实现）：v1.15.0 之前 `service.stop()` 抛错会进 `TtsPhase.error`（UI 显示 errorMessage）；v1.15.1+ 改为 phase 保持 idle + debugPrint 记录。Stop 是幂等用户意图，引擎清理失败不应阻塞 UI。

对终端用户**无 breaking change**。
