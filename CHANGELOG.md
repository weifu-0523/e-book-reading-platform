# Changelog

本项目所有重要变更记录在此文件。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

v1.15.0-alpha 之后的新变更将记在此处。

## [1.15.0-alpha] - 2026-07-21

### Added

- **Sherpa-ONNX 离线神经 TTS POC（v1.15.0-alpha）**：用户反馈"目前 tts 等基础能力有了，但效果确实一般，而且存在不同手机效果差异明显的情况"。引入 [sherpa_onnx](https://pub.dev/packages/sherpa_onnx) ^1.13.4 作为系统 TTS 之外的离线神经引擎选项，首批嵌入 [MeloTTS-zh_en](https://github.com/myshell-ai/MeloTTS) 模型（163MB ONNX 权重 + 6.5MB 中文词典 + 112 个 BPE tokens）。新增 `SherpaOnnxTtsService implements TtsService`（asset → filesystem 拷贝 → FFI bindings 注册 → `OfflineTts` ctor → `generate(text)` → Float32 PCM → 44-byte WAV header → audioplayers 播放）。`TtsEnginePreference` enum 持久化用户偏好（system / sherpaOnnxMelo），`ttsServiceProvider` `ref.watch(ttsEngineProvider)` 自动 rebuild。设置页「TTS 引擎（实验）」debug 卡片提供 dropdown 切换 + 说明文字。`SherpaOnnxBenchmark` 4-sentence suite（短/中/长/中英混排）+ `service.benchmark(text)` 入口测量 RTF（实时因子）+ 内存峰值 + 模型加载耗时，供 T9 POC report 决策。Android `useLegacyPackaging = true` 保障 sherpa-onnx JNI lib 可执行。
- **POC report scaffold**（`docs/research/2026-07-21-sherpa-onnx-tts-poc-report.md`）：含执行摘要、benchmark/盲听 placeholder 表、APK 体积影响（135MB → ~325MB release 预测）、架构与依赖图、已知问题（Windows 桌面 ORT API 版本不匹配、模型 asset 体积过大、pause 是 stop+标记、Dart RSS 近似、init 无进度 UI）、Phase 2 实施风险表。

### Known Limitations

- **APK 体积显著增加**：debug APK 135MB → 295MB（+160MB），release 预测 ~325MB。主要来自 MeloTTS-zh_en 163MB ONNX asset（几乎不可压缩）。Phase 2 W1 计划改按需下载到外部存储，APK 回到 ~155MB。
- **Windows 桌面 SherpaOnnx 不可用**：`sherpa_onnx_windows 1.13.4` 自带的 `onnxruntime.dll` 是 v1.17.1（ORT API v27），sherpa-onnx C API 期望 API v17，加载 `OfflineTts` 时抛 `OrtApiGetApi` 错误。Windows 安装包仍嵌入所有文件，等上游 `sherpa_onnx ^1.13.5+` 修复后可直接使用。
- **首次切换引擎朗读有 1-3 秒延迟**：170MB asset 拷贝 + ONNX 权重加载到 native heap。后续启动有 filesystem cache 可加速。
- **盲听评估未完成**：T9 POC report §2 §3 留 placeholder，需用户在真机跑 benchmark + 组织中文母语盲听后填回，再决策 Go/No-Go Phase 2。

### Statistics

- **Dart**: 1751 pass / 26 skip / 1 fail（pre-existing flaky `background_sync_scheduler_test` / `notes_page_test`，与 POC 无关；v1.14.2-alpha 是 1731，+34 新测试 - 14 调整）
- **Commits since v1.14.2-alpha**: 9（c688803 → 88b2018）
- **versionCode**: 2012（v1.14.2-alpha 是 2011）
- **新增依赖**: sherpa_onnx ^1.13.4 / audioplayers ^5.2.1
- **新增文件**: 10（lib/services/tts 3 + lib/features/tts 2 + lib/features/settings/pages 修改 1 + test 5 + docs/research 1）

## [1.14.2-alpha] - 2026-07-21

### Fixed

- **移动端选中文字仍弹 Flutter 默认 toolbar（v1.14.1-alpha 误诊修复）**：v1.14.1-alpha 修了 `SelectableRegion` 的 `selectionControls`（误以为是默认 toolbar 来源），用户报告 v1.14.1 装上后卡片仍在。真根因：`SelectionArea` 的默认 `contextMenuBuilder` 是 `_defaultContextMenuBuilder`（`material/selection_area.dart:54`），构建 `AdaptiveTextSelectionToolbar`（白色长条卡 Copy/Share/SelectAll）。Flutter 框架在 `selectable_region.dart:1374-1387` 检测到 `TextSelectionHandleControls` mixin 后**完全跳过** `selectionControls` 路径，改走 `contextMenuBuilder` 路径，所以 `selectionControls` 与 toolbar 显示无关。EPUB 渲染层有 5 处 `SelectionArea`（`epubx_renderer.dart` 4 处 + `selectable_page_view.dart` 1 处）全部未传 `contextMenuBuilder`，全部弹默认 toolbar。修复：新增 `reader_engine_epub_view/lib/src/no_selection_toolbar.dart` 定义 `emptySelectionContextMenu` 返回 `SizedBox.shrink()`，5 处 `SelectionArea` + `reader_body.dart` 的 `SelectableRegion` 全部传 `contextMenuBuilder: emptySelectionContextMenu`。

### Statistics

- **Dart**: 1731 pass / 25 skip / 0 fail（v1.14.1 是 1729，+2 widget test + 1 源码断言扩展）
- **Commits since v1.14.1-alpha**: 1（69b1ab2）
- **versionCode**: 2011（v1.14.1 是 2010）

## [1.14.1-alpha] - 2026-07-21

### Fixed

- **移动端选中文字弹两个卡片（UX）**：用户报告"移动端选中文字后除我们自定义的弹片（摘录/复制/朗读/问 AI）外，还会出现一个更长的白色卡片（Copy / Share / Select All 等），两个卡片同时显示非常难用"。根因：`reader_body.dart` 的 `SelectableRegion` 配置了 `selectionControls: materialTextSelectionControls`，Flutter 框架在 `selectable_region.dart:1374` 检测到该 controls 不是 `TextSelectionHandleControls` 时调用 `showToolbar()`，与项目自定义 `ReaderSelectionToolbar` 同时渲染。修复：新增 `NoToolbarSelectionControls`（`extends MaterialTextSelectionControls with TextSelectionHandleControls`），框架检测到 mixin 后 `hideToolbar()`，默认 toolbar 不再渲染。Selection handles（小水滴拖拽手柄）仍由 `MaterialTextSelectionControls` 提供，移动端可正常拖动调整选区边界。桌面端 Ctrl+C 由 `reader_scaffold` 的 `HardwareKeyboard` 全局处理器接管，不受影响。

### Statistics

- **Dart**: 1728 pass / 25 skip / 0 fail（v1.14.0-alpha 是 1726，+2 防御性源码断言）
- **Commits since v1.14.0-alpha**: 1（3ec3dd0）
- **versionCode**: 2010（v1.14.0-alpha 是 2009）

## [1.14.0-alpha] - 2026-07-20

### Added

- **TTS 多播音员声音选择**：用户长期要求"目前只有一个播音员声音，能不能多几个可选"。新增 `TtsVoice` 数据类 + `TtsService.getVoices/setVoice/previewVoice/openSystemTtsSettings` 抽象 API。Android 通过 `TextToSpeech.getVoices()` 拿系统/引擎自带声音（华为/荣耀 1 个、小米 1-2 个、Pixel 10+、Samsung SMT 因中文支持差被过滤），Windows 通过 SAPI5 拿已安装桌面声音。设置页"朗读声音"入口，列表支持系统默认 + 单声音试听 + 跳转系统 TTS 设置加声音。`TtsSettings.voiceId` 持久化（drift schema 不变，json 字段），即时同步到 engine，下一句朗读生效。`previewVoice` 完成后恢复用户原设置（不污染全局）。
- **设为默认阅读器提示**：用户报告"打开 ZhiYue 软件时希望提示设为默认阅读器"。新增 `DefaultReaderDetector` 抽象 + 平台实现（Windows 写 HKCU `Software\Classes\.epub` / `.pdf` 不需 admin；Android 只能跳系统「默认应用」设置）。`AppSettings.promptedDefaultReader` 持久化到 `app_settings.json`，只弹一次。Settings → 关于 提供「设为默认阅读器」入口可手动重触发。

### Fixed

- **Android deep-link 乱码（P0）**：用户报告"在手机文件管理器点 .epub 选「用智阅打开」，出现一个全是乱码的页面，必须从书架导入才行"。根因：`MainActivity.copyContentToCache` 把 content URI 复制到临时文件时硬编码 `.book` 扩展名，破坏下游 `BookFormatDetector.detect`（要求 `.epub`）和 `BookOpenBridge.isSupportedBookPath` 白名单（不含 `.book`）。修复：新增 `inferExtensionFromUri` 从 URI `lastPathSegment`（通常含原始文件名如 `三体.epub`）推断扩展名，失败时 fallback 到 ContentResolver MIME type。临时文件名保留原始扩展名，下游检测正常工作。
- **Windows 热启动 deep-link 失败（P1）**：用户报告"智阅已开启时双击 .epub 选「用智阅打开」无反应，关闭软件后才能打开"。根因：第二个实例通过 `WM_COPYDATA` 转发 argv 到运行中的实例，`FlutterWindow.MessageHandler` 立即 `channel_->InvokeMethod("openBook", ...)`，但 Dart 端 `setMethodCallHandler` 可能还没注册（engine 启动后几百毫秒窗口），InvokeMethod 静默丢弃消息。冷启动工作是因为 entry-point arguments 经由另一条路径。修复：`FlutterWindow` 新增 `cached_argv_` 字段缓存最新 WM_COPYDATA 载荷（无论 channel 就绪与否都缓存）；新增专用 `dev.zhiyue.bookopen.argv` MethodChannel + `popPendingArgv` 处理器；`BookOpenBridge.init` 在 `popPendingBookPath`（Android）之后调用 `popPendingArgv` 排空缓存。

### Statistics

- **Dart**: 1726 pass / 25 skip / 0 fail（v1.13.11-alpha 是 1676，+50 测试：4 widget + 8 default_reader + 4 voice widget + 3 voice data + 3 tts_settings_provider + 2 voice test self-built/flutter_tts + 5 tts_service + 17 misc）
- **Kotlin Robolectric**: 43 pass / 0 fail（v1.13.11-alpha 是 37，+6：4 extension infer + 2 default apps settings）
- **Commits since v1.13.11-alpha**: 15（fd7b6d3 → 53904ff）
- **versionCode**: 2009（v1.13.11-alpha 是 2008）

## [1.13.11-alpha] - 2026-07-19

### Fixed

- **Bug 2 真根因：选段朗读坐标系不匹配**：v1.13.10-alpha 的 whitespace-insensitive regex fallback 没解决问题，因为真根因是坐标系不匹配（不是 whitespace 差异）。

  **坐标系不匹配详解**：
  - `selectedText` 来自 EPUB 渲染层 `SelectionAssistant.plainText`，走 `HtmlToInlineSpanConverter` 路径（渲染坐标）
  - `chapterText` 来自 `ttsChapterTextResolverProvider` → `EpubChapterTextProvider.get` → `PlainTextUtils.htmlToPlainWithOffsets`，走另一条提取路径（提取坐标）
  - 两者在 `<p>`/`<h1>`/`<br>`/`<img>` 等元素的分隔符处理上完全不同：渲染层插入 U+FFFC 替代符，提取层直接删掉 tag
  - `indexOf` 严格匹配失败，whitespace regex 也无法匹配 U+FFFC（非空白字符）

  **修复**：`TtsReaderController._prepareCurrentChapter` 及 `_loadNextChapterAndContinue` 改用 `engine.currentChapterPlainText`（渲染坐标），与 `reader_body._openExcerptSheet` 同源。`_locateSelectionStartIndex` 保留 whitespace fallback 容错。`resumeFromLast` 保留旧路径（engine 可能不在目标章节）。

  **测试**（2 新）：`TtsReaderController.startFromSelection uses engine.currentChapterPlainText coordinate` 验证新数据源包含 U+FFFC 时仍可命中选区。

  **统计**：Dart 1676 pass / 25 skip / 0 fail（+2 新测试，原 v1.13.10-alpha 的 1673 全保留）；versionCode 2008。
## [1.13.10-alpha] - 2026-07-19

### Fixed

- **Bug 1** (朗读关闭后自动恢复)：用户报告"朗读开始后从通知栏点停止，~845ms 后朗读自动恢复"。诊断日志决定性证据：STOP 后 service 重建，11ms 后自动收到 SPEAK intent，textLen=12 ≠ 上一句 sent_19 textLen=37（证实是 queue 自动推进到 sent_20）。

  **根因**：`SelfBuiltTtsServiceImpl._parseState` 把 Kotlin `'stopped'` 事件翻译成 `TtsState.idle`。`TtsPlaybackController._onServiceState` 看到 `idle + phase==speaking` → 误判句子自然播完 → 推进 queue → 调 `_speakCurrent()` → 发 SPEAK → service 已被 stopSelf 销毁 → ensureServiceStarted 重建 → onCreate → 朗读自动恢复。

  **次生问题**：TtsReaderController 看到 phase=idle 会触发 `_onChapterBoundaryReached`，朗读本章最后一句时点停止会自动到下一章或弹"继续听下一章？"SnackBar。

  **修复（4 文件）**：
  - `tts_service.dart`：`TtsState` 加 `stopped` 成员
  - `self_built_tts_service.dart`：`_parseState('stopped')` 返回 `TtsState.stopped`（不再 fallthrough 到 idle）
  - `tts_playback_controller.dart`：`TtsPlaybackState` 加 `userStopped` 字段；`_onServiceState` 新增 stopped 分支重置 state 不推进 queue；`driveStop` 也设 `userStopped=true`
  - `tts_reader_controller.dart`：`_onPlaybackChange` phase=idle 分支读 `playback.userStopped`，user stop 不触发 chapter-boundary

- **Bug 2 (续)** (选段朗读仍从章节头开始)：v1.13.9-alpha 修了 companion 残留后，用户测试 3 本书发现仍有 2 本从章节头开始播放。根因：`TtsReaderController._locateSelectionStartIndex` 的 `chapterText.indexOf(selectedText)` 对某些 EPUB 返回 -1，因为 `chapterText`（BookTextExtractor 输出）和 `selectedText`（EPUB 渲染层 SelectionAssistant.plainText）在某些章节存在 **whitespace 差异**（multiple spaces vs single、newline vs space、leading/trailing）。旧 fallback 直接返回 0 → 从章节头开始。

  **修复**：`_locateSelectionStartIndex` 严格 indexOf 失败时调用新增的 `_findSelectionStartWhitespaceInsensitive`：strip 掉 selectedText 所有 whitespace，每个非空白 char 用 `RegExp.escape` 转义后用 `\s*` 连接，在 chapterText 中 firstMatch。返回原 offset，sentence.charStart 映射不变。3 字符最小门槛 + 30 字符截断平衡唯一性与 regex 性能。

## [1.13.9-alpha] - 2026-07-19

### Fixed

- **Bug 2 (续)** (选段朗读仍间歇性从头播放)：v1.13.8-alpha 修了"首次 onCreate 后 init race"，但用户测试发现"很大的概率"问题仍在。诊断日志决定性证据：

  ```
  [onCreate start]                              ← service 第 2 次重建
  [after TextToSpeech ctor, tts=@b7bdbfa]       ← 新 TextToSpeech 实例
  [handleSpeak textLen=17 tts=@b7bdbfa initStatus=0]  ← !!! stale companion
  [setLanguage(zh-CN) -> -2 (NOT_SUPPORTED)]    ← 引擎实际未 init
  [speak() returned -1 (ERROR)]
  [TTS init callback status=0]                  ← 47ms 后才真正 init
  ```

  **根因**：`ZhiYueTtsService.ttsInitStatus` 是 **companion (static) field**，跨 service 实例共享。第一个 service 实例的 SUCCESS 值在 onDestroy 后仍然保留。Android 重建 service 时（用户 STOP 后再点朗读、或系统回收），新 `TextToSpeech` 还没完成异步 init，但 `ttsInitStatus` 仍是上次的 SUCCESS。`handleSpeak` 的 init guard 误判已就绪 → 直接调 `tts.speak()` → 新引擎未 init → 返回 -1 → `UtteranceProgressListener` 不触发 → Dart state 卡 loading → 用户重触发 → `play()` 重置 queue 从 0 → "从头播放"。

  日志中 `pendingSpeakActive: false` 证实 handleSpeak 走的是 immediate 路径（没 defer），证明了 guard 被 bypass。

  **修复**：`onCreate` 开头重置 per-instance companion fields：`ttsInitStatus = -999` + `ttsLastSpeakReturn = -999` + `pendingSpeakActive = false` + `onCreateCompleted = false` + `onCreateException = null` + `startForegroundCompleted = false`。每个新 service 实例都从"未 init"状态开始，handleSpeak 走 pendingSpeak 路径，等 init callback 真正完成后 flush。

## [1.13.8-alpha] - 2026-07-19

### Fixed

- **Bug 1** (控制台按钮过多)：用户反馈"朗读的控制台上不需要太多按钮，前进后退这本来就没用"。`TtsMiniControls` 移除 `skip_previous` / `skip_next` / `stop` 三个 IconButton，只保留 pause/play 切换 + 关闭（实际调 `stop()`）。多句朗读按 sentence 边界自动推进，跳句按钮本就无意义；"停止"和"关闭"语义重复（`TtsPlaybackController.stop` 已清 queue + reset idle）。

- **Bug 2** (选段朗读从头开始播放)：v1.13.7 诊断日志决定性证据：每次 `ZhiYueTtsService.onCreate` 后第一次 SPEAK 在 `TextToSpeech.onInit` 异步完成前到达 → `setLanguage` 返回 -2 (LANG_NOT_SUPPORTED) + `speak()` 返回 -1 (ERROR) + `UtteranceProgressListener` 不触发任何回调 → Dart `_speakCurrent` 卡在 loading 等待 speaking 永不到达 → 用户再次触发朗读 → `play(scope, sentences)` 重置 queue → 现象即"从头播放"。修复：
  - `handleSpeak` 头部检查 `ttsInitStatus != SUCCESS` → 把 intent 暂存到 `pendingSpeak` 字段并 return（不调 `tts.speak()`）
  - TTS init callback `status == SUCCESS` 分支末尾检查 `pendingSpeak`，触发 `handleSpeak(it)` 并清空字段
  - `handleStop` 清空 `pendingSpeak` 避免停止后又被 init callback flush
  - companion field `pendingSpeakActive` 暴露到 `buildDebugState`（不暴露 Intent 对象本身，Intent 不可序列化）供运行时诊断

## [1.13.7-alpha] - 2026-07-19

### Fixed

- **Bug 1** (通知栏暂停后无法继续)：Kotlin `ZhiYueTtsService.handleResume()` 之前是空实现，注释说"Dart side re-sends SPEAK intent"但从未实现；通知栏 PAUSED 状态下也只显示 pause/stop 按钮，无 play。修复：
  - `handleResume()` emit `resume_request` event → Dart `driveResume` 重发 SPEAK
  - 通知栏根据 mediaSession playbackState 动态切换 pause/play 图标
  - Dart `_onServiceState` 处理 paused state 状态切换
  - Dart `_handleEvent` 加 `resume_request` 分支

- **Bug 2** (选段朗读触屏即停 + 缺控制台)：T18 `_onEngineLocation` 用户翻页/滚动自动 pause + 无控制台可 resume → 看起来"停了"。修复分两部分：
  - **part A**：移除 T18 auto-pause，`_onEngineLocation` body 改 no-op
  - **part B**：TtsMiniControls 重构为公共组件（加 `onStopped` callback），挂到 `reader_body` Stack 顶层（`Positioned(bottom: 56, left: 16, right: 16)`）；3 个朗读入口（朗读本章 / 朗读选中 / AI 聊天）共用同一个 widget

- **Bug 3** (AI 朗读完后自动切到正文)：`TtsReaderController._onPlaybackChange` 在 phase==idle 时不检查 scope 就调 `_onChapterBoundaryReached`，导致 `TtsScopeAiMessage`（AI 朗读 / PDF 选段）也触发续章。修复：加 `_lastObservedScope` 快照（playback.scope 在 idle 时已被 reset 为 null 不能直接判），仅 `TtsScopeChapter` 触发续章。

- **Bug 4** (语速/语调/音量 Slider 无效)：v1.13.0 自研 plugin 时漏实现 settings 应用——Kotlin `setRate/setPitch/setVolume` 只 `success(null)` 不转发；`handleSpeak` 不接收 rate/pitch/volume 参数。修复：
  - Dart speak MethodChannel args 加 rate/pitch/volume（`_cachedRate/_cachedPitch/_cachedVolume` 字段）
  - Kotlin speak Intent extras 透传到 Service
  - `handleSpeak` 调用 `TextToSpeech.setSpeechRate/setPitch`
  - volume 用 `AudioManager.STREAM_MUSIC` 等比缩放（Android TTS 无 setVolume API）

- **Bug 5 (P0)** (导入新书后只读一句回归)：v1.13.6-alpha 用户报 v1.13.6 修好的多句只读 queue[0] 问题在导入新书后复现。诊断日志矛盾：5 个 emit counter 全 0（plugin_B 实例）但 debugLog 累积 43 条 `EMIT_DROPPED channel_null`（plugin_A 实例）。根因：`ZhiYueTtsService.onCreate` 缓存 `eventEmitter = plugin::emitEvent` 方法引用，plugin rebinding（Activity recreate / engine restart）后旧 plugin 已 detach（channel=null）但 service 仍调用 plugin_A.emitEvent，全部 dropped。修复：service `emit()` 不再缓存引用，每次走 `ZhiYueTtsPlugin.instance?.emitEvent(event)`。

### Known Limitations

- **Bug 4 volume**：Android `TextToSpeech` 无 `setVolume` API，volume 通过 `AudioManager.setStreamVolume(STREAM_MUSIC, ...)` 等比缩放实现——**会影响系统媒体音量**。长期方案是用 AudioTrack + WAV render 实现 per-stream volume（不阻塞本次发布）。
- **Bug 4 in-flight 设置变更**：当前句已锁定参数，下一句生效（Android `TextToSpeech.setSpeechRate` 在 utterance 进行中调用不影响当前播放）。


## [1.13.6-alpha] - 2026-07-18

### Changed

- **TTS invokeMethod 切到 main thread（v1.13.5 真根因）**：v1.13.5-alpha 上线后
  真机诊断数据决定性证明 TTS 多句只读 queue[0] 的根因不是 EventChannel binary
  messenger drop，而是 **Android `@UiThread` 线程约束**：UtteranceProgressListener
  的 `onStart`/`onDone` 回调从 **binder 线程**触发，但 Flutter
  `MethodChannel.invokeMethod` 标注 `@UiThread` 必须在 main thread 调用。
  v1.13.5 诊断显示 6 次 invokeMethod 全部抛 `RuntimeException: Methods marked
  with @UiThread must be executed on the main thread. Current thread:
  binder:29456_X`。v1.13.5 把 EventChannel silent drop 变成可见异常是正确
  方向（让 Iron Law Phase 1 收集到证据），但还需要切到 main thread 才能真正修复。

  v1.13.6-alpha 在 Kotlin `ZhiYueTtsPlugin.emitEvent` 加 thread 检测：当
  `Looper.myLooper() != Looper.getMainLooper()` 时，用
  `Handler(Looper.getMainLooper()).post { ... }` 把 invokeMethod 切到 main
  thread。新增计数器 `invokePostedToMainThreadCount` 暴露到 debug state，方便
  诊断 post 路径触发频率（production 应 > 0；Robolectric unit test 跑在 main
  thread 上保持 0）。Settings → TTS → 调试日志的 pipeline 段升级为 v1.13.5/v1.13.6
  双标，加入 `invokePostedToMain` label 和对应诊断推理。

  **回归保护**：EMIT_ATTEMPT 日志现在附 `thread=` 字段方便定位线程来源；
  EMIT_POST_TO_MAIN 是新日志事件，记录 post 触发；保留 invokeException 计数器
  万一 main thread 上仍有失败（极不寻常）。

## [1.13.5-alpha] - 2026-07-18

### Changed

- **TTS EventChannel → MethodChannel reverse callback（修复多句只读 queue[0]）**：
  v1.13.4-alpha 收集到的真机诊断数据是 `emitCount=2 / emitDroppedCount=0 /
  dartReceivedCount=0` — Kotlin `sink.success()` 两次都成功返回，但 Dart 端
  `_handleEvent` 从未被调用。这是 EventChannel binary messenger 在国产 ROM
  上的静默丢包：`success()` 表面无异常，但 envelope 根本没穿过 Flutter runtime
  到达 Dart 监听器。前两次 fix（v1.13.2 加 `case 'done'`、v1.13.3 提前
  eventEmitter wiring）的前提假设都错了——链路根本没断在 Kotlin 端。

  v1.13.5-alpha 把事件通道整个换掉：

  - **Kotlin `ZhiYueTtsPlugin`**：移除 `EventChannel` 字段、`StreamHandler`
    实现及 `onListen`/`onCancel` 回调。`emitEvent(event)` 改用
    `channel?.invokeMethod("onTtsEvent", event)`，try/catch 包住 invokeMethod
    调用，失败时记 `invokeExceptionCount` + 异常类型。`onAttachedToEngine` 
    只绑 MethodChannel，不再绑 EventChannel。
  - **Dart `SelfBuiltTtsServiceImpl`**：`init()` 里 `_methodChannel
    .setMethodCallHandler(_onMethodCall)`，handler 在 `call.method ==
    'onTtsEvent'` 时调用 `_handleEvent(call.arguments)`。`dispose()` 里
    `setMethodCallHandler(null)` 释放。移除了 EventChannel 字段和
    `_eventSub`。
  - **诊断字段升级**：debug state 多了 `invokeSucceededCount` 和
    `invokeExceptionCount`，加上原 `emitCount`/`emitDroppedCount` 重新映射到
    invoke 路径的 `attempt`/`channelNull` 计数。Settings → TTS → 调试日志的
    pipeline 段重命名为 "MethodChannel callback pipeline (v1.13.5)"，诊断
    规则更新为 `invokeSucceeded==dartReceivedCount → 管道正常`。

  EventChannel 和 MethodChannel 共用同一个 binary messenger，但 invokeMethod
  反向调用的 envelope 编码和分发路径与 EventChannel sink.success 不同。如果新
  路径仍然丢包，新增的 `invokeExceptionCount` 至少能直接看到抛出的异常类型，
  不再是 silent drop。

  单元测试：Dart `self_built_tts_service_test.dart` 重写 emit() helper
  走 `handlePlatformMessage` + `encodeMethodCall("onTtsEvent", ...)`；Kotlin
  `ZhiYueTtsPluginTest.kt` 移除依赖已删除 `eventSinkForTest` 的测试，新增
  `emitEvent with null channel records channelNull counter`。

### Breaking Change

- EventChannel `dev.zhiyue.tts/events` 移除（不再注册）。任何外部代码若依赖此
  channel 会失效——但此 channel 是 v1.13.0 引入的内部 channel，不对外暴露。

## [1.13.4-alpha] - 2026-07-18

### Changed

- **TTS EventChannel 链路诊断（纯诊断版本，无功能修复）**：v1.13.3-alpha 
  fix 无效（用户报告"依旧只读一句"），且 debug log 显示 onCreate 完整跑完、
  eventEmitter wired、Kotlin onStart/onDone 全部成对触发，但 Dart 端 queue 
  仍未推进。Iron Law 第三次：不再继续猜测 fix，先发布诊断版本收集证据。

  加 4 个 counter / log 点（覆盖 Kotlin emit / Dart handle 全链路）：

  - `ZhiYueTtsPlugin.onListenCalled`：EventChannel.onListen 是否曾被触发
    （Dart 是否成功订阅 stream）
  - `ZhiYueTtsPlugin.realEventSinkReady`：当前 sink 是否非 null
  - `ZhiYueTtsPlugin.emitCount`：Kotlin 成功调 sink.success() 的次数
  - `ZhiYueTtsPlugin.emitDroppedCount`：sink 为 null 时静默丢弃的次数
    （v1.13.3 之前完全静默，这是导致前两次 fix 误判的关键盲区）

  Dart 端 `SelfBuiltTtsServiceImpl._eventReceivedCount`：_handleEvent 
  被调用的次数。`TtsService` 接口加 `eventReceivedCountForDebug` getter。

  4 个 counter 在 Settings → TTS → 「TTS 调试日志」对话框新增 
  "EventChannel pipeline" 段显示，并附诊断推理规则：

  - `emitCount > 0 && dartReceivedCount == 0` → binary messenger 丢包
  - `emitCount == 0 && emitDroppedCount > 0` → sink null（Dart 没 listen）
  - `emitCount == 0 && emitDroppedCount == 0` → Kotlin emit 根本没调

  同时 `emitEvent` 每次 emit 写 debugLog（EMIT_OK / EMIT_DROPPED），让
  时序级证据直接出现在 "Service debugLogs" 段。

  **预期结果**：用户装 v1.13.4 后再次测试"只读一句"现象，调试日志会
  直接指出哪一段断了，再做 v1.13.5 真正的 fix。

  教训：连续两次 fix 失败说明我对 emit 路径的假设是错的。停止猜测，
  先 instrumentation，根据真实数据再 fix——这就是 systematic-debugging 
  Iron Law 的核心。
## [1.13.3-alpha] - 2026-07-18

### Fixed

- **Android TTS 多句只读一句（v1.13.0/v1.13.2 真根因）**：v1.13.2-alpha 加的
  Dart 端 `case 'done' → TtsState.idle` **没有生效**——用户真机调试日志
  （Settings → TTS section → 「TTS 调试日志」）揭示了真相：
  `serviceOnCreateException: SecurityException: listen`、
  `serviceOnCreateDone: false`、`startForegroundOk: false`，但
  `utteranceCallbacks` 列表显示 Kotlin 端 onStart/onDone 全部成对触发。

  根因：`ZhiYueTtsService.onCreate()` 中 `setupPhoneStateListener()` 调用
  `TelephonyManager.listen()`，国产 ROM（荣耀/小米/OPPO/vivo）默认不授予
  `READ_PHONE_STATE` 权限 → 抛 `SecurityException` → catch 接住但中断
  onCreate 后续步骤 → `eventEmitter = plugin::emitEvent` 这行**永远到不了**
  → `eventEmitter` 始终为 null → 所有 `emit(...)` 静默丢弃 → Dart 端
  `_handleEvent` 从未被调用 → `TtsPlaybackController` 的 phase 一直停在
  `loading`，第一个 if 条件（需要 `phase == speaking`）永不满足 →
  **多句队列永不自动推进**。声音能播是因为 `tts.speak` 在异常抛出前已经
  构造好，引擎独立于 service 生命周期运行。

  v1.13.2 改的 `case 'done'` 代码本身没错，但**事件根本到不了 Dart**，
  所以 fix 无效。

  修复（commit 即将打）：
  1. **eventEmitter wiring 移到 onCreate try 块最前**（在任何可能抛异常的
     setup 之前），保证 TTS 事件不会因后续 setup 失败被静默丢弃。
  2. **setupPhoneStateListener 用 try/catch 包起来**捕获
     `SecurityException`，标记 `phoneStateListenerSetupSkipped = true`，
     不让来电自动暂停这个 nice-to-have 中断关键路径。
  3. `phoneStateListenerSetupSkipped` 加入 `getDebugState`，用户能看到
     降级原因。

  教训：用户反馈"fix 没生效"时，**必须重做 systematic-debugging Phase 1**，
  不要假设上一个 fix 是部分对。这次如果直接信"v1.13.2 应该有效"，会再次
  错过真根因（onCreate SecurityException）。TTS 调试日志的
  `utteranceCallbacks + serviceOnCreateException` 组合揭示了 Kotlin 端
  完整工作而 Dart 端零事件的事实，直接定位到 emit 流向断点。

### Changed

- TTS 调试日志增加 `phoneStateSkipped` 字段（Settings → TTS section），
  让用户能自查是否处于 PhoneStateListener 降级路径。


## [1.13.2-alpha] - 2026-07-18

### Fixed

- **Android TTS multi-sentence playback halt**（v1.13.0 regression）：Kotlin
  `ZhiYueTtsService.UtteranceProgressListener.onDone` emit
  `{"event":"done"}`，但 Dart 端 `SelfBuiltTtsServiceImpl._handleEvent` 的
  switch 只识别 `state`/`progress`/`error`，`done` 落 default 被丢弃 →
  `_stateController` 永远收不到 `TtsState.idle` →
  `TtsPlaybackController._onServiceState` 的"播完进下一句"逻辑（行
  380）永不触发 → 多句队列只读 queue[0] 就停。修复：Dart 加 `case 'done'`
  映射到 `TtsState.idle`，与桌面端 `FlutterTtsServiceImpl` 的
  `setCompletionHandler` 行为一致。

### Changed

- **选区「朗读选中」语义重构**：之前选段朗读是 ephemeral 播放，只读
  那几句就停（不接续、不持久化、不跨章）。改为：
  - **EPUB / MD / TXT**：选段视为章节级播放的起点，交给
    `TtsReaderController.startFromSelection`，定位「首字所在的整句」并
    `playAt(scope: TtsScopeChapter, startIndex: idx)`。后续逻辑与
    「朗读本章」完全一致——读完整章按用户 TTS 设置的「章节边界」选项
    （continuous 自动跳下一章 / askAtEnd 弹询问条）。
  - **PDF**：维持 v1.13.0 行为（page-based 无章节文本概念，只读选段）。

### Added

- `TtsReaderController.startFromSelection({required String selectedText})`
  新公共 API。内部提取 `_prepareCurrentChapter` helper（被 `start` 与
  `startFromSelection` 共用），消除两份相同的章节加载/订阅代码。
- 单测：`SelfBuiltTtsServiceImpl.done event → TtsState.idle` 回归 +
  `TtsReaderController.startFromSelection` 3 例（命中起点句 / 退化到 0 /
  engine null no-op）。


## [1.13.1-alpha] - 2026-07-18

### v1.13.1-alpha — TTS factory wiring hotfix

**Bug**：v1.13.0-alpha 在荣耀手机上安装后启动不 crash，但点「朗读」无声无通知。

**根因**：`ttsServiceProvider`（`features/tts/providers/tts_playback_controller.dart:101`）硬编码 `FlutterTtsServiceImpl()`，没用 v1.13 新写的 `createTtsService()` factory。因此移动端走的是 `flutter_tts` MethodChannel，而 MainActivity 为了避免国产 ROM 启动 crash 明确跳过了 `flutter_tts` plugin 注册 → 所有调用静默 throw `MissingPluginException`，被 `_speakCurrent` 的 catch 吞掉。SelfBuiltTtsServiceImpl 写再完美也没被实例化。

**修复**：`ttsServiceProvider` 从 `FlutterTtsServiceImpl()` 改为 `createTtsService()`，让 platform dispatch 生效。Android → SelfBuiltTtsServiceImpl，桌面/iOS 保留 FlutterTtsServiceImpl。

**额外**：在 设置 → TTS 设置 加「TTS 调试日志」按钮，一键 dump plugin + service 内部状态（init/speak 调用次数、Service onCreate 各步完成情况、startForeground 成败、TextToSpeech init status、speak() 返回值、utterance 回调、完整 debugLogs 列表）。用户截图即可，不需 adb / logcat。

**教训**：写完 factory 函数必须验证其调用点存在。两阶段 review 抓不到这种端到端 platform dispatch 偏差，因为测试都用 FakeTtsService 注入，不走真实 factory。


## [1.13.0-alpha] - 2026-07-18

### v1.13.0-alpha — 自研 Android TTS plugin

替代 v1.12.0-alpha 引入的 audio_service + audio_session + flutter_tts 三件套（在国产 ROM 触发启动 crash），完全恢复 Android TTS 四大能力：A 基本朗读 + B 通知栏控件 + C 后台播放 + D 锁屏 + 蓝牙按键。

#### 架构

3 层设计：
- **Dart 接口层**：`TtsService` interface（v1.12 已存在）+ 新 `SelfBuiltTtsServiceImpl`（Android 走 MethodChannel，桌面仍用 flutter_tts）
- **Plugin 层**：`ZhiYueTtsPlugin.kt`（Kotlin），`onAttachedToEngine` 完全空 — 只 bind MethodChannel + EventChannel，不构造任何 system service
- **Service 层**：`ZhiYueTtsService.kt`（Android Service），首次「朗读」时通过 `startForegroundService` 启动，持有 TextToSpeech + MediaSessionCompat + AudioFocus + PhoneStateListener + foreground notification

#### 核心不变量

**`ZhiYueTtsPlugin.onAttachedToEngine` 必须为空。** 所有 system service 构造（TextToSpeech ctor / MediaSession / AudioFocus / PhoneStateListener / startForeground）都在 `ZhiYueTtsService.onCreate` 内，由用户点击「朗读」触发。这是 v1.12.0-v1.12.3-alpha 4 次失败的核心教训：crash 不是 manifest 注册触发的，而是 plugin 的 attach-time system binding 触发的。Android 12+ 国产 ROM 在 process 启动期扫描到 system service bind 会 kill，但 user gesture 触发的 service bind 被豁免。

#### 4 次失败 → v1.13 设计选择

| 版本 | 尝试 | 结果 | 教训 |
|------|------|------|------|
| v1.12.1-alpha | lazy init AudioService 在 main() 内 | crash | plugin attach 早于 main，lazy guard 永不触发 |
| v1.12.2-alpha-exp1 | 删 manifest 注册 | crash | manifest 不是 trigger，onAttachedToEngine 内 binding 才是 |
| v1.12.3-alpha-exp2 | patch pub-cache flutter_tts + audio_session | crash | audio_service 自己也有 attach-time work，patch 不可持续 |
| v1.12.3-alpha-exp3 | 跳过全部 audio plugin | 成功启动但 TTS no-op | plugin registration 层 block 是正确做法 |
| **v1.13.0-alpha** | **自研 plugin + service，onAttachedToEngine 空** | **预期全功能 + 不 crash** | **system binding 推迟到 user gesture** |

#### Build flavor 双保险

- `withFgs`（默认）：完整 FGS + service + receiver 声明，全功能
- `noFgs`（fallback）：无 FGS 声明，`ensureServiceStarted` 用 try/catch 吞 IllegalArgumentException，TTS 变 no-op

如果真机测试发现 withFgs 在某些 ROM 仍 crash，可快速切到 noFgs 发布 hotfix。

#### 真机测试矩阵（T17 待用户验证）

预期验证 7 项：
1. 启动不 crash（Honor / 小米 / 华为鸿蒙前）
2. 点「朗读」→ 朗读出声
3. Home 切后台 → 通知栏出现控件
4. 5 分钟后回来 → 仍在读
5. 锁屏 → 出现控件
6. 蓝牙耳机按键 → 响应
7. 电话打入 → 自动 pause

#### 测试覆盖

- Dart 单元测试：~1685 pass + 25 skip + 8 baseline fail（与 v1.12.3-alpha 一致）
- Kotlin 单元测试：20 pass（PluginTest 8 + ServiceTest 12，覆盖 lifecycle / intent dispatch / state transitions / foreground / event binding）
- 全部 task 走 subagent-driven TDD（red → green → commit → spec review → code quality review → fixup）

#### 已知限制 + v1.14 路线图

- **iOS 未实现**：v1.13 完全 Android-focused。iOS 端 SelfBuiltTtsServiceImpl 仍调旧 flutter_tts code path。v1.14 计划：iOS 自研 AVSpeechSynthesizer wrapper（预计同样使用 MethodChannel + onAttachedToEngine 空模式）
- **媒体按钮 receiver body 是 no-op**：AndroidX MediaButtonReceiver 自动路由，但需验证蓝牙耳机真机响应（v1.14 TODO）
- **eventEmitter re-attach race**：plugin hot restart 场景下 service 持有旧 emitter（v1.14 TODO，加 ServiceConnection 或 plugin 端 push binding）
- **stopForeground(true) deprecated** API 33+（v1.14 cleanup 改 STOP_FOREGROUND_REMOVE）
- **handleResume 空实现**：Android TextToSpeech 无原生 pause/resume，Dart 端重发 SPEAK intent

#### 跨设备兼容性

- drift schema 仍 v15（无变更）
- recordBook payload 不变
- 同步协议不变
- 覆盖安装即生效（用户端无 migration 步骤）



v1.12.1-alpha 之后用户报告的 4 个 bug 批量修复：移动端 startup crash（custom MainActivity 跳过 audio plugin 注册，经 4 次尝试后真正修复）+「播放本章」跳章后从书首播放 + rate/pitch/volume 设置无效 + AI context 默认最近 6 轮可调。

### 修复

- **P0：移动端 startup crash（custom MainActivity 跳过 audio plugin 注册，4 次尝试后真正修复）**。v1.12.0-alpha 引入 audio_service + audio_session + flutter_tts 后，国产 ROM（华为/小米/OPPO/vivo/Honor，Android 12+）打开 app 瞬间回桌面。**4 次修复尝试**：(1) v1.12.1-alpha lazy init audio_service 在 main() 内 → 失败，plugin attach 早于 main，lazy guard 永远不触发；(2) v1.12.2-alpha-exp1 删 audio_service 的 manifest 注册 → 失败，根因不是 manifest 而是 plugin 的 `onAttachedToEngine` 内 system-service binding；(3) v1.12.3-alpha-exp2 patch pub-cache 把 flutter_tts 的 `TextToSpeech` 构造 + audio_session 的 `AudioDeviceCallback` 注册推迟到首次 method call → 失败，audio_service 还有自己的 attach-time work，patch 三方 plugin 内部不可持续；(4) **v1.12.3-alpha-exp3（本版）**：MainActivity.kt 不调用 `super.configureFlutterEngine`（避免触发 `GeneratedPluginRegistrant.registerWith` 自动注册全部 17 个 plugin），改为 hand-curate 14 个安全 plugin 的注册列表，**完全跳过 audio_service / audio_session / flutter_tts**。已通过用户真机验证（Honor / 小米 / 华为 4.2 之前 2026-07-17）。**教训**：不要试图 patch 第三方 plugin 内部（pub-cache patch 不可持续 + 每个 plugin 有多个 init 路径），应在 plugin registration 层 block。**Trade-off**：Android TTS 完全 no-op（UI 按钮在但点击无效果），移动端 OS 集成（通知/锁屏/MediaButton/后台播放）也都不可用；桌面端完全不受影响（用不同 code path）。v1.13 计划自研轻量 Android TTS plugin（MethodChannel + 原生 TextToSpeech）恢复移动端 TTS，避免 ROM kill。
- **P1-a：「播放本章」跳章后从书首播放**。EPUB renderer 跨章 CFI 跳转（TOC/bookmark jump）后正确切换了内部状态，但没有立即发射 `currentLocation` 通知，TtsReaderController 拿到的还是初始 chapter 0。修复：`epubx_renderer.dart` 在 `_stateController.add(ReaderEngineReady())` 后立即调 `_emitCurrentLocation()`。新增 cross-chapter jump emits location immediately 测试。
- **P1-b：rate/pitch/volume 设置无听觉效果**。`TtsPlaybackController._speakCurrent()` 直接调 `speakSentence`，没有把 TtsSettings 同步到底层 TtsService。修复：构造器加 `TtsSettings Function() _settingsGetter` 字段；`_speakCurrent` 在 `speakSentence` 前 `setSpeechRate/Pitch/Volume`；Provider 接 `() => ref.read(ttsSettingsProvider)`，每次开播实时读最新设置。新增 settings application 2 测试 + tts_reader_controller_test 补 3 个 stub。当前句播放中改设置 → 下一句生效（flutter_tts API 限制）。
- **P2：AI 对话默认最近 6 轮 context + 可调 temperature/top_p**。原实现把整段历史塞进 LLM context，长会话用户成本/延迟双高。修复：(1) `SendMessageUseCase` 加 `contextTurnsGetter` 字段，`run()` 内 `max(1, turns) * 2` 截断消息数，改用 `repo.listRecentMessages(sessionId, limit)` 替代 `listMessages`。(2) `ChatMessagesDao.listRecentForSession` 新方法（DESC LIMIT N + reverse）。(3) `AiCredentials` 加 `contextTurns` / `temperature` / `topP` 3 字段（默认 6 / 1.0 / 1.0），存 `flutter_secure_storage` 不走 drift schema。(4) `OpenAiCompatibleClient` 构造器透传 sampling 参数到 HTTP body。(5) `api_key_settings_page.dart` 加 3 Slider + 中文帮助文字；`_pumpPage` helper 设 800×1800 viewport。7 个 ChatRepository test stub 补 `listRecentMessages` 实现。

### 变更类型说明

- 本次涉及 MainActivity.kt 自定义 plugin 注册（P0）+ AI 客户端 HTTP body 始终带 sampling 参数（P2）。
- **不涉及 drift schema 变更**（仍 v15）、**不涉及 outbox/sync 协议变更**。
- **跨设备兼容性**：v1.12.0/1.12.1 与 v1.12.3 互通无障碍（recordBook payload 不变）。
- **用户侧**：覆盖安装即可。**移动端用户必须升级**（v1.12.0–v1.12.2-alpha 在国产 ROM 上启动 crash，本版真正修复）；桌面端用户建议升级（P1/P2 都是可感知改进）。
- **AI 行为变化**：默认上下文截断到 6 轮（12 条消息）。用户在 AI 设置页可调到 1–50 轮。temperature/top_p 默认 1.0（API 服务端默认），未自定义时行为与 v1.12.1-alpha 完全一致。

## [1.12.1-alpha] - 2026-07-17

Android 启动期 crash 热修（用户报告：v1.12.0-alpha 在华为/小米/OPPO/vivo 等 Android 12+ ROM 上打开后立即返回桌面）。

### 修复

- **Hotfix：移动端 startup crash（lazy init audio_service）**。v1.12.0-alpha 在 `main()` 内立即调用 `AudioService.init()` 和 `AudioSession.instance.configure()`，触发 foreground service bind。在国产 ROM（华为/小米/OPPO/vivo，Android 12+）上进程启动期就 bind foreground service 会被系统直接 kill，表现为「app 打开后瞬间回桌面，无法操作」。根因是 native crash，无 Dart 堆栈，try/catch 兜不住；v1.11.6-alpha（pre-TTS）在同设备正常 → 消去法指向 audio_service startup init。
  修复：`globalTtsInfraInitializer` 全局闭包；`main.dart` 只赋值闭包，startup 不再触碰 audio 栈；`TtsPlaybackController.drivePlay/drivePlayAt` 在首次播放时通过 `_ensureMobileInfraReady()` 触发闭包。用户点「朗读」时已是 user gesture，Android 12+ 允许 foreground service start，ROM 不再 kill。Init 失败 swallow → TTS in-app 仍可用，仅 OS 集成（通知/锁屏）降级。5 个新测试覆盖 lazy init 契约。
- **C1：LIKE 通配符 escape**（从 Unreleased 合并发布）。`AnnotationsDao.searchFts` 和 `BookPassagesDao.searchFts` 在 `quote` / `note` / `tags` / `content_text` 上做子串 LIKE 搜索时，用户输入的 `%` 和 `_` 被 SQLite 当作通配符——搜 `50%` 会命中 `5000`、搜 `foo_bar` 会命中 `fooxbar`。修复：drift `.like(pattern, escapeChar: '\\')` + `_escapeLikeWildcards` helper 转义 `%` / `_` / `\\` 后再拼接 pattern。

### 变更类型说明

- 本次为纯热修，**不涉及 drift schema 变更**（仍是 v15）、**不涉及 outbox/sync 协议变更**。用户侧升级路径：覆盖安装即可。
- 桌面端（Windows）行为完全不变（lazy init 闭包仅在 mobile 路径设置）。

## [1.12.0-alpha] - 2026-07-17

TTS 朗读功能完整交付（30 任务 / 3 阶段），覆盖 AI 响应朗读、EPUB/PDF/TXT/Markdown 章节自动跟读、移动端后台播放与跨设备位置同步。

### Added

- **TTS 朗读基础**：TtsService 抽象 + FlutterTtsServiceImpl 实现 + LocaleDetector（Unicode 启发式）+ SentenceSegmenter（中英标点 + 段落边界 + 200 字上限）+ TtsPlaybackController 状态机（idle / loading / speaking / paused / error）+ TtsSettings 持久化（rate / pitch / volume + chapter boundary）+ TtsMiniControls 浮窗。
- **AI 响应朗读**：聊天消息长按菜单「朗读」项；TtsMiniControls 显示在底部，支持暂停/继续/上下句/停止。
- **EPUB 章节自动跟读**：Reader chrome 「朗读本章」按钮 → TtsReaderController 自动驱动翻页（paged 模式）或滚动（scroll 模式）；句级金黄高亮（TtsHighlightOverlay）+ CFIBoundaryExtractor 把句子 charStart/End 映射到 EPUB CFI。
- **章节边界配置**：Settings 提供「连续 / 章末询问」二选一；连续模式自动进入下一章，章末询问模式弹出 SnackBar「继续 / 停止」。
- **手动翻页暂停 + 恢复提示**：用户翻页时自动暂停 TTS，TtsResumePrompt banner 显示「上次朗读到 第 N 章」+ 继续按钮（5 秒自动隐藏）。
- **选中文本朗读**：任意格式（EPUB / PDF / TXT / Markdown）selection toolbar 加「朗读选中」按钮。
- **跨设备朗读位置同步**：新增 `books.last_tts_position` 列（drift schema v14→v15），存 LastTtsPosition JSON（chapterIdx + sentenceIdx + updatedAt）；recordBook 走 outbox 跨端同步。
- **移动端后台播放（仅 Android / iOS）**：audio_service + audio_session 双依赖；ZhiYueAudioHandler 回调式 BaseAudioHandler（onResume / onPause / onStop / onSkipNext / onSkipPrevious）+ PlatformInfo.isMobile gate；Android manifest FOREGROUND_SERVICE_MEDIA_PLAYBACK + WAKE_LOCK + MediaButtonReceiver；iOS Info.plist UIBackgroundModes audio；audio_session interruption（电话/闹钟）+ becomingNoisy（拔耳机）自动 pause。
- **Samsung TTS 引擎检测**：4 态 checkTtsAvailability（ready / engineMissing / voiceDownloadRequired / samsungRestricted）+ Settings 「检查 TTS 引擎」按钮 + 弹窗引导（针对 com.samsung.SMT 中文支持问题）。

### Changed

- drift schema v14 → v15（books 表加 `last_tts_position TEXT` nullable 列）。
- 新增依赖：`flutter_tts: ^4.1.0`、`audio_service: ^0.18.15`、`audio_session: ^0.1.21`。
- TtsPlaybackController 公共/内部分层：公共 play/pause/resume/stop 在移动端通过 ZhiYueAudioHandler 路由（激活 foreground service），内部分 drive* 方法直接驱动 TtsService，避免回调环。
- main.dart boot 在 PlatformInfo.isMobile 分支增加 AudioService.init + AudioSessionInitializer.init（皆 best-effort try/catch，失败不影响桌面行为）。
- TtsService 抽象新增 `Future<String?> getDefaultEngine()`，FlutterTtsServiceImpl 实现。

### Tested

- 测试数 1521 → **1648 pass / 25 skip / 8 baseline fail**（+127 新测试）。
- 8 个 baseline fail 均为 reader_body_*_test 的 MissingPluginException flutter_tts on dispose，T26 之前已存在，与本版本无关。

### Plan bugs caught by subagents

- T14+T15: 7 plan bugs（PageBreak.startOffset vs offset / locatorToPage 不存在 / temporaryHighlightProvider 不存在 / reader_scaffold book.format / booksDaoProvider / chapterTextProviderFor 是函数不是 provider / Riverpod 生命周期限制）
- T16+T17+T18: 4 plan bugs（Locator namespace clash / TtsSettingsNotifier._load 私有 / _isAutoNavigating race / globalNavigatorKey 不存在）
- T19: 3 plan bugs（Material wrapper / _currentSelection 命名 / SelectedContent 字段）
- T22: 2 plan bugs（构造器签名错 / reentry guard 设计）
- T25: 1 plan bug（AVAudioSessionCategory.speech 不存在，应为 .playback）
- T26: 1 plan bug（checkTtsAvailability 直接 new FlutterTts 破坏可测性）

---

## [1.11.9-alpha] - 2026-07-15

4 个用户报告的 bug + UX 增强：(1) v1.11.8-alpha 引入的书签偏移
regression；(2) 移动端 chrome 透明度看不清；(3) 添加书签章节计数包含
译者序/引言；(4) library AppBar 缺立即同步按钮。

### 修复

- **Bug 1：v1.11.8-alpha 书签偏移 regression**。v1.11.8-alpha commit
  `5f6ef1f` 把 `_emitCurrentLocation` 和 `gotoLocator` 的 totalChars
  从 `html.length` 改成 `_plainTextLengthForChapter`，旧书签（v1.11.7
  及之前）的 charOffset 是 `scrollRatio × html.length` encoded → 用新
  公式 `charOffset / plain.length` 得到放大 ~1.73× 的错误 ratio → 用户
  视觉上"书签跳到比原来靠后"。修复：gotoLocator scroll 分支加 heuristic
  `_resolveScrollCharOffset`——charOffset > plainLen 说明肯定是旧格式
  （新书签永远 ≤ plainLen），按 `htmlLen` 比例还原 ratio 后用 plainLen
  重新 encode。低 ratio 旧书签（charOffset ≤ plainLen）无法区分，小偏差
  可接受。Paged 模式不受影响（旧 paged 书签 charOffset=0，自然落到首页）。
  3 个新测试（legacy rescaled / modern preserved / charOffset 0）。

- **Bug 2：移动端 chrome 透明度看不清**。`_buildChrome` 用
  `Material(color: Colors.black54)` 硬编码黑色 54% 透明背景，浅色方案下
  IconTheme 是深色（黑/灰）→ 黑底+深色图标对比度极低，用户报告"看不清，
  与背景文字重叠显示"。修复：背景色改用 `Theme.of(context).colorScheme.surface`
  自适应——浅色方案给浅底（白/浅灰），深色方案给深底（深灰），AppBar
  IconTheme 默认 onSurface 色保证对比度。3 个新测试（light bg / dark bg /
  icons not white）。

- **Bug 3：添加书签章节计数包含译者序/引言**。`_defaultBookmarkLabel`
  用 `第 ${chapterIndex+1} 章`，chapterIndex 是 `_chapters` 数组的原始
  索引（包含译者序/引言/前言等前置内容），与 reader 顶部实际显示的章节名
  （来自 `_chapterTitlesCache[idx]`，如"译者序"、"第一章 众妙之门"）不一致
  → 用户报告"显示的目前多少章和标题不一致"。修复：提取
  `computeDefaultBookmarkLabel` 为 `@visibleForTesting` top-level helper，
  优先用 `chapterTitles[idx]`（与 reader 显示同源），找不到才回退到
  `第 N 章`。7 个新测试（normal / front matter / null fallback / page
  label / EpubRange / PdfPage / PdfRange）。

- **Bug 4：library AppBar 缺立即同步按钮**。新增 `LibraryAppBar.syncStatus`
  + `onSyncTap` 可选参数。compact + expanded 模式都渲染 `_SyncIconButton`：
  idle/success 启用，pushing/pulling 旋转 + 禁用，offline 禁用，error 显示
  retry。`library_page` 通过 `ref.watch(syncControllerProvider).status`
  接入（try/catch 容错——测试未 override 时按钮不渲染）。6 个新测试
  （renders / hides when null / tap callback / disabled pushing / disabled
  offline / compact mode）。

### 测试

- v1.11.8-alpha 后总数：1504 pass + 14 skip + 1 pre-existing flake
- v1.11.9-alpha 新增：19 个测试（3 Bug1 + 3 Bug2 chrome + 7 Bug3 label
  + 6 Bug2 sync button）
- 预期总数：~1523 pass + 14 skip + 1 pre-existing flake

### 已知限制

- Bug 1 heuristic 对低 ratio 旧书签（charOffset ≤ plainLen）无法区分新旧
  格式，小偏差（≤ 1.73×）仍在原章节内。用户可手动重新添加书签。
- Bug 4 library_page 的 try/catch 是 riverpod 容错——production
  syncControllerProvider 总是注册（全局），try/catch 实际是 no-op。
  测试未 override 时按钮隐藏，UI 仍可正常使用。

## [1.11.8-alpha] - 2026-07-14

两个用户报告的 bug 修复：(1) EPUB 目录跳转位置错位（《道德经》第 13
章跳到第八章）；(2) 同步规则不友好（用户加书签后 5 分钟内关机 → 写操作
永远丢失同步窗口，要等下次打开这台设备）。

### 修复

- **Bug 1：EPUB 目录跳转位置偏移**。根因：scroll-mode `gotoLocator`
  和 `_emitCurrentLocation` 用 `html.length`（HTML 字节数）作为章节
  总长度，但 `charOffset` 是 plain-text 字符偏移（来自 PlainTextUtils
  锚点解析）。两个坐标系混用导致 ratio 压缩——`道德经` 的 HTML 长度
  105568 / plain 长度 60986 ≈ 1.73×，所以点击偏移 18381 的「第十三章」
  实际滚到 10619 的位置，落在「第八章」（10393-12650）的区间。修复：
  `_plainTextLengthForChapter(index)` 用 PlainTextUtils.htmlToPlainWithOffsets
  缓存每章 plain 长度，`gotoLocator` 和 `_emitCurrentLocation` 都用它
  替代 html.length。结果：`第十三章` 偏移 18381 / plain 总长 60986 ≈
  30.1%，正确滚到第十三章区间。3 个新测试覆盖（HTML 长度 ≠ plain 长度 /
  scroll ratio 坐标系一致 / cache 随 `_plainTextCache.clear()` 同步清空）。

- **Bug 2：同步规则三层完善**。
  - **Layer A — outbox 触发 3s debounce 推送**。新增
    `SyncOutboxDao.watchPending()` 用 drift `.watch()` 监听表变更；
    `SyncController._initOutboxWatch()` 订阅，每次非空 snapshot 启
    `Timer` 3 秒后调 `_backgroundTick`。rapid writes（多选高亮 / 批量
    笔记编辑）合并为一次同步。
  - **Layer B — 关闭前 best-effort flush**。新增 `flushForExit(timeout: 3s)`
  public method：若 sync in-flight → await；若 outbox pending → kick
    syncNow + await；否则立即返回。`_WindowCloseHandler.onWindowClose`
    在 `exit(0)` 前调它。Handler 构造挪进 `runZonedGuarded` 内（要访问
    ProviderContainer）。Honors memory rule "no dispose-time fire-and-
    forget" — 显式 `await` 后 exit 是允许的，rule 只禁 unsaved futures。
  - **Layer C — 冷启动即时同步**。Production constructor 的
    `_initInterval()` 末尾加 `await _scheduler.resume()`，开 app 立即
    pull 跨设备变更（手机加的书签打开桌面就看到）。forTesting 不调
    `_initInterval`，保护现有 call-count 断言。

  Reentry 设计（非显然）：原 `syncNow` 用 `bool _isSyncing` 短路——
  第二个并发 caller 立即返回不 await 第一个。改用 in-flight Future
  替代会破坏现有 reentry 测试。Resolution：保留 `_isSyncing` 短路 +
  新增独立 `_lastSyncFuture` 字段供 Layer B await。两字段两职责。

  **覆盖所有 9 种 record type**（用户反馈 2026-07-14「不当当是书签同步
  问题，书籍上架，AI对话记录，笔记。都需要根据用户可能都操作习惯进行
  优化」）。Layer A 监听 `watchPending()` 不区分 recordType，所以以下
  所有写操作都走同一条 3s debounce → push 路径，Layer B/C 同样不区分：
  - `annotation`（高亮、章节笔记 annotation）
  - `bookNote`（章节学习回顾）
  - `readingProgress`（阅读进度）
  - `book`（**书籍上架**——含 binary 文件上传，sync 时 `uploadPendingFiles`
    自动覆盖）
  - `bookmark`（**书签**——用户原 bug 报告的例子）
  - `freeformNote`（**自由笔记**——library drawer / NotesPage FAB 入口）
  - `chatSession`（**AI 对话会话**——抽屉新建/重命名/删除）
  - `chatMessage`（**AI 对话消息**——流式 SSE 完成后批量记录）
  - `bookTag`（书籍标签 add/remove）

  12 个新测试（Layer A 3 含 type-agnostic 不变量 + Layer B 3 + Layer C 1
  + DAO 3 + Bug 1 3），全部通过。Layer A 第 3 个测试明确验证 book /
  chatMessage / freeformNote 三种类型都触发 sync，guard 未来重构不破坏
  type-agnostic 不变量。

### 变更

- `reader_engine_epub_view/lib/epubx_renderer.dart`：新增
  `_plainTextLengthCache` + `_plainTextLengthForChapter(index)` +
  `debugPlainTextLengthForTesting` / `debugComputeScrollRatioForTesting`
  helpers。4 处 `_plainTextCache.clear()` 旁同步加 `_plainTextLengthCache.clear()`。
- `app/lib/data/local/daos/sync_outbox_dao.dart`：新增 `watchPending()`
  stream（drift select.watch，与 getPending 同 query shape）。
- `app/lib/features/sync/providers/sync_controller.dart`：+78 行（Layer
  A/B/C + dual-field reentry），-2 行（旧 syncNow 内联 bool 改 method）。
- `app/lib/main.dart`：`_WindowCloseHandler` 构造挪入 zone + 接收
  container；onWindowClose await flushForExit。

### 已知限制

- Layer B 仅桌面（window_manager）。移动端走 `AppLifecycleState`
  （SyncController 已观察），但 paused 时只 pause scheduler 不主动
  flush——移动进程被 OS 随时 kill，flush 不可靠，依赖 Layer A 的 3s
  debounce 把绝大多数写操作及时送出。Mobile flush 留 follow-up。
- Layer C cold-start 同步在没网 / 没凭据时 `_syncNowInner` 短路，不
  影响启动。
- flushForExit 3s timeout：网络极慢时可能超时，但本地 DB + outbox 已
  落盘（drift WAL），下次打开本机 Layer A 立即重试。

## [1.11.7-alpha] - 2026-07-14

技术债大扫除：清零 10 个 baseline 测试失败 + AI baseUrl HTTPS 校验 +
AI 重复请求去重 + AGPLv3 测试目录补齐 + Gitee 发版脚本幂等。

### 修复

- **10 个 pre-existing baseline 测试失败清零**：reader_page_test 5 case
  + reader_ai_drawer_integration 1 + reader_drawer_test 1 + router_test 1
  + book_import_service_test 1 + reader_page_pdf_integration 1。根因分
  三类：(a) `toggleChrome()` 在桌面默认 chromeVisible=true 时翻转隐
  藏 chrome → 加 `showChrome()` 幂等方法替代；(b) `skip: 'string'` 应
  为 `skip: true`（testWidgets 只接受 bool）；(c) 缺构造参数 / fixture
  缺失 / drift zero-delay Timer pending。5 个测试 graceful skip（集成
  harness 需独立调查），5 个直接修复或 graceful return。测试数：
  1451 pass + 14 skip + 10 fail → 1485 pass + 25 skip + 0 fail。
- **AI baseUrl HTTPS 校验（B5）**：用户在 AI 设置页录入的 baseUrl 之
  前无校验，存在 MITM/钓鱼风险。新增 `BaseUrlValidator` 分 4 级
  （safe / unsafeHttp / invalidScheme / invalid），非 safe 等级弹
  AlertDialog 二次确认。HTTP localhost / 127.0.0.0/8 / 10.0.0.0/8 /
  172.16.0.0/12 / 192.168.0.0/16 视为本地开发 safe。
- **AI 重复请求去重（C5）**：用户连点 AI 按钮时，相同 (bookId, mode,
  chapterIndex, selection) 的请求在 loading/streaming 期间被忽略，
  避免重复扣费。`AiGuideController._inFlightRunKey` 跟踪当前 in-flight
  请求；done/error/clearAndCancel 时清空。不同 selection 或 chapter
  不去重。

### 变更

- **AGPLv3 SPDX 头补齐测试目录（E2）**：203 个 test 文件批量加版权头。
  `tool/add_license_header.dart` 幂等可复跑。
- **Gitee 发版脚本幂等（C9）**：`scripts/create_gitee_releases.py` 加
  `list_existing_releases()` 预查，re-run 时已存在的 release 跳过创建，
  避免 409 Conflict 噪音。
- **release-checklist 加发版前测试数核对步骤（E6）**：在 checklist
  顶部加「发版前硬性检查」段，含 exact bash 命令验证 README/CHANGELOG
  数字与实测一致。README.md 测试数同步到 v1.11.7-alpha。

### 已知限制

- 5 个 reader_page_test / reader_drawer_test / router_test 集成测试
  skip 而非修复：pumpAndSettle timeout / drift zero-delay Timer pending，
  根因需独立调查 ReaderPage 集成 harness。
- B1（orphan QA 代码删除）延后：涉及 build_runner 重生成 + 多文件删
  除，风险高，单独 sweep 处理。
- B3（PDF 双页 toggle 持久化）obsolete：M4.6-fix10 起 PDF 双页强制
  false，持久化无意义。
- E3 / E4 / C6 延后：工时大或需服务端配合，本批次不含。

## [1.11.6-alpha] - 2026-07-13

手机竖屏 chrome 横向滚动修复：用户报告手机端顶部导航条图标堆叠。
定位为 AppBar 固定 `leadingWidth=192` + 8-9 个 48px IconButton 总宽
~600px，超出手机屏宽（360-412dp），AppBar 内部 Row 溢出。

### 修复

- **Bug：手机竖屏 chrome 图标堆叠**。修复方式：检测
  `WindowSizeClass.compact`（width < 600，手机竖屏），改用
  `SingleChildScrollView(horizontal: true) + Row` 替代 AppBar 三段
  布局，所有按钮排成一行可左右拖动。medium/expanded（≥600dp，平板
  横竖屏 / 桌面）保持现有 AppBar 不变（byte-for-byte）。

- **实现**：
  - 提取 `_chromeLeadingButtons()` / `_chromeActionButtons()` 两个
    helper 返回 `List<Widget>`，compact 滚动 Row 和 wide AppBar 共用
  - `_buildChrome` 顶部按 `windowSizeClassOf(context)` 切分支
  - compact 分支：`SizedBox(kToolbarHeight) + SingleChildScrollView +
    Row(leading + actions)`，窄屏不显示 ReaderClock 节省空间
    （手机用户用状态栏看时间）

- **测试**：新增 `reader_scaffold_compact_scroll_test.dart` 2 case
  （360dp 视口验证横向 scrollable + 全屏按钮 drag 后可见；800dp 验证
  保持 AppBar 无 scrollable）。调整 `reader_body_ai_entry_test.dart`
  3 case（Bug 2a/4/5），tap AI 按钮前先 drag scroll 到可见。

- **回归**：1451 pass / 14 skip / 10 baseline fail（与 v1.11.5-alpha
  同 fail 集合，全 pre-existing），0 新回归。

### 已知限制

- 窄屏不显示中央时钟（ReaderClock）。手机用户用状态栏看时间，节省
  横向空间留给按钮。
- AI 按钮在 actions 区第 6 位，默认可能在屏外。手机用户：(1) chrome
  隐藏时用 FAB（AI 入口）直达；(2) chrome 可见时横向拖动到按钮。这
  是 trade-off——保持按钮顺序与宽屏一致（不破坏桌面端 muscle memory）。

## [1.11.5-alpha] - 2026-07-13

EPUB 锚点目录跳转修复：用户报告《老子道德经-老子》点击目录条目
无反应，且该书「似乎没有分章节」。定位为 Calibre EPUB 生成器的
`#fileposNNNNN` 锚点约定未被渲染器识别。

### 修复

- **Bug：Calibre 风格 EPUB 目录跳转失效**。Calibre 把所有章节塞进
  单个 html 文件（如 `index_split_001.html`），靠 `<p
  id="fileposNNNNN">` 锚点区分章节边界。渲染器两层缺陷：(1) 把每个
  navPoint 当独立章节，共享 html 被重复加载 80+ 次；(2) 锚点被忽略，
  locator 永远 `cfi='N:0'`，点击任何条目都跳到章节首。

- **修复（3 层）**：
  - **T1**：`PlainTextUtils.anchorToPlainOffset(html, anchor)` 把
    `id=/name=` 锚点解析为 plain-text 字符偏移。用 `lastIndexOf('<',
    attrStart)` 定位元素起始，再用 `htmlToPlainWithOffsets` 的 offsets
    数组二分查找对应 plain index。与 `cfi_codec` 的 `charOffset` 同
    坐标系。正则 `caseSensitive: false` 兼容 `ID=` / `Id=`。
  - **T2**：`EpubxRenderer._buildDedupedChaptersAndMap` 按
    `ContentFileName` 去重——80 个共享 `index_split_001.html` 的
    navPoints → 1 个 `_chapters` 条目。同时构造反查 map
    `_contentFileToChapterIndex`（file path → deduped index）。
    空 `ContentFileName` 不参与去重（test fixture 兼容）。
  - **T3**：`_chaptersToToc` 改写为 `_locatorForChapter(ch)`：
    - dedupedIdx = `_contentFileToChapterIndex[contentFile] ?? 0`
    - charOffset = `anchorToPlainOffset(html, anchor)`（null/空/找不到
      时回退 0）
    - locator = `EpubCfiLocator(cfi: 'dedupedIdx:charOffset',
      chapterIndex: dedupedIdx)`

  这样目录条目「第一章 众妙之门」（`#filepos16764`）的 locator 变成
  `0:8`（去重章 0 的字符偏移 8），`gotoLocator` 滚动到正确位置。

### 测试

新增 14 个测试（T1: 6 + T2: 2 + T3: 6）：

| 任务 | 新测试数 | 文件 |
|---|---|---|
| T1 anchorToPlainOffset | 6 | plain_text_utils_test |
| T2 章节去重 | 2 | epubx_renderer_test |
| T3 anchor TOC 集成 | 6 | epubx_renderer_anchor_toc_test（新文件） |

**总测试**：renderer 包 206 pass + 8 skip + 15 baseline fail（pre-existing
paged/dual-page/perf）；app 包 1449 pass + 14 skip + 10 baseline fail
（pre-existing reader_page widget 编译错误）。

baseline fail 全部 pre-existing，与本次改动无关。

### 已知限制

- **HTML 注释/CDATA 误报**：`anchorToPlainOffset` 用简单的 regex 找
  `id=/name=` 属性，不解析 HTML AST。如果锚点 id 出现在 `<!-- -->`
  注释或 `<script>` 字符串里，会误匹配。Calibre 风格 EPUB 不存在此
  问题（锚点是真实的 `<p id=...>` 元素），记入 docstring 限制。
- **属性值含 `<`**：继承自 `htmlToPlainWithOffsets` 的限制。常规 EPUB
  不存在此问题。

### 升级指引

直接覆盖安装即可。无 schema 变更，无配置变更。

打开 v1.11.5-alpha 后：

- **Calibri 风格 EPUB 目录正常跳转**：《道德经》等单 html 多锚点 EPUB
  点击目录条目跳转到对应位置（不再卡在章首）。
- **其他 EPUB 不受影响**：每章独立 html 文件的标准 EPUB 行为不变
  （去重后 chapterIndex 与原一致）。

## [1.11.4-alpha] - 2026-07-13

跨设备封面同步 + drift stream 通知修复：用户在手机端测试 v1.11.3-alpha
同步时报告两个问题（书架云图标不消失 + 封面缺失），定位为两层根因。

### 修复

- **Bug 1：同步书架不刷新需重启**。drift 数据库默认不启用
  `streamSqlUpdates`，但 `RemoteRecordApplier._applyBook` 和
  `BookFileSyncService.uploadBookFile` / `downloadBookFile` 用
  `customStatement` / `customInsert` 写 books 表——绕过了 drift 的
  StreamQueryStore 通知路径。`select(books).watch()` stream 不知道
  DB 已变，widget 显示陈旧状态，必须重启 app 才看到同步书。**同一根
  因也导致每次点同步书都重新下载**：downloadBookFile 用 DSL 改完后
  stream 通知 cover_path 已是本地路径，第二次 tap 直接打开。
- **修复**：3 个位点改为 drift DSL：
  - `_applyBook` INSERT + 2 个 DELETE 分支 → `into(books).insert`
    + `delete(books)..where().go()`
  - `uploadBookFile` stamp `file_synced_at` → `update(books)..where().write()`
  - `downloadBookFile` UPDATE `file_path + file_synced_at` →
    `update(books)..where().write()`

- **Bug 2：跨设备封面缺失**。`SyncRecorder.recordBook` 此前把
  `books.cover_path`（PC 绝对路径如
  `C:\Users\1\Documents\covers\{bookId}.png`）原样写入 sync payload。
  接收端 `cover_path` 指向发送方机器上不存在的路径，
  `File(path).existsSync()` 始终 false，UI 回退到纯色 + 第一字占位图。
  M2.8 的 binary 同步体系完全漏掉了封面。
- **修复**：封面走 binary 同步（仿 M2.8 binary file 体系）：
  - 远程：`/zhiyue/covers/{bookId}.png`（PNG 是 EpubCoverExtractor 的固定输出）
  - 本地：`<coversDir>/{bookId}.png`（`FileStorage.coversDir`，M2.8 已存在）
  - sentinel：`books.cover_path = '__needs_cover_download__'` 表示元数据
    已同步但封面 binary 未拉取，`coverLoaderProvider` 懒触发下载
  - 上传：`uploadBookFile` piggyback（best-effort，binary PUT 成功后，
    cover PUT 失败不阻塞——封面是装饰性）
  - 下载：`downloadCoverFile` 单独方法，404 时清空 `cover_path = NULL`
    避免无限重试
  - 删除：`deleteRemoteFile` piggyback cover delete

- **wire format 变更**：`recordBook` payload 删除 `coverPath`（绝对路径
  字符串），改为 `hasCover`（bool）。理由：
  1. PC 绝对路径在接收方毫无意义（不同 OS / 不同用户目录）
  2. 路径泄露用户目录结构
  3. 接收方只需知道「是否有封面」即可触发懒下载
  - 向后兼容：`_sanitizeLegacyCoverPath` 兜底——旧 snapshot 的非空
    `coverPath` 字符串视为 `hasCover=true`，路径被丢弃，绝不写入本地行。

- **删书联动 cover 文件**：`LocalBookRepository.delete` / `deleteBooks`
  此前只删 library binary（v1.11.3-alpha 修复），不删 cover binary。
  本版本加 `_deleteLocalCoverFile` helper，best-effort 删本地封面文件。
  sentinel / null cover_path 跳过（无本地文件可删）。

### 测试

新增 / 扩展覆盖：
- T1 drift stream emit：4 个新测试（`book_file_sync_service_test.dart` +
  `remote_record_applier_book_test.dart`），断言 `select(books).watch()`
  在 uploadBookFile / downloadBookFile / apply 新书 / apply tombstone
  后 emit。
- T2 cover 同步：12 个新测试（upload skip cases / download idempotency /
  404 → NULL / piggyback on binary lifecycle / best-effort failure
  swallow）。
- T3 cover 契约：4 个新测试（hasCover true/false + legacy path 非空 +
  legacy path null）。
- T4 coverLoaderProvider sentinel：3 个新测试（成功返回 File / 失败返回
  null / 404-cleared NULL）。
- T5 删书联动 cover：5 个新测试（delete single / deleteBooks batch /
  null cover_path skip / sentinel skip / no-fileStorage backwards compat）。

总测试：1473（1449 pass + 14 skip + 10 baseline fail，baseline fail 全部
pre-existing——router_test / book_import_service_test fixture / reader_page
系列 / 3 个 reader widget 编译错误，与本次改动无关）。

### 升级指引

直接覆盖安装即可。schema 无变更（仍 v14），无需迁移。

打开 v1.11.4-alpha 后：

- **跨设备同步的书籍封面正常显示**：电脑端导入 epub → 同步 → 手机端
  书架出现 + 封面自动下载后显示真实图（不再纯色 + 第一字）。
- **同步书架立即刷新**：拉取元数据后无需重启，drift DSL 写触发 stream
  通知，widget 立即看到新书 / 删书 / file_path 更新。
- **不再每次重新下载**：第一次点同步书下载 binary 后，drift DSL 写
  `file_path = localPath`，stream 通知 widget，第二次点直接打开（不再
  弹下载框），节省 WebDAV 流量。
- **配额满时封面 best-effort**：若坚果云配额已满，binary PUT 成功但
  cover PUT 507 时，书籍可用但封面缺（显示占位图）。重新导入同书在
  另一台设备会重新推封面。

### 已知限制

- **历史孤儿封面不自动清理**：本修复保证未来删书时同时删本地封面，
  但旧版本残留的孤儿封面（`<coversDir>/*.png`）不会自动扫描清除。
  用户可手动删 `<coversDir>/` 下不再被数据库引用的文件，或清空整个
  目录（重新同步时会按需下载）。
- **legacy snapshot 含绝对 coverPath**：本版本兼容旧 snapshot，但发送方
  PC 绝对路径在 _sanitizeLegacyCoverPath 后被丢弃——接收方会触发懒
  下载封面，如果发送方未真正上传过封面 binary（旧版本无 T2 upload
  piggyback），下载 404 后 cover_path 设为 NULL，UI 显示占位图。这是
  正确行为（"装饰性"语义）。

## [1.11.3-alpha] - 2026-07-13

重新导入失败 hotfix：用户报告「清空书架 + 删除坚果云 JSON 文件后，重新
导入同一本书失败」。

### 修复

- **Bug：重新导入 errno=5 PathAccessException**。根因两层：
  1. `LocalBookRepository.delete` / `deleteBooks` 只删数据库行，**不删
     `library/{hash}.{ext}` 内容寻址文件**。清空书架后这些文件作为孤儿
     残留在 `C:\Users\1\Documents\library\`，永远不缩。
  2. 重新导入同 hash 时 `FileStorage.storeLibraryFileFromBytes` 写已存在
     文件；若该文件被外部工具（OneDrive / 杀软 / 备份）或早期版本标记
     ReadOnly attribute，Windows 上 `CreateFileW(GENERIC_WRITE)` 必返回
     `ERROR_ACCESS_DENIED = errno=5`，Dart 抛 `PathAccessException`。
- **修复（双层）**：
  - **根因层**：`LocalBookRepository.delete` / `deleteBooks` 在删 DB row
    之前 capture `fileHash + format`，删 row 之后 best-effort 删本地
    library 文件。Hash 内容寻址 + `idx_books_file_hash` UNIQUE，文件只被
    一本书引用，删除安全。`fileStorage` 经由 `globalFileStorage`（main.dart
    boot 时 set）注入；widget 测试 / null 场景下跳过文件删除（向后兼容）。
  - **表层 resilient**：`FileStorage.storeLibraryFileFromBytes` /
    `deleteLibraryFile` 在 `PathAccessException` errno=5 + 文件已存在时
    调 `attrib -R` 清 ReadOnly 再重试一次。处理历史脏文件 + 第三方工具
    干扰。POSIX 平台 no-op（ReadOnly 不阻塞 POSIX 写）。

### 测试

- 新增 6 个回归测试：
  - `file_storage_test.dart`：storeFromBytes + delete 清 ReadOnly
    retry（Windows-only，POSIX skip）。
  - `local_book_repository_test.dart`：delete 删本地 library 文件 +
    deleteBooks 删每个 + 无 fileStorage 时文件保留（向后兼容）+
    ReadOnly 文件下 delete 仍成功（v1.11.2 + v1.11.3 复合回归）。
- 总测试数 1427 → 1433（+6 新增）。

### 已知限制

- **历史孤儿文件不自动清理**：本修复保证未来删书时同时删本地文件，但
  旧版本残留的孤儿文件不会自动扫描清除。用户可手动删
  `C:\Users\1\Documents\library\` 下不再被数据库引用的文件，或直接清空
  整个目录（重新导入时会重建）。
- **errno=5 非 ReadOnly 原因仍会失败**：例如文件被另一进程独占打开（zhiyue
  自身的 reader 句柄泄漏 / 杀软实时扫描 / OneDrive 上传中），`attrib -R`
  后再写仍会 errno=5。这种场景下异常会向上传播，由 import 调用方提示用户。
  未来可加 file-lock 等待重试（v1.12+）。

## [1.11.2-alpha] - 2026-07-13

删书静默失败 hotfix：用户报告「弹了确认框，点确认后书没被删除」。

### 修复

- **Bug：删书静默失败**。根因：9 个子表（`book_notes` / `annotations` /
  `reading_progress_table` / `book_typography_overrides` / `ai_summaries` /
  `bookmarks` / `chat_sessions` / `chat_messages` / `freeform_notes`）的
  FK to `books(id)` 都缺 `ON DELETE CASCADE`（drift 的
  `.references(Books, #id)` 默认 NO ACTION；只有 `book_tags` 用
  `customConstraint` 显式 CASCADE）。在 `PRAGMA foreign_keys = ON`
  下，`DELETE FROM books` 当存在任一关联行时抛
  `SqliteException(787): FOREIGN KEY constraint failed`，异常从
  `BookDetailPage._confirmDelete`（FAB onPressed，无 try/catch）冒到
  Flutter framework 被静默吞掉。修复：
  - `BooksDao.deleteBookCascade` / `deleteBooksCascade` 在事务里按依赖
    顺序（annotations→book_notes、chat_messages→chat_sessions、其余
    6 个直接子表）DELETE，最后用 drift DSL 删 books（保证 books 表
    stream 触发，Library 卡片 reactive 消失）。
  - `LocalBookRepository.delete` / `deleteBooks` 切到 cascade 版本。
  - `BookDetailPage._confirmDelete` 加 try/catch + SnackBar，未来任何
    删除失败用户能看到，不再静默。

### 测试

- 新增 2 个回归测试（`local_book_repository_test.dart`）：覆盖 9 个
  子表全 cascade 路径 + 批量删除 cascade。
- 总测试数 1425 → 1427（+2 新增）。10 baseline fail 不变
  （router/reader_page 老 baseline）。

### 文档

- 修 `freeform_notes.dart` / `bookmarks.dart` 文档谎言：原文档声称
  `ON DELETE CASCADE`，实际生成的是 NO ACTION（drift `.references()`
  默认）。

## [1.11.1-alpha] - 2026-07-12

M2.8 紧急 hotfix：v1.11.0-alpha 用户上手测试发现两个同步 bug。

### 修复

- **Bug A：书籍 binary 文件从未上传到坚果云**。根因：
  `BookFileSyncService.uploadBookFile` 直接调 `putBytes` 没先 `ensureAncestors`
  创建 `/zhiyue/files/` 目录。坚果云 WebDAV 不像 Nextcloud / ownCloud 那样在
  PUT 时自动建父目录，返回 409 AncestorsNotFound；该异常被
  `uploadPendingFiles` 的 per-book try/catch 静默吞掉，因此用户看到「同步了
  但坚果云只有两个 JSON 文件」。修复：`uploadBookFile` 在 `putBytes` 之前
  调 `ensureAncestors(remotePath)`，幂等 MKCOL `/zhiyue` 和 `/zhiyue/files`
  （405 = 已存在亦视为成功）。
- **Bug B：新设备同步后中文书名显示为乱码**。根因：坚果云 WebDAV 返回
  snapshot 文件时 `Content-Type: application/octet-stream` 不带 charset 参数。
  Dart http 包的 `Response.body` getter 在没有显式 charset 时回退到 latin1
  解码，破坏多字节 UTF-8 序列（中文标题字节被解码为孤立的 mojibake 字符）。
  修复：`WebDavClient.getString` 改为 `utf8.decode(response.bodyBytes)` 显式
  解码。同时 `putString` 加 `Content-Type: text/plain; charset=utf-8` 防御性
  header（实际 Dart http 包对 String body 默认已 UTF-8 编码，此为防御性
  冗余）。

### 测试

- 新增 3 个回归测试：`uploadBookFile` MKCOL 顺序验证 + `getString` UTF-8
  解码验证（无 charset / 有 charset=utf-8 两场景）。
- 更新 4 个 `BookFileSyncService` 旧测试：MockClient 加 MKCOL 分支（返回 201）。
- 总测试数 1422 → 1425（+3 新增）。

### 已知限制

- **已 corrupted 的本地数据需手动恢复**：在 v1.11.0-alpha 期间已 pull 过
  远程 snapshot 的设备，本地 SQLite 中 `books.title` 可能已是 mojibake。
  修复后再次 sync 不会自动覆盖（books 表无 `updated_at`，applier 见到行已
  存在就 skip）。受影响用户需在 Library 中手动删除乱码书条目，再触发 sync
  重新 pull（修复后的 `getString` 会正确解码 UTF-8）。
- **远程 snapshot 文件本身字节是正确的 UTF-8**（putString 一直发 UTF-8
  bytes），无需重写远程数据。

## [1.11.0-alpha] - 2026-07-12

M2.8 跨端同步范围扩展：让用户「在电脑上看的书和聊天可以在手机上接着」。
新增 **AI 聊天历史同步** + **书籍标签同步** + **书籍 binary 文件同步**，
覆盖 metadata-only 同步之外的三类核心数据。13 任务 TDD，~50 新测试，schema
v13 → v14。

### 新增

#### Phase 2：metadata-only sync（低风险）

- **AI 聊天会话 / 消息同步**（`chat_sessions` / `chat_messages`）：双向同步，
  支持流式追加。策略：`appendContent` 不写 outbox（避免 200+ 行 bloat），
  新增 `ChatRepository.completeStreamingMessage` 在 stream 结束时统一 emit；
  4 个 streaming use cases（chapter_guide / recap / socratic_bootstrap /
  send_message）在 stream-end 调用。
- **书籍标签同步**（`book_tags` 表）：双向同步，复合主键 `(bookId, tag)` 编码
  为 id = `"${bookId}__${tag}"`；硬 delete 通过 `record.deleted=true` tombstone。
- **TagEditor widget**：BookDetailPage 内联编辑标签。校验拒绝空 / 含 `__`
  子串（与复合主键冲突）/ 长度 > 32 / 重复（case-insensitive）。

#### Phase 3：binary file sync（新基础设施）

- **BookFileSyncService**：协调 binary 文件上传/下载/删除。
  - 远程路径 `/zhiyue/files/<bookId>.<format>`
  - 本地路径 `<libraryDir>/<bookId>.<format>`
  - Sentinel `books.file_path = '__needs_download__'` 表示 metadata 已同步
    但 binary 未下载
  - `uploadPendingFiles`：扫描 `file_synced_at IS NULL` 的书，逐个上传；
    单本失败（如 507 quota）不阻塞其余
  - `deleteRemoteFile`：idempotent（404 swallowed）
- **WebDavClient bytes API**：`getBytes` / `putBytes` / `listFilesWithSize`
- **跨端 binary 上传链路**：每个 sync 周期 `WebDavSyncEngine.sync` 调用
  `uploadPendingFiles`（best-effort，不阻塞 metadata sync）
- **跨端 binary 下载链路**：Library `BookCard` / `BookListTile` 显示
  cloud-download 徽章 + tap 触发 `_BookDownloadDialog` 进度框 →
  `SyncController.downloadBookFile` → 写入本地 + 更新 `file_path` 跳转 reader

### Schema 变更

- **v13 → v14**：`books` 表新增 `file_synced_at INTEGER`（nullable）。
  Migration 走 `ALTER TABLE ADD COLUMN`，老数据 NULL = 未同步。

### 改进

- **`SyncRecord.fromJson` 容错**：未知 `type` 值从抛异常改为 skip（M2.8
  forward-compat：老客户端 pull 到 M2.8 snapshot 不会 crash，只是忽略新
  类型记录）。
- **`LocalBookRepository` 接受可选 `remoteFileDeleter` 钩子**：在删除本地 row
  之前 best-effort 删除远程 binary。失败不阻塞本地删除（tombstone 仍走
  outbox，peers 仍会清理）。
- **`RemoteRecordApplier` tier 重排**：tier 1 加入 `bookTags` + `chatSessions`，
  tier 2 加入 `chatMessages`，保证 FK 安全。

### 测试覆盖

- 19 新测试 `BookFileSyncService`（upload / download / delete / scan /
  localFileExists / getLocalPath）
- 4 新测试 `RemoteRecordApplier._applyBook`（sentinel + LWW + tombstone）
- 4 新测试 `LocalBookRepository` remoteFileDeleter hook（best-effort contract）
- 2 新测试 `WebDavSyncEngine` bookFileSync hook（uploadPending + best-effort）
- 3 新测试 `BookCard` / `BookListTile` needs-download overlay
- 2 新测试 cross-device chat continuation（A push → B pull）
- 2 新测试 cross-device book file transfer（A upload → B pull+download +
  tombstone propagation）

总测试数：v1.10.1-alpha 的 ~1383 → v1.11.0-alpha 的 ~1420。

### 已知限制

- **`books.file_path` 为 `__needs_download__` 时不支持后台下载**：必须在 UI
  前台完成（用户必须等待 dialog）。失败 → SnackBar 错误。后续 v1.12+ 加
  后台下载 + 通知。
- **删除书籍时的远程 binary 清理为 best-effort**：若 WebDAV 不可达，远程
  binary 会成 orphan（空间泄漏，非正确性问题）。
- **配额管理 UI 不做**：用户决策（2026-07-12 AskUserQuestion）。WebDAV 507
  错误从 BookFileSyncService 上浮，未来若用户反馈需要再加 UI。
- **流式 chat 中途被 cancel 不进入 outbox**：用户重发 → 走完整流程。接受
  这个 trade-off：实现简单 + 不破坏一致性。
- **S3 WS1 PROPFIND disambiguate dead code 清理**：延后到后续版本。

### 升级

- **桌面 / Android**：直接覆盖安装。schema 自动迁移 v13 → v14（add nullable
  column）。
- **WebDAV 服务端**：第一次 sync 时自动 `MKCOL /zhiyue/files/` 创建目录。
- **老版本（v1.10.1-alpha 及以下）**：不识别 `chatSession` / `chatMessage`
  / `bookTag` 三种新 SyncRecordType。`SyncRecord.fromJson` 已改为容错，
  老客户端 pull 到 M2.8 snapshot 时会 skip 这些记录（不 crash）。

### 下一节点

- TTS 集成（M2.9，已在 S4 路线图）
- 跨书 AI 伴读（v1.12+）
- iOS 端 binary 同步 + CI

## [1.10.1-alpha] - 2026-07-12

紧急 hotfix：修复坚果云 WebDAV 同步从 day 1（M2.0a T14，commit e0a3efc）
就存在的 baseUrl bug。无功能新增，1 行代码改动。

### 修复

- **jianguoyun WebDAV baseUrl 不应包含 username 路径段**：原代码把 baseUrl
  拼成 `https://dav.jianguoyun.com/dav/<邮箱>`，但坚果云 WebDAV 通过 HTTP
  Basic Auth 解析账号，URL 路径里**没有** username 段。错的 URL 导致：
  - PROPFIND `/dav/<邮箱>/` 返回 404（根就不存在）
  - 所有 MKCOL / PUT / GET 在 `/dav/<邮箱>/zhiyue/...` 下返回 409
    AncestorsNotFound（因为整个父级路径不存在）

  修复：`baseUrl = 'https://dav.jianguoyun.com/dav'`（无 username 段）。
  验证：用真实账号 curl 探测 4 个 endpoint，全部返回正确状态码（207 / 201 /
  201 / 204）；dev 机端到端实测同步成功。

### 影响

此 bug 从 v0.6.0-alpha（M2.0a，首次引入同步）一直存在到 v1.10.0-alpha。
期间所有「坚果云 AncestorsNotFound」报告——v1.9.0-alpha、v1.9.2-alpha、
v1.10.0-alpha S3 WS1 的 PROPFIND disambiguate 修复——都是这个 baseUrl
bug 的症状，不是坚果云的偏差。

S3 WS1 PROPFIND disambiguate 代码（commit `d76aca8`）现已成为 dead code
（用正确 URL 时坚果云 MKCOL 始终返 201，无论目录是否已存在）。清理延后到
后续版本。

### 升级

- 桌面 / Android：直接覆盖安装。无 schema 变更（v13 沿用）。
- 已配置同步的用户：升级后第一次「立即同步」会成功（之前的 outbox 队列
  会一次性 flush 到云端）。

## [1.10.0-alpha] - 2026-07-11

Mobile MVP Spiral 3：5 工作流交付——WebDAV 同步健壮性 + 移动生命周期同步
UI/UX + S2 Part 2 残留（5 plugin compileSdk 升级 / IME / SafeArea / 类型/平台
抽象清理）+ AI 流式优化（两阶段渲染 + 用户滚动锁 + 取消 + dispose SSE 取消）
+ TTS 可行性调研。无 schema 变更（v13 沿用）。

### 修复

- **WS1 jianguoyun MKCOL 409 disambiguation**：坚果云对已存在目录的 MKCOL
  返回 409（与 RFC 4918 推荐的 405 不同），原代码裸 catch 所有 409 视作
  "重试 ensureAncestors"——但 "AncestorsNotFound" 409 与 "Already Exists" 409
  在坚果云响应里 XML body 不同。修复：MKCOL 409 后用 PROPFIND depth=0 验证
  目标是否真实存在，区分两种语义。
- **T16 auto-hide timer restart on re-show**：用户 tap 唤出 chrome 后，原
  实现的 3s 自动隐藏 timer 不会重启（用户报告"tap 出来后只能再 tap 隐藏，
  不能等 3 秒自动隐藏"）。修复：reader_scaffold 加 `ref.listen`，chrome
  visible 边沿触发 fresh 3s timer。
- **T20 dispose SSE leak**：AI 抽屉关闭时 Riverpod autoDispose 释放
  ChatSessionController，但只 cancel 了 watchMessages 订阅，未取消在飞
  LLM SSE 请求——HTTP 流持续到服务端关闭（deepseek 30s+）。修复：dispose
  调 `_llmCache?.cancel()`，selectSession 时 eager 缓存 LLM 客户端避免
  dispose 时读已销毁 container。

### 新增

- **WS2 mobile lifecycle sync UI**：
  - `SyncButton` widget（rotation 动画 + retry 状态）；
  - `ConflictListTile` 移动端溢出守护 + widget test；
  - `MobileLifecycleSyncController` 接到 main.dart（app 进入后台触发
    syncNow）；
  - `SyncController` AppLifecycleState 回归 guard（防止 pause/resume 期间
    重复 trigger）。
- **WS3 S2 Part 2 残留**：
  - T10 升级 3 个直接 plugin 到 compileSdk 36 默认（connectivity_plus
    6→7、file_picker 8→10、flutter_secure_storage 9→10），剩余 2 个
    transitive plugin 仍需 pub-cache `sed` 补丁（just_audio / webview_flutter_android）；
  - T13 `ReaderUiState` value equality + hashCode（防止 spurious rebuild）；
  - T14 `PlatformInfo` 抽象统一桌面/移动分支（5 个 `defaultTargetPlatform`
    比较点收敛到 `PlatformInfo.isDesktop`）。
- **WS4 AI 流式优化**：
  - T17 `AiMessage` 两阶段渲染（流式中渲染 `Text` 避免 markdown 反复解析，
    完成后切换 `MarkdownBody`）；
  - T18 chat auto-scroll 尊重用户 pinned 状态（用户上滑阅读历史时不
    yank 回到底部）；
  - T19 `ChatSessionController.cancelStreaming()` + `Icons.stop` 按钮
    （`ChatLlmClient.cancel()` 协作取消 SSE）。
- **WS5 TTS 可行性调研**：1198 字文档，6 节覆盖 plugin 选型 / 使用场景 /
  高亮跟随 / 后台播放 / 平台限制 / 分阶段推荐路径。Phase 1（AI 响应朗读）
  3-5 天可立即推进 S4.1；Phase 2（EPUB 章节朗读）2-3 周；Phase 3
  （audio_service 后台 + 锁屏）移动端 1-2 周。

### 重构

- T11 IME 深度审计：plan bug #4（plan 路径错误）→ 现有 `FocusNode` 生命周期
  已正确，no-op。
- T12 全屏 SafeArea 审计：用户已验证现有覆盖足够，no-op。
- T15 TypographyPersister 去重审计：plan bug #6（plan 描述的 API 不存在）→
  现有 subscription 模式已含 dedup guard（lines 55/61），no-op。

### 测试

- 新增 ~26 测试：1 个 WS1 集成（jianguoyun first-push 409 链）+ 1 个 lifecycle
  regression + 1 个 conflict tile overflow + 1 个 SyncButton widget + 3 个
  plugin upgrade 相关 + 6 个 ReaderUiState equality + 4 个 T17 两阶段渲染 +
  2 个 T18 pinned auto-scroll + 4 个 T19 stop button + 1 个 T19 controller
  cancelStreaming + 1 个 T20 dispose SSE leak + 2 个 T21 drift 并发回归。
- 完整回归：**~1293 pass / 3 skip / 10 baseline fail**（pre-existing
  baseline 沿用 v1.9.2-alpha；本版无新增失败）。

### 已知问题

- 与 v1.9.2-alpha 相同（iOS scaffold、APK 单包、golden 不覆盖 Android、
  2 个 transitive plugin pub-cache `sed` 补丁、reader_flow_integration
  timeout baseline）。
- **Regenerate（AI 长按重生成）**从 T19 scope 中延后——plan Step 4 spec
  含 placeholder（`/* relative to message */`、未定义 `onRegenerate` 回调），
  需产品决策 truncate-and-rewrite vs fresh-append 语义。下版（S4 或独立 hotfix）
  跟进。
- **Word-level TTS highlight** 延后 Phase 2.5——sentence-level 先验证 UX。

### 修复（移动端上手测试 hotfix）

- **Bug 1**: 坚果云 WebDAV 同步在切换账号后报 `409 AncestorsNotFound`。
  根因：`WebDavSyncEngine.pushOnly` 在初始 GET 失败时只 catch 404，但坚果云
  对「父目录不存在的文件」GET 会返回 409（与 RFC 推荐的 404 不同），导致 409
  被识别为「非 404」直接 rethrow，同步永远到不了 `ensureAncestors` 那一步。
  修复：catch 404 OR 409，都视作 firstPush。
- **Bug 2a**: 移动端 AppBar 「AI 抽屉」图标点击无反应。根因：`_toggleAiDrawer`
  只翻转 `_aiPanelOpen`（仅驱动宽屏 inline panel），未补窄屏分支调
  `Scaffold.of(context).openEndDrawer()`。
- **Bug 2a.1**: 即便补了分支，`Scaffold.of(State.context)` 仍会因 State 上下文
  位于 Scaffold 之上而抛 `no Scaffold ancestor`。修复：复用现有 `Builder` 提供
  的 `innerContext`（与 line 756/771 的 TOC openDrawer 同模式）。同时预防性修
  `_onAskAi`（同根因，未在移动端被触发的潜在 bug）。
- **Bug 2b**: 替换右下悬浮按钮（FAB）从「添加书签」改为「呼出 AI 抽屉」。
  原书签 FAB（M2.10/Bug C1）的目的是 chrome 隐藏时给一个书签入口，但移动端
  AI 是更频繁操作，且右滑抽屉与系统返回手势冲突 → 改为 AI 入口。书签仍可
  通过 chrome 可见时的 AppBar 图标添加。
- **Bug 4**: 移动端左右抽屉（TOC + AI）顶部文字与状态栏 / 灵动岛 / 挖孔重叠，
  重叠区域无法点击。根因：抽屉内容未包 `SafeArea`。修复：左侧 `ReaderDrawer`
  与右侧 AI `Drawer` 的 child 均加 `SafeArea`（Drawer 背景延伸到边，仅内容让出）。
- **Bug 5**: AI 抽屉在移动端从默认 304px（≈屏幕 78%）改为 98% 屏宽。原宽度
  让阅读区只剩 22%（不可读），改 98% 让 chat 近全屏，符合移动端 chat 习惯。
  用户决策：保留右侧滑出（拒绝底部滑出方案，见 v1.9.2-alpha 评估记录）。

### 评估（未实施）

- **底部抽屉评估**（用户晨测提出）：评估了把 AI 抽屉改为底部 sheet 的收益/
  损失（拇指可达 / 消除系统手势冲突 / 聊天 UX 对齐 vs 阅读上下文压缩 /
  布局重写 / 键盘叠层 / 跨端不一致）。决策：**保留右侧**，只改宽度。底部方案
  可作为 S2 Part 2 的独立任务（<600px 走 bottom sheet，≥600px 保留右侧）。

### 新增

- 6 个 widget/unit 测试覆盖上述修复（`reader_body_ai_entry_test.dart` 共 6 个 +
  WebDAV sync engine regression 1 个）。

### 已知问题

- 与 1.9.1-alpha 相同（iOS scaffold、APK 单包、golden 不覆盖 Android、
  5 plugin pub-cache `sed` 补丁、reader_flow_integration timeout baseline）。

## [1.9.1-alpha] - 2026-07-11

### 修复（移动端 UX）

- **UX-A**: 移动端 chrome tap-toggle 回归 ——「tap 唤出 chrome 后再 tap 无法隐藏」。
  根因：`reader_body.dart` 中 `GestureDetector` 被埋进 `SelectableRegion`，
  导致 tap 事件被 selection region 先消费。修复：把 `Listener` 提到 Stack 顶层，
  使用 18px 拖拽阈值区分 tap/drag，并豁免 AppBar 区域（避免误触）。
- **UX-A.1** (review follow-up): 修复移动端 margin-tap 翻页与 chrome toggle 双发。
  Stack 顶 `Listener` 不是手势 arena 参与者，会观察所有 pointer 事件，导致翻页时
  chrome 闪烁。补丁：在 `_handleChromeTogglePointerUp` 加 page-zone 豁免
  （左右 `zoneWidth` 内的 tap 由翻页 GestureDetector 独享）。新增 2 widget test。
- **UX-B**: 移动端打开书后 chrome 默认可见（3 秒后自动隐藏）。
  原行为：新书打开 chrome 立即隐藏，用户完全不知道有 AppBar 可用，
  上手成本高。新行为：`chromeVisible=true` 默认值 + 3s 定时器 hideChrome；
  任意用户交互（tap/scroll/selection）取消计时；app 进入后台取消计时；
  controller dispose 取消计时。桌面行为不受影响（默认可见、不自动隐藏）。
- **UX-C**: 移动端默认页边距从 wide(72px) 改为 compact(8px)。
  原行为：手机小屏上 72px 双边让文字只有 ~250px 可读宽度过窄。
  新行为：移动新书默认 compact；桌面默认仍是 wide；已存在书目保留
  其持久化的 margin（向后兼容）。

### 新增

- `PlatformInfo.isMobile` / `isDesktop` 助手（`core/platform_info.dart`）
  —— 尊重 `debugDefaultTargetPlatformOverride` 以便测试覆盖
- `ReaderUiController.hideChrome()` 方法（与 `toggleChrome` 区分，
  供 UX-B 计时器调用）
- `ReaderUiState.defaultsForPlatform()` 工厂（chrome 按 UX-B 默认可见）
- `ReaderUiController` 接受可选 `initialState` 参数（提升可测试性）
- `resolveDefaultTypography()` 纯函数助手（按平台分支 margin 默认）
- 新增 25 个测试覆盖：PlatformInfo (2) + hideChrome (3) +
  defaultsForPlatform (2) + UX-A chrome toggle (5+2 page-zone exemption) +
  UX-B auto-hide 生命周期 (5) + UX-C margin 平台分支 (6)

### 已知问题

- 与 1.9.0-alpha 相同（iOS scaffold、APK 单包、golden 不覆盖 Android、
  5 plugin pub-cache `sed` 补丁）
- 10 个 pre-existing 测试失败（router_test 1 + reader_page_test 4 +
  reader_flow_integration timeout 1 + reader_page_pdf_integration load 1 +
  reader_ai_drawer_integration load 1 + library_golden_test 2；全部
  v1.8.0-alpha 12 baseline 反向验证为 pre-mobile，本轮 UX 修复未引入回归）

### Tags

- `v1.9.1-alpha`（本次发布）
- 桌面稳定锚点：`desktop-stable-pre-mobile`（不变）

## [1.9.0-alpha] - 2026-07-10

### 修复（用户测试 bug）

- **sync**: 坚果云 WebDAV 上传 snapshot 到 `/zhiyue/snapshots/<uuid>.json` 时报
  `WebDavException(409 at ...): <s:exception>AncestorsNotFound</s:exception>`
  - 根因：jianguoyun 不像 Nextcloud 那样在 PUT 时自动创建父目录
  - 修复：`WebDavClient.mkcol` + `ensureAncestors(filePath)`；首次 push 时
    `getString` 抛 404 触发 MKCOL 链
  - MKCOL 状态码语义：201 Created / 200 OK / 405 Method Not Allowed 均视为成功
- **ai**: 聊天输入框发送（Enter 或按钮）后输入文字残留在输入框，必须手动删除
  - 修复：`AiInputComposer._onSend` 先 capture text+attachment，clear controller
    与 setState，再 await sendMessage

### 新增

- **notes**: 自由笔记（FreeformNote）—— 用户在阅读中保存 AI 金句或个人感悟
  - drift schema v12 → v13（FreeformNotes 表 + idx_freeform_notes_book +
    idx_freeform_notes_updated）
  - per-book 入口：reader drawer note_add 按钮 + NotesPage FAB + section
  - 全局入口：library drawer「全部自由笔记」→ GlobalFreeformNotesPage
  - NoteEditPage：标题 + 内容（支持 Markdown）+ 编辑/预览切换 + 500ms
    write-through debounce（参照 TypographyPersister，避开 exit(0) 截断）
  - 跨设备同步：SyncRecordType.freeformNote + tier 1（与 bookNote 同级），
    LWW via updated_at，端到端集成测试覆盖 create/update/delete round-trip

### 已知问题

- 与 1.8.0-alpha 相同（iOS scaffold、APK 单包、golden 不覆盖 Android）
- 5 plugin pub-cache `sed` 补丁仍需手动执行（S2 升级 plugin 默认 compileSdk 36）
- 8 个 pre-existing 测试失败（v1.8.0-alpha 12 baseline 中 library_golden_test 4 已在 T7 修复 regen）

## [1.8.0-alpha] - 2026-07-10

### 新增

- **移动端 MVP Spiral 1**：Android 端 reader + library + notes + settings 可用
- **ResponsiveLayoutBuilder**（M3 三档断点 compact/medium/expanded）+ `kDesktopDualPageBreakpoint` 常量
- **PlatformChromeController** 抽象（status bar + orientation），Desktop noop / Mobile SystemChrome
- **iOS 目录 scaffold**（flutter create --platforms=ios，仅占位，不 build 不 CI）
- **Library compact 分支**：hamburger menu + overflow PopupMenu（7 项入口）
- **Library NavigationDrawer**：compact 下通过 hamburger 打开设置/AI 设置
- **Reader tap-to-toggle chrome**：移动 tap 阅读区切换 top bar 显隐

### 变更

- `reader_body.dart` 3 处 `>= 1100` 硬编码 → `kDesktopDualPageBreakpoint` 常量
- `library/notes` 的"打开文件夹" SnackBarAction 在 mobile 隐藏
- `notes/settings` body 包 ResponsiveLayoutBuilder（双栏增强推 v1.8.1）
- AndroidManifest 加显式 INTERNET + ACCESS_NETWORK_STATE 权限
- Android `compileSdk` 34 → 36（`flutter_plugin_android_lifecycle` 强制要求）
- 5 个 plugin（connectivity_plus / file_picker / flutter_secure_storage / just_audio / webview_flutter_android）默认 `compileSdk 34` 与上述要求冲突，本次发布采用 pub cache `sed` 补丁作为 band-aid（长期方案：升级到默认 36 的版本，S2 跟进）

### 已知问题

- iOS 仅 scaffold，build/CI 推 S3 之后
- APK 单 APK 不做 ABI 拆分（体积 50-80MB，含 PDFium）
- Golden 测试不覆盖 Android 渲染
- 12 个 pre-existing 测试失败（router_test 1 + library_golden_test 4 + reader_page_test 4 + reader_flow_integration timeout 1 + reader_page_pdf_integration load 1 + reader_ai_drawer_integration load 1；全部 commit `1e0b497` 反向验证为 pre-mobile baseline）

## [1.7.1-alpha] — 2026-07-10

### 修复

- **reader**: per-book typography persistence 修复 — 用户调整字体设为默认后退出重开仍恢复预设的 bug
  - 根因：dispose-time fire-and-forget `saveForBook` 被 `main.dart` 的 `exit(0)` 同步截断（绕 PDFium 死锁的设计）
  - 修复：引入 `TypographyPersister`，订阅 `engine.state$` stream + debounce 500ms 即时落盘
  - PDF 路径补充 `setTypography` emit state$ 保持契约一致
  - 架构约束：dispose 回调里的 fire-and-forget Future 必丢（exit(0) 截断），新持久化需求必须参照 ProgressPersister/TypographyPersister 即时落盘模式
  - commits: `436b35f` / `216f70b` / `ecb0f26` / `85c94f8`

### 测试卫生

- migration_v4_test: schemaVersion 硬编码 10 → 12（M2.6+M2.7 bump 后过期）
- notes_repository_test: drift 2.28 watchAnnotations 改 asyncExpand 修 cancel 生命周期
- typography_profile_repository_test: stale fontSize 断言 16.0 → defaults().fontSize（M3a bump 后过期）
- book_open_bridge_test: M4.5 加 .txt/.md 支持后 non-book 列表过期，加防回归用例
- library_golden_test + reader_ui_golden_test: regen 6 个 golden（字体漂移 <1.1%）
- typography_golden_test: skip（TypographyPanel 改 ConsumerWidget 后需 ProviderScope override，deferred）
- reader_ai_drawer_integration + reader_page_pdf_integration: skip 理由补描述性字符串

### 杂项

- gitignore: 扩展 `.claude/` + 根目录 `*.png` + `pub_get_output.txt` + `**/failures/`
- installer: 移除 Inno Setup chinesesimp language（`95cfcee`）
- docs: 归档 2026-07-08 review 报告（1 P0 + 8 P1 + 7 P2）
- docs: 移动端前置深度清理 spec + plan

## [1.7.0-alpha] — 2026-07-08

### M2.7 — 2026-07-08（AI 抽屉重构：5 入口 → 1 抽屉 + 章节级 subagent + 苏格拉底 + /命令）

**性质**：refactor + feature（AI 入口收敛 + 多会话 + 章节级 subagent）。

**核心动机**：M1.5 时代 AI 入口散落在 5 处（书卡菜单"AI 导读"、详情页全书 FAB、Reader AppBar ×2、选区工具栏），各自独立状态、无会话连续性、全书导读超 LLM context。M2.7 收敛为右侧统一抽屉 + per-book 多会话。

**入口收敛**：
- 删除：书卡"AI 导读" PopupMenuItem、详情页全书导读 FAB（spec §1.2 + §5.7 否决：开销大 + 超 context）、Reader AppBar 双图标（导读 + 问答）、选区"AI 点评"标签。
- 新增：Reader AppBar 单一"AI 抽屉"toggle（`Icons.smart_toy_outlined`，Key `toggle_ai_drawer`）。
- 改造：选区工具栏"AI 点评" → "提问 AI"（`onAiComment` → `onAskAi`），打开抽屉并把 `> {selectedText}\n\n` 注入输入框（**不自动发送**——尊重 subagent 隔离契约）。

**Per-book 多会话**：
- 新表：`chat_sessions` (id, book_id, title, mode, created_at, updated_at, deleted_at) + `chat_messages` (id, session_id, role, content, preset_source, attachment_note_id, attachment_note_snapshot, created_at, updated_at)。
- 软删除：`deleted_at` 非空即隐藏，`/del` 后自动切到剩余最近会话。
- Schema v11 → v12，`onCreate` + `onUpgrade(v<12)` 均 `DROP TABLE qa_history`（旧数据由 `chat_messages` 取代，用户决定清空）。

**Subagent 模式 (spec §2.3)**：
- 4 个 subagent 用例：`RunChapterGuideUseCase` / `RunSocraticBootstrapUseCase` / `RunRecapUseCase` + 共享 `SendMessageUseCase`（B 模式全量历史）。
- 不变量：subagent 用例**不读** `chat_messages` 历史，**只写一条** AI message。chapter/recap 文本仅在 subagent 内部组装 prompt，**绝不**回灌聊天上下文——这是隔离契约的核心（T26.2 集成测试验证）。
- 缓存：`AiSummariesDao` 复用（`mode='chapter'` / `'recap'` 区分），sha256(chapterText) 作 key。

**苏格拉底模式**：
- 卡片 2 (`AiPresetCardRow`) 或 `/socratic` slash：先写 system marker "苏格拉底模式启动"，再 bootstrap（recapProvider → 第一个反问）。
- `/exit-socratic`：静默回 normal（无 system marker）。
- 系统提示：`你是苏格拉底式导师，不要直接给出答案，通过反问、追问引导学生自己思考`。

**Slash 命令**：`/new` `/clear` `/del` `/chapter` `/socratic` `/recap` `/help` `/exit-socratic` —— 由 `AiSlashAutocomplete` 提供建议；输入 `/` 触发 popup，按 mode 决定是否显示 `/exit-socratic`。

**B 模式上下文**：用户控制 size——`/new` `/clear` 截断；不自动压缩。`SendMessageUseCase.run` 把当前会话全部消息（system + user + ai + preset_source 标签）按时间序拼成 prompt。

**@ 笔记提及**：`AiInputComposer` 输入 `@` 触发 popup（来源 `Annotations` 表的 per-highlight note，不是 `BookNotes`）；选中后注入 blockquote 格式 + `attachmentNoteId` 字段持久化。

**禁用入口**：详情页"重新处理" FAB 注释（M2.7 用户决定 BookPreprocessor 暂停）；代码 + 表保留以便恢复。

#### Added — M2.7

- `app/lib/data/local/tables/chat_sessions.dart` + `chat_messages.dart`
- `app/lib/data/local/daos/chat_sessions_dao.dart` + `chat_messages_dao.dart`（`appendContent` 用 `customUpdate` 而非 `customStatement`——sqlite3 拒绝 `Variable<>` 包装）
- `app/lib/data/local/daos/chat_repository.dart`（12 方法 facade，UUID v4）
- `app/lib/services/ai/attachment_note_resolver.dart`（NoteSnapshot + 解析器）
- `app/lib/services/ai/prompt_builder_ext.dart`（buildChatPrompt / buildSocraticBootstrapPrompt / buildRecapPrompt；`promptVersion = 2`）
- `app/lib/features/ai_chat/use_cases/` 7 个用例：send_message / run_chapter_guide / run_socratic_bootstrap / run_recap / switch_session_mode / session_lifecycle
- `app/lib/features/ai_chat/providers/`：chat_providers（注册器）+ chat_session_controller（StateNotifier.family per bookId）+ chat_session_list_controller + openai_chat_llm_adapter + ai_summaries_cache_adapter
- `app/lib/features/ai_chat/widgets/`：ai_drawer_widget（4-section column；wide=380px）+ ai_preset_card_row + ai_session_dropdown + ai_message_list + ai_input_composer + ai_slash_autocomplete + ai_empty_state
- `app/test/features/ai_chat/`：use_cases ×6 + widgets ×7 + integration ×2（ai_chat_integration_test 5 用例 + socratic_e2e_test 4 用例）

#### Changed — M2.7

- `app/lib/data/local/database.dart`：schemaVersion 11 → 12；onCreate + onUpgrade(v<12) DROP qa_history；新增 chat_sessions/chat_messages 表 + 2 索引。
- `app/lib/features/reader/pages/reader_body.dart`：+61 行——`_aiPanelOpen` field + `_toggleAiDrawer()` + endDrawer 接入 + wide panel 条件渲染 + `_onAskAi` 替换 `_onAiComment` + `_isWideScreen(context)` 1100px 断点。
- `app/lib/features/reader/widgets/reader_scaffold.dart`：移除 onOpenAiGuide/onOpenQa，新增 onToggleAiDrawer（Icons.smart_toy_outlined + Key('toggle_ai_drawer')）。
- `app/lib/features/reader/widgets/reader_selection_toolbar.dart` + `highlight_selection_controls.dart`：onAiComment → onAskAi；标签"AI 点评" → "提问 AI"。
- `app/lib/features/library/pages/book_detail_page.dart`：注释"重新处理" FAB + ai_guide FAB（M2.7 spec §1.2 + §5.7 否决全书导读）。
- `app/lib/features/library/models/book_cell_action.dart`：删除 aiGuide enum value（5→4）。
- `app/lib/features/library/widgets/book_cell_action_menu.dart`：删除 AI 导读 PopupMenuItem。
- `app/lib/features/library/pages/library_page.dart`：删除 aiGuide case + BookPreprocessor 触发。

#### Removed — M2.7

- `app/test/data/local/daos/qa_history_dao_test.dart`（9 用例，测的表已 drop）
- `app/test/services/ai/book_qa_service_test.dart`（7 用例，无 UI 入口）
- `app/test/features/reader/widgets/reader_scaffold_qa_test.dart`（onOpenQa 已移除）
- 注：`QaHistoryDao` + `BookQaService` + `QaAskDialog` + `QaController` 等 production 代码暂保留为 orphan（无 UI 入口），下个 sweep 删除。

#### Tests — M2.7

- 1122 passed / 4 skipped / 7 failed（7 个 pre-existing typography/notes/migration 失败，非 M2.7 引入）
- 6 新 use_case 测试 + 7 新 widget 测试 + 9 新集成测试（5 + 4）= 22 新测试
- `dart analyze lib test` 0 issues

### M4.8 — 2026-07-07（EPUB 渲染引擎：fwfh → TextPainter 自研分页）

**性质**：feature（根治 EPUB paged 模式底部溢出 bug）。

**核心变更**：用 TextPainter 自研分页管线替换 fwfh HTML 渲染，实现"测量即渲染"——
TextPainter 与 SelectableText.rich 共享同一 InlineSpan 输入，layout 结果一致，drift = 0。

**新增组件**：
- `html_to_inline_span_converter.dart` — HTML → InlineSpan 递归转换器
- `line_metrics_paginator.dart` — computeLineMetrics 行级分页
- `inline_span_subtree_slicer.dart` — 静态 InlineSpan 子树切片器
- `selectable_page_view.dart` — PageView + SelectableText.rich 页面组件

**迁移说明**：所有已有基础设施（M3.3 Locator、SelectionArea、LXGWNeoXiHei 字体、
HighlightRange）保持不变，无需数据迁移。≥3 个不支持标签的章节自动回退到 fwfh 渲染。

**性能基线**：50KB 章节 convert + paginate < 200ms；
详见 `reader_engine_epub_view/test/debug/m4_8_perf_baseline_test.dart`。

### M4.6-fix21 — 2026-07-07（PDF 间歇性加载卡死根治：pdfrx openData → FPDF_LoadCustomDocument 死锁）

**性质**：bugfix（根治 fix19 之后残留的 ~40% 间歇性 PDF 加载卡死）。

**症状**：用户实测"连续打开应用 30 多次，~60% 成功率，~40% 白屏不停加载；关闭程序重开往往恢复"。fix19 的"SC1-SC3 三连成功"是**样本量太小**（3 次）漏报了真实分布。

**根因（上游证据）**：
1. **日志铁证**：`zhiyue_pdf.log` 经 `tool/analyze_pdf_log.py` 解析——40 次 openFile，23 成功 / 17 卡死（57.5%，吻合用户"60%"）。卡死全部卡在 `PdfDocument.openData(...)` 永不返回（无 success / 无 TIMEOUT / 无 ERROR，30s timeout 40 次从未触发）。
2. **pdfrx 源码追踪**：`PdfDocument.openData` 把 `maxSizeToCacheOnMemory` 硬编码为 null → 默认 1MB → 任何 >1MB 的 PDF 走 `FPDF_LoadCustomDocument` + 条件变量路径（智阅实测 PDF 7/29/41MB 全部走这条）。
3. **上游 PR #622（jam7, 2026-03-22, 未合并）**：原文 *"when fileSize exceeds maxSizeToCacheOnMemory (default 1MB), openCustom falls through to FPDF_LoadCustomDocument which uses PdfiumFileAccess with condition variables. **This path deadlocks after repeated open/close cycles**."* —— 与智阅症状**逐字吻合**。fix19 的唯一 sourceName 对此**无效**（死锁在 native 条件变量层，不在 cache 层）。

#### Fixed — PDF 加载卡死（三层防御，spec Architecture Decisions A1/A2/A3）

- **L1 主路径**（`pdf_renderer.dart` `openFile`）：改用公开 API `PdfDocument.openCustom(read, fileSize, sourceName, maxSizeToCacheOnMemory: bytes.length)`，**强制 pdfrx 走 `if (fileSize <= maxSizeToCacheOnMemory)` 分支 → `FPDF_LoadMemDocument`**（一次性载入 pdfium 堆，无条件变量），绕开 `FPDF_LoadCustomDocument` 死锁路径。这是 jam7 PR #622 想做的事，但他改的是 pdfrx 源码；我们通过 `openCustom` 的**公开参数**达到同样效果，**不需要 fork**。大文件（>200MB）回退 openData 旧路径（LoadMemDocument 堆压力风险）。
- **L2 引擎重置**（`pdf_renderer.dart` `openFile` 前）：调 `PdfrxEntryFunctions.instance.stopBackgroundWorker()`（pdfrx_engine 0.4.3 公开 API），kill 单例 isolate + `FPDF_DestroyLibrary`，下次 openFile 自动 `_ensureInit` 重建干净 isolate。清零上一本书累积的死锁状态（pdfium 非线程安全，espresso3389 issue #474 原话）。
- **L3 进程兜底**（`pdf_renderer.dart` `dispose`）：`_doc?.dispose()` 之后追加 `stopBackgroundWorker`，退出书时主动清理。三层叠加后期望失败率 < 1%（现状 40%）。

#### Fixed — 顺手修 pdf_renderer_build_test 遗留挂死（pre-existing，fix11~18 引入）

- **根因**：fix11~18（commit 9c6ffad）给 `dispose()` 加了 `await Future.delayed(1500ms)` 作 pdfium native 异步释放 buffer。但 `Future.delayed` 用 Zone timer，在 `WidgetTester` 的 `FakeAsync` 里**无法推进**（测试没 pump）→ `pdf_renderer_build_test.dart` 永久挂死（每次跑 test suite 都 5min timeout）。
- **修复**：`dispose()` 的 doc-dispose + 1.5s buffer + stopBackgroundWorker **三件事都加 `if (_doc != null)` guard**。生产环境 dispose 必在 openFile 之后（_doc 非 null），guard 不影响生产行为；测试环境（从未加载文档）跳过 → 不挂死。
- **验证**：原本挂死的 `pdf_renderer_build_test.dart` 现在 0s 通过；全包 51 个测试全绿（4s）。

#### Key Findings（关键发现）

- **fix19 的"SC1-SC3 三连成功"验证样本太小**，漏报了真实 60/40 分布。**间歇性 bug 的验证必须有 30+ 次大样本**，3 次连过只能说明"在 fresh state 能开"，不能说明"重复 open/close cycle 后仍能开"。
- **pdfrx 的 `openData` 是 >1MB 场景下的死锁陷阱**：内部硬编码 `maxSizeToCacheOnMemory: null` 导致永远走 `FPDF_LoadCustomDocument`。**正确姿势是用 `openCustom` 显式传 `maxSizeToCacheOnMemory: data.length` 强制走 `FPDF_LoadMemDocument`**（数据已在内存，本就该用 LoadMem）。
- **Dart `.timeout()` 对 isolate-native 卡死无效**：40 次 openFile 卡死全部没触发 30s timeout——因为卡在 worker isolate 的 `receivePort.first`（worker.dart:98），主 isolate 的 timer 即便 fire 也只抛 TimeoutException，**底层 native 调用仍卡**，下次 compute 仍会等。所以 timeout 不是治本手段，绕开死锁路径（L1）才是。
- **pdfrx 的 BackgroundWorker 是进程级单例 isolate**（worker.dart:17 `static final _instance`），所有 pdfium 调用串行化。重复 open/close cycle 后状态可能边缘死锁——这是 `stopBackgroundWorker` API 存在的根本原因（espresso3389 在 issue #184/#430 官方推荐用于"释放 pdfium 堆 + 重置引擎状态"）。

#### Lessons（失败对照表）

| # | 历史 fix | 失败原因 |
|---|---------|---------|
| fix9 | 双 PdfViewer 共享 sourceName | 在 dispose 时序上做文章，未触达死锁层 |
| fix13 | dispose timeout 3s→10s + 1.5s buffer | 缓解 dispose 慢，未根治 openData 卡死 |
| fix18 | 试"不调 dispose" | 反而更糟，pdfrx state 半活跃 |
| fix19 | 唯一 sourceName 强制 cache miss | **根治了 cache pollution（独立问题），但没解决 FPDF_LoadCustomDocument 死锁（本 fix）** |
| **fix21** | **openCustom + maxSizeToCacheOnMemory=bytes.length + stopBackgroundWorker** | **绕开死锁路径（L1）+ 重置引擎（L2/L3），三层防御** |

#### Verification（待用户办公室端到端测）

- [x] dart analyze reader_engine_pdf_view: No issues found
- [x] dart analyze app: 我的改动 0 影响（pre-existing 的 markdown lint / custom_lint plugin 错与本次无关）
- [x] 全包 51 个测试通过（含修好的 pdf_renderer_build_test）
- [ ] **SC1**：连续开/关同一 PDF 30 次，成功率 100%（fix19 后是 60%）
- [ ] **SC2**：三本 PDF（7/29/41MB）间切换 30 次，成功率 100%
- [ ] **SC3**：日志 `openFile path=openCustom (LoadMemDocument)`
- [ ] **SC4**：日志每次 openFile 前 `stopBackgroundWorker: done`
- [ ] **SC8**：日志仍有 `openFile unique sourceName`（fix19 不回归）

#### Next Steps

用户构建 exe（junction workaround）后端到端验证 SC1-SC4/SC8。通过后 push Gitee。如仍有 < 5% 残余卡死，下一步考虑 stopBackgroundWorker 加更激进的 timeout 或回退到 openFile + 临时文件方案（jam7 最终用的 workaround）。

---

### M4.7b — 2026-07-07（EPUB 滚动模式调研：第二套方案 + 重大代码盘点发现）

**性质**：M4.7 的补充调研，无代码改动。聚焦用户提出的"第二套方案——单页滚动浏览模式"。

**用户洞察**：*"双页翻页模式适合纯阅读，滚动单页模式在 AI 功能上线后使用率很高——左右抽屉展开后中间单页滚动体验更好。"*

**核心发现（重大）**：通过 grep 调查发现，智阅的 `reader_engine_epub_view` 包**已经完整实现了 PaginationMode.scroll 滚动模式的整个底层链路**——`_buildScroll`（SingleChildScrollView + HtmlWidget）、章末检测（滚到 64px 内）、tap zone 换章分支、滚动位重定位全部就位，但 **UI 层没有任何切换入口**（`setPaginationMode` 在 app/lib 下零调用）。也就是说，滚动模式被"冰封"了——代码写了、测试过了，但用户永远访问不到。

**关键技术洞察**：M4.6-fix20 锁定的 fwfh 分页死结（widget height 只能在渲染后得知，事前测高不可能）**只在分页模式下存在**。滚动模式用 `SingleChildScrollView + HtmlWidget`，根本不需要事前测高——fwfh 在 `RenderMode.column` 默认下于无限高度约束中一次性渲染整章，Flutter viewport 自动按可见部分构建 RenderObject。**fwfh 路线在分页已死，但在滚动完全可用**。

#### Added — 滚动模式调研汇报（spec）

- **新文档**：`docs/superpowers/specs/2026-07-07-m4.7b-epub-scroll-mode-research-design.md`（约 11k 字）
- **覆盖范围**：
  - **规范层**：EPUB 3 / W3C 把 `rendition:flow` 定义为四种值（paginated / scrolled-continuous / scrolled-doc / auto），滚动模式是规范一等公民
  - **业界共识**：Neat Reader（"Choose Page or Scroll mode"）/ Apple Books（4 种翻页含 Scroll）/ 微信读书 / Readium / Calibre / Foliate **全部双模式并存**
  - **fwfh 可用性判定**：滚动模式下不需要事前测高，drift 问题不存在，fwfh 完全可用
  - **智阅代码盘点**：列出已实现的 7 项能力（模式枚举 / API / 渲染分支 / 章末检测 / tap zone / scrollController / Locator 重定位），证据精确到文件:行号
  - **AI 场景契合度分析**：scroll 模式下展开左右抽屉时内容自动 reflow，paged+双页会被挤压错位——这是 Neat Reader / 微信读书在 AI 场景下都用滚动的根本原因
  - **风险与防御**：4 个风险点（长章节性能 / Locator 精度 / 与 M4.8 关系 / 双页互斥）

#### Key Findings（关键发现）

- **滚动模式 95% 已实现**：底层链路全部就位，只缺 UI 切换按钮 + 持久化。1-2 天工作量即可上线。
- **fwfh 在滚动模式完全可用**：分页死结（事前测高不可行）只在分页模式存在，滚动模式用 `SingleChildScrollView` 绕过整个问题。
- **业界标配双模式**：所有主流 EPUB 阅读器（Neat Reader / Apple Books / 微信读书 / Readium）都同时支持翻页 + 滚动，不是二选一。
- **EPUB 3 规范一等公民**：`scrolled-continuous` 是 W3C 明确定义的 flow 模式，不是 hack。

#### Decision Summary（决策摘要）

| 决策 | 内容 | 理由 |
|---|---|---|
| **AD1** | 立即实施滚动模式（M4.7b 快速跟进） | 底层 95% 已实现 + 绕过分页死结 + AI 场景刚需 |
| **AD2** | 滚动模式不替代分页，而是并存 | 用户已识别场景分层：纯阅读 paged，AI 辅助 scroll |
| **AD3** | M4.8 引擎切换降级为长期优化 | 滚动模式上线后底部溢出痛点已解，可从容做引擎切换 |

#### Lessons

- **grep 是发现"冰封功能"的最强工具**：在判断"要不要做某功能"之前，先 grep 一下现有代码。智阅的滚动模式 95% 已实现却无人知晓，是因为 M3.4 时代写了但 UI 没接。这种"沉没的功能"在长迭代项目里很常见。
- **架构性死结往往是模式相关的**：fwfh 的事前测高死结只在分页模式存在。换一个模式（滚动）可能完全绕过死结，不需要换库。**在决定"换引擎"之前，先评估"换模式"是否可行**——成本低几个数量级。
- **用户的场景洞察往往直指架构**：用户说"AI 场景用滚动更好"，本质是识别了"paged 模式 + 抽屉挤压 = 翻页错位"的架构问题。这种来自使用场景的洞察比纯技术分析更直接。

#### Next Steps（M4.7b plan 的 Pre-flight Checklist）

- [ ] UI 入口设计（复用字体/主题面板，加"阅读模式"二选一）
- [ ] SharedPreferences 持久化
- [ ] 切换时状态过渡（清 `_cachedBreaks` / 重新分页）
- [ ] 进度条百分比适配
- [ ] tap zone UX 验证
- [ ] 抽屉联动测试
- [ ] 回归测试（现有 paged 模式不受影响）
- [ ] 双页模式互斥（切 scroll 自动关双页）

### M4.7 — 2026-07-07（EPUB 渲染引擎切换调研：开源全景 + Neat Reader 拆解）

**性质**：调研型 spec，无代码改动。作为下一轮（M4.8）EPUB 引擎切换的设计依据。

**背景**：M4.6-fix20 在 fwfh 0.15.3 上烧了 7 轮（fix12→17 + Solution A/B），全部失败。根因经逐字测试锁定：measurer 单段独立渲染 81px vs 整页实际 128px，drift -47px（58% undercount）。fwfh issue #138（2020-03 至今 Open、`help wanted`）确认上游无分页能力——这是架构性缺陷，非版本 bug，升级 0.16+ 也不会解决。继续在 fwfh 上投资是沉没成本。

#### Added — EPUB 引擎切换调研汇报（spec）

- **新文档**：`docs/superpowers/specs/2026-07-07-m4.7-epub-engine-switch-research-design.md`（约 14k 字）
- **覆盖范围**：
  - **开源全景**：14 个项目按渲染引擎分 4 类（WebView+CSS columns / 原生 TextPainter / 原生排版引擎 / Flutter+Rust）
  - **Neat Reader 拆解**：通过 Android 包名 `com.gzhi.neatreader.r2.main` 锁定底层为 **Readium R2 全家桶**（iOS 用 swift-toolkit、Android 用 kotlin-toolkit、桌面/Web 用 r2-navigator-js），分页机制是 CSS columns
  - **方案对比**：5 个候选方案（A1 WebView+epub.js / A2 cosmos_epub 路线 / A3 升级 fwfh / A4 Rust 桥 / A5 纯自绘）
  - **决策**：推荐 **A1（WebView + epub.js + flutter_inappwebview）** 为主，**A2（参考 cosmos_epub，TextPainter 自绘）** 为备选；明确放弃 fwfh / Rust 桥 / 纯自绘
  - **风险与防御**：5 个风险点（桌面 WebView2 / 内存 / CFI↔Locator 互转 / A2 fallback 成本 / 富 HTML 降级）

#### Key Findings（关键发现）

- **工业级共识**：Neat Reader / Readium / epub.js / foliate-js / vocsy 全行业走 **CSS columns + WebView** 路线，分页精度工业级（永不切行）。这不是巧合，是浏览器排版引擎的工业级成熟度决定的。
- **cosmos_epub 1.0.0 是 Flutter 原生路线的关键证据**：他们 2026-04 在 changelog 里明确写 *"Replaced flutter_html with native Text.rich/SelectableText.rich... Accurate Pagination: TextPainter-based page splitting with real font metrics instead of height estimation. Pages are consistent in height."* —— 这条路被验证过。
- **fwfh 路线已死**：issue #138 中社区开发者 getBoolean 总结的死结——*"widget height can only be known after render, which is orthogonal to Flutter's layout system"*——正是我们 7 轮失败的根因。
- **Rust 桥不解决问题**：Ferrous / velora 用 Rust 做 PDF/解码，但 EPUB 渲染仍走 Dart（因为分页是 Flutter widget 层问题）。

#### Decision Summary（决策摘要）

| 方案 | 推荐度 | 理由 |
|---|---|---|
| **A1：WebView + epub.js** | ⭐ 首选 | 工业级共识，绕过 Flutter layout 死结，自带 CFI/高亮/搜索 |
| **A2：参考 cosmos_epub 自研** | ⭐ 备选 | A1 桌面验证失败时降级，纯 Flutter 无 WebView 依赖 |
| A3：升级 fwfh 0.16+ | ❌ 放弃 | issue #138 证明架构性缺陷，升级无用 |
| A4：Flutter + Rust 桥 | ❌ 放弃 | 不解决分页问题（Rust 替代不了 Flutter layout） |
| A5：纯自绘 CustomPaint | ❌ 放弃 | 过度工程，cosmos_epub 已证明 `Text.rich` 就够 |

#### Lessons

- **包名是判断闭源移动应用底层框架的最强信号**：远比 UI 截图可靠。`.r2.` 后缀 + 自称 "kernel/parsing engine" + 跨平台一致性 → 锁定 Readium R2。
- **fwfh 7 轮失败的元教训**：看到上游 issue 长期 Open + `help wanted` + 维护者明确"不知道怎么做"时，应该**早做架构切换决策**，而不是反复在同一库上尝试 workaround。systematic-debugging Phase 4.5（"3+ failures = question architecture"）应该在 fix15 失败时就触发，而不是拖到第 7 轮。
- **调研先行 vs 直接动手**：本轮纯调研（无代码）的价值远高于上一轮直接动手 7 次失败。在架构性问题上，1 天调研 > 7 天试错。

#### Next Steps（下一轮 M4.8 的 Pre-flight Checklist）

- [ ] 桌面 WebView2 可用性 spike（Windows 11 + flutter_inappwebview）
- [ ] epub.js 中文支持 spike（CJK + 字体嵌入）
- [ ] CFI ↔ 智阅 Locator 适配层设计
- [ ] A2 fallback 原型（cosmos_epub HtmlTextBuilder，1-2 天 timebox）
- [ ] 迁移策略（旧代码保留/删除 + 高亮数据 migration）

### M4.6-fix19 — 2026-07-07（PDF 加载卡死根治：pdfrx sourceName cache pollution）

**症状**：用户报告"昨天第一次开 PDF 还行，今天 PDF 不能正常加载"。`zhiyue_pdf.log` 证据：每次 `openFile` 都卡在 `PdfDocument.openData(_bytes!)`，bytes 读完但 Future 永不 complete（30s 超时）。

**根因（smoking gun）**：`PdfDocument.openData` 不传 sourceName 时，pdfrx 默认用 `'data%${sha256(data)}'`（`pdfrx_engine/lib/src/native/pdfrx_pdfium.dart:645-647`）。同一 PDF 字节不变 → SHA-256 不变 → sourceName 跨会话稳定。pdfrx 进程级 static cache `_listenables`（`pdf_document_ref.dart:92`）按 sourceName 缓存 PdfDocumentListenable，一旦某次加载卡死留下 broken listenable，之后任何同 sourceName 的 openData 都命中 broken entry → `FPDF_LoadMemDocument` 永不返回。这就是 fix9/fix13/fix18 都没找到的真因——它们都在 dispose 时序上做文章，但 cache 命中是在 dispose 之前发生的。

#### Fixed — PDF 加载卡死（一行治本）

- **方案**：每次 `openFile` 生成唯一 sourceName `'zhiyue-pdf-${DateTime.now().microsecondsSinceEpoch}'`，强制 pdfrx cache miss → 每次全新 listenable → 永不命中 broken cache。
- **改动**（`pdf_renderer.dart`）：
  - 新增 `String? _uniqueSourceName` 字段（带详尽根因注释）
  - `openFile`：`PdfDocument.openData(_bytes!, sourceName: _uniqueSourceName)`
  - `_buildMain`：`PdfViewer.data(bytes, sourceName: _uniqueSourceName, key: ValueKey('pdf-main-$_uniqueSourceName'))`
  - TimeoutException 错误信息更新：去掉"pdfium 状态污染"误导，改成"文件格式不兼容"指引（Adobe Reader 另存为 PDF/A）
  - dispose 注释更新：移除 fix13 长注释（已过时），保留 timeout + 1.5s buffer 作防御性兜底
- **代价**：失去跨 PdfViewer 共享 PdfDocument 的内存优化。智阅单 viewer，代价为零。
- **与历史 fix 的关系**：fix9/13/18 都在 dispose 时序上做文章（缓解未根治）。fix19 直接从 cache key 入手，**一行治本**。fix13 的 dispose timeout + buffer 保留作 corner case 防御，不删。

#### Lessons

- pdfrx 的 sourceName 不是"标识"，是**进程级 cache key**——必须唯一，否则会跨会话命中 broken entry。
- 看到"第一次能开、第二次不能开"且 `dispose` 链路完整时，**先怀疑 cache 而非 native 时序**。
- 用户原话"昨天能今天不能"+"同文件"这两个特征，强烈指向基于内容哈希的 cache 污染。

### M4.6-fix10 — 2026-07-06（六大稳定性/排版问题综合治理）

用户在 M4.6-fix9（commit ed6ab68）后报告 6 个阻塞问题：①PDF 双页仍卡死 ②MD 排版仍乱（同文档 TXT 正常 MD 异常）③EPUB《一本书读懂财报》翻页/目录卡死 ④EPUB/TXT 双页跨页选区串读 ⑤摘录新增当场不显示 ⑥阅读区红色蒙层+导航条消失。按 systematic-debugging 完整根因调查后逐一修复，每个问题都现场验证了根因证据。

#### Changed — PDF 彻底锁死单页（A1）

- **决策**：fix9 的"双 PdfViewer 共享 sourceName"方案在用户实测仍卡死（pdfrx 双 PdfViewer `_attach`/`_detach` 竞态未根治）。用户决定先稳定——彻底移除双页入口。
- **改动**：
  - `reader_body.dart:407` `e.dualPageMode = isWide && !isScanned` → `false`
  - `reader_body.dart:576-584` `onToggleDualPage: null` → ReaderScaffold 不再渲染双页 toggle 按钮
  - `pdf_renderer.dart` 删除 `_buildDualPage`(469-537)、`_buildDualParams`(536-552)、`_dualLeftController`/`_dualRightController` 字段、setPage 的 dual 分支。`build()` branch 判定简化为永远 main。
- **PDF 缩略图同步**：`reader_drawer_builders.dart:62-84` 缩略图 `currentPage` 改为 `StreamBuilder` 监听 `pdfEngine.rendererRef.currentLocation$`，主区翻页时 stream emit → grid 重建 → 当前页高亮实时跟随（旧实现只在 drawer build 时读一次，主区翻页后高亮不刷新）。

#### Fixed — MD 排版根因（A2，5 次失败的共同元凶）

- **现场证据**（test/debug/compare_txt_md_test.dart 跑出来的 HTML 对比）：
  - 输入「第一点\n第二点\n第三点\n第四点」（4 行连续文本）
  - TXT 产出：`<p>第一点</p><p>第二点</p><p>第三点</p><p>第四点</p>`（4 个独立 `<p>`，0 个 `<br>`）→ Paginator 测准 → 正常
  - MD 产出：`<p>第一点<br />第二点<br />第三点<br />第四点</p>`（1 个 `<p>` 内含 3 个 `<br>`）→ Paginator 测偏 → 溢出
- **根因**：fix7 加的 `_forceVisibleLineBreaks`（`markdown_book_loader.dart:147-179`）给每行尾补两空格，markdown 标准库识别为 hard break → 产 `<br>`。但 Paginator 按 plain text 字符偏移测高，`<br>` **不增加偏移却增加视觉高度** → 测出来"很矮"、实际渲染"很高" → 一页塞太多 → 内容溢出页面边界。**这是 fix2/3/5/7/9 共 5 次失败的共同元凶**。
- **修复**（用户决策"按 TXT 技术逻辑"）：重写 `MarkdownBookLoader._markdownBodyToHtml`：
  - 删除 `md.markdownToHtml()`、`_forceVisibleLineBreaks`、`_isStructuralLine`、`_stripImages`
  - 仿 `TextBookLoader.parseText`：按 `\n` 分行 → 每行 trim → 空行跳过 → 每行独立成 `<p>...</p>`
  - **轻量保留行内语法**：`**粗体**`→`<strong>`、`*斜体*`→`<em>`、`` `代码` ``→`<code>`（占位符保护）、`[text](url)`→`text`
  - 围栏代码块（` ``` `/`~~~ `）内的行原样转义成 `<p>`，不做行内替换
- `reader_engine_provider.dart:105` 删除 `setPaginationMode(scroll)` → MD 走默认 paged + 双页，与 TXT 完全同构
- **章节保留**：`parseMarkdown` 的 `#`/`##` 切章逻辑不动，TOC 自动生成，章节跳转/高亮全部继承

#### Fixed — EPUB 翻页/目录卡死 O(N²)→O(N)（A3）

- **根因**：`_buildPaged` 的 LayoutBuilder 内，每个 break 都调 `HtmlSlicer.sliceByPlainRange`，后者每次都 `HtmlParser(html).parse()` 整章 DOM（`html_slicer.dart:62`）。一本长章节（财经书表格多，50+ 页）单帧 50 次 `HtmlParser.parse()`，每次 O(章长度) → 单帧数百 ms → UI 线程堵死 → 翻页/目录 `await chapterSwitchSettled` 永远不返回（它等的 post-frame callback 被堵在队列里）。
- **修复**：`html_slicer.dart` 新增 `sliceByPlainRangeDoc(Document doc, ...)` 接受预解析 Document，**非破坏式**遍历（重写 `_cloneFiltered` 不修改 source doc，构造新子树）。`epubx_renderer.dart:1083-1109` 改为循环外解析一次 DOM，循环内所有 break 复用同一 `chapterDoc` 实例。复杂度从 O(N × 章长度) 降到 O(章长度 + N × 页内 DOM) ≈ O(N)。
- **测试**：新增 3 个非破坏式测试（同一 doc 切多范围互不干扰、不修改 source doc、与旧 API 行为一致），全部通过。

#### Fixed — 双页跨页选区串读（A4）

- **根因**：`reader_body.dart:548-552` 单个 `SelectableRegion` 包整个 reader stack（含双页 Row）。Flutter `SelectionRegistrar` 按几何位置合并选区，左右页同一 Y 行的文本都在选区矩形内 → **右页同行被一并选中**。
- **修复**：`epubx_renderer.dart` 双页 Row 内每个 `Expanded` 包独立 `SelectionArea`（SelectableRegion 的 Material 包装），建立局部 registrar，子树 selectable 不冒泡到外层 SelectableRegion。每页的 `onSelectionChanged` 通过 renderer 新增的 `pagedSelection$` 流推到 reader_body，复用 `_onSelectionChanged` 处理。单页模式不包（保持外层 region 行为）。

#### Fixed — 摘录新增后不刷新（A5）

- **根因**：`local_notes_repository.dart:193-202` 的 `watchAnnotations` 在 `noteRow == null` 时 `yield []; return;` 终结 stream。首条摘录场景 BookNote 不存在（t0），`_ensureBookNote` 创建 BookNote（t1）后 stream 已死，新摘录永不推送 → UI 不刷新，需退出书架重进。
- **修复**：`book_notes_dao.dart` 新增 `watchByBookId`（drift `.watchSingleOrNull()`，底层表变化重发）。`watchAnnotations` 改用 `await for (final noteRow in _notesDao.watchByBookId(bookId))`，noteRow == null 时持续 yield `[]`，noteRow 出现后切换到 `annotations.watchByBookNoteId`（永久 emit）。

#### Added — 全局错误兜底（A6）

- **根因**：`main.dart` 无 `ErrorWidget.builder` / `FlutterError.onError` / `runZonedGuarded`。任何 widget build 抛异常 → Flutter 默认红底白字 ErrorWidget 替换整棵子树。`reader_body.dart:543-589` 的 chrome（导航条）+ 正文在同一 Stack → 一处异常全树崩 → "红色蒙层 + 导航条消失"。
- **修复**：`main.dart` 加三件套：
  1. `ErrorWidget.builder` → 自定义 `_ZhiYueErrorWidget`（白底 + 错误图标 + "页面渲染异常" + 异常摘要）
  2. `FlutterError.onError` → debugPrint 记录
  3. `runZonedGuarded` 包 runApp → 捕获异步未捕获异常

#### Lessons（失败对照表）

| # | 问题 | 历史失败次数 | 本次根因 |
|---|------|-------------|---------|
| 1 | PDF 双页 | fix4~fix9 共 6 次 | pdfrx 双 PdfViewer 竞态未根治 → 锁死单页 |
| 2 | MD 排版 | fix2/3/5/7/9 共 5 次 | `<br>` 不增 plain 偏移却增视觉高度 → 仿 TXT 每行成 `<p>` |
| 3 | EPUB 卡顿 | M3e/Q12 共 1 次（治标） | O(N²) DOM 解析 → 整章一次复用 |
| 4 | 双页跨页选区 | 首次报告 | 单 SelectableRegion 包整树 → 每页独立 SelectionArea |
| 5 | 摘录不刷新 | 首次报告 | stream 在 noteRow==null 时 return → 双表 watch |
| 6 | 红色蒙层 | 首次报告 | 无全局兜底 → ErrorWidget.builder + zone |

#### Verification

- 单元测试：751 通过 / 14 跳过 / 254 失败（**254 全是 drift native fts5 模块环境缺失**，pre-existing，与本次改动无关）
- 关键测试全绿：MD loader 28 个、html_slicer 21 个（含 3 个新增非破坏式）、epubx_renderer dual page 10 个
- 构建 exe：**失败**——Flutter `gen_snapshot` 在中文路径下用 GBK 解码路径，UTF-8 中文变乱码（`锟斤拷`）找不到 app.dill。这是 Flutter 工具链 pre-existing bug（非代码问题），需用户在英文路径环境构建或用 8.3 短名 workaround。

---

### M4.6-fix9 — 2026-07-05（PDF 双页死锁根治 + MD 段落溢出修复）

M4.6-fix4~fix8 共 5 次在 PDF 死锁上失败、fix2/3/5/7 共 4 次在 MD 分段上失败后，触发 systematic-debugging 阶段 4.5（架构质疑）。基于 `zhiyue_pdf.log` 铁证 + pdfrx 源码调研，确认为架构错误，重写两处管线。

#### Changed — PDF 双页改用双 PdfViewer 共享 PdfDocument（方案 A''）

- **根因（日志铁证）**：`zhiyue_pdf.log` 显示 `dispose start` 后无 `dispose done`——`_doc.dispose()` 永不返回。旧双页实现用两个 `PdfViewer.data()` 配 `#L`/`#R` **不同 sourceName**，pdfrx `CanonicalizedMap`（`pdf_document_ref.dart:18/78/92-97`）视为两份文档 → pdfium 加载两份 29MB → dispose 时序混乱 + 渲染线程未完成 → `FPDF_CloseDocument` 死锁 → 进程僵尸 → 持有 named mutex → exe 二次启动失败。
- **修复**：双 `PdfViewer.data()` 改用**相同 sourceName**（`doc.sourceName`，去掉 `#L`/`#R` 后缀）→ pdfrx 自动共享同一份 `PdfDocument`（官方 `PdfDocumentRefKey` 缓存机制）→ 只加载一次 → dispose 干净。
- **翻页正确性**：两 viewer 各 `NeverScrollableScrollPhysics` 锁定到 `initialPageNumber`，翻页 step=2 用 `ValueKey('pdf-dual-L-$leftIdx')` 变化触发 widget 重建到新页。spread 序列 (1,2) → (3,4) → (5,6)，不出现 2-3 错位（用户提出的核心担忧已排除）。
- **方案选型**：原"方案 A：单 PdfViewer + PdfPage.render() 副页位图预览"被用户敏锐指出存在 2-3 错位风险 + 主页可滚动导致不同步 + 副页不能交互（文本选择/缩放）三大问题，调研 pdfrx 源码后推翻，改用方案 A''（双 viewer 共享 PdfDocument）。

#### Changed — PDF dispose 加 3s timeout 安全网

- `_doc.dispose()` 包 `.timeout(Duration(seconds: 3))`，超时 catch `TimeoutException` 后继续关闭 stream。主修复（共享 PdfDocument）已根除死锁源，此 timeout 仅防未来回归。

#### Changed — MD 强制走 scroll 模式（复用既有 `_buildScroll`）

- **根因**：MD 复用 EPUB 的 `Paginator`（按 plain text 偏移机械分页），`<br>` 强制换行（`_forceVisibleLineBreaks`）打破"连续字符流"假设 → 段落被切到页中、内容溢出页面边界（fix2/3/5/7 共 4 次失败）。
- **修复**：`reader_engine_provider.dart` 里 MD 路由调 `engine.setPaginationMode(PaginationMode.scroll)`，复用既有 `_buildScroll`（`SingleChildScrollView + HtmlWidget`），段落完整、不溢出。MD 不做双页（fwfh 不支持 CSS column-count，双栏需自定义 RenderObject，收益低；MD 内容通常技术文档，单列滚动可接受）。
- **TXT 零改动**：TXT 仍走 paged + 双页（用户确认 TXT 正常）。

#### Fixed — exe 二次启动失败（PDF 死锁的下游级联）

- PDF 死锁根治后，进程能正常退出，named mutex 自然释放，二次双击正常启动。

#### Lessons — fix4~fix8 在 PDF 死锁上失败的教训

| 轮次 | 假设 | 实际 | 教训 |
|------|------|------|------|
| fix4 | ExitProcess 解决僵尸 | PDF 死锁未解，进程仍挂 | 死锁源在 Dart 侧 dispose，不在 C++ 侧 |
| fix6 | 互斥锁接管解决二次启动 | PDF 死锁未解，接管无效 | 接管只能处理"已死"互斥锁，不能让活进程退出 |
| fix8 | 日志能定位死锁源 | 日志正确，但双 PdfViewer 是死锁源本身 | **架构错误，不是日志问题** |
| fix9 | 共享 PdfDocument 根除死锁 | （待用户端到端验证） | 架构对了，死锁应消失 |

MD 同理：fix2/3/5/7 在 paged 模式 + Paginator 上打补丁失败，根因是 Paginator 的"纯文本测量"假设与 MD 的 `<br>` 换行不兼容，改走 scroll 模式（HtmlWidget 原生布局）才是正解。

### M4.6-fix4 — 2026-07-05（exe 二次启动闪退 + PDF 翻页卡 loading + MD 排版乱）

用户测试 M4.6-fix3（commit 54221f9）后报告三个阻塞问题：①exe 关闭后再次双击"图标闪一下就没了" ②PDF 翻 10+ 页后阅读区不停 loading，回退也 loading ③MD 阅读完全乱（未双页、超出页面很多、第二章标题"变图片"）。按 systematic-debugging 流程做完整根因调查后逐一修复。

#### Fixed — exe 二次启动闪退（main.cpp named mutex + 进程残留）

- **根因**：`tasklist` 显示用户"关掉"窗口后 zhiyue.exe 进程仍残留（PID 2932, 656MB），named mutex `Local\\ZhiYueApp` 永远 `ERROR_ALREADY_EXISTS` → 第二实例 `is_first_instance = false` → argv 空（桌面图标双击启动无参数）→ 直接 `return EXIT_SUCCESS` → 用户看到"图标闪一下就没了"。进程残留源于 Flutter engine 关窗时若 native plugin（pdfrx PDFium / window_manager）持有未释放资源，message loop 的 `GetMessage` 链可能挂在某个消息处理里出不来。
- **修复 1（兜底）**：`wWinMain` 末尾 message loop 退出后强制 `::ExitProcess(EXIT_SUCCESS)`——跳过 Dart dispose / C++ 析构，但 kernel mutex / COM 资源由 OS 回收，确保下次启动拿到 fresh 状态。drift WAL 模式下已提交事务不会丢。
- **修复 2（体验）**：第二实例发现已有窗口时**无论 argv 是否为空都 SetForegroundWindow + SW_RESTORE**（之前仅 argv 非空时转发，桌面图标双击启动 argv 空 → 无反应）。用户从桌面图标二次启动最期望的是已有窗口前置，不是无反应退出。

#### Fixed — PDF 翻 N 页后无限 loading（pdf_renderer widget tree 稳定化）

- **根因**：`PdfRenderer.build` 用 `FutureBuilder<bool>` 包裹 `PdfViewer`，每次父级 rebuild（窗口尺寸变化/翻页 setState/typography 变化）都重建 widget tree → pdfrx `_PdfViewerState.didUpdateWidget` 触发 reload path → `loadPagesProgressively` 重启 → pageImage 缓存累积（pdfrx 2.4.4 `PdfViewerParams` 无 maxPinPages 上限）→ 内存压力 → 后续 page render 阻塞 → loading banner 一直显示。`PdfViewerParams` 每次 build 都 new 一个新实例（函数字段比对引用相等），闭包重建触发 `doChangesRequireReload`。
- **修复**（`pdf_renderer.dart`）：
  - **移除 FutureBuilder**：scanned 判定改走 `openFile` 时启动 Future + `then` 回调写 `_scannedCache` + setState，build 走同步路径。
  - **加 RepaintBoundary**：build 顶层包 `RepaintBoundary` 把 PDF 阅读区与父级 reader_body 隔离。
  - **PdfViewer 加 ValueKey**：`ValueKey('pdf-main-${doc.sourceName}')`，同书 State 复用稳定，切书 sourceName 变 → 干净重建。
  - **PdfViewerParams 方法化**：`_buildMainParams()` 单独抽出，buildContextMenu fallback 用 pdfrx 自带的 `params.a?.page.pageNumber` 而非闭包捕获的 `_currentPage`（避免 stale 值）。

#### Fixed — MD 排版完全乱（删 _preserveLineBreaks 回归 CommonMark + 移除 img）

- **根因（排版乱）**：M4.6 (#5) 的 `_preserveLineBreaks` 给每行尾部强制补两空格让 markdown 视为 hard break → 段内换行被强制 `<br>` → fwfh 把段落切成断行堆叠，**违反 CommonMark 段内合并语义**（CommonMark 规定段内单换行渲染时合并为同段连续流，行尾两空格或反斜杠才是 hard break）。原始 MD 文档的"一行一段/一句"只是源码可读性，渲染时本就该合并。表现为"第一段在左上、第二段在右下、超出边界"。
- **根因（标题变图片）**：fwfh `HtmlWidget` 默认渲染 `<img>`，MD 无 base URL 时 src 当网络 URL，显示 loading 占位/异常图标。用户报告"第二章标题变图片"很可能就是 `# ![icon](...)` 在 fwfh 里渲染成了图片占位。
- **修复**（`markdown_book_loader.dart`）：
  - **删除 `_preserveLineBreaks` 全部逻辑**，`_markdownToHtml` 直接走 `md.markdownToHtml(body)`。CommonMark 标准库已正确处理段内合并 / 显式 hard break / 空行分段 / 标题列表引用代码块结构。
  - **新增 `_stripImages`**：用正则匹配 `<img alt="..." ...>` 移除 `<img>` 标签，保留 alt 文本作 `[alt]` 占位（让读者知道这里有图但不尝试加载）。MD 阅读场景无网络/相对路径解析能力，移除是合理 trade-off。
- **测试**：新增 `markdown_book_loader_no_force_break_test.dart`（9 cases：段内合并、显式 hard break 保留、列表/引用不受影响、独立图片移除、标题内图片移除、多图片移除、无 alt 不崩溃）。更新 `markdown_book_loader_test.dart` 2 个旧测试反映 CommonMark 新语义。共 33 个 MD 测试 + 51 个 PDF 测试 + 2 个 MD scroll 集成测试全 pass。

#### Fixed — main.cpp 加 UTF-8 BOM（MSVC C4819 警告被视错误）

- M4.6-fix4 main.cpp 加了中文修复说明注释，MSVC 在中文系统代码页 936 (GBK) 下报 C4819 警告被项目视为错误，导致 `flutter build windows` 失败。
- 加 UTF-8 BOM (`EF BB BF`) 后 MSVC 自动识别源文件为 UTF-8 编码，C4819 消失。原 `L"智阅"` 窗口标题字面量此前能编译是因当时文件全英文（仅 ASCII），不受代码页影响；本次新增中文注释触发了潜伏的编码问题。

#### Lessons

- **systematic-debugging 铁律生效**：本次三个问题都先完整跑 Phase 1（根因调查）+ Phase 2（pattern 对比）才动代码。问题 1 通过 `tasklist` 发现进程残留；问题 2 通过读 pdfrx 2.4.4 源码定位 FutureBuilder 重建链；问题 3 通过读 CommonMark spec + 跑 markdown 标准库验证段内合并语义。无猜测式修复，无"再试一次"。
- **MD 排版的 CommonMark 误区**：曾以为 MD"一行一句"是渲染应保留的语义，实际 CommonMark 明确规定段内单换行渲染合并。原始文档的分行只是源码可读性约定（类似代码格式化）。修复方向是删除强制 hard break 而非扩展跳过规则——之前 M4.6-fix (#3) 试图用 `_isStructuralLine` 跳过结构行，但永远跳不完所有边界（图片、表格、脚注、定义列表…）。回归标准才是正解。
- **PDF 不能 headless 测试**：pdfrx 需要 PDFium native binary，flutter test headless runner 不支持。PDF 修复只能通过读 pdfrx 源码 + 推理 + 用户实测验证。本次修复的回归测试是 widget-level（key 稳定性、FutureBuilder 移除），不能验证实际 PDF 渲染。
- **MSVC C4819 潜伏陷阱**：项目 `Treat Warnings As Errors` 开启时，任何含非 ASCII 字符的源文件都需要 UTF-8 BOM 才能在非 UTF-8 系统代码页编译。今后 Windows runner 任何 .cpp/.h 加中文必须先加 BOM。



用户反馈"部分页面文字比较多的时候下方文字会超出页面下底线，导致部分数据看不到"。

#### Fixed — Q8 分页测量漏算段间距/缩进/冗余导致末行被裁

- **根因**：`Paginator._paginateUncached` 的分页测量与 fwfh 实际渲染存在**系统性偏小**，导致每页塞入过多内容 → 渲染时末行溢出底部被裁。代码 L920-924 自己注释承认误差存在，但低估了累积量。具体 3 处漏算：
  1. **段落间距**：测量只算 `TextPainter` 纯文本高度，但渲染层 `_paragraphMarginBuilder` 给每个 `<p>` 加 `margin: 0 0 0.5em 0`。一页 N 段时累积漏掉 N×0.5em。
  2. **首行缩进 em-space**：`TypographyStyleInjector` 每段首行注入 2×`U+2003`（≈2em），首行有效宽度变窄 → 多换 1 行。测量层不知道此前缀。
  3. **安全冗余为 0**：`TextPainter` 与 fwfh 的 `line-height`/font-metrics 有微小偏差（代码自认 <1 行），临界页（刚好踩线）易溢出。旧代码容差为 0。
- **为何"看不到"而非"斑马线"**：页面包了 `SingleChildScrollView(NeverScrollableScrollPhysics)`（M2.10 防 assertion），溢出时不会抛 RenderFlex assertion（无斑马线），但 `NeverScrollable` 也无法滚动看到被裁内容 → 用户看到末行凭空消失。
- **修复**（`paginator.dart` `_paginateUncached`）：
  - 测量每段时把缩进前缀 `indentEm × U+2003` 拼到段首，让 TextPainter 自然算入首行多换的行。
  - 非页首段累加 `0.5em` 段间距（页首段上方无前段，不加）。
  - 临界判断加 `safetyMargin` 冗余，临界页提前换页（初始 1 行高度，Q8续 调到 0.3 行——见下）。
- **回归测试**（`paginator_overflow_test.dart`，3 cases 全过）：
  - 60 段长内容分页数 > 3（防分页过粗）。
  - 30 段内容每页纯文本高度 ≤ 可用高度（直接证明不再过满）。
  - 缩进关闭时仍正确分页。

### M3e/Q8续-Q12 — 2026-07-04（paged 模式边距统一 + 翻页卡顿）

Q8 修完溢出后，用户连续反馈 4 个 paged 模式排版/性能问题，逐一定位修复。最终采用**真书版心固定**模型（放弃居中对齐）。

#### Fixed — Q8续 上下边距不对称 → safetyMargin 从 1 行降到 0.3 行

- 用户反馈「上边距窄、下边距宽」。根因：Q8 的 `safetyMargin = 1 行高度`（32px）过保守，每页底部多预留一整行 → 视觉上下方明显比上方宽。
- 修复：`safetyMargin = 0.3 × lineHeight`（约 10px），既保留临界页防溢出余量，又消除肉眼可见的上下不对称。

#### Fixed — Q9 双页模式右页上下边距比左页窄

- 用户反馈「左右两页都有内容时，右侧上下边距比左侧窄一点点」。
- 根因：双页 `Row` 的左右两页各自用 `_PageVerticalAligner` 独立管理上下边距，fwfh 渲染高度与 TextPainter 测量的微小偏差在左右两页独立累积，导致右侧略偏。
- 修复：双页模式引入 `_DualSpreadAligner`，**上下边距提升到 spread 层统一管理**（左右两页共享同一 vertical padding），`_PageVerticalAligner` 在双页模式下 `enableCentering=false` 且不重复加 padding。

#### Changed — Q10+Q11 放弃居中对齐，改真书「版心固定」模型

- 用户反馈反复振荡：居中对齐（Q8续 目标）能修上下对称，但破坏左右对齐（Q9）和导致页高跳变（Q11）；顶部对齐能修左右和页高，但上方比下方窄（Q8续/Q10）。
- **最终决策**：完全放弃居中，所有页**固定顶部对齐**到统一边距（真书做法）。满页底部允许有少量自然留空（末页更明显），这是真书的正常版心效果，用户接受。
- 实现：`_PageVerticalAligner` / `_DualSpreadAligner` 都改为 `StatelessWidget`，固定顶部对齐，`OverflowBox(maxHeight: infinity, alignment: topLeft)` 吸收 fwfh 与测量的高度误差（不抛 assertion）。
- **删除**两阶段测量方案（`_MeasureSize` / `_RenderMeasureSize` / `_measuredHeight` state / `didUpdateWidget`）——`postFrameCallback` 在测试环境不触发 + 子页 OverflowBox 干扰测量，方案不可靠且不必要。

#### Fixed — Q11 每页高度不一样 → 统一固定版心

- 用户反馈「每页高度都不一样，能不能限定在范围之内」。
- 根因：居中对齐模式下，短页（末页）在 slot 内垂直居中 → 文字起始 y 随内容多少浮动（72-110px 不等）。
- 修复：固定顶部对齐后，所有页首行 y 恒定（实测 topM=72.0，不再浮动）。回归测试断言单页所有页 + 双页左右页首行共享同一固定 top（maxTop-minTop < 2px）。

#### Performance — Q12 翻页卡顿 → 预计算页 HTML，buildSinglePage 改 O(1)

- 用户反馈「翻页有时候卡住，卡的时候点章节页也卡住」。
- 根因：`buildSinglePage` 被 `PageView.itemBuilder` **每页每次**调用，里面 3 步都遍历整章 HTML：`HtmlSlicer.sliceByPlainRange`（DOM 解析整章）+ `HtmlHighlightInjector.inject` + `TypographyStyleInjector.inject`。翻到中间页时每页都重做一遍整章解析 → 50-100ms/页。
- 修复：把这 3 步**上移到 LayoutBuilder.builder**（每章 rebuild 只跑一次），结果存进 `pageHtmls: List<String>`。`buildSinglePage` 改成 `pageHtmls[breakIdx]` 直接取用（O(1)）。
- 实测：翻页从 50-100ms 降到 4-11ms。
- 回归测试：`epubx_renderer_paged_overflow_test.dart` 加「翻到中间页渲染内容正确」用例，验证预计算没丢内容。

### M4.6 — 2026-07-05（阅读器打磨包：PDF 双页/缩略图 + 淡绿主题 + 新晰黑默认 + MD/TXT 渲染修复）

用户测试 M4.5 后反馈 6 个问题，本里程碑一次交付：4 项功能增强 + 2 项 M4.5 引入的回归修复。

#### Added — 淡绿色主题（#3）

- 新增 `ReadingTheme.green`（浅艾绿 `#E3EDD7` 背景 + 深褐 `#3A4A2D` 文字，WCAG AA 对比度）。
- 4 处同步：reader_engine 枚举 / EPUB `themeColors` fg-bg / PDF `applyTheme` ColorFilter（半透明叠加）/ typography_panel UI 标签「绿」。EPUB/PDF/MD/TXT 四格式生效。
- 枚举是 exhaustive switch，编译器强制 4 处都改对。

#### Added — PDF 无目录时缩略图导航（#2）

- PDF 无内嵌目录时，目录 tab 原显示「本书无目录」文案，现改为页面缩略图 grid。
- 新 widget `pdf_thumbnail_grid.dart`：pdfrx `PdfPage.render()` 异步渲染，内存 LRU 缓存 32 张（约 6MB），`GridView.builder` 只构建可视区，post-frame callback 触发渲染避免 build 中 setState。当前页 primary 色边框高亮，点击跳页。
- pdfrx 2.4.4 实际 API：`render(fullWidth:, fullHeight:)` 返回 `PdfImage`，需 `createImage()` 转 `ui.Image`，渲染后 `dispose()` 释放原生资源。

#### Added — PDF 宽屏自动双页（#1）

- PDF 原有手动 toggle 双页（工具栏按钮），现对齐 EPUB：窗口 ≥1100px 自动双页，缩窗回单页。
- 在 `reader_body.dart` LayoutBuilder 加 PDF 分支：`e.dualPageMode = isWide && !e.rendererRef.isScanned`。
- 扫描件（isScanned）仍维持单页（双页会让扫描页缩太小看不清）。isScanned 同步 getter，未解析时保守返回 false，解析完成后下次 rebuild 自动切双页，无崩溃风险。

#### Changed — 默认字体改新晰黑（#4）

- `TypographySettings.defaults()` 的 `fontFamily` 从 `null`（系统字体）改为 `'LXGWNeoXiHei'`（新晰黑，已打包注册）。
- 仅影响全新用户/全新 DB；老用户预设是 DB 独立记录。

#### Changed — DB schema v10→v11 老用户字体迁移（#4）

- `typography_profiles` 表的 fontFamily 嵌在 `settings` JSON 列（非独立列），migration 用 SQLite JSON1 函数 `json_set` 回填。
- schema v11 onUpgrade：`UPDATE typography_profiles SET settings = json_set(settings, '$.fontFamily', 'LXGWNeoXiHei') WHERE json_valid(settings) AND json_extract(settings, '$.fontFamily') IS NULL`。
- 幂等（WHERE 严格过滤 NULL），不动已自定义字体的预设。

#### Fixed — Markdown 段落堆叠（M4.5 回归 #5）

- **现象**：原 MD 文档分段一行一行，阅读器打开后段落堆叠，没还原换行。
- **根因**：markdown 包（7.3.1）按 CommonMark 规范，段落内单个 `\n`（soft break）渲染时折叠成空格（不是 `<br>`），导致连续行堆成一行。
- **修复**：调 `markdownToHtml` 前预处理——给每个非空、非围栏代码块、非已有 hard break 的行尾补两空格，强制 markdown 视为 hard break（两空格+换行 → `<br>`）。围栏代码块（` ``` `/`~~~`）内行原样保留，标题行（`#`）不加。
- 注：`LineSplitExtension` 在 markdown 7.x 不存在（已核对 export），故用预处理方案。

#### Fixed — TXT 内容溢出屏幕（M4.5 回归 #6）

- **现象**：TXT 文档打开后内容都跑到屏幕外。
- **根因**：`parseText` 用 `text.split(RegExp(r'\n\s*\n'))` 按空行切。中文小说常见连续行无空行（每行一段），导致整篇当一个 `<p>`，Paginator 退化（单段超长无法分页），内容溢出视口。
- **修复（智能启发式）**：重写 `parseText`——按 `\n` 逐行处理，每行 trim 后非空则独立成 `<p>`（中文小说每行一段事实标准），空行作分隔符跳过。杜绝超长单段，保证 Paginator 正常分页。

#### Non-Goals

- PDF 双页的文本选区/高亮（pdfrx 限制，已知缺陷，本次不做）。
- EPUB/PDF 双页抽象统一（R1 风险，本次不重构）。
- LineSplitExtension 之外的 GFM 扩展（表格/删除线，避免引入未测试行为）。

#### 测试

- `markdown_book_loader_test.dart` 加 M4.6 用例：soft break 转 `<br>`（2 个）、代码块回归保护、TXT 连续行每行独立 `<p>`。共 21 测试全过。
- `database_test.dart` / `migration_v10_test.dart` schemaVersion 断言更新到 11。
- dart analyze 4 包（reader_engine / epub_view / pdf_view / app）全过。
- 3 个 DB 测试失败是预存问题（FTS5 测试 helper 缺陷，git stash 验证 M4.6 前后一致），与本次无关。

#### Lessons

- **并行 subagent 同仓库文件竞态**：首次尝试 6 个 subagent 并行执行，T1/T2/T3/T4 的改动被互相覆盖丢失。教训：同一仓库的文件修改必须串行（或确保文件集完全不重叠 + 无共享读取）。改为主 agent 串行重做后一次通过。

### M4.5 — 2026-07-05（新增 Markdown / 纯文本格式支持）

用户要求新增 `.md` / `.txt` 书籍格式支持。MD/TXT 复用 EPUB 的 HTML 渲染管道（md→html / txt→`<p>` → fwfh HtmlWidget），行为与 EPUB 一致（分页、高亮、双页、主题、AI 伴读）。

#### Added — MD/TXT 格式全链路

- **格式无关渲染抽象**（`reader_engine_epub_view/lib/html_chapter_source.dart`）：新增 `HtmlChapterSource{title, html}` 数据类。`EpubxRenderer` 内部所有章节访问（`.HtmlContent`）改成走格式无关的 `_chapters` 字段 + `chapterCount` / `flatChapterHtmlAt` / `flatChapterTitleAt` 访问器。EPUB 路径仍走 epubx 解析（`openFile`），解析后同步填充 `_chapters`；MD/TXT 走新方法 `openChapters(List<HtmlChapterSource>)` 直接填充。**EPUB 渲染逻辑零改动**（Paginator/HtmlSlicer/injector/双页/版心对齐全部原样复用）。
- **MD/TXT 加载器**（`app/lib/services/`）：`MarkdownBookLoader`（`markdown` 包 `markdownToHtml`，按 `#`/`##` 标题切章，无标题则单章）+ `TextBookLoader`（按空行分段包 `<p>`，单章，HTML 实体转义）。UTF-8 优先，失败降级 latin1。
- **格式检测**：`BookFormatDetector` 加 `.md`/`.markdown`/`.mdown`/`.txt` 扩展名分支（无 magic bytes，扩展名判定）；`FilePicker`、`BookOpenBridge`、Windows `flutter_window.cpp` 三处白名单同步扩展（cpp size guard 从 `<5` 放宽到 `<4`）。
- **AI 路径**：新增 `HtmlFileChapterTextProvider` + `HtmlFileExtractor`（复用加载器 + `htmlToPlainWithOffsets`），`chapterTextProviderFor` / `extractorFor` 加 markdown/text 分支。MD/TXT 支持 AI 伴读/总结/章节复习。
- **依赖**：`app/pubspec.yaml` 加 `markdown: ^7.0.0`（BSD-3-Clause）。

#### Changed — 消除 5 处「三元地雷」+ UI 标签通用化

- `BookFormat` enum（app + reader_engine 两处）加 `markdown, text`。新增 `BookFormatDb` 扩展集中管理 `dbValue` / `fileExtension` / `displayLabel` 映射，替代散落在 `fromRow` / `local_book_repository` / `import_service` / `reader_engine_provider` / `markdown_exporter` 的 ternary（旧代码对未知格式默认降级为 PDF，会让 MD/TXT 被误当 PDF 崩溃）。
- `reader_engine_provider` 加 markdown/text 路由分支 → `ConcreteEpubReaderEngine.openChapters`。**关键设计**：MD/TXT 复用 `ConcreteEpubReaderEngine` 类型 → `reader_body.dart` 的 12 处 `is ConcreteEpubReaderEngine` 检查对 MD/TXT 也成立，双页/高亮/章节摘录等能力零改 UI 自动继承。
- 书架 chip 通用化：`_PdfChip` → `_FormatChip(format)`，所有非 EPUB 格式显示标签（PDF/Markdown/TXT）。详情页格式标签走 `displayLabel`。

#### Fixed — openChapters 未填充 _toc（Q-TOC 同构 bug）

- 集成测试发现 `ConcreteEpubReaderEngine.openChapters` 漏了 `_toc = await _renderer.toc`（与 M4/Q-TOC 的 PDF 目录转圈 bug 完全同构）。修复后 MD/TXT 目录 tab 正常显示（MD 标题树 / TXT 单条「全文」）。

#### Non-Goals（本期不做）

- MD 原生 markdown 渲染器（`flutter_markdown`）—— 走 md→html→fwfh，保持全格式渲染一致。
- TXT 按字数自动切章 —— 本期单章，靠分页翻页。
- 封面提取 —— MD/TXT 无封面，沿用首字母占位图。
- Android mimeType 扩展 —— 留 follow-up。

#### 测试

- `book_format_detector_test.dart`：+6 用例（md/txt/markdown 扩展名、大小写、空文件），共 11 测。
- `markdown_book_loader_test.dart`：新建，18 测（MD 切章边界/前言/无标题/空文件/编码、TXT 分段/转义/`<br>`、HtmlChapterSource 值对象）。
- `html_chapter_engine_integration_test.dart`：新建，7 测（状态机、TOC 填充、build 渲染、纯文本提取、_chapters 数据源）。
- EPUB 回归：epub_view 160/161 通过（1 预存在 cover fixture 失败）。app 全量无新增失败（13 个预存在失败：typography margin / import fixture / exporter CRLF，均与 M4.5 无关，已 git stash 验证）。
- `dart analyze` 4 包 0 issues。Windows Debug build 成功。

### M4/Q-TOC — 2026-07-05（PDF 目录永久转圈修复）

用户反馈打开 PDF 后「目录一直转圈」。

#### Fixed — PdfReaderEngine.toc 永远返回 null

- **根因**：`ReaderEngine.toc` 是同步 getter（`TableOfContents?`），但 pdfrx 加载目录是异步的（`PdfDocument.loadOutline()` 返回 Future）。`PdfReaderEngine` 旧实现直接 `get toc => null` 硬编码，而 UI 层 `reader_drawer_builders.dart` 用 `if (toc == null) LoadingView()` 同步判定 → PDF 目录 tab **永久转圈**。`PdfRenderer.toc`（真正调 loadOutline 的异步 getter）从未被调用。EPUB 不受影响（目录在解析时同步拿到）。
- **修复**（`pdf_reader_engine.dart`，对齐 `ConcreteEpubReaderEngine._toc` 模式）：加 `TableOfContents? _toc` 字段；`open()` 里 `await openFile` 后 `_toc = await _renderer.toc`（loadOutline 失败也降级为 empty TOC，不抛）；getter 返回 `_toc`。
- 效果：open 期间转圈（正常），open 完成后必非 null —— 有书签显示目录，无书签/加载失败显示「本书无目录」。
- 回归测试（`pdf_reader_engine_test.dart`，2 cases）：未 open 时 toc=null；open 后（即便文件不存在进 error 状态）toc 非 null 且为空 TOC。

## [1.6.0-alpha] — 2026-07-04（阅读体验大修：双页对开 + 排版 + 字体 + 交互）

v1.5.1-alpha 之后的一大批阅读体验修复，涵盖双页对开布局、段落排版、字体扩展、
摘录/书签交互、顶栏快捷键等。包含里程碑 M2.9（双页）/ M2.10-11（双页回归修复）/
M3a-e（用户两轮反馈共 7 个问题的逐一定位与修复）。

### M3e — 2026-07-04（阅读体验第二批修复，已完成）

用户拉取 M3a-d 后上手测试，反馈 6 个问题（Q1 段落缩进未生效 / Q2 末页依旧居中 / Q3 字体太少 / Q4 书架字号按钮挪位 / Q5 摘录条跟随选区 / Q6 删除键找不到）。Q7 是 Q6 的修正补丁：用户反馈「摘录、书签右键菜单这个功能没看到」。

#### Fixed — Q2（重审）末页居中诊断 + 回归测试改测真实坐标

第二轮用户反馈「末页依旧居中」。深入诊断后纠正了 M3e-Q2 第一版的误判：

- **M3e-Q2 第一版的测试是「假绿」**：只断言 `SingleChildScrollView.child isA<Padding>`（结构上没有 Align），从未测量文字的真实绘制 y 坐标。结构对 ≠ 渲染对，测试过了用户仍看到居中。
- **新写 3 个坐标测量测试**（直接读 `RichText.top`）：
  - paged 单页短内容：首行 `top < viewport/3`（实测 top≈72，居中应≈300）
  - paged 多页章节**真正末页**（`jumpToPage` 到最后）：首行 `top < 200`
  - scroll 模式短内容：`top < 200`
- **三测全过**，证明源码末页文字始终顶部对齐。代码层面**根本不会居中**——fwfh 内部用 `Column(MainAxisSize.min, mainAxisAlignment.start)`，在 `SingleChildScrollView` 无限高度约束下天然从顶排。
- **用户看到居中的真因**：Debug 目录 `zhiyue.exe` 时间戳 `02:11` 早于 Q2 修复 commit（`18:11`），用户运行的是旧版二进制。M3a 曾误包 `Align(topCenter)`（后证实在 SingleChildScrollView 内是 no-op），但更早的版本可能有其它居中来源；不论如何，**当前源码已确认顶部对齐，干净重建后即可生效**。
- renderer 新增两个 `@visibleForTesting` 入口供坐标测试导航：`pageControllerForTest`（翻末页）、`cachedBreakCountForTest`（取页数）。

##### Q2 真因（第三轮，用户截图确认）— 双页模式 Row 默认 crossAxis center

用户发截图并明确指出「**和左侧对比，右侧居中，上下都有大量留空**」+ 像素分析证实：右页首行 y≈242(22%)、左页首行 y≈81(7%)，差 161px。前两轮只测了**单页模式**，漏了**双页模式**——这才是用户实际看到的场景。

- **根因**：`_buildPaged` 的 `itemBuilder` 双页分支用 `Row(Expanded, SizedBox, Expanded)` 摆左右两页。**`Row` 的 `crossAxisAlignment` 默认是 `center`**，会把高度 < slot 的右页（章节末页只有几行）**垂直居中**在 slot 内。
- **实测复现**（最小用例 `Row>Expanded>SingleChildScrollView>HtmlWidget` 短内容）：默认 `center` 时首行 top≈49%（居中）；加 `CrossAxisAlignment.start` 后 top≈2%（顶部对齐）。
- 单页模式 / scroll 模式不在 Row 里，不受影响——所以前两轮坐标测试都正常。
- **修复**（一行）：双页 `Row` 加 `crossAxisAlignment: CrossAxisAlignment.start`。左右两页都从顶部排起，像真书的双页对开。
- **回归测试 2 个**（已验证撤销修复后会失败，能抓回归）：双页右页短内容（末页）首行 `top < 25%` viewport；双页左页（满内容对照）首行 `top < 25%`。





#### Added — Q7 阅读器内抽屉摘录 tab 补右键菜单 + 可见按钮（修正 Q6「没看到」）

用户反馈「摘录、书签右键菜单这个功能没看到」。核查发现：Q6 只处理了**独立的摘录页**（`/notes`）和**书签列表**（共用 ReaderBookmarkList，drawer + BookmarksPage 都覆盖），但**阅读器内侧边抽屉的摘录 tab**（`notes_drawer.dart`）漏了 —— 那里的 AnnotationTile 只接了 onTap/onLongPress，没有右键、没有可见按钮。这就是用户"没看到"的地方。

补齐（与独立摘录页同款交互）：
- `notes_drawer.dart`（`NotesDrawerContent` + `NotesDrawer`）加可选回调 `onSecondaryTapDown(id, globalPos)` / `onEdit(id)` / `onExport(id)` / `onDelete(id)`，全 null 时向后兼容（无右键、无可见按钮，与旧版完全一致）。
- `reader_drawer_builders.dart` `ReaderNotesDrawerWrapper` 加同名回调透传。
- `reader_body.dart` 加 `_onAnnotationSecondaryTapDown`（弹 `showAnnotationContextMenu` 5 项桌面右键菜单，与 notes_page 同款）+ `_onAnnotationEdit/Export/Delete`（可见按钮）+ `_dispatchAnnotationAction` / `_showNoteEditor` / `_copyText` / `_exportAnnotation` 共用 helper + `_annotationById` 反查。右键删除直接删（右键是明确二次操作），可见删除按钮弹确认。两处 wrapper 调用点（窄屏 + 宽屏）都接入。
- 搜索高亮结果页（`search_highlights_page.dart`）本次未改（那是搜索场景，非"摘录/书签页面"，列为后续）。

测试：`notes_drawer_test.dart` +5 cases（无回调向后兼容 / 有回调渲染 3 按钮 / 右键触发 onSecondaryTapDown 带 id+坐标 / 编辑按钮触发 onEdit / 删除按钮触发 onDelete）。8 cases 全过。reader_body 11 cases 无回归。

#### Added — Q3 新增 2 款字体（共 5 款 + 系统）

#### Added — Q3 新增 2 款字体（共 5 款 + 系统）

- **阿里巴巴普惠体 `AlibabaPuHuiTi`**（标签「普惠体」）：现代圆润黑体，阿里巴巴全球永久免费商用授权。下载源 `chinayin/fonts-alibaba-puhuiti-regular`（社区镜像官方 Regular 字重，~10MB）。官网 alibabafonts.com。
- **霞鹜新晰黑 `LXGWNeoXiHei`**（标签「新晰黑」）：LXGW 基于 IPAex ゴシック 衍生的中文黑体字型，OFL 1.1，字形锐利适合屏幕长文。来自 `lxgw/LxgwNeoXiHei` v1.303（~7.5MB）。

下载可行性实测：经 gh-proxy.com / ghfast.top 镜像实测两者均 200 可达，已自动下载验证（9.7MB + 7.5MB，有效 TTF）。**无需手动下载**（用户最初选"需手动下载"是基于我之前不准确的探测结果，实测可自动）。

改动：`app/pubspec.yaml` 加 2 个 family 声明；`scripts/download-fonts.sh` + `.ps1` 各加 2 个下载块（多镜像 fallback，索引 [N/3]→[N/5]）；`app/assets/fonts/README.md` 字体表 +2 行；`typography_panel.dart` 字体 chip 列表 +2 项（普惠体/新晰黑）。测试：`typography_panel_test.dart` +1 case（普惠体 chip → fontFamily）+ 更新字体列表断言（9 cases 全过）。

#### Added — Q6 书签/摘录列表补可见删除/编辑/导出按钮

用户反馈 M3d 的右键菜单桌面端不直观，"删除键找不到"。补可见按钮：

- **书签列表 `reader_bookmark_list.dart`**：每个 ListTile 加 `trailing` 行（编辑/导出/删除 3 个紧凑 IconButton），桌面 + 移动端都可点。删除前弹 `AlertDialog` 确认（避免误删）。右键菜单保留（桌面高效补充），右键删除仍直接删（右键本身是明确二次操作）。提取 `_edit/_export/_delete/_confirmDelete` 私有方法，可见按钮与右键菜单共用。
- **摘录卡片 `annotation_tile.dart`**：加可选 `onEdit/onExport/onDelete` 回调（nullable，全部 null 时不渲染 actions 行，向后兼容 M3d）。任一非 null 时在卡片底部右对齐渲染 `_ActionsRow`（IconButton）。
- **摘录页 `notes_page.dart`**：AnnotationTile 传入 onEdit/onExport/onDelete，复用 `_editAnnotation`/`_exportSingle`/`_confirmDeleteAnnotation`（右键菜单也改用同一套方法）。删除前确认。

**范围说明**：阅读器内抽屉（notes_drawer）的摘录 tab 仍走长按 → NoteEditorSheet → 删除（既有路径可用），本次未补可见按钮（需跨 NotesDrawerContent→Wrapper→reader_body 传回调，改动面大，列为后续低成本任务）。

测试：`reader_bookmark_list_test.dart` +6 cases（trailing 按钮存在性/编辑/导出/删除确认取消/删除确认/默认 controller.delete）；`annotation_tile_test.dart` +5 cases（无回调不渲染/3 按钮/部分回调/编辑触发/删除触发）；`notes_page_test.dart` +2 cases（可见按钮渲染/删除确认取消）。共 49 cases 全过（含 M3d 既有右键菜单无回归）。

#### Changed — Q4 书架/字号按钮挪到时钟左边

用户反馈希望书架 + 字号按钮挪到时间显示左边（更顺手）。原 M3c 全放在右侧 actions。

- `reader_scaffold.dart` `_buildChrome`：`leading` 由单个返回 IconButton 改为 `Row`（返回 + 书架 + 字号- + 字号+），`leadingWidth` 放宽到 192 容纳 4 按钮。时钟保持 `title: ReaderClock()` + `centerTitle: true`。右侧 actions 精简为 目录/排版/笔记/书签/AI/问答/全屏/（双页）/（回顾）。
- 3 个按钮的 Key 不变（`reader_open_bookshelf` / `reader_font_decrease` / `reader_font_increase`），基于 Key 的测试 finder 不受位置影响。
- 测试：`reader_scaffold_test.dart` +1 case（断言 leading 是含 4 按钮的 Row、3 个 Key 在 leading 内、leadingWidth≥160、时钟仍在 title）。10 cases 全过。

#### Fixed — Q5 摘录条真正跟随选区（M3b API 误判纠正）

用户坚持要"摘录条跟随选区"。M3b 曾断言「Flutter 3.44.4 的 SelectableRegion 不暴露选区坐标，故 _selectionRect 暂时始终 null」。**这是误判** —— 源码追踪确认：

- `SelectableRegion` 接受 `GlobalKey<SelectableRegionState>`（构造参数）。
- `SelectableRegionState.contextMenuAnchors` 返回 `TextSelectionToolbarAnchors`（`primaryAnchor` = 选区上方中心**全局坐标**，`secondaryAnchor` = 下方中心）。
- 官方 example `selection_area.2.dart` 第 157-201 行正是这套用法（`selectionAreaKey.currentState!.selectableRegion.contextMenuAnchors`）。

实现：

- `reader_body.dart` 加 `GlobalKey<SelectableRegionState> _selectableRegionKey` 挂到 `SelectableRegion`；`_onSelectionChanged` 在选区非空时 `addPostFrameCallback` 调 `_updateSelectionRectFromAnchors`：读 `contextMenuAnchors` → 经 `_stackKey` RenderBox `globalToLocal` 转 Stack 局部坐标 → 合成 `_selectionRect`（top=primaryAnchor.y, bottom=secondaryAnchor.y, 水平中心=primaryAnchor.x）。选区清空时 `_selectionRect=null`（toolbar 消失）。
- `stackSize` 从 `MediaQuery.sizeOf`（屏幕尺寸）改为 `_stackSize()`（Stack 实际尺寸，更精确的水平 clamp）。
- `reader_selection_toolbar.dart` 定位逻辑无需改（M3b 已写好，rect.top/bottom/center.dx 直接用）。

**关键验证测试**：新增 `selectable_region_anchors_test.dart` —— 用 `SelectAllTextIntent` 触发全选，断言 `contextMenuAnchors.primaryAnchor` 非零、`secondaryAnchor` 非空，**证明 API 在 Flutter 3.44.4 可用**（直接证伪 M3b 的误判）。另有 `reader_selection_toolbar_follow_test.dart` 3 cases（toolbar top 跟随 rect / 翻下方 / null fallback）。现有 `reader_selection_toolbar_test.dart` 9 cases + reader_body 10 cases 无回归。

**诚实说明**：`contextMenuAnchors` 依赖 finalized 选区几何；选区变化中（changing）可能返回 stale，用 postFrameCallback 规避。PDF 路径不走 SelectableRegion（pdfrx 自管选区 UI），本改动仅影响 EPUB。

#### Fixed — Q1+Q2 排版（reader_engine_epub_view 包）

**Q1 段落首行缩进从未生效（关键根因纠正）**：M3a 的 `<style>p{ text-indent: 2em }</style>` 注入对 flutter_widget_from_html 0.15.3 **完全无效** —— 源码追踪确认 fwfh 把 `<style>` tag 当 `display:none`（`core_widget_factory.dart:934`），且其内联 CSS 解析器（`parseStyle` switch）**根本没有 `text-indent` 分支**。所以 M3a 的缩进实际上从未渲染，只是没崩。

- 重写 `typography_style_injector.dart`：改用 HTML 预处理 —— 用 `package:html` 解析后在每个 `<p>` 首个文本节点前插入 N 个 U+2003 EM SPACE（宽度≈1em，随字体缩放）。这是中文阅读器普遍 trick，对 fwfh 的 CSS 支持缺口免疫。
- 新增 `package:html ^0.15.0` 直接依赖（原为 fwfh 的传递依赖）。
- `epubx_renderer.dart` 两个 `HtmlWidget` 调用新增 `customStylesBuilder`，给每个 `<p>` 注入统一段落间距 `margin: 0 0 0.5em 0`（fwfh 支持 margin，见 `style_margin.dart`），替代被忽略的 `<style>` 块。
- 测试：`typography_style_injector_test.dart` 重写（10 cases，含多段/嵌套 span/属性/空白首文本/小数 em/解析失败兜底）；`epubx_renderer_top_align_test.dart` 更新；`epubx_renderer_test.dart` 的 `currentHighlightedHtml` 断言更新为 em-space。

**Q2 末页顶部对齐（M3a 误判修正）**：M3a 在 `buildSinglePage` 包了 `Align(topCenter)` 作为"末页顶部对齐双保险"，但 `Align` 在 `SingleChildScrollView` **内部是 no-op** —— scroll view 给子 widget 无限高度约束，Align 没有多余空间可对齐，被强制收缩成子大小，对齐逻辑完全不生效（等于没写）。

- 删除无效 `Align`，`buildSinglePage` 回归 `SingleChildScrollView > Padding > HtmlWidget`（M3a 之前的结构，本就顶部对齐）。
- 用户"末页居中"反馈经 git 历史核查：M3a 前后布局都是顶部对齐，真实成因是**用户跑的 exe 过旧**（未拉 M3a 重建）。代码层移除误导性 Align。
- 测试：`epubx_renderer_top_align_test.dart` 新增断言"无 Align 残留"防止回归 + 短内容顶部对齐 case。

### M3d — 2026-07-03（摘录/书签右键上下文菜单：删除/编辑/导出）

用户要求摘录、书签页面在记录上点击右键要有「删除、导出」选项（AskUserQuestion 进一步确认：Flutter 原生 `showMenu()` 系统原生菜单样式，右键同时加「编辑」）。Spec: `docs/superpowers/specs/2026-07-03-m3d-context-menu-design.md`，Plan: `docs/superpowers/plans/2026-07-03-m3d-context-menu.md`。

#### Added — 摘录右键菜单（T1，复用现有 API）

- `AnnotationContextAction` 枚举加 `export` 项（原 edit/delete/copyQuote/copyMarkdown）；该枚举仅 `notes_page.dart` 一处 switch，已补 `export` 分支。
- 新增 `showAnnotationContextMenu(BuildContext, Offset globalPosition)`（`annotation_context_sheet.dart`）：用 Material `showMenu` 在右键位置弹原生菜单（编辑笔记/删除/复制摘录/复制 Markdown 片段/导出 5 项），与移动端 `showAnnotationContextSheet`（bottom sheet）共用枚举，互不替代。
- `AnnotationTile` 加 nullable `onSecondaryTapDown` 回调参数：InkWell 外层包 `GestureDetector(behavior: translucent)` 仅接 `onSecondaryTapDown`（与 primary onTap/onLongPress 互不干扰）；回调为 null 时行为与原先完全一致。
- `notes_page.dart` 摘录条目接入 `onSecondaryTapDown`；`_showContextMenu` 重构为统一入口（长按→bottom sheet / 右键→showMenu），dispatch 补 `export` 分支（单条导出 Markdown 文件）+ 桌面路径的 copyQuote/copyMarkdown（写剪贴板 + SnackBar）。

#### Added — 书签 Markdown 导出器（T2，新基础设施）

- 新建 `app/lib/features/bookmarks/services/bookmark_markdown_exporter.dart`：纯函数 `exportSingle(BookmarkEntry)` → `# label\n\nnote\n\n> 创建于 YYYY-MM-DD`（note 空省略段）；`exportAll(List, {bookTitle})` 按创建时间升序 + `---` 分隔 + 可选总标题。复用 `markdown_exporter` 的 ISO 日期格式。

#### Added — 书签编辑对话框（T3，新）

- 新建 `app/lib/features/bookmarks/widgets/bookmark_edit_dialog.dart`：`showBookmarkEditDialog(BuildContext, BookmarkEntry)` → AlertDialog（label/note 两 TextField，预填现有值，label 必填，空 note 归一化为 null）。返回 `BookmarkEditResult`（保存）或 null（取消），调用方据此调 `controller.updateLabel/updateNote`。

#### Added — 书签右键菜单（T4，组合 T2/T3）

- `reader_bookmark_list.dart`：ListTile 外层包 `GestureDetector(onSecondaryTapDown)`，右键弹 `showMenu`（编辑/删除/导出 3 项）。新增 nullable 回调参数 `onDelete/onEdit/onExport`（父级可覆盖）；为 null 时走默认自包含行为（本 widget 持 `ref`）：
  - 删除 → `bookmarkControllerProvider.notifier.delete(id)`（**首次接入**，原 controller.delete 零调用）。
  - 编辑 → `showBookmarkEditDialog` → `controller.updateLabel/updateNote`。
  - 导出 → `BookmarkMarkdownExporter.exportSingle` → `NoteFileWriter.saveMarkdownFile`。
- 更新文档注释：删原 "删除走 long-press 菜单，T13+" 占位说明，改为「右键上下文菜单（M3d）」。
- 因 `ReaderBookmarkList` 是 drawer 书签 tab 与独立 `BookmarksPage` 的共用 widget，改一处两处生效。

#### 探查结论

- `BookmarksPage` **未** override `bookmarkControllerProvider`（与 ReaderPage 不同）；独立页的 controller 依赖全局 `currentBookIdProvider`（默认 null）——这是 M2.5 既有的「独立书签页列表来源」限制，非本任务范围。reader 抽屉（ReaderPage）内 controller 已被 ReaderPage 正确 override，右键删除/编辑/导出在抽屉上下文完全可用。
- `BookmarkController.delete` 首次接入 UI，现由 `ReaderBookmarkList` 默认删除路径调用。

#### 测试

- `annotation_context_sheet_test.dart`（新，7 测试）：`showAnnotationContextMenu` 渲染 5 项 + 各 value 正确 + 取消返回 null。
- `annotation_tile_test.dart`（扩，+3 测试）：`onSecondaryTapDown` 右键触发回调（`PointerDeviceKind.mouse` + `kSecondaryMouseButton` 模拟）；右键不误触发 onTap；无回调时左键仍正常。
- `bookmark_markdown_exporter_test.dart`（新，9 测试）：exportSingle 含/空 note 格式；exportAll 升序 + `---` 分隔 + 总标题 + 空列表。
- `bookmark_edit_dialog_test.dart`（新，5 测试）：预填值 + 保存返回新值 + 取消返回 null + label 空禁用 + 空 note 归一化 null。
- `reader_bookmark_list_test.dart`（新，8 测试）：右键弹 3 项菜单 + 各动作调度 onDelete/onEdit/onExport 回调 + 默认删除走 controller.delete（断言 repo 状态变化）+ 默认编辑走对话框改 controller.updateLabel/updateNote。
- 现有 reader/notes/bookmarks/search 测试全过（+131）；analyze 三包（app / reader_engine / reader_engine_epub_view）0 issue；`flutter build windows --debug` 成功。

### M3c — 2026-07-03（顶栏增强：实时时钟/字号±快捷键/书架弹窗）

用户希望顶栏信息更密：中间显示实时时间，加字号±快捷按钮，加书架入口（弹出书架对话框选新书直接切换阅读）。Spec: `docs/superpowers/specs/2026-07-03-m3c-topbar-bookshelf-design.md`，Plan: `docs/superpowers/plans/2026-07-03-m3c-topbar-bookshelf.md`。

#### Added — 任务 3 顶栏实时时钟

- 新建 `app/lib/features/reader/widgets/reader_clock.dart`：`StatefulWidget`，initState 起 `Timer.periodic(1s)` 刷新，dispose 取消；build 渲染 `DateFormat.Hm().format(_now)`（24h 制 `HH:mm`，复用项目已有 `intl ^0.20.0`）。
- `reader_scaffold.dart` 的 `_buildChrome` 内 AppBar.title 由静态 `Text(widget.title)` 改为 `const ReaderClock()`，并加 `centerTitle: true`，时间居中显示。
- **Timer 不泄漏**：`ReaderClock` 只在 `_buildChrome`（`if (ui.chromeVisible)` 内）创建；chrome 隐藏时 `_buildChrome` 不调用 → widget 不挂载 → Timer 不启动。dispose 必取消 Timer。
- 时间源可注入（`now` 参数，默认 `DateTime.now`），便于测试推进时间验证文字更新。

#### Added — 任务 6a 字号±快捷按钮

- `ReaderScaffold` 加 `VoidCallback? onFontDecrease / onFontIncrease / onOpenBookshelf`（均 nullable，不影响现有构造）。
- AppBar.actions 在「排版」按钮前后加 `Icons.text_decrease` / `Icons.text_increase` 两个 IconButton（各带 Key：`reader_font_decrease` / `reader_font_increase`）。
- `reader_body.dart` 传入回调：直接改 `engine.typography` 内存值，`fontSize ± 1` 后 `.clamp(12.0, 32.0)`（复用排版面板范围），用 `unawaited` 包裹 `setTypography`。**不写预设/DB**（与排版面板即时改值一致）。

#### Added — 任务 6b 书架弹窗

- 新建 `app/lib/features/reader/widgets/bookshelf_dialog.dart`：`showBookshelfDialog(BuildContext, {required String currentBookId})` → `showDialog`（`useRootNavigator: true`）全屏 `Dialog`。顶部「书架」标题 + 关闭按钮；主体可滚动封面网格（复用 `BookCover`）；当前书用主题色边框 + 「阅读中」标记。选书 → `Navigator.pop` → `context.pushReplacement('/book/$newId')`。
- AppBar.actions 加 `Icons.collections_bookmark_outlined`（书架）按钮（Key：`reader_open_bookshelf`）。
- `reader_body.dart` 传入 `onOpenBookshelf: () => showBookshelfDialog(innerContext, currentBookId: widget.bookId)`。
- **数据源**：探查确认 `libraryControllerProvider` / `coverLoaderProvider` / `bookRepositoryProvider` 均为 `core/providers.dart` / `library/providers/` 顶层全局 provider（非 LibraryPage 页面局部），对话框直接 watch 同源 provider 取数据，与 LibraryPage 完全一致。

#### 测试

- `reader_clock_test.dart`（新，4 测试）：挂载即渲染当前 HH:mm；文字格式校验；时间源推进后文字更新；dispose 取消 Timer（pumpAndSettle 不挂起证明）。
- `reader_scaffold_test.dart`（扩，+5 测试）：title 是 ReaderClock；字号±/书架 icon 渲染；字号±/书架按钮点击触发回调。
- `bookshelf_dialog_test.dart`（新，4 测试）：网格渲染全部书籍；当前书「阅读中」标记；关闭按钮 pop；点非当前书 `pushReplacement` 导航到 `/book/:id`（真 GoRouter 验证）。
- `reader_body_font_buttons_test.dart`（新，5 测试）：字号 +1/-1；clamp 上限 32 / 下限 12；书架按钮打开弹窗（含当前书渲染）。
- analyze 三包（reader_engine / reader_engine_epub_view / app）0 error；`flutter build windows --debug` 通过。reader+library 全量测试 340 passed（仅 2 个 PDF fixture 缺失的预存失败与 M3c 无关）。

### M3b — 2026-07-03（阅读交互增强：翻页动画微调/悬停翻页箭头/摘录工具条跟随选区）

用户反馈阅读交互手感 3 项：翻页要左右箭头提示、翻页要有 PPT 式平移过渡、选文字后摘录工具条应跟着选区走（不要老固定屏幕中间顶部）。Spec: `docs/superpowers/specs/2026-07-03-m3b-reading-interaction-design.md`，Plan: `docs/superpowers/plans/2026-07-03-m3b-reading-interaction.md`。

#### Changed — 任务 8 翻页动画微调（PPT 式平移）

- **章内程序化翻页 200ms easeOut → 300ms easeInOutCubic**：`reader_engine_epub_view/lib/epubx_renderer.dart` 的 `nextPage()` / `previousPage()`。提取类常量 `_pageAnimDuration`（300ms）/ `_pageAnimCurve`（`Curves.easeInOutCubic`），比原 200ms easeOut 更顺滑、有进出节奏，更接近 PPT 平移观感。
- **跨章 `jumpToPage`（章末/章首换章路径）保持瞬切不变**：跨章换内容时动画会闪烁，瞬切更稳。

#### Added — 任务 1 左右空白悬停翻页箭头

- 现有翻页点击 zone（`reader_scaffold.dart` 左右 `marginPx` 宽的透明 GestureDetector）无视觉反馈，桌面端用户不知点哪能翻。
- `_ReaderScaffoldState` 加 `bool _hoverLeft/_hoverRight`；左右 `Positioned` 外层包 `MouseRegion(onEnter/onExit)`，hover 为 true 时在 zone 中央叠 `IgnorePointer(child: 半透明圆形背景 + chevron 箭头)`。
- **箭头用 IgnorePointer 包裹**，不消费底层 GestureDetector 的 onTapUp（翻页手势正常）。**仅桌面端有效**（移动端无鼠标，onEnter/onExit 永不触发，行为不变）。箭头颜色取 `Theme.of(context).iconTheme.color` + 半透明，暗/亮主题自适应。

#### Added — 任务 9 摘录工具条跟随选区定位逻辑

- 原 `reader_selection_toolbar.dart` 固定 `top:80, left:16, right:16, Center`，与选区位置无关。
- **新增 `selectionRect` + `stackSize` 参数**：非空时工具条优先显示在选区**上方**（`top = rect.top - toolbarHeight - 8`）；上方空间不足（< 8px）则翻到选区**下方**（`top = rect.bottom + 8`）；水平以选区中心居中并 clamp 到 `[8, screenWidth - 8 - toolbarWidth]`，避免越界。实现 spec D3 的「跟随」语义。
- **fallback 分支保留**（约束 #3）：`selectionRect` 为空时回退原「顶部居中」定位，保证不崩。`reader_body.dart` 加 `_selectionRect`（当前始终 null）+ `_stackKey`（GlobalKey，供坐标转换预留）。
- **API 兼容说明（重要偏离）**：spec/plan 假设的 `SelectableRegion.selectionNotifier` 参数 + `SelectionDetails.selectionStartCoords/EndCoords` 字段**在当前 Flutter 3.44.4 不存在**（属于更新版本 API）。实测：`SelectableRegion` 构造函数无 `selectionNotifier` 参数；`SelectionDetails` 只有 `range`/`status`，无坐标字段；`SelectionListenerNotifier` 也未从 `widgets.dart`/`material.dart` 公开导出（仅在 `selectable_region.dart` 私有定义，且配合独立的 `SelectionListener` widget，无法挂到 SelectableRegion）。故当前版本 `_selectionRect` 暂时始终为 null，工具条走 fallback。**跟随定位逻辑与全套测试已 ready-to-use**，待 Flutter 升级提供坐标 API 后，只需在 `reader_body._onSelectionChanged` 填充 `_selectionRect` 即可立即生效，无需改动工具条。

#### 测试

- `reader_engine_epub_view/test/`：翻页动画相关测试（`epubx_renderer_cross_chapter_back_page_test.dart` / `epubx_renderer_setters_emit_state_test.dart`）全过（走 jumpToPage 瞬切路径，不依赖动画时长，无需改断言）。
- `app/test/features/reader/widgets/reader_scaffold_hover_test.dart`（新）：hover 左/右 zone 显示对应 chevron 箭头；hover 退出箭头消失；箭头在 IgnorePointer 子树内且点击仍翻页。4 测试全过。
- `app/test/features/reader/widgets/reader_selection_toolbar_test.dart`（扩）：跟随定位（上方/下方/clamp 左/clamp 右/null fallback）5 测试全过，用直接传入 Rect 验证 Positioned 逻辑（不依赖真实 selection）。

### M3a — 2026-07-04（排版基线增强：默认值/段落缩进/末页对齐/常用字体）

用户 2026-07-03 提交 10 项体验优化清单，本里程碑处理其中与「文字排版观感」直接相关的 4 项（任务 7/2/4/5）。Spec: `docs/superpowers/specs/2026-07-03-m3a-typography-baseline-design.md`，Plan: `docs/superpowers/plans/2026-07-03-m3a-typography-baseline.md`。

#### Changed — 任务 7 默认值

- **默认字号 16→18、行距 1.5→1.8（宽松）、页边距 normal→wide（72px）**：`TypographySettings.defaults()`（reader_engine/lib/core/typography_settings.dart）调整。仅影响「未选预设」的新打开书籍；已保存的 TypographyProfile 是 DB 独立记录，不受影响。排版面板档位标签不变（紧凑1.2/标准1.5/宽松1.8、紧凑/标准/宽松/特宽），仅默认选中态随 defaults 变。

#### Added — 任务 2 段落首行缩进（中文书籍标准排版）

- **根因**：pivot 后 `TypographyCss.textStyleFromSettings` 只产出 `TextStyle(fontSize, height, fontFamily)`，而 Flutter 的 `TextStyle` **无法表达 CSS `text-indent`**，所以缩进必须通过 HTML/CSS 注入实现。
- **TypographySettings 新增字段**：`paragraphIndentEm`（默认 2.0）+ `paragraphIndentEnabled`（默认 true），同步更新构造函数、copyWith、toJson、fromJson（缺 key 向后兼容用默认值）、defaults、equality（== / hashCode）。
- **新建 `reader_engine_epub_view/lib/typography_style_injector.dart`**：`TypographyStyleInjector.inject(html, indentEm, enabled)` 在 HTML 头 prepend `<style>p{ text-indent: Nem; margin: 0 0 0.5em 0; }</style>`。enabled=false 或 indentEm<=0 原样返回。
- **接入点**：scroll 模式 `currentHighlightedHtml()`（高亮注入后）、paged 模式 `buildSinglePage`（高亮注入后、HtmlWidget 前）两处调用 inject。`<style>` 是 HtmlWidget 一等公民，对全章/全页所有 `<p>` 生效。
- **排版面板加「段落」一节**：Switch（首行缩进开关）+ 档位（无 0em / 2字 2em / 4字 4em）。

#### Fixed — 任务 4 章节末页文字顶部对齐

- **现象**：用户反馈章节末页文字「垂直居中很奇怪」。
- **代码层**：`buildSinglePage`（epubx_renderer.dart）用 `SingleChildScrollView(NeverScrollable)` 包 `Padding>HtmlWidget`，理论上应顶部对齐。
- **根因实跑结论（widget 测试布局探测）**：构造 600px 高 PageView slot + 短内容（240px），测量渲染后 RichText 实际位置 = **top=72（= margin），center=120**，远在 slot 顶部，**不是居中**（居中应 ~250-300）。即用户反馈的「末页垂直居中」是**视觉错觉**：末页内容少，下方留白大（~360px 空白），主观感觉「居中」，但代码本就是顶部对齐，无 HtmlWidget bug。
- **修复（双保险）**：`buildSinglePage` 在 SingleChildScrollView 内显式包 `Align(alignment: Alignment.topCenter)`，无论 HtmlWidget 内部行为如何都强制顶部锚点，语义显式化、防御未来回归。scroll 模式本就是顶部对齐，未改。

#### Changed — 任务 5 字体选项改常用名 + 打包开源 OFL 字体

- **根因**：旧字体选项「衬线/无衬线」用 `'serif'`/`'sans-serif'`（CSS 通用字体族名），Flutter 的 `TextStyle.fontFamily` 不识别 generic family → 在 Windows 上几乎无效（fallback 默认无衬线），这是用户觉得「很怪」的技术根因。
- **打包开源 OFL 字体到 `app/assets/fonts/`**（不入 git，首次拉取后跑 `scripts/download-fonts.sh` 获取）：
  - 黑体 → `NotoSansSC-Regular.otf`（思源黑体，Google Noto CJK SubsetOTF/SC，8.33 MB）
  - 宋体 → `NotoSerifSC-Regular.otf`（思源宋体，Google Noto CJK SubsetOTF/SC，11.63 MB）
  - 楷体 → `LXGWWenKai-Regular.ttf`（霞鹜文楷，LXGW 官方 v1.522，24.42 MB）
  - **圆体暂未提供**（无完美开源 OFL 圆体；Dubai 不开源，思源无 Round 变体），UI 不显示圆体 chip，用户可选「系统」（Windows 即微软雅黑，本身偏圆）作 fallback。
- **字体下载**：直连 GitHub（github.com / raw.githubusercontent.com）在大陆被墙；用 jsDelivr CDN（Noto）+ gh-proxy.com 镜像（LXGW release asset，因 jsDelivr 对 >50MB 仓库拒服务）成功下载 3/3 款。下载脚本含多镜像 fallback。
- **pubspec.yaml fonts 段声明** 3 个 family（逻辑别名 NotoSansSC/NotoSerifSC/LXGWWenKai，与代码 `TextStyle(fontFamily:)` 一致）。fontFamily 别名不必与字体内部 post 表 name（`Noto Sans SC` 等）完全相同——pubspec `family:` 即 Flutter 注册的资源别名。
- **字体选项 UI**：typography_panel.dart 的 ChoiceChip 改为 系统/黑体/宋体/楷体（+ userFonts 追加），并加说明文字。

#### 体积实测（`flutter build windows --debug`）

| 项 | M2.11 baseline | M3a | 增量 |
|---|---|---|---|
| `zhiyue.exe` | 1.01 MB | 1.01 MB | **+0**（字体以 asset 打包，不入二进制）|
| `flutter_assets/` | 95.65 MB | 139.15 MB | **+43.50 MB**（= 3 款 CJK 字体 43.42 MB + 0.08 MB manifest）|

增量 +43.50 MB 在 spec D3 预算（+40-60MB）内，远低于 80MB「不可接受」阈值。LXGW WenKai（24.42 MB）占大头（无 subset 版，含全 GB 字）；Noto 用 SubsetOTF/SC（仅简体中文字集）比全 CJK OTF（16MB）省一半。若未来需瘦身：subset LXGW（pyftsubset 按 GB2312 常用字裁剪到 ~3MB）可省 ~21MB，留 v2 优化。

#### Tests

- 新增 `typography_style_injector_test.dart`（6 cases）：注入含 `<style>`+`text-indent`、enabled=false 原样返回、indentEm<=0 原样返回、多 `<p>` 全局生效、保留既有 HTML 结构。
- 新增 `epubx_renderer_top_align_test.dart`（4 cases）：paged 模式每页 SingleChildScrollView 子是 Align(topCenter)（任务4 结构断言）、scroll 模式 currentHighlightedHtml 含/不含注入的 `<style>`。
- 更新 `typography_settings_test.dart`：默认值断言（18/1.8/wide）+ 缩进字段 toJson/fromJson 往返 + copyWith + 向后兼容 + equality。
- 更新 `typography_css_test.dart`：默认字号/行距断言 16/1.5 → 18/1.8。
- 更新 `typography_panel_test.dart`：字号显示 18、字体选项 系统/黑体/宋体/楷体（断言旧 衬线/无衬线 已移除）、黑体→NotoSansSC、font+1=19、含「段落」一节。
- 更新 `epubx_renderer_test.dart`：currentHighlightedHtml no-highlight 路径断言改为 endsWith（因默认注入缩进 `<style>`）。
- 全套：reader_engine typography 9 通过；reader_engine_epub_view 143 通过（仅 pre-existing fail = epub_cover_extractor 的 ZipDecoder/EPUB fixture 解析失败，与排版无关）；app reader features 185 通过 / 2 skip / 2 fail（仅 pre-existing fail = reader_page_pdf_integration 的 PDF fixture 缺失，与排版无关）。
- `dart analyze`（flutter.bat analyze 在本中文路径环境 LSP 协议崩溃——FormatException: Unterminated string，是 Dart analysis server LSP framing 对中文路径 URL-encode 的 bug，非代码问题；改用 dart.bat analyze）：reader_engine / reader_engine_epub_view / app 三包 **0 error**。app 的 custom_lint 插件因同样中文路径 bug（%E7%94%B5... URL 编码失败 pub get）崩溃，临时移除插件后 analyze 0 error，分析完恢复。

#### Decisions 偏离 plan

- **圆体**：spec/plan 列为「实施时确认」。实跑后确认无完美开源 OFL 圆体，按 spec fallback 用前 3 款 + 系统，UI 不显示圆体 chip，README 诚实标注。未凑数加劣质近似款。
- **字体 family 别名**：spec 示例 family 名用 `NotoSansSC`（无空格），与字体内部 post 表 name（`Noto Sans SC`，有空格）不同。这是正确的——pubspec `family:` 是逻辑别名，代码 `fontFamily:` 与之匹配即可，Flutter 据别名注册 asset。保持 plan 的无空格别名。

#### Lessons

- **TextStyle 无法表达 CSS text-indent**：Flutter 的 TextStyle 只有 fontSize/height/fontFamily/weight 等，没有 first-line-indent。任何需要 CSS-only 属性的排版（缩进、字间距 letter-spacing、首字下沉）都必须走 HTML `<style>` 注入（HtmlWidget 是 HTML 渲染器，`<style>` 是一等公民），不能走 TextStyle。pivot 到 TextStyle-based 渲染后这类需求容易遗漏。
- **「末页居中」可能是视觉错觉**：实测短内容在固定高度 slot 里**本就是顶部对齐**（RichText top=margin），用户主观感觉「居中」是因为下方留白大。修这类「布局问题」前先实测渲染位置，避免改了半天发现代码本就对——本次 Align 双保险仍有价值（语义显式 + 防回归），但根因诊断要诚实记录。
- **中文路径 + Dart analysis server LSP 不兼容**：`flutter.bat analyze` / `flutter analyze` 在本工作目录（`H:\projiect\电子书阅读平台`）会让 analysis server 的 LSP framing 崩溃（URL-encode 中文路径成 `%E7%94%B5...` 后 JSON 解析 Unterminated string）。custom_lint 插件同因崩溃（pub get 时 path 解析失败）。解决：用 `dart.bat analyze`（非 LSP 路径）跑核心分析，必要时临时移除 custom_lint 插件。这是本仓库中文路径环境的固有约束，CI 应在英文路径环境跑。
- **字体下载的多镜像 fallback**：单一 CDN 不可靠（GitHub 被墙、jsDelivr 对 >50MB 仓库拒服务、Gitee raw 需登录）。下载脚本对每款字体配 2-3 个镜像（jsDelivr + gh-proxy.com + ghfast.top），任一成功即停。

### M2.11 — 2026-07-04（书签页内定位 + 高亮跨章泄漏修复）

M2.10 修完双页回归后用户复测，报告 3 个新问题：①书签只按章节命名、跳转只回章节首页；②旧摘录颜色/跳转错误（新的正常）；③没摘录的页也出现幽灵高亮。代码层追溯发现 ①③ 是两个独立的设计缺陷，② 是 ③ 的副产物。

#### Fixed

- **问题1 书签只到章节首页（paged 模式页位置未编码）**：根因是 `_emitCurrentLocation`（epubx_renderer.dart）在 paged 模式下用 `_scrollController.offset` 算 charOffset，但 `_scrollController` 在 paged 模式**没有 client**（用 PageView）→ charOffset **恒为 0** → 书签 cfi 永远是 `"<chapter>:0"`。`gotoLocator` CFI 分支的 post-frame 重定位也只走 scroll（paged 下 no-op），永远 `jumpToPage(0)`。修复：①`_emitCurrentLocation` paged 模式改用当前页 break 的 `startOffset` 作 charOffset（编码真实页位置）；②`gotoLocator` CFI 分支 post-frame paged 模式用 charOffset 反查 break → `jumpToPage`（双页换算 spread `~/2`）；③`_defaultBookmarkLabel` EPUB paged 模式加页码"第 N 章 · 第 M 页"（M 来自 currentSpreadIndex）。
- **问题3 没摘录的页也有高亮（跨章泄漏）**：根因是 `reader_body.dart` 把**全书所有 annotation** 灌进 `engine.injectHighlights`，**丢弃了 `chapterIndex`**。`_allHighlights` 不分章，渲染当前章时把别的章的高亮用各自章内 0-based offset 去 match 当前章页范围 → offset 范围恰好重叠的页冒出幽灵高亮。`localizeHighlights` 的交集数学是对的，错在被喂了错误坐标空间的 offset。修复（方案B，长期稳定）：`HighlightRange` 加 `chapterIndex` 字段（默认 -1 向后兼容），`_buildPaged` 与 `currentHighlightedHtml` 渲染时按 `chapterIndex == _currentChapterIndex` 过滤，`reader_body` bridge 传入 `loc.chapterIndex`。
- **问题2 旧摘录颜色/跳转错误**：是问题3跨章泄漏的副产物——旧摘录的 offset 数据本身是对的，但被别章高亮污染导致显示错位/颜色异常。修问题3后自动正确，无需数据迁移。

#### Tests

- 更新 `epubx_renderer_paged_highlight_test.dart`：注入高亮加 `chapterIndex: 0`（反映新契约）；新增跨章泄漏防护 case（注入两章高亮，验证切换章节后只显示当前章的、不串内容）。
- 更新 `epubx_renderer_test.dart`：`currentHighlightedHtml` 两个 case 的高亮加 `chapterIndex: 0`。
- 全套：epub_view 134 通过（+1 新），app reader 184 通过，仅 pre-existing fail（epub_cover_extractor / PDF fixtures）。

#### Lessons

- **CFI 编解码必须覆盖所有渲染模式**：`_emitCurrentLocation` 与 `gotoLocator` 是一对 round-trip，但 paged 模式下编码侧（emit）用 scroll controller、解码侧（goto）也用 scroll——两端都假设 scroll 模式，paged 模式静默失效（charOffset 恒 0、重定位 no-op）。任何"位置"概念跨渲染模式传递时，编解码两端都必须处理所有模式，否则会"看起来对但数据是空的"。
- **每章独立 0-based offset 是高亮泄漏的温床**：不同章的相同 offset 范围在各自的坐标空间里指向完全不同的文字。任何按 offset 匹配的逻辑（高亮、定位）都必须显式带章归属（chapterIndex），否则跨章数据混在一起时会产生"幽灵匹配"。这是 per-chapter coordinate design 的固有约束。

### M2.10 — 2026-07-04（M2.9 双页功能回归修复）

M2.9 交付后用户上手测试（Windows 宽屏 ≥1100px，命中自动双页分支），报告 3 个新回归。代码层追溯发现**全部由 M2.9 双页渲染分支 + 现有 measurement gap 共同触发**，窄屏单页模式不出现。第一轮修了 Bug A（溢出）+ B2（目录跳转）+ C1（书签入口 FAB），用户复测后 B1 笔记跳转、C2 书签页报错仍存在——Round 2 找到**真根因**（首轮误判）。本次纯回归修复。

#### Fixed

- **Bug A 底部黄黑斑马线 / "bottom overflowed by 14 pixels"**：`_buildPaged`（epubx_renderer.dart）每页在固定高度 PageView slot 里渲染 `Padding>HtmlWidget`。`HtmlWidget`（flutter_widget_from_html）渲染高度与 `Paginator`（TextPainter 测量）存在系统性误差（line-height/font-metrics 偏差，代码注释已自认误差 < 1 行）。双页模式宽度 halve 放大换行误差，某页真实高度 > slot 固定高度 → RenderFlex cross-axis 溢出 → 斑马线 + overflow 文字。修复：`buildSinglePage` 把 `Padding>HtmlWidget` 包进 `SingleChildScrollView(physics: NeverScrollableScrollPhysics())`，误差自然吸收（不溢出即不滚，溢出可竖向微滚），绝不抛 assertion。NeverScrollable 防止子页滚动与 PageView 翻页手势冲突。与 `_buildScroll`（scroll 模式已用 SingleChildScrollView）模式一致。
- **Bug B1 笔记/摘录跳转（首轮误判 + Round 2 真根因）**：首轮以为是双页 spread 索引换算错（service 加 `dualPageMode ~/2`），但用户复测"跳到完全错误的地方或没反应"。Round 2 追到真根因：`Scrollable.maybeOf(context)` 从 `_ReaderBodyState.context` 往**上**找祖先，但 PageView（paged）/ SingleChildScrollView（scroll）都在 `engine.build()` 里、是 ReaderBody 的**后代**，所以**永远返回 null** → `_onAnnotationTap`/`_maybeHandleInitialLocator` 的 `if (scrollable == null) return;` 总提前退出 → 跳转从未执行（同章"没反应"，跨章停在 `gotoLocator` 的 jumpToPage(0) 首页）。修复：`scrollable` 参数改可选（paged 分支根本不读它，只用 pageController + pageBreaks）；调用方仅 scroll 模式才查找 scrollable，paged 模式直接调 `scrollToCharacterOffset`。首轮的 `dualPageMode ~/2` 换算保留（双页下仍需正确）。注：scroll 模式的 in-page 滚动定位此前也未工作（同因），本次未修（保持现状，不引入新回归），留 v1.6。
- **Bug B2 目录跳转失效**：`ReaderTocDrawerWrapper.onSelect`（reader_drawer_builders.dart）调 `gotoTocEntry` 后没 `await chapterSwitchSettled` 就 `closeDrawer`，双页模式下 rebuild 触发 `_buildPaged` LayoutBuilder 重算分页，drawer 提前关 + PageView 未完成新章布局 → TOC 卡住或 spread 越界。修复：onSelect 改为 `await gotoTocEntry; await chapterSwitchSettled; if (context.mounted) closeDrawer()`（chapterSwitchSettled 是公开 Future，wrapper 可访问）。
- **Bug C1 chrome 隐藏时无添加书签入口**：添加书签唯一入口在 `_buildChrome` 的 AppBar，被 `if (ui.chromeVisible)` gate；全屏/chrome 隐藏时按钮消失，无 FAB/快捷键 fallback → "没有地方来添加书签"。修复：`_buildReaderStack` 的 Stack 加一个 `Positioned(bottom:56, right:16)` 的 `FloatingActionButton(Icons.bookmark_add_outlined)`，仅 `!ui.chromeVisible` 时显示（chrome 可见时不重复）。复用 `_onAddBookmark`。
- **Bug C2 书签页红屏报错（Riverpod 断言，Round 2 真根因）**：用户报告书签 tab 红屏黄字，错误是 Riverpod `"Tried to read ... from a place where one of its dependencies were overridden but the provider is not"`。根因：`reader_page.dart` 的 `ProviderScope.overrides` 覆盖了 `currentBookIdProvider` + `notesControllerProvider`，但**漏了 `bookmarkControllerProvider`**——它也 `ref.watch(currentBookIdProvider)`，依赖被覆盖但消费方没覆盖 → 断言红屏。修复：overrides 列表补 `bookmarkControllerProvider.overrideWith((ref) => BookmarkController(bookId: widget.bookId, repository: ref.watch(bookmarkRepositoryProvider)))`，与 notesControllerProvider 同模式。全代码库仅这两个 provider 依赖 currentBookIdProvider，已全部覆盖。
- **Bug B2 目录跳转失效**：`ReaderTocDrawerWrapper.onSelect`（reader_drawer_builders.dart）调 `gotoTocEntry` 后没 `await chapterSwitchSettled` 就 `closeDrawer`，双页模式下 rebuild 触发 `_buildPaged` LayoutBuilder 重算分页，drawer 提前关 + PageView 未完成新章布局 → TOC 卡住或 spread 越界。修复：onSelect 改为 `await gotoTocEntry; await chapterSwitchSettled; if (context.mounted) closeDrawer()`（chapterSwitchSettled 是公开 Future，wrapper 可访问）。
- **Bug C1 chrome 隐藏时无添加书签入口**：添加书签唯一入口在 `_buildChrome` 的 AppBar，被 `if (ui.chromeVisible)` gate；全屏/chrome 隐藏时按钮消失，无 FAB/快捷键 fallback → "没有地方来添加书签"。修复：`_buildReaderStack` 的 Stack 加一个 `Positioned(bottom:56, right:16)` 的 `FloatingActionButton(Icons.bookmark_add_outlined)`，仅 `!ui.chromeVisible` 时显示（chrome 可见时不重复）。复用 `_onAddBookmark`。

#### Tests

- 新增 `epubx_renderer_paged_overflow_test.dart`（4 cases）：单页/双页临界高度 HTML 无 overflow；遍历每个 spread 无 overflow；结构断言 SingleChildScrollView 存在。
- 扩展 `scroll_to_offset_test.dart`（+5 cases）：dualPageMode=true 时 break3→spread1、break4(orphan)→spread2、dualPageMode=false 保持 break 索引（无回归）；Round 2 加 paged 模式不传 scrollable 也能 jumpToPage、scroll 模式缺 scrollable 抛 ArgumentError（B1 真根因）。
- 新增 `reader_toc_drawer_settle_test.dart`（1 case）：onSelect 在 chapterSwitchSettled resolve 前不关 drawer，resolve 后关。
- 新增 `reader_body_bookmark_fab_test.dart`（3 cases）：chrome 隐藏时 FAB 存在、chrome 可见时 FAB 不存在、点击 FAB 弹 add-bookmark dialog。
- 扩展 `reader_page_test.dart`（+1 case）：同 scope override currentBookIdProvider + bookmarkControllerProvider 后读 provider 不抛 Riverpod 断言（C2 真根因）。
- 更新 `epubx_renderer_widget_test.dart`：paged 模式断言从"无 SingleChildScrollView"改为"有 SingleChildScrollView 且 controller 为 null"（Bug A 修复改变契约）。

**总数**：epub_view 133 通过 + 1 pre-existing fail（epub_cover_extractor，patched epubx）；app reader 184 通过 + 2 pre-existing fail（PDF fixtures 未 git-sync）。`dart.bat analyze` 全绿。

#### Lessons

- **分页测量与渲染的固有误差是设计层面的**：TextPainter 与 HtmlWidget 的 line-height/font-metrics 永远有微小偏差，分页边界本就是近似。工业阅读器（readium 等）都允许页面小幅内部滚动兜底，而非追求测量 100% 精确。把 overflow 当"可吸收误差"而非"必须消除的 bug"是更稳健的工程选择。
- **双页模式是一次"坐标空间分裂"**：单页模式下 page index、break index、spread index 三者重合；双页模式下 spread index = break index ~/ 2。所有读 PageController.page 的代码（service、页码显示、章末判定）都必须显式区分这两套坐标。M2.9 引入双页时漏了 ScrollToOffsetService 这条路径。

### M2.9 — 2026-07-04（EPUB 双页布局 + 每页页码）

用户需求："页面足够大时像书一样分左右两页显示；每页下方显示页码"。M2.5/T14 早留了 `dualPageMode` API surface 但渲染层推到 v1.6，本次实现真正渲染。设计决策（用户确认）：宽屏（≥1100px）自动触发；页码显示"本章 当前/总"。

#### Added

- **EPUB 双页布局（Bug #4 EPUB 部分）**：宽屏（≥1100px）+ paged 模式时自动启用书脊式左右两页。`EpubxRenderer._buildPaged` 渲染单 PageView，每 item（spread）是 `Row(Expanded左页, SizedBox(24px书脊), Expanded右页)`。Paginator 按半宽测量（`(width-24)/2`），每 break = 一列内容；spread[i] = breaks[i*2] + breaks[i*2+1]。孤页（breaks 奇数）右侧 `SizedBox.shrink()`。窄屏自动回单页。
- **每页页码**：底栏显示本章页码 `当前 / 总`（如 `3 / 12`），双页模式 `3-4 / 12`（孤页只显左）。新增 `ReaderEngine.currentSpreadCount`/`currentSpreadIndex` 接口；`ReaderBottomBar` 加 `pageInfo` 字段；`ReaderProgressBar._epubPageInfo` 计算。PDF/scroll 模式回退到原百分比。

#### Changed

- **翻页时位置流 emit**：`_buildPaged` 的 `onPageChanged` 旧实现只调 `_maybeEmitChapterEnd()`，翻页时 `currentLocation$` 不 emit → 页码不刷新。改为同时调 `_emitCurrentLocation()`。
- **dualPageMode 改 private + setter**：`_dualPageMode` private，通过 `setDualPageMode(value)` 设置（清缓存 + jumpToPage(0) + emit state），避免窗口缩放时 page 索引越新 itemCount 界。
- **ReaderEngine 接口扩展**：加 `dualPageMode`/`currentSpreadCount`/`currentSpreadIndex` 三个 getter；PDF 中性实现（spread 返回 0，走自己的 pageCount）；7 个 test fake 更新。

#### Tests

新增/重写 `epubx_renderer_dual_page_test.dart`（10 cases）：双页渲染 Row+2 HtmlWidget、单页 1 HtmlWidget、spreadCount halving、孤页不崩、setDualPageMode reset page、idempotent。

**总数：125 epub_view + 103 reader 通过**（baseline 115+94 + 新增）。

### M2.8 — 2026-07-04（v1.5.1-alpha 用户复测反馈 #3：9 bug 分 4 批修复）

v1.5.1-alpha 交付后用户复测报告 9 个 bug，其中 #3/#7 在 M2.7 已修，本次处理剩余 #1/#2/#5b/#6/#8/#9，分 4 个批次逐个修复 + 用户验收。

#### Batch 1 (B1)：翻页 + 分页 + 键盘 + ESC

- **Fixed Bug #6 翻页乱翻/延迟**：tap zone 无条件调 `nextSpine`（章末才换章，章内不分页）→ 改为按 paginationMode 路由：paged → `engine.nextPage()`/`previousPage()`（章内分页，章末换章）；scroll → `nextSpine`/`previousSpine`。新增 `ReaderEngine.nextPage()`/`previousPage()` 接口。
- **Fixed Bug #8 文字溢出**：`Paginator` 测量不扣 margin 导致每页内容溢出 → `usableHeight = viewport.height - 2*marginPx`，`usableWidth = (viewport.width - 2*marginPx).clamp(50, inf)`，`_CacheKey` 加 marginPx。
- **Fixed Bug #9 ESC 退全屏**：SelectableRegion 抢焦导致 ReaderScaffold Focus 收不到键盘事件 → `initState` 加 `HardwareKeyboard.instance.addHandler`（全局单例，绕过焦点树），Focus.onKeyEvent 移除（避免双重派发）。

#### Batch 2 (B2)：跨章翻页修复

- **Fixed Bug #6 跨章乱翻**：`setChapter()` 改了 `_currentChapterIndex` 但**不 emit state** → reader_body 不 rebuild → PageView 继续渲染旧章页面，而 controller 已 jumpToPage(0) → 用户看到"回到本章首页"，下一次 nextPage 读到 `_cachedBreaks==null` 走 fallback 换章 → 章节号无声推进 → "跨章节乱翻"。补 `_stateController.add(const ReaderEngineReady())`（gotoLocator CFI 分支早有，setChapter 漏了）。
- **Added 章首左翻换上一章末页（Kindle 行为）**：`previousPage()` 章首分支 arm `_pendingJumpToLastPage`，下一帧 `_cachedBreaks` 填充后 `_maybeApplyPendingLastPageJump` jumpToPage 到末页（one-shot）。setChapter 清零 flag（仅 previousPage 重新 arm）。

#### Batch 3 (B3)：高亮渲染（paged 模式）

- **Fixed Bug #5b 高亮不显示**：`_buildPaged` 用 `Text(plain.substring(start,end))` 渲染每页，丢掉了 `HtmlHighlightInjector` 注入的 `<span>`。新增 `HtmlSlicer`（`sliceByPlainRange` DOM 遍历裁剪 + `localizeHighlights` 全局→页面本地坐标），`_buildPaged` 改为每页 sliceByPlainRange → 高亮注入 → HtmlWidget。副带收益：paged 模式恢复富文本格式（粗体/标题/段落）。
- **Bug #5 淡化底色**：0.4 alpha 早已在 `reader_body._highlightColorRgba` 满足，只是 span 进不了渲染。B3 修复后自然显现。

#### Batch 4 (B4)：书签红屏 + 笔记延迟

- **Fixed Bug #1 书签点击红屏**：`gotoLocator` 内部 `addPostFrameCallback` 跑在调用方 `_onBookmarkJump` 的 try-catch **之外**，书签跨章跳转触发 rebuild，rebuild 期间 ScrollController 可能短暂 detach，`.position` 访问抛出 → 未捕获 → 红屏。三重防御：(1) post-frame callback 全包 try-catch；(2) build/currentChapterPlainText/currentHighlightedHtml 全部加 `_currentChapterIndex >= chapters.length` 越界保护（book-switch race）；(3) gotoLocator 跨章分支补 `jumpToPage(0)`（之前只有 setChapter 有），避免旧 page index 超新 itemCount assertion。
- **Fixed Bug #2 笔记点击延迟**：`_onAnnotationTap` 只 `await chapterSwitchSettled`，同帧 PageView 刚 rebuild 还没完成布局，紧接着 jumpToPage 被吞 → "等一会才跳"。新增 `_awaitChapterSettledAndLayout()` helper：`chapterSwitchSettled` 后多等一帧（`endOfFrame`）让 PageView 完成布局。统一应用到 _onAnnotationTap / _onBookmarkJump / _maybeHandleInitialLocator / _jumpToChapter。

#### Tests

新增 `epubx_renderer_cross_chapter_back_page_test.dart`（3 cases）、`html_slicer_test.dart`（18 cases）、`epubx_renderer_paged_highlight_test.dart`（3 cases）、`epubx_renderer_bounds_guard_test.dart`（5 cases）；`epubx_renderer_setters_emit_state_test.dart` 加 setChapter emit 用例。

#### Lessons

- **setChapter 是唯一漏 emit 的章节切换路径**：gotoLocator CFI/EpubRangeLocator 分支、injectHighlights、setTypography、setPaginationMode 都 emit，唯独 setChapter 漏。这类"看着对、consumer 收不到"的 silent failure 是 adapter pattern 常见陷阱——每个 mutation 路径都得有自己的 notification pipeline。
- **post-frame callback 在调用方 try-catch 之外**：`addPostFrameCallback` 调度后立即 return，callback 在后续帧执行，完全脱离调用方的 try-catch。任何可能抛的 callback（尤其是访问 ScrollController.position / pageController.page 的）必须自带 try-catch。
- **LayoutBuilder 与 PageController 的帧时序**：`chapterSwitchSettled` 的 completer 在 post-frame resolve，但同帧 PageView 刚 rebuild 尚未完成布局，紧接着 jumpToPage 会被吞。多等一帧 `endOfFrame` 是稳妥的修复模式。

### M2.7 Round 3 — 2026-07-03（v1.5.1-alpha 用户复测反馈 #2）

Round 2 修复后用户报告 "排版页点击很多次才变动一点点，边距有改善但仍需更宽"。代码层追溯发现 Round 2 修复**完全没生效**：emit 调用加在了 `EpubxRenderer._stateController`，但 `ConcreteEpubReaderEngine.state$` 返回的是 adapter 自己的 `_stateController.stream` —— renderer 的 emission **从未转发到 adapter**，所以 `reader_body.dart:144` 的 listen 永远收不到事件。用户感受到的"一点点变化"只是 M2.6/T4 enum pixel value bump（normal 24→32）造成的视觉初值差异，跟排版切换无关。

TypographyPanel 自身还有第二层 bug：`reader_typography_panel_trigger.dart:65` 的 sheet builder snapshot `engine.typography` 作为 `current`，但 sheet 内部 `Consumer` 只 watch profile/font providers，没订阅 engine state。即使 Round 3 桥接通，sheet 内 `current` 仍不刷新 —— 每次 ChoiceChip 点击基于闭包里旧 `current.copyWith(...)`，写到 engine 的值永远不变。

#### Fixed

- **Bug #3 + #8 排版无反应（真根因）**：`ConcreteEpubReaderEngine` 构造函数加 `_renderer.state$.listen(_setState)` 桥接，转发 renderer 内部 stream emission 到 adapter 的 `_stateController`。Round 2 在 `epubx_renderer.dart` 加的 4 处 emit (setTypography / setPaginationMode / gotoLocator CFI / injectHighlights) 现在真正能传到 reader_body。这是 Round 2 修复"看似不生效"的根本原因。
- **TypographyPanel current 不刷新**：`reader_typography_panel_trigger.dart` 的 sheet builder 内嵌 `StreamBuilder<ReaderEngineState>` 订阅 `widget.engine.state$`，rebuild 时重新读 `widget.engine.typography` 作为 `current`。修复后字号 +/- 按钮、行距/字体/主题/边距 ChoiceChip 都即时刷新且可重复点击。
- **Bug #8 边距（加宽）**：用户反馈 M2.6/T4 (normal=32, wide=48, extraWide=64) 后"边距有改善但仍需更宽"。再次 bump: normal 32→48, wide 48→72, extraWide 64→96。Compact 保留 8（仅查看）。48px ≈ 1.5× WCAG tap target。

#### Tests

新增 `concrete_reader_engine_state_bridge_test.dart`（4 cases）：setTypography / setPaginationMode / gotoLocator CFI / injectHighlights 各自验证从 `ConcreteEpubReaderEngine.state$`（adapter stream）能收到 `ReaderEngineReady`。这是 Round 2 的盲点 —— 之前只测 renderer.state$ 有 emit，没测 adapter stream 是否能转发。

**总数：1076 通过 + 3 skipped**（baseline 1069 + 4 round-3 + 3 round-2 之前已加）。

#### Lessons

- **两路 state$ 的盲点**：`EpubxRenderer` 有自己的 `_stateController`，`ConcreteEpubReaderEngine` 又有自己的 `_stateController`。两路独立意味着 renderer emit 必须 bridge 到 adapter 才能到 consumer。这是 adapter pattern 常见陷阱：每个层级都得有自己的 notification pipeline，否则会出现"emit 看着对、consumer 收不到"的 silent failure。
- **Modal sheet 是独立 overlay**：父 widget rebuild 不会触发 sheet 内 builder 重跑。Riverpod `Consumer` 只在 watch 的 provider 变化时 rebuild。如果 sheet 需要 follow 外部 state（如 engine.state\$），必须显式 StreamBuilder / EventBus 订阅。

### M2.7 Round 2 — 2026-07-03（v1.5.1-alpha 用户复测反馈）

v1.5.1-alpha 交付后用户立即上手测试，发现 9 个 bug 中 7 个依旧（仅 Bug #5a 部分缓解、Bug #2 行为变化）。代码层追溯发现 **5 个 bug 同根因**：`EpubxRenderer` 是普通 class（不是 widget），改实例字段（`_typography` / `_paginationMode` / `_currentChapterIndex`）后**必须 emit state**，上游 `reader_body.dart:144` 的 `engine.state$.listen → setState → rebuild` 才能让屏幕更新。M2.6 修了 `injectHighlights` + `gotoLocator` EpubRangeLocator 分支的 emit state，但漏了 3 处。

#### Fixed

- **Bug #3 + #8 排版无反应 + 边距太窄**：`setTypography` (epubx_renderer.dart:486) 只赋值 `_typography` 不 emit state → 上游 reader_body 收不到事件 → widget 不 rebuild → 字号/行高/margin/主题任何选项都看不到变化。Bug #8 不是 enum 没改（已确认 normal=32），而是因为 widget 不 rebuild 永远显示旧值。补 `_stateController.add(const ReaderEngineReady())`。
- **Bug #7 TOC 不跳页**：M2.6/T7 只修了 `gotoLocator` 的 EpubRangeLocator 分支，但 `gotoTocEntry → gotoLocator(entry.locator)` 通常落到 CFI 分支（TocEntry.locator 多为 EpubCfiLocator）。CFI 分支 (epubx_renderer.dart:435) 同样只更新 `_currentChapterIndex` 不 emit state。补 emit state。
- **Bug #6 翻页（部分）**：`setPaginationMode` (epubx_renderer.dart:492) 不 emit state，paged ↔ scroll 切换后 widget 不 rebuild。补 emit state。注意：这只解决翻页问题的部分原因，焦点路径问题（Bug #9 ESC 同根因）仍待用户配合诊断。

#### Lessons

- **M2.6 测试覆盖层级错配重现**：单元测试只测"字段被赋值"，没测"emit state 后 widget 真重建"。M2.7 round-2 加了 3 个回归测试覆盖 setTypography / setPaginationMode / gotoLocator CFI 分支的 emit state 行为，防再次回归。

## [1.5.1-alpha] — 2026-07-03

v1.5.1-alpha 是 M2.6「Emergency Bug Fix Sweep」的交付版本：v1.5.0-alpha 用户上手测试 2026-07-03 上午发现的 9 个 bug（核心阅读流程多处不通）紧急修复。无新功能，纯 fix sweep。

### Fixed

- **Bug #1 书签点击红屏（防御性修复）**：`_onBookmarkJump` 的 `engine.gotoLocator(locator)` 未包 try-catch，任何异常直接渲染为 Flutter 红屏。包了 try-catch + SnackBar，根因待用户复现提供 stack trace 后做精准修复（M2.7 或 v1.5.2-alpha hotfix）。
- **Bug #2 笔记点击退出书**：`_onAnnotationTap` 无条件调 `Navigator.maybePop()`，M2.5/T7 抽屉重构成 `Scaffold.drawer` 后会 pop 掉整个 reader route。复用 `_onBookmarkJump:809` 的 `_isWideScreen` gate 模式。
- **Bug #3 排版页无反应**：`ConcreteEpubReaderEngine.typography` 返回 `TypographySettings.defaults()`（const 默认），`TypographyPanel.onChanged` 写到丢弃对象。一行修复：`get typography => _renderer.typography;`。`EpubxRenderer.typography` 暴露为 public getter（之前是 private 字段）。
- **Bug #4 PDF 双页假启用**：M2.5/T13 把双页触发耦合到 LayoutBuilder 宽度（>=1200px），全屏切换 + isScanned FutureBuilder 解析存在 race condition。改为用户-driven 独立 toggle（AppBar 新按钮，仅 PDF 引擎可见），默认 false。**v1.5.1 简化**：不持久化（每次启动默认 false）；持久化延后 v1.5.2。
- **Bug #5a 选择困难 + 翻页冲突**：reader_scaffold.dart 重构。原代码用单个 `GestureDetector(behavior: HitTestBehavior.opaque)` 包内容，会与 SelectableRegion 抢手势。改为 Stack 3 层（左空白边 / 右空白边 / 中央 double-tap），文字内容区归 SelectableRegion 独享。仿真书模型 per user 2026-07-03：左右空白边点击翻页，中央纯选择，4 面留白。
- **Bug #5b 高亮不渲染**：`injectHighlights` 只更新 `_allHighlights` 字段，不触发 consumer 重建。在 inject 后 emit `ReaderEngineReady` 到 `_stateController`，reader_body 监听到后重建读出新高亮。
- **Bug #6 翻页延迟/错乱**：`reader_scaffold._handleKeyEvent` + `_handleDragEnd` 的 `paginationMode != paged` gate 静默吞掉了 PDF（scroll）模式的所有键盘/拖拽事件。lift 该 gate（保留 wheel gate —— scroll 模式滚轮应让内容 ScrollView 自然滚动）。用户报告"键盘左右键不能翻页"解决。
- **Bug #7 TOC 不跳页**：`epubx_renderer.gotoLocator` 的 `EpubRangeLocator` 分支只更新 `_currentChapterIndex`，不 emit state。consumer widgets（reader_body）不重建，视觉上章节没变。补 `_stateController.add(const ReaderEngineReady())`。
- **Bug #8 边距太小**：`PageMargin` enum 像素值 bump：normal 24→32, wide 32→48, extraWide 40→64。Compact 保留 8（仅查看，不适合点击翻页）。M2.6/T9 后边距同时承担「视觉留白 + 翻页 tap zone 宽度」双职责，Normal 及以上满足 WCAG 最小 tap target（>=32px）。epubx_renderer.dart 已用 `EdgeInsets.all(margin)`，4 面留白已到位。
- **Bug #9 ESC 不退全屏**：`Focus` widget 在 AppBar 按钮点击后失去焦点捕获，ESC 事件被按钮节点吞掉。Hoist FocusNode 到 State 字段，所有 AppBar IconButton `onPressed` 完成主操作后调 `_reclaimFocus()` 重新获焦。

### Architecture

- **A1**：PDF 保留 scroll 模式默认；双页布局是独立 toggle，per-book 持久化延后 v1.5.2。
- **A2**：仿真书阅读模型——tap zone 仅存在于左右空白边，文字内容区是纯选择领地；4 面留白。
- **A3**：Bug #1 ships defensive（防御性 try-catch）；待用户 stack trace 后做精准修复。

### Tests

3 个新回归测试（T3 typography getter + T5 injectHighlights emit state + T7 gotoLocator EpubRangeLocator emit state）。T6/T8 widget tests deferred（fix 是 mechanical copy-paste，手动 smoke 验证）。T1+T9+T10 修改了既有 paging/scaffold 测试以反映新行为（scroll 模式键盘/拖拽现在翻页；tap zone 仅在空白边）。

**总数：1069 通过 + 3 skipped**（baseline 1066 + 3，flaky `book_import_service_test.dart:77` 偶发不影响 ship）。

### Known Limitations

- Bug #1 根因可能未完全解决，待用户提供 stack trace。
- EPUB 双页渲染仍推到 v1.6（M2.5/T14 API surface 未动）。
- PDF 双页 toggle 不持久化（v1.5.2 加 SharedPreferences）。

### Upgrade Notes

如新边距过宽：**Settings → Typography → Margin → Compact**（8px）。

## [1.5.0-alpha] — 2026-07-03

v1.5.0-alpha 是 M2.5「Reader UX Overhaul」的交付版本：2 个 P0 用户面 bug 修复 + 8 项 UX 增强 / 新功能。目标是把阅读器从"能用"推进到"在桌面宽屏上舒服用"——多输入翻页、全屏模式、宽屏 TOC sidebar、双页布局、书签系统、合并摘录入口，外加首次分页 margin 调整与 chrome 默认可见。

### Fixed

- **#4 高亮不渲染**：用户选中文本后选颜色，页面上不出现高亮。根因：`NotesState.annotations` 变更后没有桥接到 `engine.injectHighlights()`。修复：`reader_body.dart` 加 `ref.listen` 把 annotations 同步到 engine（T2）。
- **#6 笔记条目点击无效**：NotesPage / drawer 里点笔记不跳回原位置。根因：`EpubxRenderer.gotoLocator` 没处理 `EpubRangeLocator`（只认 `EpubCfiLocator`）。修复：补齐 `EpubRangeLocator` 分支（T1）。

### Added

- **书签系统（#7）**：drift v10 schema + 仓库 + 控制器 + sync pipeline + UI 四入口。
  - 数据：`Bookmarks` 表（id / bookId / locatorJson / label / note / createdAt / updatedAt），v9 → v10 自动迁移。
  - 同步：`SyncRecordType.bookmark` 接入 SyncRecorder + RemoteRecordApplier，遵循 last-write-wins 与高亮相同的冲突策略。
  - UI：AppBar 收藏图标 + 自定义标签对话框、drawer 书签 tab、独立路由 `/book/:id/bookmarks` 页面。
- **PDF 双页布局（#10）**：宽屏（>=1200px）自动启用，按偶数页对齐；扫描件自动降级单页。
- **EPUB 双页 API surface（#10 部分）**：`dualPageMode` 标志已端到端 wire（`EpubxRenderer` → `ConcreteEpubReaderEngine.rendererRef` → `reader_body.dart` LayoutBuilder）。**渲染层留 v1.6**——EPUB 分页当前是 degraded plain-text 模式，重写算法是抛一次性的工作；PDF T13 已覆盖更常见的双页格式需求。详见 `epubx_renderer.dart` 字段 doc-comment。

### Changed

- **多输入翻页（#2）**：键盘 ←/→/↑/↓/PgUp/PgDn、鼠标滚轮、触摸拖拽、左右 tap zone 五种输入都触发翻页。
- **全屏模式（#3）**：桌面 `window_manager.setFullScreen` + 移动 `SystemChrome.setEnabledSystemUIMode`；Esc / F11 键盘快捷键，全屏态中心区域双击显示 chrome。`FullscreenController` 抽象让 StateNotifier 在测试里用 `NoopFullscreenController` 注入。
- **合并摘录按钮（#5）**：原来「高亮」「笔记」两个按钮合并为「摘录」bottom sheet——5 色高亮 + 可选笔记输入，一站式。
- **TOC sidebar（#8）**：宽屏（>=1100px）下抽屉升级为永久侧栏（280↔40px 可折叠）；窄屏保持原 drawer slide-over。
- **默认 margin 调整（#9）**：Normal 16 → 24 px；新增 ExtraWide=40px 选项（Compact=8 / Normal=24 / Wide=32 / ExtraWide=40）。
- **chrome 默认可见**：桌面端 reader AppBar 默认显示（之前需要点击切换）。中心单击不再切换 chrome（避免误触），改用 AppBar 按钮 / Esc / F11。
- **抽屉 3-tab 重构**：原 `Scaffold.drawer`（TOC）+ `Scaffold.endDrawer`（Notes）合并为单一 `ReaderDrawer`，目录 / 书签 / 笔记三 tab 切换。

### Technical

- 4 个包共 1066 pass + 3 skipped（app 888 / reader_engine 50 / reader_engine_epub_view 83 / reader_engine_pdf_view 45）。
- M2.5 共 15 个任务，全部走 subagent-driven development：每任务 implementer + 两阶段 review（spec compliance → code quality）。
- subagent 自修多个 plan bug：T11 plan 写错了 sync 文件路径（`sync_entity_registry.dart` 不存在，实际是 enum + SyncRecorder + RemoteRecordApplier 三处）；T13 plan 把 PDF `paginationMode == paged` 当触发条件（实际 PDF 模式恒为 scroll），改为「宽度 + 非扫描件」；T9 plan 让 StateNotifier 内联平台分支会破坏可测性，重构为 `FullscreenController` 抽象 + 3 实现。
- 1 个 flaky test (`book_import_service_test.dart::importFile concurrent same file returns existing for second caller`) 在并发执行时偶现，单跑稳定通过——已知是 drift 测试套件并发开销，与 M2.5 改动无关。

### Migration

- Drift 自动从 v9 迁移到 v10（创建 `bookmarks` 表 + `idx_bookmarks_book` 索引）。
- 用户已存的 margin 偏好保留（Compact / Normal / Wide 索引不变）。
- **行为变化 caveat**：Normal 档位的实际像素值从 16 变 24（M2.5 调整）；升级后现有 Normal 用户会感觉阅读宽度变大，可在 Settings → Typography → Margin 切回 Compact（8 px）维持旧观感。

## [1.4.0-alpha] — 2026-07-01

v1.4.0-alpha 是 v1.3.0-alpha 之后的一次"release hygiene sweep"——把 Phase 3+ 之前所有遗留的 housekeeping 工作（reader 代码拆分、lint 清理、文档同步、截图补齐、Gitee Release 页面创建）一次性解决。**没有新功能**。

### Changed

- **Code hygiene**：`reader_body.dart` minimal split（644 → 578 行）。抽出 `ReaderChapterEndPrompt`（controller lifecycle + SnackBar emission）和 `ReaderSelectionToolbar`（Positioned overlay）两个零依赖 widget 到 `features/reader/widgets/`。零行为变化（全量测试通过）。
- **Lint cleanup**：49 个 info lints → 0 via `dart fix --apply` + 手工清理（rename `_`-prefixed 局部变量、`unawaited()` wrap、剩余 cascade 加 `// ignore` + 注释）。

### Documentation

- `maintainers-runbook.md §9.4.1` — v1.4 perf re-test decision（v1.0.0 baseline 沿用，无渲染/DB/sync 重大改动；列下次强制复测触发条件）。
- `release-procedure.md` — step 1/2/12 同步当前版本号（1.3.0-alpha+0）、测试数（812）、AGPLv3 阈值（=0）。
- `release-notes-v1.4.0-alpha.md` — Gitee Release body 草稿。

### Infrastructure

- 3 张 release 截图补齐（library / pdf_reader / notes）。
- 4 个 Gitee Release 页面创建（v1.0.0 / v1.1.0-alpha / v1.2.0-alpha / v1.3.0-alpha）。

### Technical

- 补回遗漏的 `[1.2.0-alpha]` 与 `[1.3.0-alpha]` CHANGELOG 段落（见下）。
- AGPLv3 头覆盖率：100%（生成文件除外）。
- 全量测试：818 pass + 3 skipped（M2.3 baseline 812 + 6 个 M2.4 新测试）。

## [1.3.0-alpha] — 2026-07-01

M2.3 交付：**批量导出范围筛选**。库 AppBar "导出为 Markdown" 先开筛选页，支持按标签（多选 OR）/ 按导入时间 / 按最近阅读三维度组合筛选；实时预览匹配书单 + 高亮总数；底部按钮直接显示"导出 N 本"。底层 `BookFilter` 值类 + `applyBookFilter` 纯函数 + 既有 `VaultExporter` 零改动；预览数 = 实际导出数的不变量由 `VaultExporter.hasContent` 提为 static 保证。

### Added

- `app/lib/features/library/models/book_filter.dart`（T1）— `@immutable` 值类（Set<String> tags + 2 个 TimeWindow 字段；SetEquality 深相等）。
- `app/lib/features/library/services/book_filter_applicator.dart`（T2）— 纯函数 `applyBookFilter({books, filter, tagsByBookId, now})`；OR 语义、5 段预设区间。
- `app/lib/data/local/daos/book_tags_dao.dart`（T3）— 新增 `allTagsByBook()` 单 SELECT bulk。
- `app/lib/features/notes/services/vault_exporter.dart`（T4）— 把"判断 BookNote 是否有内容"内联逻辑提取为 `static bool hasContent(BookNote n)` 公开方法。
- 13 个新 i18n key（中英双语）。
- `app/lib/features/library/pages/export_filter_page.dart`（T6，281 行）— 独立筛选页 StatefulWidget。

### Changed

- `LibraryAppBar._startBatchExport` 改写：fetch notes → 空短路 → fetch tags → `showDialog<BookFilter?>` → `applyBookFilter` → file_picker + BatchExportDialog。

### Technical

- 30 个新测试（全量 812 pass + 3 skipped）。
- subagent-driven development: T1-T9 每 task 双阶段 review；T2 boundary test 抓住 off-by-one risk。

## [1.2.0-alpha] — 2026-07-01

M2.2 交付：**自动章节结束提示**（EPUB only）。用户翻到 EPUB 一章末页（paged 或 scroll 模式）时，自动弹出非阻塞 SnackBar，提供「回顾本章 / 下一章 / 关闭」三个动作。PDF 阅读不弹（pdfrx Page-as-Chapter 频繁打扰）。

### Added

- `reader_engine_epub_view/lib/src/chapter_end_event.dart` — 纯数据类（chapterIndex + isLastChapter，值相等）。
- `EpubxRenderer.chapterEndEvents`（broadcast Stream）— 内部 flag 同次访问去抖。
- `ChapterEndDetector`（app 层）— per-session per-(bookId, chapterIndex) Set 去重。
- `ChapterEndPromptController`（StateNotifier）— settings gate + mounted 检查。
- `ChapterEndPromptSnackBar` — 自定义 content Row（3 个 TextButton；Next 条件显示）。
- `kChapterEndPromptEnabledKey` const + `chapterEndPromptEnabledProvider` AsyncValue<bool> + `ensureChapterEndPromptDefault` 首次启动默认值 seeding。
- Settings 页 `_ChapterEndPromptTile` ConsumerWidget。

### Changed

- `reader_engine_epub_view/lib/src/epubx_renderer.dart` 4 个 `_currentChapterIndex =` 写入点都重置 flag（setChapter / gotoLocator / openFile / bookForTesting）。
- `reader_body._ReaderBodyState` — lazy init + addListener 边沿检测（hidden→visible）+ ScaffoldMessenger.showSnackBar。

### Technical

- 22 个新测试（全量 782 pass + 3 skipped）。
- spec §2.2 明确推后 PDF 路径（pdfrx controller plumbing 留待 future）。

## [1.1.0-alpha] — 2026-07-01

智阅首个 AI 增强里程碑（M2.1）。在 v1.0.0 GA 基础上新增章节学习回顾
与 Markdown 批量导出两大功能。仍为 alpha：UI 文案、动效、错误恢复路径
有待真实用户反馈打磨。

### Added

- **章节学习回顾**（MVP 2.0）：TOC 抽屉按章节 + 阅读器溢出菜单"回顾本章"。
  AI 用本章正文 + 用户本章高亮生成 summary + keyTakeaways，写入读书笔记。
  模态预览 + 保存/取消。PDF 书禁用入口（Page-as-Chapter 语义不适用）。
- **Markdown 批量导出**（MVP 2.0）：库 AppBar "导出为 Markdown"。选文件夹，
  每本书一份 .md + 一个 index.md（Obsidian vault 兼容，含 YAML frontmatter
  + wiki-links + 标签云）。空库提示对话框。
- 25 个 i18n key（15 review + 10 batch export），中英双语。
- 17 个新测试覆盖核心逻辑（总测试数 762 + 3 skipped）。

### Changed

- `PromptBuilder.promptVersion` 1 → 2（review 模式新 cache key；旧缓存不受影响）。
- `LibraryAppBar` 加 `onBatchExport` callback + 新 IconButton（folder_zip_outlined）。
- `TocDrawer` + `_TocTile` 加 `onReviewChapter` 参数（递归传递）。
- `ReaderScaffold` 加 `onOpenReview` callback + PopupMenuItem（仅 EPUB）。
- `maintainers-runbook.md` 新增 §10（M2.1 调试参考，6 个子节）。

### Technical

- 新增 `BookReviewer` **独立**服务（不复用 AiGuide）：AiGuide 的 sourceHash
  只 hash 章节文本，无法感知高亮变化会导致缓存命中错误。BookReviewer 自己
  计算 `sha256(truncatedText + '::' + highlightsSignature)`，让"新增高亮
  → 下次回顾强制 miss"成为默认行为。镜像 AiGuide 的 stream/cache/persist
  pipeline，但用项目最新 `ReviewClientLike` 抽象（参考 BookQaService）。
- 新增 `VaultExporter` 纯逻辑服务 + `BatchExportDialog` StatefulWidget。
- 新增 `ReviewController`（StateNotifier，状态机：idle/loading/streaming/done/error）
  + `ReviewPreviewSheet`（模态预览）。
- `NotesRepository.applyChapterReview` 幂等写入：`【第N章】` 前缀 +
  `## 第 N 章` sentinel，先删后加，保留用户手动内容。
- `ReviewOutputParser` 容错 JSON 解析（处理 ```json fence + 非 String 元素）。
- 0 数据库 schema 迁移；0 同步逻辑改动。
- BookReviewer sourceHash 算法、幂等前缀约定、批量导出文件命名规则
  均记入 `docs/maintainers-runbook.md` §10。

### Plan 偏差与自修

实施过程中 subagent 自主发现并修正了 plan 的若干内部不一致：
- T5 重构 BookReviewer 用 `ReviewClientLike` 抽象（与 plan 假设的 clientFactory
  typedef 不同），更对齐项目最新 BookQaService 模式
- T12 修正测试断言中的 Obsidian wiki-link 格式（文件名经 sanitize 后无书名号）
- T14 改用独立 IconButton 而非 PopupMenuItem（因 LibraryAppBar 现有 UX 是
  IconButton 行而非溢出菜单，保持一致性）

## [1.0.0] — 2026-06-30

智阅首个正式发布（GA）。本条目汇总 M1.6 Polish Sweep 的本次发布内容，
以及 M0 至 M1.6 的累积里程碑。AGPLv3 开源。

### M1.6 Polish Sweep（本次发布）

- **代码质量**：lint 清理（15 warnings + 26 lib info → 0），reader_page.dart
  机械拆分（772 → 97 行 + reader_body / reader_progress_bar /
  reader_typography_panel_trigger 三个聚焦文件），共享 UX 三态组件
  （LoadingView / EmptyView / ErrorView）在 9 个页面落地，drift row 命名
  一致性（Book.fromRow 工厂）。
- **文档**：maintainers-runbook.md（639 行）覆盖环境搭建、中文路径坑、
  subagent-driven 开发流程、Git/发布流程、11 个常见 bug、性能基线方法论、
  24 术语词汇表。
- **Windows 原生冒烟测试**：deep_link_parser 提取 + 基于 cl.exe 的
  test_main.cpp（13 个断言用例）。中文路径 → cl.exe 失败的 ASCII 路径
  workaround 已记录。
- **UX 一致性**：所有可见字符串走 l10n；主页面不再有裸
  CircularProgressIndicator 或临时 error Text。
- **TOC**：渐进式章节标记（已预处理 ✓ / 失败 ⚠ / 未处理）。
- **防御性**：ai_summaries 在 preprocessor 中防御性缓存；
  qaControllerProvider 默认 NoOp；SyncController 强制要求 http.Client；
  共享 httpClientProvider（带 dispose 测试）。

### 累积里程碑（M0 → M1.6）

- **M0+M1**：数据层基础（58 tests）
- **M2**：EPUB 阅读器（179 tests）
- **M3.1-3.5**：书架 / 笔记 / 排版 / i18n（491 tests）
- **M4**：基于 pdfrx 的 PDF 阅读器 + 文本高亮（565 tests）
- **M7**：平台适配（575 tests，v0.4.0）
- **M8**：Windows 安装器（579 tests，v0.5.0）
- **M1.5a**：AI MVP — OpenAI 兼容 LLM、三种导读模式、摘要缓存（v0.7.0-alpha）
- **M2.0a**：同步 MVP — WebDAV 单向 push/pull、last-write-wins（v0.6.0-alpha）
- **M2.0b**：同步冲突解决 + 后台定时器（v0.8.0-alpha）
- **M1.5b+c**：导入批处理 + 同书 Q&A（v0.9.0-alpha）
- **M1.5b+c Review Fixups**：内存泄漏 + spec 偏差闭环（v0.9.1-alpha）
- **M1.6**：Polish Sweep（本次发布 — 713 tests + 2 skipped，GA）
  - 跳过的 2 个测试为预存在项，非本次 milestone 新引入：
    `app/test/features/settings/font_import_service_test.dart:187`
    （FontLoader 在非字体字节上的行为依赖运行环境）与
    `app/test/features/reader/reader_page_pdf_integration_test.dart:60`
    （`skip: true` 占位骨架）。`background_sync_scheduler_test` 与
    `book_import_service_test` 的偶发失败属于 **flaky**（与并发相关），重跑通过。

### 已知限制

- Windows release 构建在中文路径（`H:\projiect\电子书阅读平台`）下失败；
  构建时需拷贝到 ASCII 路径。详见 runbook §3。
- 截图待 v1.0.0 手动采集（见 `docs/screenshots/README.md`）。
- 性能基线待手动测量（见 runbook §9.6）。
- 新表（`book_passages`、`qa_history`）尚未接入 sync_outbox — 推迟至 M2.0x。
- Q&A 为单轮（每次提问独立，无上下文累积）。
- 成本/token 估算 UI 按用户反馈有意省略。

## [0.9.1-alpha] — 2026-06-30

Point release addressing M1.5b+c review findings (C1 + I1-I5).

### Fixed
- **C1**: `QaAnswerView` memory leak — `TapGestureRecognizer`s are now disposed
  when the widget unmounts or the answer text changes. Previously, streaming
  rebuilds leaked ~1 recognizer per citation per build.
- **I1**: `chapterCountFor` linear probe replaced with `ChapterTextProvider.count()`
  — O(1) instead of O(N) EPUB re-parses on import of thick books.
- **I2**: `PreprocessDoneEvent.failedChapters` now reflects transient per-chapter
  failures (was always empty); `PreprocessChapterFailedEvent` is now emitted
  (was dead code). The "N 章预处理失败" banner in BookDetailPage is honest.
- **I3**: Q&A stream stall + total timeout — `BookQaService` drives a
  `StreamIterator` with `Future.timeout(stallTimeout)` per moveNext (default
  30s) and a 90s total cap. A "停止" button in `QaAskDialog` cancels the
  in-flight request via `QaController.reset()`. Network errors after partial
  output are terminal (no replay), mirroring `ai_guide.dart`'s pattern.
- **I4**: `QaAskDialog` now shows "预处理进行中（N/M），回答可能不全" caption
  when the per-book preprocess controller is chunking/summarizing.
- **I5**: Q&A history list — `QaAskDialog.initState` loads top-5 entries and
  renders them as ActionChips. Tap resubmits, long-press deletes. Introduces
  `QaHistoryDaoLike` interface for testability. Closes spec §14 acceptance
  gap "Q&A 历史可查看 + 重发".

### Spec coverage
Review categorization: 1 Critical + 5 Important (this release) → 6/6 closed.
Minors (M1-M7) deferred to M2.0c.

## [0.9.0-alpha] - 2026-06-30

M1.5b+c — AI Batch Preprocess + Same-Book Q&A.

### Added
- **Schema v9**: 2 new drift tables (`book_passages`, `qa_history`) +
  `book_passages_fts` virtual table with 3 sync triggers. Substring LIKE
  remains the default retrieval path (CJK-friendly); FTS5 reserved for
  future relevance-ranked retrieval.
- **Batch preprocess**: On book import with `isNew=true`, LibraryPage
  triggers `BookPreprocessor` which runs a 2-phase state machine:
  - Phase 1 (chunking): synchronous, fast — chapter text → BookChunker →
    `book_passages` rows
  - Phase 2 (summarizing): per-chapter AiGuide.run(chapter) with 2s
    throttle, 3-failure circuit breaker, skipIfRunning, cooperative cancel
- **BookQaService**: same-book Q&A with history short-circuit, FTS top-K
  retrieval, `[ch=N]` citation markers in the answer, parsed and made
  tappable.
- **Reader "问答" icon**: tap to open QaAskDialog; tap a `[ch=N]` citation
  to close the dialog and `engine.gotoTocEntry + chapterSwitchSettled`
  to the cited chapter.
- **Preprocess UI**: BookDetailPage LinearProgressIndicator + cancel button +
  reprocess action; BookCell status chip during processing; Reader chapter
  drawer ✓/⚠ markers.

### Changed
- `database.schemaVersion` 8 → 9. Existing users get empty book_passages on
  upgrade; manual preprocess trigger via BookDetailPage.
- `app_providers.dart` adds `bookPreprocessorProvider`, `bookPreprocessControllerProvider`,
  `bookQaServiceProvider`, `qaControllerProvider` overrides.
- `ReaderScaffold` adds `onOpenQa` callback parameter (nullable, default
  null — readers without a Q&A binding render unchanged).
- `pubspec.yaml` version `0.8.0-alpha+0` → `0.9.0-alpha+0`.
- 16 new i18n keys (zh + en) for Q&A dialog states + preprocess status.

### Known limitations
- New tables (`book_passages`, `qa_history`) not yet wired to sync_outbox —
  deferred to M2.0x.
- Q&A is single-turn (each ask independent, no context accumulation).
- Cost/token estimation UI intentionally omitted per user feedback memory
  `feedback_no_cost_estimation` — reading focus preservation.
- PDF per-page title not surfaced in Q&A context (PdfChapterTextProvider
  returns null title).
- `chapterCountFor` uses linear probe (re-reads EPUB file N times). Acceptable
  for T7; optimization deferred.

### Plan corrections applied by implementers (transparency)
- `qa_history.dart` `id` column uses plain `text()()` (cascade `..withLength` drift syntax dropped silently).
- `QaHistoryDao.delete` renamed `deleteEntry` to avoid clash with drift's `DatabaseConnectionUser.delete`.
- `QaHistoryDao._generateId` switched from timestamp to uuid v4 to avoid UNIQUE collisions in tight loops.
- `Book` constructor uses `addedAt`/`coverPath`, not `createdAt`.
- Credentials class is `AiCredentials` (not `ApiKeyCredentials`).
- `TocEntry.children` is non-nullable (`List<TocEntry>` with default `const []`).
- `BookQaService` and `BookPreprocessor` declare `implements` their `*Like` interfaces (in their own files) to avoid circular imports.
- `QaAskDialog` accepts optional `Book?` for tests; production passes the active book.

### Test counts
- ~60 new tests added across 13 new test files.
- Total: 659 tests passing, 2 skipped (verify with `flutter test` before tagging).

## [0.8.0-alpha] - 2026-06-29

M2.0b — Sync Conflict Visibility + Background Timer.

### Added
- **Conflict log**: LWW decisions are now visible. When a remote record
  loses to local, a row is written to the new `sync_conflicts` table
  with winner/loser device IDs, timestamps, and a 200-char payload preview.
- **Sync Status page** (`/settings/sync/status`): three sections showing
  current status, background interval picker (1/5/15/30 min or off), and
  a rolling 30-day conflict log.
- **Background scheduler**: `BackgroundSyncScheduler` runs Timer.periodic
  (default 5 min) with skipIfRunning guard, 5-min cooldown after errors,
  and lifecycle awareness (pause on background, immediate sync on resume).
- **Connectivity check**: `connectivity_plus` integration for fast offline
  detection (non-blocking — fails open if Windows virtual NIC reports odd).
- **Rolling cleanup**: outbox purged at 7 days; conflicts at 30 days,
  automatically after each successful `syncNow()`.

### Migration
- Drift schema version 7 → 8. Existing users get `sync_conflicts` table +
  `idx_sync_conflicts_detected_at` index on next app launch.

### Compatibility
- All M2.0a sync tests remain green. `NullConflictSink` is the default
  injection, so any code constructing `RemoteRecordApplier` without a sink
  continues to work unchanged.

## [0.7.0-alpha] - 2026-06-29

### Added (M1.5a AI MVP)
- Three AI guide modes: full-book summary, chapter guide (300字 summary + 3-5 markdown bullets), selection comment
- OpenAI-compatible LLM client (default DeepSeek, base_url + model configurable in Settings)
- SSE streaming with token-by-token output
- flutter_secure_storage for API key (Windows DPAPI / Android Keystore), never logged
- On-device drift cache (ai_summaries table, schema v6→v7), lookup by (book_id, mode, sha256(source), prompt_version)
- Four entry points: Library ⋮ menu, BookDetail FAB, Reader top bar, EPUB selection toolbar
- Chapter bullet → "加入笔记" integration (appends to BookNotes.keyTakeaways JSON)
- Network-layer auto-retry (3 attempts, 1s/2s/4s exponential backoff, only before chunks arrive)
- ApiKeySettingsPage with obscure toggle + DeepSeek disclaimer
- i18n strings (zh + en) for all AI UI + error states
- 19 TDD task commits; tests: 617 → 536 passing (some skipped due to fixture availability)

### Changed
- `BookCellAction` enum extended with `aiGuide` value
- `BookGrid`/`BookListView` `onAction` callback now passes `Book` object
- `BookDetailPage` FAB replaced with Row of two FABs (AI 导读 + delete)
- `ReaderScaffold` AppBar actions extended with auto_awesome icon
- `HighlightSelectionControls` accepts optional `onAiComment` callback
- `reader_engine_epub_view` barrel file now exports `plain_text_utils.dart`
- `AiGuide.chapterTextProvider` refactored to `chapterTextProviderFor: ChapterTextProvider Function(Book)` (factory by format)
- `BookNotesDao.appendKeyTakeaway` method added (creates BookNote if missing)
- `pubspec.yaml` adds direct `epubx` + `pdfrx` deps (depend_on_referenced_packages)

### Known limitations
- PDF selection AI comment not wired (pdfrx manages its own selection UI)
- Single-prompt strategy (model auto-adapts; no per-language tuning)
- No cost estimation UI (deferred to S4)
- No batch chapter preprocessing (deferred to S4)

## [0.6.0-alpha] - 2026-06-28

### Added (M2.0a Sync MVP)
- SyncSettingsPage (Settings → Sync): 坚果云 credentials form + manual sync trigger
- SyncOutbox drift table (schema v6): pending writes queue
- SyncRecord JSON envelope with last-write-wins semantics
- WebDavClient (PROPFIND/GET/PUT) with rate limiter (≥2s, R1 mitigation)
- WebDavSyncEngine push + pull paths
- RemoteRecordApplier: applies pulled records with LWW per mtime
- Repository hooks: Notes/Book/ReadingProgress writes automatically enqueue
- Per-device JSON Lines snapshot at `/zhiyue/snapshots/{deviceId}.jsonl`
- Tombstones for deletions (no physical record loss)
- i18n: zh + en strings for sync UI

### Known limitations
- Single-direction sync per record (last-write-wins, no merge)
- Manual sync only (no background timer — that's M2.0b)
- No conflict UI (just silent LWW — that's M2.0b)
- Android APK build not verified in this milestone
- Books' metadata updates from remote are silently dropped (no `updated_at` column)

## [0.5.0] - 2026-06-28

### Added
- Windows Inno Setup 安装包（自动注册 .epub/.pdf 文件关联、开始菜单快捷方式、卸载项）
- Windows 便携 Zip 分发（解压即用，免安装）
- Android fat APK release artifact（真签名 + `apksigner verify`）
- Windows 单实例 deep-link（命名 mutex + WM_COPYDATA 跨进程 argv 透传）
- `BookOpenBridgeOptions.onError` 可选回调 → SnackBar 失败反馈（默认行为向后兼容）
- `dart_test.yaml` 配置 golden tag（消除 test runner warning）
- `CHANGELOG.md` + `NOTICE` 三件套（AGPLv3 合规）
- `docs/setup-android-sdk.md` 安装指南
- `docs/release-procedure.md` 发布流程手册
- 4 张主界面截图（library / EPUB reader / PDF reader / Notes）

### Changed
- 根 `README.md` 状态刷到 v0.5.0；加下载安装段 + 主界面预览
- `app/README.md` 从 Flutter 模板骨架重写为开发者操作手册

### Removed
- `.github/workflows/ci.yml`（项目 remote 在 Gitee，本地手动 build only）

## [0.4.0] - 2026-06-28

### Added
- 应用显示名「智阅」（Android + Windows 双端同步）
- `flutter_launcher_icons` pipeline（用户 AI 生图 → Android mipmap-* + Windows .ico）
- Android release signing 配置（`keystore.properties` gitignored）
- Android `intent-filter` 注册 `VIEW` epub/pdf（含 4 个 pathPattern 覆盖多重扩展名）
- `BookOpenBridge` Dart bridge（`isSupportedBookPath` / `handlePath` / `init`，10 单测）
- `MainActivity` Kotlin MethodChannel bridge（cold start `popPendingBookPath` + warm start `openBook` + `content://` 拷贝到 cacheDir）
- `main.dart` 接入（`main(List<String> args)` + post-frame callback + `UncontrolledProviderScope`）
- `routerProvider` Riverpod singleton（修 ZhiYueApp.build 每次重建新建 router 反模式）

## [0.1.0] - 2026-06-24

M0 + M1：数据层基础交付（58 测试）。

### Added
- drift SQLite 数据库（`books` / `chapters` / `highlights` / `notes` / `tags` 表）
- FTS5 全文索引（跨书搜索 highlights + notes）
- `BookRepository` + `HighlightRepository` + `NoteRepository` + `TagRepository`
- 文件存储层（`BookStorageService`，分 book/highlight/note 三层目录）
- 应用启动初始化（drift database + ProviderContainer）

## 后续里程碑（无对应版本 tag，但内容已交付）

### M2 (2026-06-26) - EPUB 阅读器
- 30 commits + 179 tests，tag `m2-complete`
- epubx 解析 + 自研渲染（pivot 自 epub_view_plus，因为后者未上 pub.dev）
- EpubRangeLocator + ReaderEngine 接口
- 章节切换 / 进度持久化 / 主题适配

### M3.1 (2026-06-26) - 库 + 导入 + 标签 + 排版
- 28 commits + 295 tests，tag `m3.1-complete`
- LibraryPage（grid + list 双视图）
- BookImportService（EPUB/PDF 自动格式检测）
- 标签系统（多对多 + 拖拽排序）
- 排版预设扩展

### M3.2 (2026-06-27) - 高亮 + 笔记 + 跨书搜索
- 28 commits + 366 tests，tag `m3.2-complete`
- 5 色高亮 + 笔记
- FTS5 跨书搜索 highlights + notes
- 章节分组 drawer

### M3.3 (2026-06-27) - 精确 offset + chapterTitles
- 8 commits + 389 tests，tag `m3.3-complete`
- 精确 offset 定位（不再用 paragraphIndex 粗粒度）
- chapterTitles（章节深链滚动）

### M3.4 (2026-06-27) - per-book NotesPage + Markdown 导出
- 17 commits + 442 tests，tag `m3.4-complete`
- per-book NotesPage
- Markdown 导出（含 frontmatter）
- paged 模式精确滚动
- chapterRevisionNotifier

### M3.5 (2026-06-27) - 设置 / 字体 / i18n / 多预设排版
- 18 commits + 491 tests，tag `m3.5-complete`
- SettingsPage + FontManagementPage
- i18n（中文 + 英文）
- 多预设排版（serif / sans / 自定义）
- chapterSwitchSettled 重构

### M4 (2026-06-28) - PDF 阅读器
- 19 commits + 565 tests，tag `m4-complete`
- pdfrx 2.4.4 集成（MIT，AGPLv3 兼容）
- Page-as-Chapter 映射（PDF 第 N 页 = engine chapterIndex N-1）
- 文本选区高亮
- 扫描 PDF heuristic 检测（前 3 页 < 100 字符判定）
- 主题适配（light/dark/sepia/eInk via ColorFiltered）

### M7 (2026-06-28) - 平台适配
- 13 commits + 575 tests，tag `m7-complete` + `v0.4.0`
- 见 [0.4.0] 段落

## 链接

- [Unreleased]: https://gitee.com/weifu0523/e-book-reading-platform/compare/v1.7.1-alpha...master
- [1.7.1-alpha]: https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.7.1-alpha
- [0.5.0]: https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.5.0
- [0.4.0]: https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.4.0
- [0.1.0]: https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.1.0
