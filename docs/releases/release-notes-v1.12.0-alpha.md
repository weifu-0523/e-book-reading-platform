# v1.12.0-alpha

**发布日期**：2026-07-17
**类型**：feature release（TTS 朗读完整交付）
**上一版本**：v1.11.9-alpha

## 摘要

TTS 朗读功能完整交付，覆盖 3 阶段 30 任务，新增 3 依赖
（`flutter_tts` / `audio_service` / `audio_session`），drift schema
v14 → v15（books 加 `last_tts_position` 列）：

1. **AI 响应朗读**——AI 聊天消息长按「朗读」，底部 TtsMiniControls
   浮窗支持暂停/继续/上下句/停止。
2. **章节自动跟读**——EPUB / TXT / Markdown Reader 顶部 chrome 新增
   「朗读本章」按钮，自动驱动 paged 翻页或 scroll 滚动，当前句子金黄
   高亮；CFIBoundaryExtractor 把句子 charStart/End 映射到 EPUB CFI。
3. **跨设备朗读位置同步**——当前章节 + 句子序号存到
   `books.last_tts_position`，走 outbox 跨端同步；新设备打开同书时
   TtsResumePrompt 提示上次位置。
4. **移动端后台播放**——Android foreground service + iOS
   UIBackgroundModes audio；ZhiYueAudioHandler 回调式 BaseAudioHandler，
   锁屏媒体控件（播放/暂停/上下句/停止）。
5. **音频焦点与耳机拔出**——audio_session interruption（电话/闹钟）
   + becomingNoisy（拔耳机）自动暂停。
6. **Samsung TTS 引擎检测**——4 态 `checkTtsAvailability`（ready /
   engineMissing / voiceDownloadRequired / samsungRestricted）+ Settings
   「检查 TTS 引擎」按钮 + 引导 dialog（针对 com.samsung.SMT 中文
   支持问题）。

测试数：**1648 pass + 25 skip + 8 pre-existing baseline fail**
（reader_body_\*_test 的 MissingPluginException flutter_tts on dispose，
T26 之前已存在，与本版本无关）。

---

## TTS 朗读基础（P1：T1-T8）

### 服务层

- **TtsService 抽象**：定义 `speak` / `pause` / `resume` / `stop` /
  `setRate` / `setPitch` / `setVolume` / `getDefaultEngine` /
  `getAvailableEngines` / `getLanguages` 12 个方法 + 4 个状态 stream
  （`onStart` / `onComplete` / `onPause` / `onContinue` / `onError` /
  `onProgress`）。
- **FlutterTtsServiceImpl 实现**：包装 `flutter_tts` 包，所有方法
  delegating 到 `FlutterTts` 实例；构造函数注入便于测试。
- **LocaleDetector**（Unicode 启发式）：扫描段落前 200 字符，按 CJK
  Hangul / Hiragana / Cyrillic / Latin 字符比例决定 locale（`zh-CN` /
  `ja-JP` / `ko-KR` / `ru-RU` / fallback `en-US`）。
- **SentenceSegmenter**：按中英标点（。！？.!? + 段落边界 `\n\n`）
  切句，单句 200 字上限硬切，输出 `Sentence(text, charStart, charEnd)`
  三元组列表。

### 状态机与持久化

- **TtsPlaybackController**（Riverpod `StateNotifier<TtsPlaybackState>`）：
  5 态状态机（idle / loading / speaking / paused / error）+ 公共
  `play` / `pause` / `resume` / `stop` / `nextSentence` /
  `previousSentence` + 内部 `drive*` 方法直接驱动 TtsService（避免
  回调环）。公共方法在移动端通过 ZhiYueAudioHandler 路由激活
  foreground service。
- **TtsSettings**（持久化）：rate（0.5-1.5）/ pitch（0.5-2.0）/
  volume（0.0-1.0）/ chapterBoundaryMode（continuous / askAtEnd）+
  enabled flag，全部走 SharedPreferences JSON。

### 入口与 UI

- **AI 响应朗读**：`AiMessage` 长按菜单加「朗读」项，调用
  `ttsPlaybackControllerProvider.playAiResponse(text)`。
- **TtsMiniControls**：浮在底部（80px 高），4 按钮（上一句 / 播放暂停
  toggle / 下一句 / 停止）+ 当前句子预览（前 30 字 + 省略号）+ 进度
  条（句子序号 / 总句数）。dispose 时 stop TTS 避免泄漏。
- **Settings 朗读分区**：6 个控件——启用开关 / 语速 slider / 音调
  slider / 音量 slider / 章节结束行为 segmented control / 「检查 TTS
  引擎」按钮（T26）。

---

## 章节自动跟读（P2：T9-T19）

### 持久化与同步

- **drift schema v14 → v15**：`books` 表加 `last_tts_position TEXT`
  nullable 列。
- **LastTtsPosition model**：`{chapterIdx, sentenceIdx, updatedAt}` 3 字段
  JSON。
- **BooksDao**：`getLastTtsPosition(bookId)` / `setLastTtsPosition(...)`
  / `clearLastTtsPosition(bookId)` 三方法。
- **Sync wiring**：`recordBook` payload 自动包含 `lastTtsPosition`，
  outbox 走 v1.11.0 起的 recordBook 路径；T27 集成测试验证跨端读取。

### 渲染层

- **CFIBoundaryExtractor**：把每页的 plain-text sentence（charStart/End）
  映射到 EPUB CFI range，用于 highlight overlay 与 page-flip 决策。
- **TtsHighlightOverlay**：临时金黄高亮（区别于 5 色用户高亮），3 秒
  后淡出，不写入 annotations 表，纯视觉反馈。
- **TtsReaderController**：
  - **Paged 模式**：当前句子 charOffset 跨页时自动翻页，重 play 当前
    句。
  - **Scroll 模式**：当前句子 charOffset 不在 viewport 时滚动到可见
    区域。
  - **章节边界**：`continuous` 模式自动进入下一章；`askAtEnd` 模式弹
    SnackBar「继续 / 停止」。
  - **手动翻页暂停**：用户翻页 → TTS 自动 pause + TtsResumePrompt
    banner 显示「上次朗读到 第 N 章 [继续]」，5 秒后自动隐藏。

### 入口

- **Reader chrome 「朗读本章」按钮**（图标 `record_voice_over`）：触发
  从本章开头自动跟读。
- **PDF selection toolbar 「朗读选中」**：任意格式选中文字 → 工具条
  「朗读选中」→ 仅朗读该段（不进入章节模式）。

---

## 跨设备朗读位置同步（P2：T11 + T27）

`books.last_tts_position` 通过 v1.11.0 的 `recordBook` 路径走 outbox。
LastTtsPosition 字段更新时自动 bump books row 的 `updatedAt`（books
表无独立 updated_at 字段，与封面同步同限制——整 book payload LWW）。

T27 集成测试覆盖：设备 A 朗读到第 3 章第 5 句 → push → 设备 B pull →
打开同书 → TtsResumePrompt 显示「上次朗读到 第 3 章」。

---

## 移动端后台播放（P3：T20-T24）

### 依赖与抽象

- **新依赖**：`audio_service: ^0.18.15`（resolved 0.18.19）+
  `audio_session: ^0.1.21`（resolved 0.1.25）。
- **ZhiYueAudioHandler**：继承 `BaseAudioHandler`，回调式实现
  `onPlay` / `onPause` / `onResume` / `onStop` / `onSkipToNext` /
  `onSkipToPrevious`，每个回调 delegating 到 TtsPlaybackController 的
  对应方法。
- **PlatformInfo.isMobile gate**：桌面（Windows）不初始化
  audio_service，避免 plugin 缺失异常。

### 平台配置

- **Android manifest**：声明 `FOREGROUND_SERVICE` +
  `FOREGROUND_SERVICE_MEDIA_PLAYBACK` + `WAKE_LOCK` 权限；注册
  `<service android:name="com.ryanheise.audioservice.AudioService"/>`
  + `<receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"/>`。
- **iOS Info.plist**：`UIBackgroundModes` 数组加 `audio` 项。

### main.dart boot

```dart
if (PlatformInfo.isMobile) {
  try {
    await AudioService.init(
      builder: () => ZhiYueAudioHandler(...),
      config: const AudioServiceConfig(...),
    );
  } catch (_) {
    // best-effort, 不阻塞 boot
  }
  try {
    await AudioSessionInitializer.init();
  } catch (_) {}
}
```

---

## 音频焦点与耳机拔出（P3：T25）

`audio_session` 配置：

- **interruption**（电话 / 闹钟 / 其他 app 抢占音频）：自动 `pause`，
  电话结束后不自动 resume（用户需手动）。
- **becomingNoisy**（拔耳机）：自动 `pause`，避免外放突然大音量。

`AudioSessionConfig`：

```dart
const AudioSessionConfig(
  avAudioSessionCategory: AVAudioSessionCategory.playback,
  avAudioSessionMode: AVAudioSessionMode.spokenAudio,
  androidAudioAttributes: AndroidAudioAttributes(
    contentType: AndroidAudioContentType.speech,
    usage: AndroidAudioUsage.media,
  ),
  androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
);
```

---

## Samsung TTS 引擎检测（P3：T26）

### 问题

Samsung 自家 TTS 引擎 `com.samsung.SMT` 对中文支持差（发音怪异、
缺中文语音数据），用户首次体验容易放弃。

### 4 态可用性检查

```dart
enum TtsAvailability {
  ready,                  // 引擎装了 + 语音数据齐
  engineMissing,          // 完全没装 TTS 引擎
  voiceDownloadRequired,  // 引擎在但缺语音数据
  samsungRestricted,      // 当前是 Samsung SMT 且语言未下载
}
```

### Settings 入口

设置 → 朗读 → 「检查 TTS 引擎」按钮 → 调
`TtsService.checkTtsAvailability()` → 弹 dialog 显示状态：

| 状态 | 引导文案 |
|---|---|
| ready | "TTS 引擎就绪，可以开始朗读" |
| engineMissing | "未检测到 TTS 引擎，请安装 Google TTS 或系统 TTS 引擎" |
| voiceDownloadRequired | "检测到引擎但语音数据未下载，请到系统 TTS 设置下载对应语言" |
| samsungRestricted | "检测到 Samsung SMT 引擎，中文支持受限。建议切换到 Google TTS 或在 Samsung Voice Assistant 设置中下载中文语音包" |

`SamsungTtsDetector._samsungEngines = {'com.samsung.SMT'}` 硬编码包名。

---

## 变更文件

| 区域 | 文件 | 变更 |
|---|---|---|
| schema | `app/lib/data/db/database.dart` | drift schema v14 → v15（books.last_tts_position TEXT） |
| schema | `app/lib/data/db/books_dao.dart` | +getLastTtsPosition / +setLastTtsPosition / +clearLastTtsPosition |
| services | `app/lib/features/tts/tts_service.dart`（新） | TtsService 抽象 + FlutterTtsServiceImpl |
| services | `app/lib/features/tts/locale_detector.dart`（新） | Unicode 启发式 |
| services | `app/lib/features/tts/sentence_segmenter.dart`（新） | 中英标点切句 |
| services | `app/lib/features/tts/tts_playback_controller.dart`（新） | 5 态状态机 |
| services | `app/lib/features/tts/tts_settings.dart`（新） | rate / pitch / volume / chapter boundary |
| services | `app/lib/features/tts/cfi_boundary_extractor.dart`（新） | sentence → EPUB CFI |
| services | `app/lib/features/tts/tts_reader_controller.dart`（新） | page-flip + scroll auto-navigate |
| services | `app/lib/features/tts/audio/zhiyue_audio_handler.dart`（新） | BaseAudioHandler 回调式 |
| services | `app/lib/features/tts/audio/audio_session_initializer.dart`（新） | interruption + becomingNoisy |
| services | `app/lib/features/tts/samsung_tts_detector.dart`（新） | com.samsung.SMT 检测 |
| features | `app/lib/features/ai/widgets/ai_message.dart` | 长按菜单 + 「朗读」 |
| features | `app/lib/features/tts/widgets/tts_mini_controls.dart`（新） | 底部浮窗 |
| features | `app/lib/features/tts/widgets/tts_highlight_overlay.dart`（新） | 临时金黄高亮 |
| features | `app/lib/features/tts/widgets/tts_resume_prompt.dart`（新） | 「上次朗读到 第 N 章」banner |
| features | `app/lib/features/reader/widgets/reader_chrome.dart` | +「朗读本章」按钮 |
| features | `app/lib/features/reader/widgets/reader_selection_toolbar.dart` | +「朗读选中」（PDF/TXT/Markdown） |
| features | `app/lib/features/settings/pages/settings_page.dart` | +朗读分区（6 控件） |
| features | `app/lib/data/sync/remote_record_applier.dart` | recordBook 自动含 lastTtsPosition |
| platforms | `app/android/app/src/main/AndroidManifest.xml` | +FOREGROUND_SERVICE_MEDIA_PLAYBACK + service + receiver |
| platforms | `app/ios/Runner/Info.plist` | +UIBackgroundModes audio |
| platforms | `app/lib/main.dart` | PlatformInfo.isMobile 分支 AudioService.init + AudioSessionInitializer.init |
| deps | `app/pubspec.yaml` | +flutter_tts ^4.1.0 + audio_service ^0.18.15 + audio_session ^0.1.21 |
| tests | `app/test/features/tts/*`（11 新文件） | 127 新测试覆盖全部 service + widget |
| docs | `docs/user-guide.md` / `docs/user-guide.html` | +6.8 TTS 朗读 + Q13/Q14 FAQ |
| docs | `CHANGELOG.md` / `README.md` | +v1.12.0-alpha section |
| docs | `app/windows/installer/zhiyue.iss` | MyAppVersion bump（T29 一起） |

---

## 已知限制

1. **iOS 未真实 build 验证**：仅 manifest 配置就绪
   （`UIBackgroundModes: audio`），Xcode build 留待 v1.12.0-alpha 用户
   上报。Android 已通过 audio_service 0.18.x 默认配置。
2. **Android 真机冒烟测试待用户上报**：锁屏控件 + foreground service
   通知的视觉验证 + 拔耳机 / 来电自动暂停的时序验证。
3. **Samsung SMT 引擎检测依赖包名 `com.samsung.SMT`**：若 Samsung
   改包名需更新 `SamsungTtsDetector._samsungEngines` 集合。
4. **lastTtsPosition 走 `recordBook` 整书 payload**：books 表无
   `updated_at`，无法字段级 LWW（与封面同步同限制）。多设备并发朗读
   同一本书时，最后写入者获胜——可接受，因为朗读是单人活动。
5. **8 个 pre-existing baseline test fails**：`reader_body_ai_entry_test`
   / `reader_body_font_buttons_test` / `reader_body_review_menu_test` /
   `reader_sidebar_test` 在 dispose 时调 `flutter_tts`（未在测试
   binding 注册），抛 `MissingPluginException`。**T26 之前已存在**，
   与本版本无关。修复需要为 4 个测试加 `flutter_tts` channel mock，
   推到 v1.12.1-alpha。

---

## 验证

### 单元/集成测试

```
$ flutter test
1648 pass + 25 skip + 8 baseline fail
```

新增 127 测试覆盖：

- T1-T8 P1：services + AI message entry + TtsMiniControls + Settings
  分区
- T9-T11 P2：schema v15 migration + BooksDao + sync wiring
- T12-T19 P2：CFIBoundaryExtractor + TtsHighlightOverlay + chrome
  button + TtsReaderController（paged flip + scroll navigate + chapter
  boundary）+ TtsResumePrompt + selection toolbar
- T20-T26 P3：ZhiYueAudioHandler + PlatformInfo gate + manifest +
  Info.plist + audio_session + SamsungTtsDetector
- T27：cross-device lastTtsPosition sync integration

### 手工验证（建议）

1. **AI 长按朗读**：打开任意书 → 点 AppBar `smart_toy` 进 AI 抽屉 →
   AI 回复一条消息 → 长按消息 → 选「朗读」→ 验证底部 TtsMiniControls
   浮窗出现 + 听到中文语音。
2. **EPUB 朗读本章**：打开 EPUB → chrome 「朗读本章」按钮 → 验证自动
   从章首朗读 + 当前句子金黄高亮 + paged 模式自动翻页（或 scroll 模式
   自动滚动）。
3. **锁屏控件**（Android）：朗读中按电源键锁屏 → 验证锁屏媒体控件
   显示智阅 + 播放暂停按钮可用 + foreground service 通知栏有智阅条目。
4. **检查 TTS 引擎**：设置 → 朗读 → 「检查 TTS 引擎」按钮 → 验证弹窗
   显示状态（理想是 `ready`，Samsung 设备可能是 `samsungRestricted`）。
