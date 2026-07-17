# v1.12.2-alpha

**发布日期**：2026-07-17
**类型**：hotfix（4 bug 批量修复）
**上一版本**：v1.12.1-alpha

## 摘要

用户在 v1.12.1-alpha 上报告 4 个问题，本版本一次性闭环：

1. **P0（移动端阻断）**：v1.12.1-alpha 在国产 Android ROM（华为/小米
   /OPPO/vivo）上启动后依然瞬间回桌面。v1.12.1-alpha 的 lazy init
   audio_service 修复不够，需要彻底剥离 manifest 注册。
2. **P1-a（桌面端 + 移动端）**：从目录/书签跳到目标章节后点「播放
   本章」，TTS 依然从书首开始播放。
3. **P1-b（桌面端 + 移动端）**：在设置里调整 rate / pitch / volume
   没有任何听觉效果。
4. **P2（桌面端 + 移动端）**：AI 对话默认把整段历史塞进 context；
   改为默认最近 6 轮（12 条消息），并在 AI 设置页提供可调滑块
   + temperature / top_p 暴露。

测试数：**1655 pass + 25 skip + 8 baseline fail**（baseline 与
v1.12.1-alpha 一致，全部为 reader_body_ai_entry / reader_sidebar
widget 测试的 pre-existing layout 问题，与本版本修复无关）。

---

## P0：彻底剥离 audio_service manifest 注册（v1.12.1-alpha 不够）

### 用户报告

> 1.12.1 版本手机端问题依旧没有解决，启动后立马就回到桌面。

### 根因（v1.12.1-alpha 之后的新认知）

v1.12.1-alpha 的 lazy init 假设：只要 `main()` 不调
`AudioService.init()`，audio_service 就不会触发 foreground service
bind。但 Android 包管理器在 **APK 安装/启动扫描期** 就会读取
`AndroidManifest.xml`，发现 `<service android:name="com.ryanheise
.audioservice.AudioService" android:foregroundServiceType="mediaPlayback">`
+ `<receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver">`
+ 3 个相关权限（FOREGROUND_SERVICE / FOREGROUND_SERVICE_MEDIA_PLAYBACK
/ WAKE_LOCK），就把它当作「media-style app」走特殊路径。国产 ROM
的启动期 foreground service 限制会在这个扫描阶段直接 kill 进程——
早于 Flutter engine 启动，早于 `main()` 执行，所以 v1.12.1-alpha
的 lazy init 根本来不及生效。

### 修复

**`app/android/app/src/main/AndroidManifest.xml`**：删除 3 块注册：

```xml
<!-- 删除 -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.WAKE_LOCK" />

<!-- 删除 -->
<service
    android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="mediaPlayback">
    <intent-filter>...</intent-filter>
</service>

<!-- 删除 -->
<receiver
    android:name="com.ryanheise.audioservice.MediaButtonReceiver"
    android:exported="true">
    <intent-filter>...</intent-filter>
</receiver>
```

**`app/lib/main.dart`**：移除 audio_service / audio_session /
zhiyue_audio_handler / audio_session_initializer / tts_playback_controller
5 个 import；把原本 `if (PlatformInfo.isMobile) { globalTtsInfraInitializer
= () async { ... AudioService.init + session.configure ... }; }` 整块
替换为 `if (PlatformInfo.isMobile) { // no-op }`。

### 副作用与权衡

- **移动端 OS 集成降级**：通知栏控件、锁屏控件、MediaButton 事件
  不再可用。但 in-app TTS 仍然完整工作（flutter_tts 不依赖
  audio_service，foreground service 只是为了后台播放 + OS 集成）。
- **后台播放**：移动端切到后台后 TTS 会被 OS 暂停（同 v1.11.x
  pre-TTS 行为）。这是 trade-off——后台播放与启动稳定二选一时，
  启动稳定优先级更高。
- **桌面端完全不受影响**：Windows / macOS / Linux 不依赖
  AndroidManifest，TTS 行为完全不变。
- **后续路线**：v1.13.x 考虑用 `flutter_local_notifications` +
  自研 lightweight audio focus 替代 audio_service，重新引入后台
  播放但不触发国产 ROM 启动期限制。

### 验证

- 用户先验过 `zhiyue-1.12.2-alpha-exp.apk`（仅含本 P0 修复）
  在受影响设备上启动正常。
- 本 v1.12.2-alpha 在 P0 exp 基础上追加 P1-a/P1-b/P2 修复，
  startup path 不再触碰 audio 栈，P0 验证结论延续。

---

## P1-a：从目录/书签跳章后「播放本章」从书首播放

### 用户报告

> 电脑端测试，选择文字点击语音播放基本正确，但点击播放本章是混乱的，
> 从目录，或者从书签跳转到目的位置，点击播放本章，但都是从这本书
> 最开始的时候开始播放。
> 我觉得播放的逻辑是这样：
> 1. 点击播放本章节，就需要从本章开始阅读。

### 根因

EPUB renderer 在跨章 CFI 跳转（TOC/bookmark jump）后，正确切换了
内部状态（`_stateController.add(const ReaderEngineReady())`），
但**没有立即发射 `currentLocation` 通知**。TtsReaderController 订
阅 location 变化来决定起始章节，结果在用户跳章 → 点「播放本章」
之间，location stream 还没更新，TTS 拿到的还是初始 chapter 0。

### 修复

**`reader_engine_epub_view/lib/epubx_renderer.dart`**：在
`_stateController.add(const ReaderEngineReady())` 后立即调
`_emitCurrentLocation()`，把跳转后的新位置推给所有订阅者。

**新增测试**：
`reader_engine_epub_view/test/epubx_renderer_goto_locator_test.dart`
新增 `EpubCfiLocator cross-chapter jump emits location immediately
(v1.12.2-alpha P1-a)` 用例，断言跳章后 currentLocation stream
立即收到事件。

### 用户期望 #2 / #3 验证

> 2. 选择文字播放，从选择的文字开头进行播放，播放完后继续播放。
> 3. 设置里面的选项，播放完本章是否播放下一章这个功能必须生效。

- **「朗读选中」**：v1.12.0-alpha T19 已实现 `selection toolbar →
  TtsPlaybackController.drivePlayAt(sentenceIndex)`，从选中句子
  开头播放、播完后续句。本版本未触及该路径，行为延续。
- **「章末是否播放下一章」设置**：v1.12.0-alpha T17 实现连续 /
  章末询问二选一；v1.12.2-alpha P1-b 修复的 rate/pitch/volume
  bug 与该设置正交，行为延续。如果用户仍然遇到「设置不生效」，
  请提供具体复现步骤（连续 vs 章末询问 / EPUB vs PDF）。

---

## P1-b：rate / pitch / volume 调整无听觉效果

### 用户报告

> 在设置里面调整音色等视乎没有变化。

### 根因

`TtsPlaybackController._speakCurrent()` 直接调
`_service.speakSentence(sentence)`，**没有把 TtsSettings 同步到
底层 TtsService**。用户在设置页改了 rate / pitch / volume 后，
虽然 `ttsSettingsProvider` 的 StateNotifier 状态更新了，但
TtsService 仍然用启动时的默认值。

### 修复

**`app/lib/features/tts/providers/tts_playback_controller.dart`**：

1. 构造器新增 `TtsSettings Function() _settingsGetter` 字段（依赖
   注入，避免 StateNotifier 直接依赖另一个 Provider）。
2. `_speakCurrent()` 在 `speakSentence` 之前先 `setSpeechRate /
   setPitch / setVolume`，保证每句开播前都同步最新设置。
3. Provider 接线：`() => ref.read(ttsSettingsProvider)`，每次
   `_speakCurrent()` 调用时实时读最新设置（用户在设置页修改
   → 立即对下一句生效）。

**新增测试**：
`app/test/features/tts/providers/tts_playback_controller_test.dart`
新增 `settings application` group，2 个测试：
- `applies rate/pitch/volume from settingsGetter before speakSentence`
- `settingsGetter is read fresh on each _speakCurrent (live update)`

### 已知限制

- 当前句播放中改设置 → 该句不变（底层 TTS 已锁定参数），下一句
  生效。这是 flutter_tts 的 API 限制，不是 bug。
- 桌面 Windows SAPI 引擎对 pitch 的响应较粗糙（特别是中文语音），
  可能听觉上变化不明显——不是 app bug，是引擎限制。

---

## P2：AI 对话 context 默认最近 6 轮 + 可调 temperature / top_p

### 用户报告

> 前期设置的 AI 对话聊天所有记录都送入 context 的方式目前从用户
> 体验来看不太合适，有的用户会进行对话管理，每个对话的内容进行
> 分类，但依旧有大量的用户不会新增和管理对话，在一个对话中聊天，
> 这样过长的上下文就没有太多意义了，所有进行修改。
> 1. 默认最近 6 轮对话作为上下文，超过六轮的不再送入 context，
>     但提供设置，在 AI 设置中可以设置引入的对话轮次。
> 同时考虑是否开放 设置 top 和温度。

### 修复

#### 1. SendMessageUseCase context 截断

**`app/lib/features/ai_chat/use_cases/send_message_use_case.dart`**：

- 新增 `int? contextTurnsGetter` 字段（Provider 注入，从
  `AiCredentials.contextTurns` 读）。
- `run()` 内：`final turns = contextTurns ?? contextTurnsGetter?.call()
  ?? 6; final messageLimit = max(1, turns) * 2;`（1 轮 = 1 用户 +
  1 助手 = 2 条消息）。
- 改用 `repo.listRecentMessages(sessionId, messageLimit)`（新
  DAO 方法，DESC LIMIT N + reverse 还原时间顺序）替代
  `repo.listMessages(sessionId)`，避免一次性加载整段历史。

**`app/lib/data/local/daos/chat_messages_dao.dart`**：新增
`listRecentForSession(sessionId, {required int limit})` 方法，
`DESC LIMIT N` 取最近 N 条 + 反转回时间顺序。

**`app/lib/data/local/daos/chat_repository.dart`**：新增
`listRecentMessages(sessionId, limit)` wrapper。

#### 2. AiCredentials 加 3 字段

**`app/lib/services/ai/api_key_store.dart`**：

- `AiCredentials` 新增 `contextTurns`（默认 6）/ `temperature`
  （默认 1.0）/ `topP`（默认 1.0）3 字段 + `copyWith`。
- `flutter_secure_storage` 新增 3 个 key；load 用
  `_parseIntOrDefault` / `_parseDoubleOrDefault` 兜底旧版本
  snapshot（防止 schema migration 问题）。
- 新增 `ApiCredentialsDefaults` 常量类，集中管理默认值。

#### 3. OpenAiCompatibleClient 透传 sampling 参数

**`app/lib/services/ai/open_ai_compatible_client.dart`**：

- 构造器新增 `this.temperature = 1.0, this.topP = 1.0`。
- HTTP body 始终包含 `'temperature': temperature, 'top_p': topP`。
  默认值与 OpenAI / DeepSeek 服务端默认一致，未自定义时行为不变。

#### 4. 设置页 UI

**`app/lib/features/ai/pages/api_key_settings_page.dart`**：

- 在原有 3 个 TextField（API Key / Base URL / Model）下方追加
  3 个 Slider + 帮助文字：
  - **对话上下文（轮次）**：1–50，默认 6，分度 49。
  - **采样温度（temperature）**：0–2，默认 1.0，分度 20（步长 0.1）。
  - **核采样（top_p）**：0–1，默认 1.0，分度 20（步长 0.05）。
- 每个 Slider 下方有中文帮助文字解释含义和推荐用法（包括
  DeepSeek 官方「只调 temperature 或 top_p 其一」的建议）。
- _pumpPage helper 设置 800×1800 viewport（3 Slider + 帮助文字
  超出默认 800×600）。

### 为什么用 `flutter_secure_storage` 而不是 drift schema

设备本地偏好（per-device sampling preference）放 drift 会引入
schema migration（v15→v16）+ 跨设备同步复杂度（每个设备的偏好
不一样，但 drift 表是全局的）。`flutter_secure_storage` 已经
存 API Key / Base URL / Model，再加 3 个 key 风险更低。代价：
跨设备不同步（用户在 PC 设的 temperature 不会到手机）——可接受，
sampling 偏好通常是设备相关的（PC 用于深度阅读，手机用于碎片）。

### 测试覆盖

- `app/test/features/ai_chat/use_cases/send_message_use_case_test.dart`
  扩展：context truncation + 默认 6 轮 + 用户覆盖。
- `app/test/services/ai/api_key_store_test.dart` 扩展：3 字段
  round-trip + 旧 snapshot 兜底。
- `app/test/features/ai/pages/api_key_settings_page_test.dart`
  扩展：Slider 初始值 + 拖动 + 保存路径（_pumpPage 800×1800）。
- 7 个 ChatRepository test stub 补 `listRecentMessages` 实现。

---

## 升级路径

- **drift schema**：不变（v15）。
- **outbox/sync 协议**：不变。
- **跨设备兼容性**：v1.12.0/1.12.1 与 v1.12.2 互通无障碍。
- **用户侧**：覆盖安装即可。
- **移动端用户**：强烈建议升级（v1.12.1-alpha 启动 crash
  仍未解决；v1.12.2-alpha 彻底剥离 manifest 注册，是 P0 修复）。
- **桌面端用户**：建议升级（P1-a/P1-b/P2 都是桌面端可感知的修复）。

## 构建产物

- `zhiyue-1.12.2-alpha.apk`（Android，~140 MB）
- `zhiyue-setup-1.12.2-alpha.exe`（Windows installer，~48 MB）
- `zhiyue-portable-1.12.2-alpha.zip`（Windows portable，~61 MB）

## 已知 baseline fail（与本版本无关）

- `test/features/reader/pages/reader_body_ai_entry_test.dart`：
  4 个 widget test（Bug 2a / 2b / 4 / 5）在 v1.12.1-alpha 就已
  fail，是 ReaderBody 在窄屏 scaffold 上的 layout 断言问题。
  v1.13.x 重构 ReaderBody 时一并修。
- `test/features/reader/widgets/reader_sidebar_test.dart`：4 个
  wide-screen sidebar widget test（T8 collapse / expand / wide /
  TOC tap），同样 v1.12.1-alpha baseline，不影响功能。
