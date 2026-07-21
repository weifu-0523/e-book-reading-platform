# v1.15.4-alpha

**发布日期**：2026-07-22
**类型**：hotfix（2 UX bug 修复）
**上一版本**：v1.15.3-alpha

## 摘要

用户测试 v1.15.3-alpha 后报告 SherpaOnnx 朗读有声音输出 ✓，但反映 2 个 UX 问题：

1. **Bug 1**：设置页调整音调无变化，问"这个 TTS 只有一个声音选择吗？"
2. **Bug 2**：读完一句后等一会才出下一句，需要"顺畅不出现卡顿感"

## 真因 + 修复

### Bug 1：pitch 无效 + 单声音

**真因**：sherpa_onnx `OfflineTts.generate(text, sid, speed)` API 没有 pitch 参数；MeloTTS-zh_en VITS 模型本身不支持运行时变调。`getVoices()` 返回空列表（单说话人 sid=0）。UI 无条件显示 pitch slider + voice tile 误导用户。

**修复**（`tts_settings_section.dart`）：顶部 `ref.watch(ttsEngineProvider)`，engine=sherpaOnnxMelo 时：
- **Pitch slider**：`onChanged: null` 灰显 + 下方提示"SherpaOnnx MeloTTS 不支持音调调整（POC 限制）"
- **Voice tile**：`onTap: null` 灰显 + subtitle 改为"SherpaOnnx MeloTTS 仅单声音（POC 限制）"

**disable + hint 而非 hide 的理由**：保留肌肉记忆（用户切回 system 引擎时 UI 位置不变）+ 教育用户为何不可用（避免"是不是 bug？"的误解）。

### Bug 2：句间卡顿

**真因**：`speakSentence` 完全串行执行——

```
speakSentence(N):
  generate(N)  ← 500-900ms 阻塞
  play(N)      ← 等待音频播完（3-5s）
  return
speakSentence(N+1):  ← 此处用户感知到静音 gap
  generate(N+1)  ← 500-900ms 阻塞（gap = 此时长）
  play(N+1)
```

**句间静音 = generate(N+1) 时长**。v1.15.2 调试日志证实每句 generate 500-900ms。

**修复**：prefetch pipeline 三层改动——

1. **接口层**（`tts_service.dart`）：加 `Future<void> hintNext(Sentence? next) async {}` 默认 no-op 方法。所有现有 impl（FlutterTtsServiceImpl / SelfBuiltTtsServiceImpl）继承默认行为无破坏。

2. **Controller**（`tts_playback_controller.dart _speakCurrent`）：在 `await _service.speakSentence(current)` 前调 `unawaited(_service.hintNext(next))`，让引擎知道下一句是什么。

3. **SherpaOnnxTtsService**（核心实现）：
   - 覆写 `hintNext`：存 hint，若 hint text 变化则清 stale cache
   - 改 `speakSentence`：先查缓存命中→用 prefetched samples（即时播放无 gap）；未命中→sync generate；然后 `unawaited(_doPrefetch(...))` 在 play await 窗口内并行 generate 下一句
   - `_doPrefetch`：FFI generate 在主 isolate 跑（sherpa_onnx `OfflineTts` 持有 native pointer 不能跨 isolate），但 audioplayers 已在 native audio thread 渲染不受 FFI 阻塞影响——**用户感知不到句间 gap**

**为什么不用 Isolate.run**：sherpa_onnx `OfflineTts` 持有 native pointer 不能跨 isolate；移到 worker isolate 需重写 FFI 绑定，超 POC hotfix 范围。`unawaited(Future(() {}))` 在主 isolate 调度，FFI 仍阻塞主 isolate ~500-900ms，但用户感知到的句间 gap 消除（核心目标），可能感知到 UI 输入滞后（acceptable tradeoff）。

### 缓存失效策略（v1.13.10-alpha Bug 1 教训套用）

- `setSpeechRate`：rate 变化时清缓存（否则播旧速率音频）
- `stop`：清 hint + cache（防 stop→skip→resume 序列播 stale 音频）
- `pause`：继承（委托 stop）

### 诊断增强

`SherpaOnnxTtsService.getDebugState()` 新增 3 字段：
- `prefetchHitCount`：缓存命中次数（gap 消除次数）
- `prefetchMissCount`：缓存未命中次数（sync generate 兜底）
- `prefetchFailCount`：后台 generate 失败次数

in-app TTS 调试日志 dialog 直接打印，无需 adb。

## 测试步骤（用户）

### 测试 1：Bug 1 pitch UI（核心修复验证）

1. 装 v1.15.4-alpha APK
2. 设置 → 朗读 → 「TTS 引擎（实验）」→ 选 SherpaOnnx MeloTTS
3. **pitch slider 应灰显**，下方应有提示文字"SherpaOnnx MeloTTS 不支持音调调整（POC 限制）"
4. 切回「系统（默认）」→ pitch slider 应恢复可用，提示文字消失

### 测试 2：Bug 1 voice tile（核心修复验证）

1. 同测试 1 切到 SherpaOnnx
2. **voice tile 应灰显**（点击无反应），subtitle 应为"SherpaOnnx MeloTTS 仅单声音（POC 限制）"
3. 切回「系统（默认）」→ voice tile 应恢复可点击路由到 VoiceListPage

### 测试 3：Bug 2 句间平滑（核心修复验证）

1. 切到 SherpaOnnx 引擎
2. 完全关闭 app，重新打开
3. 长按选中一段多句的文字，点选区弹片的「朗读」按钮
4. **应感觉到句与句之间无明显停顿**（v1.15.3 是每句后等 0.5-1 秒）
5. 首次启动延迟 1-3 秒（asset 拷贝 + ONNX 加载）属正常

### 测试 4：缓存命中率（诊断）

1. 朗读一段 5+ 句的话
2. 设置 → 朗读 → 「TTS 调试日志」
3. Playback 区应显示：
   ```
   prefetchHit     : N    (cache hits — inter-sentence gap eliminated)
   prefetchMiss    : 1    (sync generate — first sentence, hint missed)
   prefetchFail    : 0    (background generate errors)
   ```
4. `prefetchHit > 0` = prefetch 工作正常

### 测试 5：rate 即时生效（缓存失效验证）

1. 朗读中调语速（设置→朗读→语速滑块）
2. 下一句生效新语速（不应继续用旧语速的缓存音频）
3. TTS 调试日志中 `setSpeechRate: prefetch cache cleared` 应可见

### 测试 6：stop/skip 不残留音频

1. 朗读中点 mini control 关闭按钮
2. 立即停止，无音频残留
3. 再次朗读 → 从新位置开始，无 stale 音频

### 测试 7：startup 不被国产 ROM kill（v1.12.3 防护未破坏）

1. 冷启动 app
2. **应正常进入 library 页面**（不应闪退回桌面）

## 升级路径

直接装 v1.15.4-alpha 覆盖 v1.15.3 或更早版本。

- drift schema v15 不变
- versionCode 2016 > v1.15.3 的 2015
- 默认 TTS 引擎仍是「系统（默认）」

## Breaking Change

无。
