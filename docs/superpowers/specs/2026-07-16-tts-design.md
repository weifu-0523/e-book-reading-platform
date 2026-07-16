# TTS 朗读功能设计（P1 + P2 + P3）

**日期**：2026-07-16
**目标版本**：v1.12.0-alpha（预期）
**前置**：v1.11.9-alpha（M2.5+ Bug Batch 5）
**调研文档**：`docs/superpowers/research/2026-07-11-tts-feasibility.md`
**作者**：weifu0523 + Claude（subagent-driven）

## 背景

调研报告 `2026-07-11-tts-feasibility.md` 已确认 `flutter_tts` 为最优技术选型，并把 TTS 能力分为三个递进的 Phase：

- **Phase 1**：AI 响应朗读（最小可用，3-5 天）
- **Phase 2**：EPUB 章节朗读 + 句级高亮跟随（2-3 周）
- **Phase 3**：移动端后台播放 + 锁屏控制（1-2 周）

用户在 2026-07-16 brainstorming 中决定一次性交付三个 Phase，对应版本号 v1.12.0-alpha。

## 用户决策（2026-07-16 AskUserQuestion）

| 决策点 | 选择 | 备注 |
|---|---|---|
| Scope | **P1 + P2 + P3 全功能** | 4-6 周工期，单次交付 |
| EPUB 朗读 UX | **A. 自动跟读（TTS 驱动翻页）** | 沉浸式；paged 模式触发翻页，scroll 模式触发滚动 |
| 章节边界 | **C. 设置可选** | 默认「连续朗读」（A），可切换为「章末询问」（B） |
| P3 平台范围 | **A. 仅移动端后台/锁屏** | 桌面仅 app 内控制；与 `desktop-stable-pre-mobile` 一致 |
| Voice/语言 | **A. 自动跟随内容语言** | 按当前句子的 Unicode 主语言决定 locale，整段混排不切换 |

## 范围

### Phase 1：AI 响应朗读

- `flutter_tts: ^4.x` 依赖
- `TtsService` 接口（speak / stop / pause / progress stream）
- `AiMessageBubble` 长按菜单「朗读」项
- `AiInputComposer` 上方迷你控件条（上一句/暂停/下一句/停止/关闭）
- 设置页「朗读」分区（语速/音调/音量/章节边界/测试朗读）

### Phase 2：EPUB / Markdown / TXT 章节朗读

> **关键洞察**：markdown 和 txt 在 `reader_engine_provider.dart` 中已被转成 EPUB 内部格式（同样走 `ConcreteEpubReaderEngine(renderer: EpubxRenderer())`）。因此 EPUB 朗读的代码路径自动覆盖这两种格式，无需额外工作。本节以下统称「章节朗读」。

- reader_scaffold 工具栏「朗读本章」按钮
- `SentenceSegmenter`（按中英标点 + 段落边界切句）
- CFI 映射 + auto-page-flip（paged）/ auto-scroll（scroll）
- 临时 highlight overlay（半透明金黄 `Color(0x66FFD700)`，不写数据库）
- 章节边界处理（连续朗读 / 章末询问，设置可切换）
- `books.last_tts_position` schema v15 新列，跨设备同步
- PDF 选中文本 → selection toolbar「朗读选中」（无翻页联动）

### Phase 3：移动端后台播放 + 锁屏

- `audio_service: ^0.18` 集成
- `ZhiYueAudioHandler extends AudioHandler`，桥接 `TtsService`
- Android `FOREGROUND_SERVICE_MEDIA_PLAYBACK` 权限 + manifest service
- iOS `UIBackgroundModes: audio`
- `MediaItem` metadata（书名/章名/封面/句号）
- `audio_session` 处理来电/抢占/拔耳机
- Samsung TTS 引擎检测与引导

## 非目标

- Word-level highlight（P2.5，待 P2 用户反馈）
- 流式 TTS（AI 边 stream 边读，sentence boundary 检测成本高）
- 多角色朗读（小说角色切换）
- SSML 标记（`<break>` / `<emphasis>`）
- macOS / Linux / Web（项目目前不支持）
- 桌面端锁屏控件 / 系统媒体 transport controls
- iOS 自动续读（与 Android 一致，重启不自动续读）

---

## 1. 架构分层

```
┌─────────────────────────────────────────────────────────┐
│  UI 层                                                   │
│  ┌──────────────────┐  ┌─────────────────────────────┐  │
│  │ AiMessageBubble   │  │ ReaderScaffold 工具栏       │  │
│  │ 长按→朗读          │  │ 朗读本章 + 迷你控件         │  │
│  └────────┬─────────┘  └────────────┬────────────────┘  │
│           │                          │                    │
│           ▼                          ▼                    │
│  ┌──────────────────────────────────────────────────┐   │
│  │  TtsPlaybackController (Riverpod)                │   │
│  │  ├─ state: idle/loading/speaking/paused/error    │   │
│  │  ├─ current session: {bookId, chapterIdx, sentIdx}│   │
│  │  ├─ queue: List<Sentence>                        │   │
│  │  └─ methods: play(scope) / pause / resume / stop │   │
│  │           / skipNext / skipPrev / seekToSentence │   │
│  └────────┬─────────────────────────┬───────────────┘   │
│           ▼                         ▼                    │
│  ┌──────────────────────┐  ┌──────────────────────┐    │
│  │ TtsService            │  │ AudioHandlerAdapter  │    │
│  │ (flutter_tts 包装)    │  │ (仅移动端，P3)        │    │
│  │ - speak/stop/pause    │  │ audio_service 桥接    │    │
│  │ - progress stream     │  │ 锁屏控件 + 后台      │    │
│  │ - voice auto-pick     │  │ foreground service   │    │
│  └──────────────────────┘  └──────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### 1.1 关键设计点

- **三层解耦**：TtsService 是纯技术层（flutter_tts 包装），TtsPlaybackController 是业务状态机，AudioHandlerAdapter 是平台条件层。P1 时只实现前两层，P3 时加 Adapter 不影响 P1/P2 代码。
- **sentence 队列模型**：上层提交一个 scope（「AI message」或「章节」），Controller 切句入队，逐句 `speak()`。`onRangeStart` 回调驱动句子级 highlight + 翻页。
- **AudioHandlerAdapter 仅移动端**：通过 `PlatformInfo.isMobile` gate，桌面端 TtsPlaybackController 直接调 TtsService，不经过 Adapter。
- **状态机**：`idle → loading → speaking ⇄ paused → stopped`，错误进 `error` 带 retry。

### 1.2 状态机

```
                         ┌──────────┐
                         │  idle    │ ◀──── initial
                         └────┬─────┘
                              │ play(scope)
                              ▼
                         ┌──────────┐
              ┌──────────│ loading  │
              │          └────┬─────┘
              │ error          │ sentences enqueued
              ▼               ▼
         ┌──────────┐    ┌──────────┐
         │  error   │◀──│ speaking │──┐
         └────┬─────┘    └────┬─────┘  │ pause
              │ retry          │       ▼
              └──────────▶ ┌──────────┐
                            │  paused  │
                            └────┬─────┘
                                 │ resume
                                 ▼
                            ┌──────────┐
                            │ speaking │
                            └────┬─────┘
                                 │ stop / queue exhausted
                                 ▼
                            ┌──────────┐
                            │  idle    │
                            └──────────┘
```

---

## 2. Phase 1：AI 响应朗读

### 2.1 触发点

`AiMessageBubble` 长按菜单加「朗读」项，与现有「复制」「选中原文」并列。流式消息等 stream 完成后才出现该菜单项（避免朗读半句话）。

### 2.2 控制 UX

- 启动朗读后，`AiInputComposer` 上方出现迷你控件条：`⏮ 上一句  ⏸/▶  ⏭ 下一句  ⏹ 停止  ✕ 关闭`。
- 同时其他 message bubble 的「朗读」入口禁用（同时只允许一路 TTS 会话）。
- 用户切换页面/章节时，AI 朗读**自动暂停**（不停止，状态保留 5 分钟；5 分钟内回来可 resume，超时则丢弃）。

### 2.3 TtsService 接口

```dart
abstract class TtsService {
  Stream<TtsState> get state;
  Stream<TtsProgress> get progress;
  Stream<String> get error;

  Future<void> init();
  Future<void> speakSentence(Sentence sentence);
  Future<void> stop();
  Future<void> pause();  // 仅 iOS 真暂停；其他平台用 stop + 记录 sentenceIdx
  Future<void> setSpeechRate(double rate);  // -1.0 ~ 1.0，默认 0.0
  Future<void> setPitch(double pitch);      // 0.5 ~ 2.0，默认 1.0
  Future<void> setVolume(double volume);    // 0.0 ~ 1.0，默认 1.0
  Future<bool> isLanguageAvailable(String locale);
  Future<bool> isLanguageInstalled(String locale);
  Future<List<Map<String, dynamic>>> getAvailableVoices();
  Future<void> dispose();
}

class FlutterTtsServiceImpl implements TtsService {
  final FlutterTts _tts = FlutterTts();
  // init 时挂载 setInitHandler / setStartHandler / setCompletionHandler
  //     / setProgressHandler / setErrorHandler
  // setAwaitSpeakCompletion(true) 让 speak() await until completion
}
```

### 2.4 Locale 自动选择

使用 Unicode 范围启发式：

```dart
String detectLocale(String text) {
  final cjkCount = text.runes.where((c) =>
      (c >= 0x4E00 && c <= 0x9FFF) ||  // CJK Unified Ideographs
      (c >= 0x3400 && c <= 0x4DBF)).length;  // CJK Extension A
  if (cjkCount > text.length * 0.3) return 'zh-CN';
  return 'en-US';  // fallback
}
```

- 按当前句子的主语言决定 locale
- 整段混排不切换（避免每句切换 locale 导致 engine 重启卡顿）
- AI 响应常见中英混排，按句检测足够

### 2.5 设置页新增「朗读」分区（SettingsPage）

| 项 | 类型 | 默认 | 备注 |
|---|---|---|---|
| 语速 | slider 0.0-1.0 | 0.5 | 显示 0~1，内部映射到 flutter_tts 的 -1~1 |
| 音调 | slider 0.5-2.0 | 1.0 | |
| 音量 | slider 0.0-1.0 | 1.0 | |
| 章节边界行为 | segmented: 连续 / 章末询问 | 连续 | P2 用，但放这里 |
| 测试朗读 | button | — | 朗读固定示例 |

### 2.6 验收标准

- AI 单条消息可朗读、可暂停、可停止。
- 切换语速后立即生效（下一句开始用新值，不打断当前句）。
- 桌面 + Android 真机通过。
- 切走再回来（5 分钟内）能 resume。

---

## 3. Phase 2：EPUB / Markdown / TXT 章节朗读

### 3.1 触发点

reader_scaffold 工具栏（顶部 chrome）新增「朗读」按钮 ▶。点击启动当前章节朗读。启动后 chrome 切换为「朗读控件条」：`⏮ ⏸/▶ ⏭ ⏹ ✕` + 当前句子预览（一行 ellipsis）。

### 3.2 句子切分（SentenceSegmenter）

```dart
class Sentence {
  final String text;
  final String locale;
  final CfiRange cfiRange;  // startCfi + endCfi
  final int charStart;      // 在章节纯文本中的偏移
  final int charEnd;
}

class SentenceSegmenter {
  static List<Sentence> split({
    required String text,
    required List<CFIBoundary> paragraphBoundaries,
  }) {
    // 按 [。！？.!?；;] + lookahead 空白/段落结束 切
    // 中文用 。！？；，英文用 .!?;"
    // 段落边界强制切（即使没有标点）
    // 每个 Sentence 继承所在段落的 CFI range，按 char offset 拆出 startCfi/endCfi
  }
}
```

**关键约束**：
- 一句不超过 200 字（超过强切，避免 onRangeStart 精度下降）
- 图片 alt、表格 cell 不切句，作为独立 Sentence 朗读
- 标点符号本身不朗读（flutter_tts 引擎自动跳过）

### 3.3 自动跟读（paged 模式）

```
TTS 朗读到 Sentence #N：
  1. onStart 回调触发 → 拿 sentence.cfiRange.startCfi
  2. ReaderEngine.locatorToPage(startCfi) → targetPage
  3. if targetPage != currentPage: triggerPageFlip(targetPage)
  4. flip 完成后 → highlightOverlay.show(sentence.cfiRange)
  5. 句子朗读完成 → 推进 #N+1
```

**scroll 模式**：不做翻页，改为 `scrollController.animateTo(startCfi 像素位置)`。

**句子跨页**：CFI range 横跨两页时，先翻到 startCfi 所在页，highlight 在 startCfi 所在页部分显示；朗读推进到下页部分时自动翻页。

### 3.4 Highlight overlay

复用现有 highlight 基础设施（M3.2），但用**临时色**：
- `Color(0x66FFD700)` 半透明金黄
- 朗读完毕或推进到下一句后自动清除上一句的 overlay
- 不写入数据库（区别于用户高亮）
- 命名：`ttsHighlight`，与用户高亮的 5 色独立

### 3.5 章节边界

**默认「连续朗读」（A）**：
- 当前章最后一句 complete → 加载下一章 → 继续 speak 第一句
- 加载失败（解析错误、文件损坏）→ 提示「下一章加载失败，已暂停」→ state = paused

**可选「章末询问」（B，设置切换）**：
- 当前章最后一句 complete → 弹 `SnackBar`「继续听下一章？」+ 「继续/停止」按钮
- 用户选「继续」→ 加载下一章
- 用户选「停止」→ state = idle，清除 queue

### 3.6 状态恢复

- TTS 会话**不持久化**（重启 app 不续读，避免大段音频上下文 resume 难）。
- 但**当前位置**（chapterIdx + sentenceIdx）写入 `books.last_tts_position`（schema v15 新增列）。
- 用户下次打开 reader 显示「上次朗读到：第 N 章 M 句」提示（5 秒自动消失），点击可跳回。
- 跨设备同步（M2.8 sync 体系）：在另一台设备打开同一书也能看到提示。

### 3.7 与现有 reader 交互

| 场景 | 行为 |
|---|---|
| TTS 朗读中，用户手动翻页 | TTS 暂停（不等句子结束），弹出迷你控件条让用户决定 resume 还是 stop |
| TTS 朗读中，用户手动加高亮 | 允许，不暂停 TTS |
| TTS 朗读中，用户打开设置/笔记 drawer | 不影响 TTS，drawer 关闭后控件条仍在 |
| TTS 朗读中，app 切后台（桌面） | 桌面端继续朗读（用户能听见），回来 UI 一致 |
| TTS 朗读中，app 切后台（移动） | P3 走 audio_service 后台播放（见 §4） |

### 3.8 PDF 处理

PDF **不加**「朗读本章」按钮。用户选中文本时，selection toolbar 加「朗读选中」项（复用 `SelectionArea` toolbar customization），调 TtsService 朗读选中片段，无翻页联动。

### 3.9 Markdown / TXT 章节边界

代码已确认（`reader_engine_provider.dart:101-127`）：markdown 和 txt 都通过 `ConcreteEpubReaderEngine(renderer: EpubxRenderer())` 渲染。

- **Markdown**：按 `#` 标题切章（`markdown_book_loader.dart` 已实现）
- **TXT**：按段落/行切章（`txt_book_loader.dart` 「仿 TXT 每行成 `<p>`」）
- TTS 行为与 EPUB 完全一致：自动翻页、句级高亮、章节边界处理

### 3.10 验收标准

- EPUB / MD / TXT 当前章节可启动朗读，自动翻页 + 句级高亮。
- paged + scroll 两种模式都正常。
- 章末行为符合设置（A/B）。
- 长章节（> 5 万字）内存稳定。
- PDF 选中文本可朗读。

---

## 4. Phase 3：移动端后台播放 + 锁屏

### 4.1 架构（仅移动端激活）

```
┌──────────────────────────────────────────────────────┐
│  TtsPlaybackController (P1/P2 共用)                  │
│  ↓ play/pause/stop 调用                              │
│  ┌─────────────────────────────────────────────────┐ │
│  │  ZhiYueAudioHandler extends AudioHandler        │ │
│  │  (audio_service ^0.18)                          │ │
│  │  ├─ play() → ttsService.speakSentence(current)  │ │
│  │  ├─ pause() → ttsService.pause()                │ │
│  │  ├─ stop() → ttsService.stop()                  │ │
│  │  ├─ skipToNext() → advance + speak              │ │
│  │  ├─ skipToPrevious() → back + speak             │ │
│  │  └─ onPlayerStateChanged → broadcast            │ │
│  └────────┬────────────────────────────────────────┘ │
│           ↓ 桥接                                      │
│  ┌─────────────────────────────────────────────────┐ │
│  │  audio_session (AudioSession.instance)          │ │
│  │  - 配置 category=speech, mode=spokenAudio       │ │
│  │  - 处理来电/其他 app 抢占 → pause TTS            │ │
│  └─────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘

平台 gate（PlatformInfo.isMobile）：
  - 桌面：TtsPlaybackController 直接调 TtsService，不经过 AudioHandler
  - 移动：必经 AudioHandler，由 audio_service 接管后台生命周期
```

### 4.2 Android 配置

**`AndroidManifest.xml` 新增**：

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.WAKE_LOCK" />

<service
  android:name="com.ryanheise.audioservice.AudioService"
  android:foregroundServiceType="mediaPlayback"
  android:exported="true">
  <intent-filter>
    <action android:name="android.media.browse.MediaBrowserService" />
  </intent-filter>
</service>

<receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
  android:exported="true">
  <intent-filter>
    <action android:name="android.intent.action.MEDIA_BUTTON" />
  </intent-filter>
</receiver>
```

minSdk 已 21+；compileSdk 36 已升级（M3 完成）。

### 4.3 iOS 配置

**`Info.plist` 新增**：

```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
```

**App Store 审核风险**：审核可能质疑 audio 后台是否为「app 主要用途之一」。
- **缓解**：在审核说明（App Review Information）里写明：「智阅作为阅读应用，TTS 朗读是无障碍能力的核心组成，对于视障用户、学习场景、运动/通勤场景必不可少」。
- **风险等级**：低-中（同类阅读 app 如 Marvin、Bound 都通过审核）。
- **降级方案**：如果首次审核被拒，iOS 退化为「app 内控制」（移除 UIBackgroundModes，仅在 app 前台时朗读）。Android 不受影响。

### 4.4 MediaItem metadata（锁屏显示）

```dart
MediaItem(
  id: '${bookId}:${chapterIdx}:${sentenceIdx}',
  album: book.title,                       // 「三体」
  title: chapterTitle,                     // 「第 N 章 黑暗森林」
  artist: '正在朗读：第 $sentenceIdx 句',   // 「正在朗读：第 42 句」
  artUri: coverFileUri,                    // 封面（M2.9 已同步）
  duration: Duration(seconds: estimatedDuration),
);
```

锁屏控件映射：
- 系统播放/暂停 → AudioHandler.play/pause
- 系统上一首 → skipToPrevious（上一句）
- 系统下一首 → skipToNext（下一句）
- 系统停止（拔耳机/锁屏滑动）→ pause（不是 stop，便于 resume）

### 4.5 Foreground notification（Android）

audio_service 自动渲染。文案定制：
- Title: `智阅正在朗读：${chapterTitle}`
- Body: `第 $sentenceIdx 句 / 共 $totalSentences 句`
- SubText: `📚 ${bookTitle}`

通知 channel：新建 `zhiyue_tts_channel`，importance=low（不打断用户但可见）。

### 4.6 Audio focus 处理

```dart
final session = AudioSession.instance;
await session.configure(const AudioSessionConfiguration(
  avAudioSessionCategory: AVAudioSessionCategory.speech,
  avAudioSessionMode: AVAudioSessionMode.spokenAudio,
  androidAudioAttributes: AndroidAudioAttributes(
    contentType: AndroidAudioContentType.speech,
    usage: AndroidAudioUsage.assistiveSonification,
  ),
  androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
));

// 来电/其他 app 抢占
session.interruptionEventStream.listen((event) {
  if (event.begin) ttsController.pause();
});

// 耳机拔出
session.becomingNoisyEventStream.listen((_) => ttsController.pause());
```

### 4.7 桌面端行为（不做 P3）

桌面端 TtsPlaybackController 直接调 TtsService，**不**经过 AudioHandler：
- app 最小化时仍朗读（系统扬声器继续输出）
- app 关闭时停止
- 无锁屏控件

与 `desktop-stable-pre-mobile` 原则一致。

### 4.8 切换上下文

| 场景 | 行为 |
|---|---|
| 用户切到其他 app（移动） | TTS 继续（foreground service 保活） |
| 用户锁屏（移动） | TTS 继续，锁屏控件显示当前章/句 |
| 用户拔耳机（移动） | 自动 pause（`becomingNoisy`） |
| 来电 | 自动 pause，通话结束不自动 resume（用户手动） |
| 其他 app 抢占音频（如音乐播放器） | TTS pause，等用户手动 resume |
| 用户在 app 内启动 AI chat | TTS 继续，AI chat 不抢占 |
| 系统内存压力 kill foreground service | 重启 app 不自动续读（与 §3.6 一致，只记位置） |

### 4.9 验收标准

- Android 真机：朗读中锁屏能控制（上一句/暂停/下一句），通知栏显示当前句。
- iOS 真机：锁屏控件正常（如被审核拒，按 §4.3 风险预案降级）。
- 桌面：app 内控件正常，不出现「通知栏锁屏」概念。
- 拔耳机自动 pause；来电自动 pause，结束通话不自动恢复。

---

## 5. 边界情况、schema 改动、风险

### 5.1 Schema 改动（drift v14 → v15）

新增 1 列到 `books` 表：

```dart
// shared/books.dart
TextColumn get lastTtsPosition => text().nullable()();
// 存储 JSON: {"chapterIdx": 3, "sentenceIdx": 42, "updatedAt": 1721234567890}
// 朗读启动时写入，朗读停止/章节切换时更新
```

迁移 v14 → v15：

```sql
ALTER TABLE books ADD COLUMN last_tts_position TEXT;
```

`books.last_tts_position` **进入 sync**（M2.8 sync 体系）—— 与 lastReadAt 类似，跨设备同步。

### 5.2 TTS 引擎可用性检测

app 启动时**不预检**（避免延迟）。**首次点朗读按钮时**检测：

```dart
Future<TtsAvailability> checkAvailability() async {
  final isAvailable = await FlutterTts().isLanguageAvailable('zh-CN') ??
      await FlutterTts().isLanguageAvailable('en-US');
  if (!isAvailable) {
    return TtsAvailability.engineMissing;
  }
  final zhInstalled = await FlutterTts().isLanguageInstalled('zh-CN');
  if (zhInstalled != true) return TtsAvailability.voiceDownloadRequired;
  return TtsAvailability.ready;
}
```

检测到缺失时弹对话框：
- **engineMissing**：跳转系统「文本转语音」设置页（Android: `ACTION_TTS_DATA`；iOS 不可跳转，提示去「设置→辅助功能→朗读内容」）
- **voiceDownloadRequired**：跳转 TTS voice 下载页

### 5.3 长文本与内存

- 单章节 < 5 万字：直接切句入队
- 5 万 - 20 万字：分批切句，每次队列 < 1000 句，读完前批再加载下批（lazy）
- > 20 万字（极少见）：弹警告「章节过长，朗读可能不稳定」，建议改用「连续朗读 + 章末询问」模式

### 5.4 Samsung 设备坑

Android 15 / One UI 7 起 Samsung 私有 TTS 引擎限制第三方使用。首次朗读失败时检测：
- 如果检测到当前 default engine 是 `com.samsung.SMT`，弹引导「请在系统设置→语言和输入法→文字转语音输出中切换到 Google TTS 引擎」。
- 不强制跳转（用户可能无 Google TTS），允许继续尝试。

### 5.5 风险与缓解

| 风险 | 等级 | 缓解 |
|---|---|---|
| EPUB CFI 与 TTS char offset 不对齐 | 中 | 句级 highlight 而非 word-level；归一化文本（HTML 实体解码、空白折叠）后再切句 |
| iOS 审核被拒（audio 后台） | 中 | 审核说明强调无障碍；必要时降级 iOS 为前台-only |
| audio_service 与现有 just_audio 冲突 | 低 | 项目目前无 just_audio 依赖，零冲突；新增依赖前先 `flutter pub deps` 确认 |
| flutter_tts pause 仅 iOS | 中 | Android/macOS/Windows 用 stop + 记录 sentenceIdx 实现「伪 pause」（resume 时重新 speak 当前句） |
| 长章节内存峰值 | 低 | §5.3 lazy queue 策略 |
| 朗读中用户切书 | 中 | Controller 监听 bookId 变化 → 强制 stop 当前会话，不跨书保留 |
| TTS 后台 service 被系统 kill | 低 | 不自动续读（§3.6 一致），用户重启看到「上次朗读到 N 章 M 句」提示 |
| 中文 voice 质量参差（Android） | 低 | 用户教育：设置页加「推荐使用 Google TTS」提示 |
| audio_service 初始化失败 | 低 | try/catch + 回退到前台-only 模式（仅 app 内控制） |

### 5.6 待决问题

- 朗读位置 `last_tts_position` 是否需要单独 purge 策略（M2.0b 的 30 天 conflicts purge 类似）？**建议不需要**——只是 JSON 字符串，不占空间。
- 章节切分遇到「第 N 章」这种数字标记是否切？**建议按章节边界切**（`SentenceSegmenter` 已设计段落边界强制切）。

---

## 6. 工期估算（subagent-driven TDD）

| Phase | Tasks | 工期 |
|---|---|---|
| P1 (AI TTS) | TtsService + TtsPlaybackController skeleton + AI bubble 长按菜单 + 迷你控件 + 设置页 | 5-7 天 |
| P2 (EPUB/MD/TXT 章节) | SentenceSegmenter + CFI 映射 + auto-page-flip + highlight overlay + 章节边界 + lastTtsPosition schema + PDF selection | 12-15 天 |
| P3 (移动后台) | audio_service 集成 + AudioHandler + Android manifest + iOS plist + 锁屏 metadata + audio_session + Samsung 检测 | 7-10 天 |
| **合计** | ~30 tasks | **4-6 周** |

版本号：**v1.12.0-alpha**（M3 minor bump，因为引入新功能模块 + 新依赖 + 新平台权限）。

---

## 7. 依赖新增

```yaml
# pubspec.yaml
dependencies:
  flutter_tts: ^4.1.0       # TTS 引擎封装
  audio_service: ^0.18.15    # 移动端后台媒体控件
  audio_session: ^0.1.21     # 音频焦点管理
```

全部 AGPLv3 / MIT 兼容，无 license 风险。

---

## 8. 测试策略

### 8.1 单元测试

- `SentenceSegmenter`：中英标点、跨段落、长句切分边界
- `TtsService`：state machine（mock FlutterTts）
- `TtsPlaybackController`：play/pause/stop/skip 状态转移、错误恢复
- `ZhiYueAudioHandler`：MediaItem 构造、skipToNext/skipToPrevious 逻辑（mock TtsService）
- `LastTtsPosition` JSON 序列化/反序列化
- `LocaleDetector`：CJK/Latin 启发式

### 8.2 Widget 测试

- AI message 长按菜单显示「朗读」
- 迷你控件条状态切换
- reader_scaffold 工具栏「朗读本章」按钮
- PDF selection toolbar 含「朗读选中」
- 设置页朗读分区交互

### 8.3 集成测试

- 模拟 interruption event → 验证 pause 被调用
- 模拟 becomingNoisy → 验证 pause 被调用
- 章节切换时 `last_tts_position` 写入数据库
- 跨设备同步 `last_tts_position`

### 8.4 手工测试

- **Windows**：AI 朗读 + EPUB 章节朗读（paged + scroll）
- **Android 真机**：全部功能 + 锁屏控制 + 后台播放 + 拔耳机 + 来电
- **iOS 真机**（TestFlight 内部测）：全部功能 + 锁屏控制
- **PDF**：选中文本朗读

---

## 9. 实施顺序（writing-plans 阶段拆 task）

按依赖顺序：

1. **基础设施层**（P1 的前 3 个 task）：
   - TtsService 接口 + FlutterTtsServiceImpl
   - SentenceSegmenter
   - TtsPlaybackController skeleton（不含 audio_service）

2. **P1 完成**：
   - AI bubble 长按菜单 + 迷你控件
   - 设置页朗读分区

3. **P2 主体**：
   - schema v15 migration + lastTtsPosition
   - reader_scaffold 工具栏按钮
   - CFI 映射 + auto-page-flip
   - highlight overlay（临时色）
   - 章节边界（A 连续 / B 询问）
   - PDF selection toolbar

4. **P3 主体**（仅移动端）：
   - audio_service + AudioHandler 集成
   - Android manifest + iOS plist
   - 锁屏 metadata + foreground notification
   - audio_session + interruption/becomingNoisy
   - Samsung TTS 引擎检测

5. **收尾**：
   - 跨设备 sync `last_tts_position`
   - CHANGELOG + README + 用户手册更新
   - pubspec bump v1.12.0-alpha
   - 全量回归 + 构建 artifacts

---

## 10. 用户文档影响

- `docs/user-guide.md` + `docs/user-guide.html`：新增「TTS 朗读」章节
- `README.md`：功能列表加 TTS
- `CHANGELOG.md`：v1.12.0-alpha 条目
- `docs/releases/release-notes-v1.12.0-alpha.md`：新版本说明

---

## 决策追踪

- **2026-07-16**：brainstorming 完成 5 节设计 + 用户确认。spec 写入 `docs/superpowers/specs/2026-07-16-tts-design.md`，等待 user review 后进入 writing-plans 阶段。
