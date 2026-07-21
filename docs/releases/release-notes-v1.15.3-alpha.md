# v1.15.3-alpha

**发布日期**：2026-07-21
**类型**：hotfix（SherpaOnnx 真根因修复）
**上一版本**：v1.15.2-alpha

## 摘要

用户报告 v1.15.0 / v1.15.1 / v1.15.2 SherpaOnnx 朗读一直无声音，v1.15.2 in-app 调试日志暴露决定性证据：

```
[22:02:40.100] generate OK in 932ms samples=48128 sampleRate=44100
[22:02:40.102] speakSentence FAILED:
  MissingPluginException(No implementation found for method create
  on channel xyz.luan/audioplayers)
```

**8 次朗读全失败但 SherpaOnnx FFI generate 完全正常**。真根因：`MainActivity.registerSafePlugins` 列表没有 audioplayers。v1.12.3-alpha 为绕国产 ROM startup kill 手动 curate 的 safe plugin list 跳过了 3 个 audio plugin（audio_service / audio_session / flutter_tts），v1.15.0-alpha 引入 audioplayers 时忘记加回去。

## 真根因诊断流程（systematic-debugging Iron Law 案例）

| 版本 | 修复 | 是否命中真根因 |
|---|---|---|
| v1.15.0-alpha | 首次 SherpaOnnx POC 发布 | N/A（基线） |
| v1.15.1-alpha | audioplayers `onPlayerComplete` → `onPlayerStateChanged` + driveStop 顺序 + 诊断日志 | 否（合理 hypothesis 但 audioplayers plugin 根本没注册，事件根本没机会 emit） |
| v1.15.2-alpha | in-app 调试日志面板 | 否（修复本身，但提供了定位真根因的渠道） |
| **v1.15.3-alpha** | **MainActivity.registerSafePlugins 加 audioplayers** | **是（决定性证据 MissingPluginException）** |

v1.15.1+v1.15.2 改动虽然没命中真根因，但都是**正确的防御性 + 诊断性改动**，v1.15.3 全部保留：
- `onPlayerStateChanged` 比 `onPlayerComplete` 更可靠（多一层保险）
- driveStop 先切 state 让 UI 立即响应（用户意图优先）
- in-app 调试日志是定位本次根因的关键基础设施

## 修复详情

### MainActivity.kt:169 safePlugins 加 audioplayers

```kotlin
val safePlugins: List<Pair<String, () -> Any>> = listOf(
    "audioplayers" to { xyz.luan.audioplayers.AudioplayersPlugin() },  // v1.15.3-alpha 新增
    "connectivity_plus" to { ... },
    ...
)
```

**为何安全**：`AudioplayersPlugin.onAttachedToEngine`（audioplayers_android 4.0.3 源码 `AudioplayersPlugin.kt:45-55`）只做 4 件事：
1. 存 `context` + `binaryMessenger`
2. 创建 `MethodChannel("xyz.luan/audioplayers")`
3. 创建 `MethodChannel("xyz.luan/audioplayers.global")`
4. 创建 `EventChannel("xyz.luan/audioplayers.global/events")` + EventHandler

**完全不绑系统 audio service**（不调 AudioManager / AudioDeviceCallback / TextToSpeech / MediaSession），所以注册此 plugin 不触发 v1.12.3-alpha 想避免的国产 ROM startup kill。系统 audio service 绑定发生在 `AudioPlayer._create` 时（用户触发朗读才调），已 deferred 到 user gesture，满足 Android 12+ user-gesture exemption。

## 测试步骤（用户）

### 测试 1：SherpaOnnx 朗读（核心修复验证）

1. 卸载 v1.15.2-alpha，装 v1.15.3-alpha APK
2. 打开任意中文 EPUB
3. 设置 → 朗读 → 「TTS 引擎（实验）」→ 选 SherpaOnnx MeloTTS
4. 出现 SnackBar「引擎已切换，重启朗读生效」
5. 完全关闭 app，重新打开
6. 长按选中一段文字，点选区弹片的「朗读」按钮
7. **应能听到 SherpaOnnx 女声普通话朗读**（首次启动 1-3 秒延迟，因 asset 拷贝 + ONNX 加载）
8. 朗读完成后 mini control 应自动消失

### 测试 2：mini control 关闭按钮（v1.15.1 修复验证）

1. 触发朗读
2. 朗读中点 mini control「关闭」按钮（× 图标）
3. **应立即消失**

### 测试 3：速率/音量调整

1. 切到 SherpaOnnx 引擎
2. 设置 → 朗读 → 语速 / 音量滑块 → 调整
3. 触发朗读，**应反映调整**

### 测试 4：调试日志（v1.15.2 基础设施验证）

1. 设置 → 朗读 → 「TTS 调试日志」
2. 应看到完整链路：
   ```
   [HH:MM:SS.mmm] speakSentence idx=0 len=N initialized=true
   [HH:MM:SS.mmm] generate OK in Xms samples=N sampleRate=44100
   [HH:MM:SS.mmm] [AudioPlayer] play start samples=N sampleRate=44100 durationMs=N
   [HH:MM:SS.mmm] [AudioPlayer] play() returned, awaiting state
   [HH:MM:SS.mmm] [AudioPlayer] state=PlayerState.playing
   [HH:MM:SS.mmm] [AudioPlayer] state=PlayerState.completed
   [HH:MM:SS.mmm] [AudioPlayer] play done stopped=false
   [HH:MM:SS.mmm] audioPlayer.play returned stopped=false
   ```
3. speakFailCount 应保持 0（v1.15.2 是 8）

### 测试 5：startup 不被国产 ROM kill（v1.12.3 防护验证）

1. 装 v1.15.3-alpha 后冷启动 app
2. **应正常进入 library 页面**（不应闪退回桌面）
3. 如果闪退，说明 audioplayers plugin 在国产 ROM attach-time 仍有问题（极不寻常，源码层已确认无系统 service 绑定）

## 升级路径

直接装 v1.15.3-alpha 覆盖 v1.15.2 或更早版本。

- drift schema v15 不变
- versionCode 2015 > v1.15.2 的 2014
- 默认 TTS 引擎仍是「系统（默认）」

## Breaking Change

无。
