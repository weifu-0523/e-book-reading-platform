# v1.16.0-alpha: TTS 混合云策略（移除 SherpaOnnx + 加双云端 TTS）

**日期**：2026-07-23
**类型**：major（架构 pivot）
**前一版本**：v1.15.6-alpha
**目标版本**：v1.16.0-alpha

## 背景

v1.15.0-alpha 起投入 6 个版本（v1.15.0 → v1.15.6）验证 SherpaOnnx + MeloTTS-zh_en 离线神经 TTS POC，用户报告两个核心问题：

1. **卡顿**：句间 gap 明显。v1.15.6 的 prefetch pipeline 已极限——把 generate 推到 audio 开播后的 native 并行窗口。但 MeloTTS-zh_en 在用户荣耀手机上 **RTF ≈ 0.85**（生成时长 ≈ 0.85×播放时长），长句的 generate 时长 > 当前句播放时长 → 必有 gap。这是**模型 × 硬件**的硬限制，不是 plumbing 能修的。
2. **音质差强人意**：MeloTTS 是开源 VITS 小模型，质量上限本身有限。

**负面结论**：开源 VITS 在中端 Android 手机上做不到实时 + 高质量。POC 失败。

## 目标

切换为**混合云策略**：

- **默认**：系统 TTS（Android SelfBuilt / Desktop FlutterTts）—— 零延迟，现代设备已是神经 TTS
- **可选**：双云端 TTS provider 让用户自行选择
  - **火山引擎**（豆包语音）：国内顶级中文音质，10+ 声音
  - **阿里云 Qwen/CosyVoice**：国内主流，多模型 + 多音色
- **网络失败**：自动 fallback 到系统 TTS + SnackBar 提示用户
- **移除**：SherpaOnnx + MeloTTS-zh_en 全套代码 + 163MB 模型 + 相关 Gradle 补丁

成功标准：
- 句间无感知 gap（prefetch 命中时）
- 音质显著优于 MeloTTS，至少与系统 TTS 持平
- APK 从 264MB 减到 ~100MB
- 用户可自行在 4 个引擎间切换（system / volcengine / qwen / 残留 sherpaOnnx 选项移除）

## 总体架构

### 引擎枚举（4 → 3，删 SherpaOnnx 加 2 云端）

```dart
enum TtsEnginePreference {
  system,             // 默认：Android SelfBuilt / Desktop FlutterTts
  volcengineCloud,    // NEW：火山引擎豆包语音
  qwenCloud,          // NEW：阿里云 Qwen/CosyVoice
}
```

`sherpaOnnxMelo` 删除。持久化值变更时 `fromPersistedValue` 已有 `orElse: system` 兜底，老用户 `tts.engine=sherpaOnnxMelo` 自动降级为 system。

### 服务类层级

```
TtsService (abstract)
├── FlutterTtsServiceImpl          (desktop, 已有)
├── SelfBuiltTtsServiceImpl        (Android 自研 plugin, 已有)
├── BaseCloudTtsService (NEW abstract)
│   ├── VolcengineCloudTtsService  (NEW)
│   └── QwenCloudTtsService        (NEW)
└── [删除] SherpaOnnxTtsService
```

`BaseCloudTtsService` 共享：
- HTTP client 池（lazy 初始化）
- Prefetch cache（Sentence.text → 音频 bytes）+ `hintNext` 覆写
- `setSpeechRate` / `setVoice` 时清缓存
- `stop` 清缓存
- `onAudioStarted` callback 模式（复用 v1.15.6 验证过的 SherpaOnnx 并行 pattern）
- 错误分类（网络 / 鉴权 / 配额 / 服务端）→ 上报到 `TtsPlaybackController` 决定是否 fallback
- 音频播放（复用 `TtsAudioPlayer.awaitCompletion` Timer 模式）

子类实现 abstract 方法：
- `Future<AudioData> fetchAudio(Sentence sentence, CloudTtsCredentials cred, double rate, String voice)` — 单次 HTTP 请求
- `List<VoicePreset> get supportedVoices` — 静态声音列表
- `CloudTtsCredentials? loadCredentials()` — 从 secure storage 读

### 通用音频播放（rename + 共享）

`sherpa_onnx_audio_player.dart` → `tts_audio_player.dart`：

- `TtsAudioPlayer.play(bytes, sampleRate, {onAudioStarted})` — 接受 MP3 bytes 或 Float32（cloud 用 MP3）
- `TtsAudioPlayer.awaitCompletion(...)` — 复用 v1.15.5 Timer-based completion（不依赖 audioplayers 不可靠的 OnCompletionListener）
- 内部仍用 `audioplayers` 包

## SherpaOnnx 移除清单（Phase A）

### Dart 代码

**删除文件**：
- `app/lib/services/tts/sherpa_onnx_tts_service.dart`
- `app/lib/features/tts/utils/sherpa_onnx_benchmark.dart`

**Rename + 重构**：
- `app/lib/services/tts/sherpa_onnx_audio_player.dart` → `app/lib/services/tts/tts_audio_player.dart`
  - 改名 `SherpaOnnxAudioPlayer` → `TtsAudioPlayer`
  - `play()` 签名扩展：接受 `Uint8List mp3Bytes` 或 `Float32List samples`（重载或 union）
  - 保留 `awaitCompletion` 静态方法不动（v1.15.5 已验证）

**修改文件**：
- `app/lib/services/tts/tts_engine_preference.dart`
  - 删 `sherpaOnnxMelo` enum 值
  - 加 `volcengineCloud` + `qwenCloud`
- `app/lib/services/tts/tts_service_factory.dart`
  - 删 SherpaOnnx 分支
  - 加 volcengineCloud / qwenCloud 分支（根据 secure storage 中是否有对应 credentials 决定）
- `app/lib/features/settings/pages/tts_settings_section.dart`
  - 删 SherpaOnnx UI 逻辑（dropdown item, pitch disable, voice tile disable, _prettySherpaDebugState）
  - 加双云端引擎 dropdown item
  - 加云端 credentials + voice 选择 UI
  - 加网络失败 fallback 提示
- `app/lib/features/tts/providers/tts_playback_controller.dart`
  - hintNext 调用保留（cloud 也用）
  - 加 fallback 逻辑：service 报 network error 时切回 system 引擎 + emit 提示事件

### 测试

**删除**：
- `app/test/features/tts/services/sherpa_onnx_prefetch_test.dart`
- `app/test/services/tts/sherpa_onnx_audio_player_test.dart`
- `app/test/features/tts/utils/sherpa_onnx_benchmark_test.dart`（若存在）

**修改**：
- `app/test/features/tts/providers/tts_playback_controller_test.dart`
  - 删 SherpaOnnx mock 分支
  - 加 BaseCloudTtsService fake（用于 fallback 测试）

### pubspec.yaml

- 删 `sherpa_onnx: ^1.13.4`
- 保留 `audioplayers: ^5.2.1`（TtsAudioPlayer 仍用）
- 保留 `flutter_secure_storage`（云端 credentials 用）
- 删 3 个 MeloTTS asset 条目

### Android

- `app/android/app/build.gradle.kts`：移除 sherpa_onnx 相关 dependency
- `pub-cache` 补丁脚本（`scripts/patch-pub-cache.sh` 或类似）：移除 sherpa_onnx_android 的 compileSdk 36 sed 补丁；保留 audioplayers_android 补丁（TtsAudioPlayer 仍用）
- `AndroidManifest.xml`：INTERNET 权限已有（AI 对话用），无需新增

### 模型文件

- 删 `app/assets/tts-models/vits-melo-tts-zh_en/`（163MB，gitignored）
- 删 `.gitignore` 中 TTS model 条目（`app/assets/tts-models/**/*.onnx` 等）

### 文档

- `CHANGELOG.md`：v1.16.0-alpha 条目，标注 SherpaOnnx POC 失败 + 移除
- `docs/releases/release-notes-v1.16.0-alpha.md`：升级路径说明（老用户 sherpaOnnxMelo 自动降级 system）

## 云端 TTS 详细设计（Phase B）

### 火山引擎（豆包语音）

**API**（参考[官方文档](https://www.volcengine.com/docs/6561/1257584)，POC 用 HTTP API v1）：

- Endpoint: `https://openspeech.bytedance.com/api/v1/tts`
- Auth: `Authorization: Bearer;<token>` + `X-Api-App-Key: <appId>`
- Request body:
  ```json
  {
    "app": {"appid": "...", "token": "...", "cluster": "volcano_tts"},
    "user": {"uid": "zhiyue"},
    "audio": {"voice_type": "BV001_streaming", "speed_ratio": 1.0, "pitch_ratio": 1.0, "volume_ratio": 1.0, "encoding": "mp3", "rate": 24000},
    "request": {"reqid": "<uuid>", "text": "...", "operation": "query"}
  }
  ```
- Response: JSON `{data: "<base64 mp3>", "code": 3000, "message": "success"}`

**预置声音**（subset，UI 显示用）：
- `BV001_streaming` 通用女声
- `BV002_streaming` 通用男声
- `BV700_streaming` 灿灿（女声，活泼）
- `BV701_streaming` 擎苍（男声，沉稳）
- `BV705_streaming` 炉鼎（男声，说书）
- 后续可扩展

**Credentials**：`VolcengineTtsCredentials(appId, accessToken)`，存 `flutter_secure_storage`，key `zhiyue.tts.volcengine.{appId,token}`

### 阿里云 Qwen/CosyVoice

**API**（参考[百炼文档](https://help.aliyun.com/zh/model-studio/cosyvoice-tts-http-api)，POC 用 HTTP 非流式）：

- Endpoint: `https://dashscope.aliyuncs.com/api/v1/services/audio/tts/generate`
- Auth: `Authorization: Bearer <apiKey>`
- Request body:
  ```json
  {
    "model": "qwen-audio-3.0-tts-flash",
    "input": {
      "text": "...",
      "voice": "longxiaoxia_v2",
      "format": "mp3",
      "sample_rate": 24000,
      "rate": 1.0,
      "pitch": 1.0,
      "volume": 50
    }
  }
  ```
- Response: JSON `{output: {audio: {url: "..."}}, usage: {...}, request_id: "..."}` — 注意：返回的是 URL 不是 base64，需多一次 HTTP GET 拿音频 bytes
- 或选用 `cosyvoice-v2` 模型（同接口）

**预置声音**（参考[音色列表](https://help.aliyun.com/zh/model-studio/cosyvoice-voice-list)）：
- `longxiaoxia_v2` 龙小夏（沉稳权威女）
- `longyichen` 龙逸尘（洒脱活力男）
- `longwanjun` 龙婉君（细腻柔声女）
- `longlaobo` 龙老伯（沧桑岁月爷）
- `longxiu_v2` 龙修（博才说书男）
- `longbaizhi` 龙白芷（睿气旁白女）
- 后续可扩展

**Credentials**：`QwenTtsCredentials(apiKey, model, workspaceId?)`，存 `flutter_secure_storage`，key `zhiyue.tts.qwen.{apiKey,model}`

### Prefetch 流程（共享于 BaseCloudTtsService）

```
speakSentence(current):
  if cache has current.text:
    samples = cache[current.text]
    cache.remove(current.text)
  else:
    samples = await fetchAudio(current)  // 同步阻塞点
  await ttsAudioPlayer.play(samples, onAudioStarted: () {
    if (hintedNext != null && !prefetchInProgress && !cache.containsKey(hintedNext.text)):
      prefetchInProgress = true
      unawaited(_doPrefetch(hintedNext))
  })

_doPrefetch(sentence):
  try:
    bytes = await fetchAudio(sentence)
    cache[sentence.text] = bytes
  catch:
    prefetchFailCount++
  finally:
    prefetchInProgress = false
```

关键不变量（v1.15.6 教训）：
- prefetch 必须在 `ttsAudioPlayer.play` 返回后启动（`onAudioStarted` callback 触发）—— async function 无 await 时同步执行整个 body，FFI/HTTP 阻塞 isolate
- `setSpeechRate` / `setVoice` 变化时清 cache（roughEqual 0.001 容差，避免 float 比较误清）
- `stop` 清 cache

### 错误分类与自动 fallback

`BaseCloudTtsService.fetchAudio` 抛 `CloudTtsException`，子类区分类型：

```dart
enum CloudTtsErrorKind {
  network,       // SocketException, TimeoutException
  auth,          // 401/403
  quota,         // 429
  server,        // 5xx
  invalidRequest // 4xx other
}
```

`TtsPlaybackController` 收到 `TtsService.error` 事件时：
- 若 `error.kind == network || server`：emit `TtsFallbackEvent`，自动切回 system 引擎，重播当前句
- 其他类型：仅 SnackBar 提示用户，不 fallback（auth/quota 是配置问题，fallback 也无意义）

UI 监听 `TtsFallbackEvent` 弹 SnackBar：「网络异常，已切换至系统 TTS。可在设置中检查云端配置」。

### 多声音选择

`BaseCloudTtsService.supportedVoices` 返回 `List<VoicePreset>`：

```dart
class VoicePreset {
  final String id;          // voice_type / voice 参数
  final String displayName; // UI 显示名
  final String? description; // 特质描述
  final String gender;      // male / female
}
```

设置页：引擎选 volcengineCloud/qwenCloud 时，展开 voice dropdown（来自 supportedVoices），选中后存 secure storage `zhiyue.tts.<engine>.voice`。

## UX 设计

### 设置 → 朗读 页布局

```
┌─ TTS 引擎 ────────────────────────────────┐
│ Dropdown: [系统（默认）▼]                  │
│   - 系统（默认）                           │
│   - 火山引擎（云端）                       │
│   - 阿里云 Qwen（云端）                    │
│                                            │
│ [选中云端时展开]                           │
│ App ID: [____________________]            │
│ Access Token: [____________________]      │
│ (Qwen: API Key + Model dropdown)          │
│ 声音: [龙小夏 ▼]                           │
│ [测试连接]                                 │
│                                            │
│ ⓘ 文本将发送至 <provider> 服务器合成       │
└───────────────────────────────────────────┘

[语速 slider] [音调 slider] [音量 slider]
[声音 tile → voice list page]  (system engine only)
...
```

### 测试连接按钮

点「测试连接」→ 用当前 credentials 合成固定测试句 "你好，这是智阅朗读测试" → 播放 → 成功显示 ✓ + 实际声音，失败显示 ✗ + 错误消息。

### Fallback 提示

朗读过程中网络失败 → 顶部 SnackBar：
```
⚠ 网络异常，已切换至系统 TTS
[撤销] [去设置]
```

点「撤销」→ 切回云端（用户可能换了网络）
点「去设置」→ 跳到 TTS 设置页

## TDD 任务大纲（详细 plan 在 writing-plans 阶段生成）

### Phase A：SherpaOnnx 移除（~1 天）

| Task | Scope |
|---|---|
| A1 | rename SherpaOnnxAudioPlayer → TtsAudioPlayer（独立 commit，无行为变化） |
| A2 | TtsEnginePreference 删 sherpaOnnxMelo + 加 volcengineCloud/qwenCloud |
| A3 | tts_service_factory.dart 删 SherpaOnnx 分支 |
| A4 | tts_settings_section.dart 删 SherpaOnnx UI + 加双云端 dropdown item（仅 UI，无 impl） |
| A5 | 删 sherpa_onnx_tts_service.dart + sherpa_onnx_benchmark.dart + tests |
| A6 | pubspec 删 sherpa_onnx 依赖 + 3 个 MeloTTS asset 条目 |
| A7 | 删模型文件 + 清 .gitignore + Android Gradle 清理 |
| A8 | 验证 build：APK ~100MB，所有现有测试 pass |

### Phase B：双云端 TTS 实现（~3 天）

| Task | Scope |
|---|---|
| B1 | CloudTtsCredentials 基类 + VolcengineTtsCredentials + QwenTtsCredentials + secure storage |
| B2 | BaseCloudTtsService abstract + TtsAudioPlayer 支持 MP3 bytes 输入 |
| B3 | VolcengineCloudTtsService impl（fetchAudio + supportedVoices） |
| B4 | QwenCloudTtsService impl（fetchAudio + supportedVoices + audio URL fetch） |
| B5 | Prefetch cache + hintNext + onAudioStarted pattern（参照 v1.15.6 SherpaOnnx 测试） |
| B6 | 错误分类 + CloudTtsException + TtsPlaybackController fallback 逻辑 |
| B7 | 设置 UI：credentials 输入 + voice dropdown + 测试连接按钮 |
| B8 | Fallback SnackBar UI + TtsFallbackEvent provider |

### Phase C：发布（~0.5 天）

| Task | Scope |
|---|---|
| C1 | CHANGELOG + release notes + pubspec bump 1.16.0-alpha+2019 |
| C2 | 双端 build + marker 验证（libapp.so MD5） + Desktop + 华为同步盘分发 |
| C3 | push Gitee master + tags `v1.16.0-alpha` + `m-tts-hybrid-cloud` |

## 风险与对策

### 风险 1：用户无法独立完成 cloud provider 注册

- **风险**：火山引擎 + 阿里云都需实名 + 绑卡。开发者已有 key 可测，但用户独立申请门槛较高
- **对策**：release notes 详细列出双方申请步骤 + 试用额度（火山 20 万字/月免费、阿里云免费额度见官网）；提供详细 troubleshooting 指南
- **残余风险**：部分用户因门槛放弃，仍使用 system TTS（可接受——system TTS 是兜底）

### 风险 2：网络延迟波动

- **风险**：弱网下首句 ~2-5s 延迟，prefetch 也可能超时
- **对策**：HTTP 超时设 10s；超时触发 fallback；用户感知 SnackBar
- **残余风险**：地铁等弱网场景体验差（用户可手动切回 system）

### 风险 3：DashScope 返回音频 URL 而非 base64

- **风险**：Qwen API 返回 OSS URL，需多一次 HTTP GET。增加 ~200ms 延迟
- **对策**：fetchAudio 内部串接 API POST → URL GET → bytes，对外仍是 `Future<Uint8List>`，不暴露中间步骤
- **后续**：v1.17 切 WebSocket 流式可消除此延迟

### 风险 4：TtsAudioPlayer rename 破坏 v1.15.6 测试基线

- **风险**：rename + 重构 audio player 可能破坏 awaitCompletion 4 个测试
- **对策**：Phase A 先纯 rename（无行为变化），跑测试 pass 后再扩展签名
- **回退**：若 rename 引发大量破坏，可保留旧类名做 alias

### 风险 5： SherpaOnnx 移除漏改导致 build break

- **风险**：SherpaOnnx 引用散布在 10 个文件，漏改会编译失败
- **对策**：A4 完成后跑 `dart analyze lib/` 全扫；A5 完成后跑所有 test
- **回退**：分多个 commit，break 时 git revert 单 commit
- **构建位置**：实施在 `C:\zhiyue_build_s3` worktree（ASCII 路径，branch `s4-build`），spec 提交到 `H:\projiect\电子书阅读平台` 主仓库后 worktree pull 拿到

### 风险 6：audioplayers BytesSource(MP3) 在 Android/Honor ROM 不可靠

- **风险**：v1.15.1 发现 audioplayers onPlayerComplete 在 Honor ROM 不可靠。但 play() 本身是 OK 的。MP3 vs WAV 差异未知
- **对策**：TtsAudioPlayer 已用 Timer-based awaitCompletion 不依赖 OnCompletionListener，应能 cover。Phase C 真机验证

## Out of Scope（后续版本）

- **WebSocket 流式 TTS**：v1.17 升级，进一步降低首句延迟到 ~200ms
- **声音复刻**：用户上传 10-20s 音频生成 custom voice（CosyVoice 已支持，UI 工作量大）
- **多 provider 同时启用 + 智能切换**：当前用户单选，未来可「主用 Qwen，网络失败 fallback 火山」
- **自动选声音**：根据书的语言/类型自动选最合适声音
- **缓存策略**：相同文本 + voice + rate 的合成结果本地缓存（节省 API 调用 + 离线重播）
- **iOS 平台**：当前 SelfBuiltTts 仅 Android，iOS 留待 mobile MVP S2

## 安全与隐私

- Cloud credentials 存 `flutter_secure_storage`（Android Keystore / Windows DPAPI）
- 合成文本发送至 provider 服务器，UI 需明确提示（设置页 + 首次切换云端时弹确认 dialog）
- 不在日志中打印 credentials 或文本内容（debug 日志只打句子 index + 时长 + 字节数）
- API key 不随 WebDAV 同步（与 AiCredentials 一致策略，设备本地偏好）

## 升级路径

- drift schema 不变（v15）
- versionCode: 2019 > v1.15.6 的 2018
- 老 `tts.engine=sherpaOnnxMelo` 自动降级为 system
- 老 `tts.engine=system` 不受影响
- 用户首次打开 v1.16 → 引擎仍是 system（无 surprise），需主动去设置切换云端

## Breaking Change

- 删除 `TtsEnginePreference.sherpaOnnxMelo`（自动降级 system）
- 删除 SherpaOnnx 相关 Dart API（无外部消费者）
- SherpaOnnx 调试日志功能移除（云端 TTS 用统一 `BaseCloudTtsService.getDebugState`）

## 相关

- [[project_zhiyue_2026_07_22_v1_15_6_prefetch_parallel]]：prefetch pattern 来源
- [[project_zhiyue_2026_07_22_v1_15_5_timer_completion]]：Timer-based completion 来源
- [[project_zhiyue_2026_07_21_v1_15_sherpa_onnx_poc_release]]：SherpaOnnx POC 起点
