# v1.12.3-alpha

**发布日期**：2026-07-17
**类型**：hotfix（v1.12.2-alpha 未发布的 P0 重做 + 已闭环的 P1/P2）
**上一版本**：v1.12.1-alpha（v1.12.2-alpha 仅 commit 未 tag，因 P0 修复失败）

## 摘要

v1.12.2-alpha 在 release prep 阶段就发现 P0 修复无效（删 manifest
注册不够），随即又做了 2 次 P0 修复尝试（pub-cache patch / custom
MainActivity），第 4 次才真正闭环。本版本：

1. **P0（移动端阻断）**：custom MainActivity 跳过 audio plugin 注册，
   4 次尝试后真正修复，用户真机验证 2026-07-17 通过。
2. **P1-a + P1-b + P2**：与 v1.12.2-alpha commit 一致，详见下文。

测试数：**1655 pass + 25 skip + 8 baseline fail**（baseline 与
v1.12.1-alpha 一致，全部为 reader_body_ai_entry / reader_sidebar
widget 测试的 pre-existing layout 问题，与本版本修复无关）。

---

## P0：custom MainActivity 跳过 audio plugin 注册（4 次尝试后真正修复）

### 用户报告

v1.12.0-alpha 引入 audio_service + audio_session + flutter_tts 后，
国产 ROM（华为 / 小米 / OPPO / vivo / Honor，Android 12+）打开 app
瞬间回桌面，无法操作。无 Dart 堆栈，try/catch 兜不住。v1.11.9-alpha
（pre-TTS）在同设备正常 → 消去法指向 audio 三件套。

### 4 次修复尝试

| # | 版本 | 策略 | 结果 | 失败原因 |
|---|---|---|---|---|
| 1 | v1.12.1-alpha | lazy init audio_service 在 `main()` 内（首次播放才初始化） | 失败 | plugin 的 `onAttachedToEngine` 在 `GeneratedPluginRegistrant.registerWith` 阶段（早于 `main()`）就绑定 system service，lazy guard 永远不触发 |
| 2 | v1.12.2-alpha-exp1 | 删 audio_service 的 `<service>` / `<receiver>` / 3 个权限的 manifest 注册 + 移除 main.dart 5 个 audio import | 失败 | manifest 不是 ROM kill 的触发点，plugin 的 `onAttachedToEngine` 内的 `new TextToSpeech(...)` / `AudioManager.registerAudioDeviceCallback(...)` 才是 |
| 3 | v1.12.3-alpha-exp2 | patch pub-cache：把 flutter_tts 的 `TextToSpeech` 构造推迟到首次 method call + 把 audio_session 的 `AudioDeviceCallback` 注册推迟到首次 `requestAudioFocus` | 失败 | audio_service plugin 自己的 attach-time work 没被 patch 到；pub-cache patch 不可持续 + 三方 plugin 有多个 init 路径，逐个 patch 是必输的游戏 |
| 4 | **v1.12.3-alpha-exp3（本版）** | `MainActivity.kt` 不调用 `super.configureFlutterEngine`（避免 `GeneratedPluginRegistrant.registerWith` 自动注册全部 17 个 plugin），改为 hand-curate 14 个安全 plugin，**完全跳过 audio_service / audio_session / flutter_tts** | **成功** | 直接从 registration 层 block，绕开所有 attach-time work |

### 用户真机验证（2026-07-17）

荣耀、小米、华为（4.2 之前非鸿蒙）三台设备均报告：app 正常启动，
不再瞬间回桌面。

### 教训（已记入 memory）

> **不要试图 patch 第三方 plugin 内部（pub-cache patch 不可持续 +
> 每个 plugin 有多个 init 路径），应在 plugin registration 层
> block。**

这个教训适用于任何"plugin attach-time work 引发宿主兼容问题"的
场景。具体到本案例：flutter_tts / audio_session / audio_service
三个 plugin 各有自己的 attach-time system binding（TextToSpeech
ctor / AudioDeviceCallback / foreground service bind），逐个 patch
是 3 倍工作量且永远 miss 新版本可能新增的 init 路径。registration
层 block 是 O(1) 维护成本。

### 关键文件

- `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/MainActivity.kt`
  - 新增 `registerSafePlugins(flutterEngine)` 私有方法
  - `configureFlutterEngine` 不再调用 super，改为调
    `registerSafePlugins`
  - hand-curate 14 个安全 plugin 的注册列表（mirror
    `GeneratedPluginRegistrant.registerWith` 但跳过 3 个 audio
    plugin）
  - 顶部 Kotlin doc 注释完整记录 4 次尝试 + 教训 + trade-off + v1.13
    路线图
- `scripts/patch_pub_cache_tts_plugins.py`（exp2 阶段添加，本版
  **已删除**，因为不再需要 patch pub-cache）

### Trade-off（必须接受）

| 功能 | v1.11.9-alpha | v1.12.0/1/2-alpha | **v1.12.3-alpha** | v1.13（计划） |
|---|---|---|---|---|
| Android app 启动 | ✅ | ❌（crash） | ✅ | ✅ |
| Android TTS 朗读 | — | ❌（启动 crash） | ❌（UI 在但无效） | ✅ |
| Android 通知栏控件 | — | ❌（启动 crash） | ❌ | 部分恢复 |
| Android 锁屏控件 | — | ❌（启动 crash） | ❌ | 部分恢复 |
| Android 后台播放 | — | ❌（启动 crash） | ❌ | 部分恢复 |
| 桌面端 TTS | — | ✅ | ✅ | ✅ |

**Android 用户从 v1.11.9-alpha 升级到 v1.12.3-alpha 后**：
- ✅ 不再启动 crash
- ✅ AI 对话 / 同步 / 阅读等所有非 TTS 功能正常
- ❌ TTS 朗读按钮点击无效果（v1.13 恢复）
- ❌ 通知/锁屏/后台播放不可用（v1.13 部分恢复）

### v1.13 路线图（自研 TTS plugin）

放弃 audio_service + audio_session + flutter_tts 三件套，自研：

1. **Android 端**：原生 Kotlin `TextToSpeech` 封装为 MethodChannel
   plugin，**完全控制 init timing**——只在用户首次按「朗读」时（user
   gesture）构造 `TextToSpeech`，attach-time 不做任何事。
2. **iOS 熟**：`AVSpeechSynthesizer` 同样封装为 MethodChannel。
3. **后台播放/通知**：用 `flutter_local_notifications`（无 foreground
   service 依赖）+ 自管 wakelock，绕开 audio_service 的 foreground
   service bind 路径。
4. **跨设备位置同步**：保留 drift schema v15 的
   `books.last_tts_position` 列，不变。

预期 v1.13 在 2026-07 下旬交付。

---

## P1-a：「播放本章」跳章后从书首播放

### 用户报告

从目录/书签跳到目标章节后，点「播放本章」，TTS 依然从书首开始播放，
而不是当前章节。

### 根因

EPUB renderer 跨章 CFI 跳转（TOC/bookmark jump）后正确切换了内部
state，但没立即发射 `currentLocation` 通知。TtsReaderController 订阅
location 变化来决定起始章节，跨章跳转后拿到的是初始 chapter 0。

### 修复

`epubx_renderer.dart` 在 `_stateController.add(ReaderEngineReady())`
后立即调 `_emitCurrentLocation()`，保证 listener 收到 ready 事件时
location 也已更新。

新增测试：cross-chapter jump emits location immediately。

---

## P1-b：rate / pitch / volume 设置无听觉效果

### 用户报告

在设置里调整 rate（语速）/ pitch（音调）/ volume（音量）后，朗读
出来没有任何变化。

### 根因

`TtsPlaybackController._speakCurrent()` 直接调 `speakSentence`，没有
把 TtsSettings 同步到底层 TtsService。`flutter_tts` 的设置必须在
speak 之前 apply 才生效。

### 修复

1. 构造器加 `TtsSettings Function() _settingsGetter` 字段（依赖
   注入，避免 StateNotifier 直接依赖另一个 Provider）。
2. `_speakCurrent` 在 `speakSentence` 之前调 `setSpeechRate` /
   `setPitch` / `setVolume`。
3. Provider 接 `() => ref.read(ttsSettingsProvider)`，每次开播实时
   读最新设置。

**已知限制**：当前句播放中改设置 → 下一句生效（flutter_tts API
限制，无法在 utterance 中途改设置）。

新增测试：2 个 settings application tests + tts_reader_controller_test
补 3 个 stub（setSpeechRate/Pitch/Volume）。

---

## P2：AI 对话默认最近 6 轮 context + 可调 temperature / top_p

### 用户报告

AI 对话默认把整段历史塞进 LLM context，长会话用户成本/延迟双高。
此外希望暴露 temperature / top_p 等采样参数。

### 修复

1. **SendMessageUseCase 截断**：加 `contextTurnsGetter` 字段，`run()`
   内 `max(1, turns) * 2` 截断消息数，改用
   `repo.listRecentMessages(sessionId, limit)` 替代 `listMessages`。
2. **ChatMessagesDao.listRecentForSession**：新方法（DESC LIMIT N +
   reverse 模式，避免一次性 listMessages）。
3. **AiCredentials 加 3 字段**：`contextTurns`（默认 6）/
   `temperature`（默认 1.0）/ `topP`（默认 1.0），存
   `flutter_secure_storage` 不走 drift schema（设备本地偏好，跨设备
   不同步反而合适）。
4. **OpenAiCompatibleClient 透传**：构造器把 sampling 参数塞进 HTTP
   body（始终带，未自定义时 1.0/1.0 与服务端默认一致）。
5. **api_key_settings_page.dart**：加 3 个 Slider + 中文帮助文字；
   `_pumpPage` helper 设 800×1800 viewport 容纳新增 UI。
6. **测试 stub**：7 个 `implements ChatRepository` 的 test stub 补
   `listRecentMessages` 实现（mirror `listMessages` + sublist last N）。

### 默认值

- `contextTurns = 6`（即最近 12 条消息）
- `temperature = 1.0`（API 服务端默认）
- `topP = 1.0`（API 服务端默认）

未自定义时行为与 v1.12.1-alpha 完全一致。

### 跨设备兼容性

新字段仅存在内存 + secure storage，**recordBook payload 不变** →
v1.12.0/1.12.1 与 v1.12.3 互通无障碍。后续 drift schema v15→v16
时再考虑是否同步 sampling 偏好。

---

## 升级指南

### Android 用户

**强烈建议立即升级**。v1.12.0–v1.12.2-alpha 在国产 ROM（华为/小米
/OPPO/vivo/Honor）上启动 crash，无法使用。v1.12.3-alpha 真正修复。

升级后：
- ✅ 正常启动，所有非 TTS 功能可用
- ❌ TTS 朗读按钮点击无效果（v1.13 恢复）

如需 TTS，**暂时回到桌面端使用**，或等 v1.13（预期 2026-07 下旬）。

### 桌面端用户（Windows）

**建议升级**。P1-a / P1-b / P2 都是可感知改进：
- 「播放本章」跳章后从正确位置播放
- rate / pitch / volume 设置生效
- AI 对话默认 6 轮 context，可在 AI 设置页调整 + temperature / top_p

### 数据库

- **不变**（drift schema 仍 v15）。
- 覆盖安装即可，无需迁移。

---

## 测试

- 总数：**1655 pass + 25 skip + 8 baseline fail**
- baseline 8 个 fail 全部为 reader_body_ai_entry / reader_sidebar
  widget 测试的 pre-existing layout 问题，与 v1.12.1-alpha baseline
  一致，与本版本修复无关。
- 新增测试（v1.12.2-alpha 阶段已 commit，本版本继承）：
  - P1-a：cross-chapter jump emits location immediately
  - P1-b：2 个 settings application tests + tts_reader_controller_test
    3 个 stub
  - P2：api_key_settings_page 3 Slider + 7 个 ChatRepository stub

---

## 已知限制

1. **Android TTS no-op**：UI 按钮在但点击无效果。v1.13 自研
   MethodChannel plugin 恢复。
2. **Android OS 集成缺失**：通知栏控件 / 锁屏控件 / MediaButton /
   后台播放都不可用。v1.13 部分恢复。
3. **Hand-curated plugin registration 维护成本**：每次升级 Flutter
   或新增 plugin，`MainActivity.kt` 的 `registerSafePlugins` 列表
   都要手动同步（mirror `GeneratedPluginRegistrant.registerWith`
   减去 3 个 audio plugin）。Mismatches 表现为 runtime "channel not
   registered" 错误，不是 crash。v1.13 自研 plugin 后可恢复 super
   call。
4. **TTS rate/pitch/volume mid-utterance 不可改**：当前句播放中改
   设置 → 下一句生效（flutter_tts API 限制）。
5. **AI contextTurns/temperature/topP 不跨设备同步**：设备本地偏好，
   存 flutter_secure_storage 不走 drift schema。

---

## 致谢

感谢用户在 4 次 P0 修复失败后依然耐心验证并提供真机反馈。这次
经验记入项目 memory，作为"3+ 次失败必须 question architecture"
的典型案例——第 4 次 custom MainActivity 的成功正是因为质疑了
"必须保留 audio_service 依赖"这个隐含假设。
