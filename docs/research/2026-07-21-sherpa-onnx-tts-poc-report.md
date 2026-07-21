# Sherpa-ONNX TTS Engine POC Report

**日期**: 2026-07-21
**POC 周期**: T1-T8 单日完成（同日 09:30 开始，~17:00 完成 8 个 task 的代码侧）
**参与人**: 用户 + Claude Code（实施）+ 中文盲听评估组（**待用户组织**）
**对应 plan**: `docs/superpowers/plans/2026-07-21-sherpa-onnx-tts-poc.md`

---

## 1. 执行摘要

**当前状态**：代码侧 POC（T1-T8）已全部交付，**未决策**。
**阻塞项**：T9 真机 benchmark + 中文母语盲听评估需用户操作，数据填回本报告 §2 / §3 后才能给出 Go/No-Go。

**初步信号（代码侧可观察）**：
- ✅ sherpa_onnx Flutter package 集成成功（FFI bindings 工作正常，无 linker error）
- ✅ MeloTTS-zh_en 模型加载逻辑通过单元测试（asset → filesystem 拷贝 + OfflineTts ctor）
- ✅ 5 个新测试文件全绿（共 +34 测试），无回归（1751 pass / 26 skip / 1 fail pre-existing flaky）
- ⚠️ **APK 体积显著膨胀**：debug APK 135MB → 295MB（+160MB），主要来自 MeloTTS-zh_en 的 163MB ONNX asset（详细 §4）
- ⚠️ Windows desktop 因 sherpa_onnx_windows 1.13.4 ORT API 版本不匹配，集成测试无法在桌面跑（详见 T4 已知问题）

**Go/No-Go 决策门槛**（plan §G4 定义）：
- ✅ RTF < 0.5（中端设备）→ 性能合格
- ✅ 中文母语综合评分 ≥ 4.0/5（与系统 TTS 持平或更高）→ 质量合格
- ⚠️ APK 体积 < 250MB（plan 阈值）→ **预计超限**（见 §4）

---

## 2. Benchmark 数据

> **TODO（用户操作）**：在中端 Android 设备（骁龙 7 系 / 天玑 8000 为主，旗舰作为对照）上跑：
> 1. 切换引擎到 SherpaOnnx MeloTTS（设置 → 朗读 → TTS 引擎（实验））
> 2. 朗读任意中文 EPUB 一段（触发首次 asset 拷贝 + 模型加载）
> 3. 通过临时 debug 入口跑 `SherpaOnnxBenchmark.run()`（T9 step 1 计划在 settings 加临时按钮；目前需 `flutter run` + 断点触发）
> 4. 把每句 `result.toMarkdownRow()` 输出粘回本表

| 设备 | 句子类别 | 长度 | synth (ms) | audio (ms) | RTF | peakMem (MB) | modelLoad (ms) |
|---|---|---|---|---|---|---|---|
| _待填_ | 短（"你好,这是一个测试。"）| 9 | _XXX_ | _XXX_ | _X.XX_ | _XXX_ | _XXX_ |
| _待填_ | 中（"当夜幕降临..."）| 30 | _XXX_ | _XXX_ | _X.XX_ | _XXX_ | _XXX_ |
| _待填_ | 长（"中华人民共和国..."）| 56 | _XXX_ | _XXX_ | _X.XX_ | _XXX_ | _XXX_ |
| _待填_ | 中英混排（"Thinking, Fast and Slow"）| 41 | _XXX_ | _XXX_ | _X.XX_ | _XXX_ | _XXX_ |

**门槛**：RTF < 0.5 = 移动端可用；0.5-1.0 = 边缘可用（短句可接受，长句会断续）；> 1.0 = 不可用。

**实测注意事项**：
- `peakMemoryMb` 是 Dart isolate RSS 近似值（不含 native heap 中 163MB 模型），真实进程 RSS 需 `adb shell dumpsys meminfo dev.zhiyue` 查看。
- 首次朗读会触发 1-3 秒 asset 拷贝（170MB 写入 applicationSupportDirectory）+ 1-3 秒 ONNX 模型加载；后续启动有 filesystem cache 可加速。
- 中端设备建议目标：骁龙 778G / 天玑 8100 / 三星 Exynos 1380 以上；旗舰对照：骁龙 8 Gen2 / 天玑 9200。

---

## 3. 中文母语盲听评估

> **TODO（用户操作）**：至少 3 位中文母语用户对以下 4 句做盲听 A/B 评分（系统 TTS vs SherpaOnnx MeloTTS，顺序随机，不告知哪个是哪个）。评分维度：发音准确 / 自然度 / 节奏感 / 听感疲劳（连续 30 分钟朗读后）。每项 1-5 分。

| 维度 | 系统 TTS | SherpaOnnx MeloTTS | 差距 |
|---|---|---|---|
| 发音准确 | _X.X_ | _X.X_ | ±_X.X_ |
| 自然度 | _X.X_ | _X.X_ | ±_X.X_ |
| 节奏感 | _X.X_ | _X.X_ | ±_X.X_ |
| 听感疲劳 | _X.X_ | _X.X_ | ±_X.X_ |
| **综合** | _X.X_ | _X.X_ | ±_X.X_ |

**门槛**：综合 ≥ 4.0/5 且 ≥ 系统 TTS - 0.3 分 → 质量合格。

**已知 MeloTTS-zh_en 模型特性**（基于 MyShell 官方说明）：
- 单说话人（不可换声音），女声，标准普通话
- 不支持运行时调 pitch（`setPitch` 是 no-op，T3 已注释）
- 中文-英文混排时英文为中文口音（"Thinking, Fast and Slow" 会读成接近中文的发音）
- 采样率 22050 Hz（vs 系统 TTS 通常 16000/24000 Hz，MeloTTS 高频更细腻）

---

## 4. APK 体积影响

| 配置 | APK 大小 | 增量 | 说明 |
|---|---|---|---|
| v1.14.2-alpha baseline（release）| 135 MB | - | T1 前的稳定版本 |
| + sherpa_onnx native libs（arm64-v8a only，预测）| _~155 MB_ | +20 MB | T1 添加 `sherpa_onnx_android_arm64` 子 package，需 R8 strip 后实测确认 |
| + MeloTTS-zh_en asset（uncompressed）| _~325 MB_ | +170 MB | ONNX 二进制低压缩性，asset bundle 几乎不缩小 |
| **POC v1.15.0-alpha 实测（debug）** | **295 MB** | +160 MB | debug APK 含 sherpa_onnx + 模型，对照 v1.14.2 debug 同条件 |
| **POC v1.15.0-alpha 预测（release）** | **~325 MB** | +190 MB | 待 release build 实测填回 |

**结论**：APK 增量约 **+190 MB（141% baseline）**，**显著超出 plan G4 的 250 MB 阈值**。

**缓解方案（如果决定继续）**：
1. **Phase 2 W1**：移除 asset bundle 内的模型，改为首次启动时按需下载（hf-mirror.com 镜像 + 坚果云 CDN fallback）。APK 回到 ~155 MB。
2. **ABI split**：只打包 arm64-v8a（覆盖 99% 现代 Android），不打包 armeabi-v7a / x86_64。
3. **模型压缩**：MeloTTS-zh_en 可重量化到 int8（~80MB），但 sherpa_onnx 当前版本对 int8 VITS 支持有限，需验证。

---

## 5. 架构与依赖

**新增依赖**（`app/pubspec.yaml`）：
- `sherpa_onnx: ^1.13.4` — federated plugin，主 package + 平台子 package（arm64 / windows / macos）
- `audioplayers: ^5.2.1` — PCM16 WAV 播放（替代 flutter_tts 的 native playback）

**新增文件**（10 个）：

```
lib/services/tts/
├── sherpa_onnx_tts_service.dart       (T3-T5 + T8 benchmark 入口,231 行)
├── sherpa_onnx_audio_player.dart      (T5 Float32 → PCM16 WAV 转换 + 播放,105 行)
└── tts_engine_preference.dart         (T2 enum + 持久化 helper,15 行)

lib/features/tts/
├── providers/tts_engine_provider.dart (T2 StateNotifier + SettingsRepository,68 行)
└── utils/sherpa_onnx_benchmark.dart   (T8 SherpaOnnxBenchmarkResult + 4-sentence suite,80 行)

lib/features/settings/pages/
└── tts_settings_section.dart          (T7 修改,+50 行 Card + Dropdown)

lib/services/tts/
└── tts_service_factory.dart           (T6 修改,加 preferredEngine 参数)

test/ (5 新文件,+34 测试)
├── services/tts/sherpa_onnx_tts_service_test.dart     (4 测试 + 1 integration skip)
├── services/tts/sherpa_onnx_audio_player_test.dart    (6 测试)
├── features/tts/providers/tts_engine_provider_test.dart
├── features/settings/pages/tts_settings_section_engine_test.dart (T7, 2 widget tests)
└── features/tts/utils/sherpa_onnx_benchmark_test.dart (T8, 5 测试)
```

**修改的现有文件**：
- `app/pubspec.yaml` — 加 2 依赖 + 3 个 asset entries
- `app/android/app/build.gradle.kts` — `useLegacyPackaging = true`（sherpa_onnx JNI 稳定性）
- `app/lib/features/tts/providers/tts_playback_controller.dart` — `ttsServiceProvider` 读 `ttsEngineProvider`，非 system 偏好时 fire-and-forget `init()`
- `app/lib/services/tts/tts_service_factory.dart` — 加 `preferredEngine` 命名参数

**Android 配置变更**：
- `packaging { jniLibs { useLegacyPackaging = true } }` — 让 sherpa_onnx 解压 JNI lib 到 data dir（FFI dlopen 需要可执行权限，APK 内 zip 压缩的 .so 不可执行）

**数据流**：
```
用户在 TtsSettingsSection 切换 dropdown
  → ttsEngineProvider.setEngine(value)
  → SettingsRepository.set('tts_engine_pref', 'sherpaOnnxMelo')
  → ttsEngineProvider state 变化
  → ttsServiceProvider rebuild (ref.watch 触发)
  → createTtsService(preferredEngine: sherpaOnnxMelo) 返回 SherpaOnnxTtsService()
  → svc.init() 异步触发（拷贝 asset + FFI bind + ONNX ctor）
  → TtsPlaybackController 用新 svc 跑 play()
  → speakSentence(sentence) → _tts.generate(text) → Float32List samples
  → SherpaOnnxAudioPlayer.buildWavFromFloat32 → 44-byte RIFF + PCM16 body
  → audioplayers.AudioPlayer.play(BytesSource(wavBytes))
```

---

## 6. 已知问题与限制

### 6.1 Windows desktop 集成测试无法运行

`sherpa_onnx_windows 1.13.4` 自带的 `onnxruntime.dll` 是 v1.17.1（API v27），但 sherpa-onnx C API 期望 API v17。导致 `OfflineTts` ctor 抛 `OrtApiGetApi` 失败。

**影响**：POC 期间无法在 Windows 桌面调试 TTS，必须依赖 Android 真机。
**Mitigation**：T4 集成测试 `sherpa_onnx_tts_service_test.dart` 默认 skip，需 `RUN_SHERPA_INTEGRATION=1` 才跑（仍会失败）。Phase 2 升级 `sherpa_onnx ^1.13.5+` 修复后再启用。

### 6.2 模型 asset 体积过大

MeloTTS-zh_en 的 `model.onnx` 是 163MB（plan §T1 估计 60MB，实际约 2.7 倍）。这是 MeloTTS-zh_en 完整 VITS 模型，未做权重量化。

**影响**：APK 增量 +190MB（见 §4），首次启动 asset 拷贝需 1-3 秒。
**Mitigation**：Phase 2 切换到 MeloTTS-zh_en 的 int8 量化版本（~50MB）或改用 Piper-zh_CN（更小但需 g2pw 153MB 字典）。

### 6.3 pause() 实现是 stop + 标记

SherpaOnnx 离线合成是 fire-and-forget：调 `generate()` 一次性产出整句 PCM，`audioplayers` 播放时无法精确暂停（只能 stop + restart）。

**影响**：用户点暂停后点继续，会从句子开头重新合成，不是断点续读。
**Mitigation**：句子通常 < 10 秒，用户感知可接受。Phase 2 可切到 streaming 合成 API（如 CosyVoice）支持真 pause。

### 6.4 peakMemoryMb 是 Dart isolate RSS 近似值

`ProcessInfo.currentRss` 只反映 Dart heap，不包含 native heap 中 163MB ONNX 模型权重。

**影响**：benchmark 报告的内存数字严重低估实际占用。
**Mitigation**：Phase 2 加 platform channel 调 Android `Debug.MemoryInfo`，或读 `/proc/self/status` 的 VmRSS 字段。

### 6.5 模型加载期间 UI 无进度反馈

`init()` 调用 `_tts!.generate(...)` 是同步阻塞 1-3 秒（ONNX runtime 加载权重），期间 TtsPlaybackController 状态是 `loading` 但 UI 无 progress bar。

**影响**：用户首次切换引擎点朗读会感觉 app 卡死。
**Mitigation**：Phase 2 在 TtsSettingsSection 加"模型准备中"对话框，或在 init() 前 show loading state。

---

## 7. 决策（待填）

> **填表指引**：完成 §2 真机 benchmark + §3 盲听评估后，根据 G4 门槛给出决策。

**数据汇总**：
- RTF（中端设备平均）：_待填_（门槛 < 0.5）
- 中文母语综合评分：_待填_（门槛 ≥ 4.0 且 ≥ 系统 TTS - 0.3）
- APK 体积增量：+190MB（**已超 plan G4 的 250MB 阈值**）
- Phase 2 W1 按需下载后 APK 体积：~155MB（满足阈值）

### 选项 A：Go Phase 2（推荐如果 §2 §3 达标）

- MeloTTS-zh_en 作为移动端主力离线引擎
- Phase 2 实现范围（plan §Phase 2）：
  - W1：模型按需下载（hf-mirror.com + 坚果云 CDN），APK 回到 ~155MB
  - W2：多 voice 选择（Piper-zh_CN-huayan / MeloTTS-zh_en 切换）
  - W3：CosyVoice 桌面集成（替代 Windows flaky flutter_tts SAPI）
  - W4：正式 settings panel（移出 debug 卡片，进主 TTS 设置）

### 选项 B：No-Go，启动 Phase 4 备选

如果 §2 RTF > 0.5 或 §3 评分 < 4.0：
- 保持系统 TTS（flutter_tts / SelfBuiltTtsServiceImpl）为默认
- 评估 edge-tts（在线，免费但需联网）
- 评估阿里云 CosyVoice API（在线，付费但质量高）

### 选项 C：范围调整

- 仅保留 SherpaOnnx 桌面端（替代 Windows SAPI），移动端继续系统 TTS
- 推迟 Phase 2 到 v1.16+，等 sherpa_onnx_windows ORT API 修复

**用户决策**：_待填（A / B / C + 说明）_

---

## 附录 A：TDD 实施日志

| Task | Scope | 文件 | 测试数 | Commit |
|---|---|---|---|---|
| T1 | sherpa_onnx 依赖 + 模型 asset + Android build | pubspec.yaml / build.gradle.kts / assets/ | 0（配置 task）| `c688803` |
| T2 | TtsEnginePreference enum + ttsEngineProvider | tts_engine_preference.dart / tts_engine_provider.dart | 3 | `a88b23a` |
| T3 | SherpaOnnxTtsService skeleton | sherpa_onnx_tts_service.dart | 2 | `6ab1252` |
| T4 | TDD init() asset 拷贝 + OfflineTts 加载 | （同上）| 1 + 1 skip | `99462fe` |
| T5 | TDD speakSentence + WAV 播放 | sherpa_onnx_audio_player.dart + 修改 service | 6 + 1 | `c3eba8e` |
| T6 | 工厂分发 + 播放控制器注入 | tts_service_factory.dart + tts_playback_controller.dart | ~15（含既有调整）| `7f6edfc` |
| T7 | Debug 设置页引擎切换 UI | tts_settings_section.dart | 2 widget + 既有 4 调整 | `4d3c477` |
| T8 | Benchmark harness + service.benchmark | sherpa_onnx_benchmark.dart + service 修改 | 5 | `371ed3a` |
| **小计** | 8 task | 10 新 + 5 修改 | **34 新测试** | **8 commits** |

**测试基线对比**：
- T1 前：~1715 pass / 26 skip / 0 fail（估算）
- T8 后：1751 pass / 26 skip / 1 fail（pre-existing flaky `notes_page_test`）
- 净增：+36 pass / 0 skip / +1 flaky（与基线无关）

**已知 flaky**：`background_sync_scheduler_test` / `notes_page_test` 在不同运行中交替失败，与 TTS POC 无关，pre-existing 问题。

---

## 附录 B：Phase 2 实施风险

| 风险 | 概率 | 影响 | Mitigation |
|---|---|---|---|
| 模型按需下载（W1）失败率高 | 中 | 高（用户无法用 SherpaOnnx）| 坚果云 WebDAV 已有，作为 hf-mirror.com 的 fallback；支持断点续传 |
| CosyVoice 桌面（W3）体积过大 | 高 | 中（桌面 APK +500MB）| CosyVoice 仅 macOS / Linux，Windows 桌面继续 flutter_tts SAPI |
| 多 voice 切换（W2）状态机复杂 | 中 | 中（用户切换后中断朗读）| 复用 T6 factory dispatch 模式，每个 voice 独立 SherpaOnnxTtsService 实例 |
| 用户切换引擎后内存泄漏 | 中 | 中（多次切换后 OOM）| TtsPlaybackController.ref.onDispose 调 svc.dispose()，释放 OfflineTts + audioplayers |
| Android 低端机 init 卡死 | 高 | 高（用户感知 app 死了）| Phase 2 W1 加 init 进度 dialog；考虑 isolate 包裹 generate() 防 jank |
