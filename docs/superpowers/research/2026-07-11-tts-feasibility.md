# TTS（Text-to-Speech）可行性调研

> 调研日期：2026-07-11
> 触发：S3 plan WS5 / Task 22
> 目标：为 S4+ TTS 功能（AI 响应朗读、EPUB 章节朗读、高亮跟随、后台播放）提供技术决策依据
> 结论摘要：**Phase 1（AI 响应朗读）技术成熟、低风险，建议 S4.1 立即实现**；Phase 2（EPUB 章节朗读 + 高亮跟随）技术可行但工作量大（4-6 周），建议 S4.2 单独立项；Phase 3（后台播放 + 锁屏）需要 `audio_service` 集成，移动端额外 1-2 周，桌面端不适用。

---

## 1. Plugin 选型对比

### 1.1 主候选：`flutter_tts`

[pub.dev/packages/flutter_tts](https://pub.dev/packages/flutter_tts) 是 Flutter 生态最成熟的 TTS 插件，由 dlutton 维护，跨平台覆盖最广：

| 平台 | 后端 | 备注 |
|---|---|---|
| Android | `android.speech.tts.TextToSpeech`（系统框架） | minSdk 21+；onRangeStart 需 API 26+ |
| iOS / macOS | `AVSpeechSynthesizer`（AVFoundation） | iOS 7+ 支持 speech marks |
| Windows | SAPI（`ISpVoice` COM 接口） | Windows 10/11 自带 |
| Web | 浏览器 Web Speech API | 仅 default voice engine 可靠 |
| Linux | ❌ 不支持 | |

**核心 API**（我们用得到的）：
- `speak(String text)` / `stop()` / `pause()`（pause 仅 iOS）
- `setLanguage(String locale)` —— 例如 `zh-CN`、`en-US`
- `setSpeechRate(double)` / `setPitch(double)` / `setVolume(double)`
- `setVoice(Map)` —— 选具体 voice（同语言可能有多个）
- `awaitSpeakCompletion(bool)` —— await `speak()` 直到播完
- `setInitHandler` / `setCompletionHandler` / `setErrorHandler` / `setProgressHandler` / `setStartHandler`

**进度回调**：`setProgressHandler` 报告 0.0-1.0 的进度；Android 的 `onRangeStart`（API 26+）和 iOS 的 speech marks 报告当前正在朗读的字符 offset（`start`/`end`），这是高亮跟随的基础（见 §3）。

### 1.2 替代方案

| Plugin | 适用场景 | 不适用本项目的理由 |
|---|---|---|
| `text_to_speech`（另一个） | 跨平台基础 TTS | API 不如 flutter_tts 完整，无 speech marks |
| `openai_tts` | OpenAI 云端 TTS（含 streaming） | 需联网 + API key + 按字符付费；与 "本地优先 + 无新增订阅" 项目原则冲突 |
| `deepgram_speech_to_text` | Deepgram STT + TTS | 同上，云端付费 |
| `alan_voice` | AI 语音助手 SDK | 是托管 SDK，绑定 vendor，不适合开源 |
| Readium native bridge | 高质量 EPUB CFI + TTS 集成 | 需要 Swift/Kotlin 桥接，违背 "同代码库 + Dart 优先" 原则（参考 [[project_zhiyue_mobile_mvp_kickoff]]） |

**结论**：`flutter_tts` 是当前最优选择。所有替代方案要么功能不足，要么违背项目原则（云端付费 / 重桥接）。

### 1.3 已知坑

- **Samsung 设备 TTS 引擎碎片化**：One UI 7 / Android 15 起，Samsung 私有 TTS 引擎限制仅 Samsung 自家应用可用（参考 Tecarta support 文档）。第三方 app 必须依赖 Google TTS 引擎或用户手动切换。**对智阅的影响**：用户首次启用 TTS 时需要检测可用引擎，引导切换到 Google TTS。
- **Chinese voice 质量**：系统自带中文 voice 在 Android 上质量参差（取决于引擎版本），Windows 中文 voice 默认安装但不一定启用。
- **Web 平台 voice engine 限制**：speech marks 仅在 default voice engine 下可靠。

---

## 2. 使用场景对比

智阅目前规划三类 TTS 场景，复杂度递增：

### 2.1 AI 响应朗读（简单 —— Phase 1）

**输入**：`ChatMessage.content`（已经是纯文本或 markdown）。
**输出**：朗读整条消息，无定位需求。
**实现要点**：
- 在 `AiMessageList` 的 `_MessageBubble` 上加长按菜单 → "朗读"。
- 复用现有 `SelectionArea` 的长按手势冲突需要评估（可能要在 bubble 外层包一层 `GestureDetector` 并优先级调试）。
- 流式朗读：可选 —— 在 stream 完成后启动朗读，或边流边读（更复杂，需要 sentence-boundary 检测）。**建议先做"读完再朗读"**，简单可靠。

**预估工期**：3-5 天（含测试 + UX 调整）。

### 2.2 EPUB 章节朗读（中等 —— Phase 2）

**输入**：当前章节的纯文本（已有 `chapterTextProvider.get(filePath, chapterIndex)`）。
**输出**：顺序朗读整章，允许跳过/重听。
**实现要点**：
- 句子切分：用 `intl` 或简单正则按 `。！？.!?` 切句，避免一次 `speak()` 太长导致 onRangeStart 精度下降。
- 章节边界：朗读到章节末尾时，提示用户"继续下一章"（参考 M2.2 的 auto-chapter-end UX 模式 [[project_zhiyue_m2_2_complete]]）。
- 与翻页/滚动联动：朗读时不强制翻页，但提供"跳到当前朗读位置"按钮。

**预估工期**：1-2 周。

### 2.3 PDF 章节朗读（**不推荐**）

PDF 文本提取受扫描质量影响（参考 [[project_zhiyue_m4_complete]] 的扫描降级策略）。即便有文本层，阅读顺序也可能错乱（多栏、表格、图文混排）。

**建议**：PDF TTS 列为"实验性"功能，仅在用户手动选择文本时朗读选中片段（复用 selection toolbar）。

---

## 3. 高亮跟随可行性

### 3.1 技术原理

TTS 朗读时，引擎通过 `onRangeStart(utteranceId, start, end, frame)` 回调报告当前正在朗读的字符区间。把这些区间映射回 DOM 位置 → 生成 highlight → 滚动到 highlight。

### 3.2 EPUB 的难点：CFI 映射

EPUB 用 CFI（Canonical Fragment Identifier）定位，但 TTS 只认纯文本 offset。两者之间需要一个 offset table：

```
DOM 节点顺序：<p>hello</p><p>world</p>
TTS 输入文本："hello world"（拼接时插入空格）
offset table:
  TTS offset 0-4  → DOM 第1个 <p> 的 text node 0-4
  TTS offset 6-10 → DOM 第2个 <p> 的 text node 0-4
```

难点：
1. **文本归一化**：HTML 实体、空白折叠、连字（ligature）会让 TTS 文本与 DOM 文本不对齐。
2. **图片/表格**：`<img alt="...">` 的 alt 文本要不要朗读？表格的阅读顺序？
3. **跨段落 highlight**：highlight 要跨越多个 text node，需要 Range API（Web）或 DOM 范围抽象。

### 3.3 智阅的现状

智阅的 EPUB 渲染走的是 `epubx` + 自研渲染层（参考 [[project_zhiyue_m2_pivot_epubx]]），CFI 支持已经存在（高亮功能 [[project_zhiyue_m3_2_complete]]）。**复用现有 CFI 基础设施是关键**。

### 3.4 实现路径

1. **Sentence-level highlight（粗粒度）**：把章节按句切分，按句 `speak()`，在 `onStart` 回调里 highlight 整句。**1-2 周，精度可接受**。
2. **Word-level highlight（细粒度）**：用 `onRangeStart` 的 char offset 反查 offset table，找到对应的 word-level CFI range。**2-3 周，需要 offset table 构建 + 测试**。

**建议**：Phase 2 先做 sentence-level，验证 UX；如果用户反馈需要 word-level，再做 Phase 2.5 升级。

---

## 4. 后台播放 + 锁屏控制

### 4.1 移动端（Android / iOS）

**架构**：`audio_service` 包裹 TTS 渲染逻辑，作为 background task 运行。audio_service 官方 README 明确把 TTS reader 列为典型用例：

> "a Text-to-speech reader app might implement these callbacks using flutter_tts to render the speech, while a music player app might implement these callbacks using just_audio to render the audio"

**关键点**：
- **不要用 `just_audio`**：TTS 自己产生音频流，不需要 audio player。直接在 `AudioHandler` 的回调里调 `flutter_tts.speak()`。
- **后台执行**：Android 需要 foreground service 类型 `mediaPlayback`；iOS 需要 `UIBackgroundModes: audio`。
- **锁屏控制**：play/pause/stop/seek 都通过 `AudioHandler` 回调暴露，系统会自动渲染锁屏控件。
- **MediaItem metadata**：把章节标题 / 书名作为 `MediaItem` 传给 audio_service，锁屏会显示。

**预估工期**：移动端 1-2 周（含 platform manifest 改动 + 测试）。

### 4.2 桌面端（Windows / macOS）

桌面没有"锁屏媒体控件"的概念。Windows 有 SystemMediaTransportControls（SMTC），macOS 有 NSNowPlayingInfoCenter，但用户预期不同（桌面用户更习惯在 app 内控制）。

**建议**：桌面端**不做 audio_service 集成**，TTS 仅在 app 内控制。这与项目"桌面稳定锚点 desktop-stable-pre-mobile"原则一致（参考 [[project_zhiyue_mobile_mvp_kickoff]]）—— 不为移动-only 特性干扰桌面 UX。

### 4.3 已知陷阱

- **audio_session 冲突**：TTS 启动时若其他 app 在播放音乐，需要正确处理 audio focus 抢占。`audio_session` 包提供 `setActive(true/false)` API。
- **混合音频**：如果未来加入背景音乐功能（BGM while reading），需要混音器逻辑。**当前不在 scope**。
- **Doze / 后台限制**：Android 8+ 对后台 service 有限制，foreground notification 必须可见。用户可能反感"正在朗读"的持久通知，需要 UX 文案优化。

---

## 5. 平台限制

### 5.1 Android

- **minSdk**：flutter_tts 要 21+，我们项目已满足。
- **onRangeStart API level**：26+（Android 8.0+）。低于 26 的设备无 word-level highlight。市场占有率：Android 8.0 以下 < 5%（2026 stat），可接受降级。
- **TTS 引擎碎片化**：见 §1.3。Samsung / Huawei / Xiaomi 定制 ROM 可能预装非 Google 引擎，质量参差。需要"切换 TTS 引擎"引导。
- **后台限制**：Doze 模式下，未播放音频时系统可能冻结 service。需要保持 foreground notification。
- **中文 voice 安装**：用户首次使用 zh-CN 需要下载 voice data，flutter_tts 提供 `isLanguageInstalled` 检测。

### 5.2 iOS

- **AVSpeechSynthesizer**：iOS 7+，全部现代设备支持。
- **后台音频**：需 `UIBackgroundModes: audio`。App Store 审核要求 audio 功能是 app 主要用途之一，否则可能被拒。**智阅作为阅读 app，TTS 是辅助功能，审核可能存疑** —— 需要在审核说明里强调 TTS 是核心无障碍能力。
- **中文 voice**：iOS 自带普通话 voice（Ting-Ting），质量比 Android 默认好。
- **Silent mode**：iPhone 物理静音开关不影响 AVSpeechSynthesizer（与 AVAudioPlayer 行为不同），无需特殊处理。

### 5.3 Windows

- **SAPI**：Windows 10/11 自带 Microsoft语音平台，默认安装中文（HuiHui、Kangkang）和英文（Zira、David）voice。
- **voice 安装位置**：Settings → Time & Language → Speech → Add voices。用户可能未启用非默认 voice，需要在 app 内提示。
- **后台 / 锁屏**：桌面无意义，不做。
- **Windows 7**：项目不支持（最低 Windows 10），无问题。

### 5.4 macOS / Linux / Web

- **macOS**：与 iOS 共享 AVSpeechSynthesizer，技术上可行但用户基数小（参考 [[project_zhiyue_mobile_mvp_kickoff]] 的 iOS scaffold-only 决策），**延后**。
- **Linux**：flutter_tts 不支持，**不实现**。
- **Web**：Web Speech API 受浏览器和 default voice engine 限制，质量不可控，**不实现**。

---

## 6. S4 实现推荐路径

### Phase 1：AI 响应朗读（S4.1，3-5 天）

**目标**：验证 TTS UX 假设，最小代价交付。

**Scope**：
- 添加 `flutter_tts: ^4.x` 依赖。
- 抽象 `TtsService` 接口（`speak`、`stop`、`isSpeaking`、progress stream）—— 便于后续 Phase 2 扩展。
- 在 `AiMessageList._MessageBubble` 长按菜单加"朗读"项。
- 在 `AiInputComposer` 加全局"停止朗读"按钮（仅当 `isSpeaking` 时显示）。
- 设置页加"语音 / 语速 / 音量"基础调节。

**不做**：
- EPUB TTS（留 Phase 2）。
- 后台 / 锁屏（留 Phase 3）。
- Word-level highlight（留 Phase 2.5）。

**验收标准**：
- AI 响应可一键朗读、可停止。
- 切换语言/voice 后能立即生效。
- 桌面 + Android 真机手动测试通过。

### Phase 2：EPUB 章节朗读 + sentence-level highlight（S4.2，2-3 周）

**目标**：章节级沉浸式朗读。

**Scope**：
- 在 reader_scaffold 工具栏加"朗读本章"按钮。
- 复用 `chapterTextProvider` 获取章节文本。
- Sentence-level 切分 + sentence-level highlight（粗粒度，复用 highlight 基础设施）。
- 章节结束提示（复用 M2.2 auto-chapter-end UX 模式）。
- PDF 朗读：仅手动选中文本时通过 selection toolbar 触发。

**风险**：
- `epubx` 渲染层与 highlight 联动需要验证（paged vs scroll 模式）。
- 长章节内存 / 性能（章节文本可能几十 KB）。

### Phase 3：后台播放 + 锁屏（S4.3，移动端 1-2 周）

**目标**：移动端后台朗读 + 锁屏控制。

**Scope**：
- 集成 `audio_service`，把 `TtsService` 包成 `AudioHandler`。
- Android manifest 加 foreground service + mediaPlayback。
- iOS Info.plist 加 `UIBackgroundModes: audio`。
- 桌面端**不集成**（保持 app 内控制）。

**风险**：
- iOS App Store 审核可能要求说明 audio 后台的必要性。
- Foreground notification UX 优化。

### Phase 2.5（可选）：Word-level highlight（1-2 周）

仅当用户反馈 sentence-level 不够精准时启动。需要构建 offset table + 测试 DOM 文本归一化边界情况。

---

## 附录：参考资料

- [flutter_tts on pub.dev](https://pub.dev/packages/flutter_tts)
- [flutter_tts GitHub: onRangeStart support #41](https://github.com/dlutton/flutter_tts/issues/41)
- [Android onRangeStart docs](https://stackoverflow.com/questions/44461533/android-o-new-texttospeech-onrangestart-callback)
- [audio_service on pub.dev](https://pub.dev/packages/audio_service)（README 明确提到 TTS reader 用例）
- [Background audio playback guide](https://vibe-studio.ai/insights/background-audio-playback-and-media-controls-in-flutter)
- [Android 15 Samsung TTS restriction](https://support.tecarta.com/hc/en-us/articles/41616767343387-Device-Text-to-Speech-Changes-on-Android-15-One-UI-7)
- [Mastering Android TextToSpeech](https://proandroiddev.com/mastering-android-text-to-speech-the-ultimate-guide-8932b21afcda)

---

## 决策追踪

- **2026-07-11**：调研完成，确认 Phase 1 技术成熟可立即推进 S4.1。Phase 2/3 工作量明确，待 Phase 1 用户反馈后启动。
- **待决**：是否在 Phase 1 同时引入 `audio_session`（处理音频焦点抢占）？建议**引入**——成本低（1 个 pub 依赖 + 几行 init），避免后续 Phase 3 时再加要改初始化路径。
- **待决**：Phase 1 是否支持中文长文本朗读（章节级）？建议**不支持**，仅做 AI 响应（单条 < 2000 字）。长文本朗读的内存、暂停、恢复留给 Phase 2。
