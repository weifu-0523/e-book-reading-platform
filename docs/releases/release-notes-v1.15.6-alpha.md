# v1.15.6-alpha

**发布日期**：2026-07-22
**类型**：hotfix（v1.15.5-alpha prefetch 同步阻塞 + setSpeechRate 误清缓存）
**上一版本**：v1.15.5-alpha

## 摘要

用户测试 v1.15.5-alpha 后报告"朗读还是很卡顿，没说一句话要停下来一会"。用户提供完整 TTS 调试日志，**决定性证据**显示两个 bug：

1. **prefetch 完全没起作用**：`prefetchHit=0/miss=5`，每次 speakSentence 都 sync generate
2. **日志串行显示**：`speakSentence → generate OK → prefetch OK → play start`，prefetch 在 play 启动前完成

## 真因 + 修复

### Bug 1（prefetch 同步阻塞 isolate）

**真因**（v1.15.4-alpha 设计缺陷）：

```dart
// v1.15.4-alpha 错误设计：
unawaited(_doPrefetch(_hintedNext!, speed));  // 在 play 之前调
await _audioPlayer.play(samples, sampleRate);
```

`unawaited` 只让 caller 不等待 future，但 Dart async function **无 await 时会同步执行整个 body**。`_doPrefetch` 内的 `tts.generate()` 是同步 FFI，**阻塞 isolate 2-5 秒**——期间 `await _audioPlayer.play(...)` 排队等 isolate。

用户日志显示：
```
[09:17:33.504] speakSentence idx=5
[09:17:34.298] generate OK in 793ms        ← N=5 generate
[09:17:37.029] prefetch OK in 2731ms       ← N=6 prefetch（同步阻塞 2.7 秒！）
[09:17:37.038] play start                   ← play 在 prefetch 完成后才启动
[09:17:38.382] timer fired                  ← speakSentence 完成
```

`generate(793ms) + prefetch(2731ms) = 3.5 秒` 串行阻塞，play 排队 2.7 秒——用户感知"读完一句等几秒"。

**修复**（v1.15.6-alpha）：

`SherpaOnnxAudioPlayer.play` 加 `onAudioStarted` callback：

```dart
Future<void> play(
  Float32List samples,
  int sampleRate, {
  void Function()? onAudioStarted,
}) async {
  ...
  await p.play(BytesSource(wavBytes));  // audio queued to native thread
  onAudioStarted?.call();                // 触发 callback
  await awaitCompletion(...);            // 等 audio 完成
}
```

`speakSentence` 把 prefetch 移到 callback 内：

```dart
await _audioPlayer.play(
  samples,
  sampleRate,
  onAudioStarted: () {
    if (_hintedNext != null && !_prefetchInProgress && _prefetchedResult == null) {
      _prefetchInProgress = true;
      unawaited(_doPrefetch(_hintedNext!, speed));  // FFI 阻塞 isolate
      // 但 audio 已在 native thread 渲染——并行！
    }
  },
);
```

修复后时间线：
```
T=0: speakSentence idx=5 start
T=793: generate(5) done
T=893: p.play returns, audio N=5 starts on native (will play 964ms)
T=893: onAudioStarted → unawaited(_doPrefetch(6))
       _doPrefetch sync runs FFI generate(6) blocking isolate 2731ms
       audio N=5 plays on native (T=893 to T=1857)
T=1857: audio N=5 finishes on native
T=3624: prefetch done, cache populated
T=3624: awaitCompletion timer (started T=893) wall-clock fired at T=2057 but isolate was blocked, dispatched at T=3624
T=3624: speakSentence(5) returns
T=3624: speakSentence(6) starts, cache HIT! → 立即 play(6) at T=3724
```

**用户感知**：audio N=5 结束 (T=1857) → audio N=6 开始 (T=3724) gap = ~1.9 秒。比 v1.15.5 的 ~2.5 秒好，但仍不完美——因为 N=6 generate 时长 (2731ms) > N=5 audio 时长 (964ms)。

### Bug 2（setSpeechRate 误清 prefetch cache）

**真因**：v1.15.4-alpha 用 `if (newRate == _rate) return` 精确相等短路，但用户日志显示每次 `speakSentence` 之间都触发 `setSpeechRate: cache cleared`（rate=0.8 未变）：

```
[09:17:38.382] audioPlayer.play returned stopped=false  ← idx=5 完成
[09:17:38.383] setSpeechRate: rate=0.8, prefetch cache cleared  ← !!! rate 没变却清缓存
```

`prefetchHit=0/miss=5` 决定性证据：每次 prefetch 结果都被 setSpeechRate 清空，下一句永远 cache miss。

**根因未完全定位**（可能 double 精度或 service rebuild 链触发），**修复用 roughEqual workaround**：

```dart
if ((newRate - _rate).abs() < 0.001) return;  // 容差 0.001
```

### 已知限制（**MeloTTS RTF 接近 1 的本质问题**）

用户真机日志的 RTF（Real-Time Factor = generate 时长 / audio 时长）：

| 句子 | generate (ms) | audio (ms) | RTF |
|---|---|---|---|
| idx=5 (7 chars) | 793 | 964 | 0.82 |
| idx=6 (18 chars) | 1725 | 2009 | 0.86 |
| idx=7 (31 chars) | 2482 | 2902 | 0.86 |
| idx=15 (39 chars) | 3214 | 3878 | 0.83 |
| idx=16 (55 chars) | 4881 | 5526 | 0.88 |

**RTF ≈ 0.85**，接近 1。意味着 MeloTTS-zh_en 在用户荣耀手机上**勉强实时**，prefetch 时长经常 > 当前句 audio 时长——即使 prefetch 真正并行，gap 仍会存在。

**根本解决方案**（超出本 hotfix 范围）：
- (a) **更快的模型**：Piper zh（更轻量，RTF 更低）或更小的 VITS
- (b) **Isolate.run**：把 generate 放到 worker isolate（需重构 sherpa_onnx FFI 绑定，每个 isolate 加载自己的 OfflineTts 实例，约 1-2 周工作量）
- (c) **接受现状**：MeloTTS POC 在中端手机上 RTF 0.85 = 可用但不丝滑

如果用户测试 v1.15.6-alpha 后觉得体验仍不可接受，建议切回系统 TTS（荣耀自带 TTS 已是不错的神经 TTS）。

## 测试步骤（用户）

### 测试 1：句间平滑改善（核心修复验证）

1. 装 v1.15.6-alpha APK
2. 切到 SherpaOnnx 引擎
3. 完全关闭 app，重新打开
4. 长按选中一段多句文字，点选区弹片的「朗读」按钮
5. **应感觉到句间 gap 比 v1.15.5-alpha 小**（v1.15.5 是 2.5-3 秒，v1.15.6 应 1-2 秒）
6. **完全不卡顿**不可能（MeloTTS RTF 限制，见"已知限制"）

### 测试 2：TTS 调试日志确认 prefetch 命中

1. 朗读一段 5+ 句的话
2. 设置 → 朗读 → 「TTS 调试日志」
3. Playback 区应显示：
   ```
   prefetchHit     : N    ← v1.15.5 是 0，v1.15.6 应 > 0
   prefetchMiss    : 1    ← 首句必 miss（无 hint）
   prefetchFail    : 0
   ```
4. **`prefetchHit > 0` = prefetch 真正命中**（修复生效）
5. Service debugLogs 应显示 `onAudioStarted: kicking off prefetch for next sentence` 而不是 speakSentence 后立即 `setSpeechRate: cache cleared`

### 测试 3：setSpeechRate 误清缓存修复验证

1. 朗读多句后看 Service debugLogs
2. **`setSpeechRate: cache cleared` 字样应只出现一次**（首次设置 rate 时），后续 speakSentence 不应再清缓存
3. 如果每次都还出现，说明 roughEqual 没生效（可能根因更深），反馈给开发者

### 测试 4：stop 立即生效（regression）

1. 朗读中点 mini control 关闭按钮
2. 立即停止，日志应显示 `state=stopped (early termination)`
3. 再次朗读 → 从新位置开始

## 升级路径

直接装 v1.15.6-alpha 覆盖 v1.15.5 或更早版本。

- drift schema v15 不变
- versionCode 2018 > v1.15.5 的 2017
- 默认 TTS 引擎仍是「系统（默认）」

## Breaking Change

无。
