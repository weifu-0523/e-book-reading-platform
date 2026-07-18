# v1.13.1-alpha

**发布日期**：2026-07-18
**类型**：hotfix（Android TTS 无声）
**上一版本**：v1.13.0-alpha

## 摘要

修复 v1.13.0-alpha 在国产 Android ROM（确认设备：荣耀）上安装后启动不 crash、但点「朗读」无声无通知的严重 bug。

根因：`ttsServiceProvider` 硬编码 `FlutterTtsServiceImpl()`，没用 v1.13 新写的 `createTtsService()` factory → 移动端调的是 `flutter_tts` MethodChannel，而 MainActivity 跳过 flutter_tts 注册（v1.12.3-alpha 解 startup crash 的方案） → 所有调用静默 throw `MissingPluginException` 被 catch 吞 → SelfBuiltTtsServiceImpl 从未被实例化。

附带：加 in-app 「TTS 调试日志」按钮，让没装 adb 的用户也能截图反馈 plugin/service 状态。

---

## 用户报告

> 好消息 zhiyue-1.13.0-alpha-with-fgs.apk 安装它没有退出，可以正常使用。坏消息在移动端测试没有声音输出。正文朗读选中，或者AI回答朗读都没有声音出来。

设备：荣耀手机，首选 TTS 引擎「荣耀 AI 语音引擎」+「荣耀语音引擎」，系统 TTS 试听有声音。

## 根因（systematic-debugging Phase 1）

### 排除候选

| 候选 | 证据 | 结论 |
|---|---|---|
| TTS init race（H1） | 没有 logcat 看不到 init callback | 无法证伪但不是首要 |
| TTS engine 缺失（H2） | 用户报告系统 TTS 试听有声音 | **排除** |
| locale 不支持（H3） | 系统试听中文有声音 | **排除** |
| 通知 channel 禁用（H5） | 用户报告没出现通知 | service 没启动，不是通知问题 |
| Manifest 合并失败（H7） | merged_manifests/withFgsRelease 有完整 service + permission + receiver | **排除** |
| MainActivity 漏注册 plugin（H8） | MainActivity.kt:116 明确注册 `"zhiyue_tts"` | **排除** |

### 真正根因

`tts_playback_controller.dart:101`：

```dart
final ttsServiceProvider = Provider<TtsService>((ref) {
  final svc = core.globalTtsServiceOverride ?? FlutterTtsServiceImpl();  // ← BUG
  ref.onDispose(svc.dispose);
  return svc;
});
```

v1.13 写了 `createTtsService()` factory（`services/tts/tts_service_factory.dart`）做平台分发，但**整个项目没有任何地方调用它**。`ttsServiceProvider` 硬编码 `FlutterTtsServiceImpl()`，所以 Android 也走 `flutter_tts` MethodChannel。

数据流（broken）：
```
UI 点「朗读」
  → TtsPlaybackController._speakCurrent
    → FlutterTtsServiceImpl.speakSentence
      → MethodChannel('flutter_tts').invokeMethod('speak', ...)
        → ❌ flutter_tts plugin 未注册（MainActivity 跳过）
          → throw MissingPluginException
            → 被 _speakCurrent 第 365 行 catch 吞
              → state.errorMessage 进了但 UI 不显示
                → 用户看到「无声无通知不 crash」
```

完整证据链：
- 用户装的是 withFgs release APK（merged manifest 正确）
- MainActivity 注册了 `"zhiyue_tts"` plugin（`onAttachedToEngine` 应该被调用）
- 但 Dart 端 `ttsServiceProvider` 用 `FlutterTtsServiceImpl`（不走 zhiyue_tts channel）
- flutter_tts plugin 没注册（MainActivity 故意跳过）
- MissingPluginException 被 catch 吞

## 修复（1 行 + 1 import）

```dart
// before
final svc = core.globalTtsServiceOverride ?? FlutterTtsServiceImpl();

// after
final svc = core.globalTtsServiceOverride ?? createTtsService();
```

加 `import '../../../services/tts/tts_service_factory.dart';`，删 unused `flutter_tts_service.dart` import。

Android → SelfBuiltTtsServiceImpl → MethodChannel `dev.zhiyue.tts` → ZhiYueTtsPlugin → ZhiYueTtsService（自研，onCreate 拿到 TextToSpeech + startForeground）。桌面/iOS → FlutterTtsServiceImpl（保留）。

## 额外：in-app 调试日志

设置 → TTS 设置 加「TTS 调试日志」按钮（`tts_settings_section.dart`）。点开后 dialog 显示 plugin + service 内部状态：

```
=== Plugin ===
attached         : true
isServiceCreated : true
initCallCount    : 1
speakCallCount   : 1
lastStartError   : (none)

=== Service onCreate ===
completed         : true
exception         : (none)
startForegroundOk : true

=== TTS engine ===
initStatus       : 0 (-999=未回调, 0=SUCCESS, -1=ERROR)
lastSpeakReturn  : 0 (0=success, -1=error)

=== onStartCommand ===
count            : 1
lastAction       : dev.zhiyue.tts.SPEAK
utteranceCallbacks: [onStart:sent_0]

=== Service debugLogs ===
[1752840123456] onCreate start
[1752840123457] before TextToSpeech ctor
...
```

用户截图即可，无需 adb / logcat。

## 测试

- analyze：103 issues（info/warning，无 error；pre-existing）
- Dart test：见 CHANGELOG / commit message（跑全量回归）
- Kotlin test：本 hotfix 没改 Kotlin 代码逻辑（只加 debug instrumentation），20 + 20 测试照过
- 真机验证：用户在荣耀手机装 `zhiyue-1.13.1-alpha-with-fgs.apk`，点「朗读」应有声音 + 出现「智阅朗读」通知

## 教训

1. **写完 factory 必须验证调用点**：`createTtsService()` 写得再漂亮，没人调用就是 dead code。下次写完 factory 立即 grep 一遍 `createTtsService(`。
2. **两阶段 review 抓不到端到端 platform dispatch**：subagent 测试都用 FakeTtsService 注入，不走真实 factory。下次 platform-dependent 代码必须有 "smoke test"：实际跑 `createTtsService()` 然后断言返回类型。
3. **silent catch 是双重危害**：`_speakCurrent` 第 365 行 catch 把 MissingPluginException 吞了，error 进 state.errorMessage 但 UI 不显示。下次：所有 catch 必须要么 rethrow，要么 surface 到 UI（Snackbar / dialog）。

## 升级路径

直接装 `zhiyue-1.13.1-alpha-with-fgs.apk` 覆盖 v1.13.0-alpha。无 schema 变化（drift v15），无 setting migration。

如果 v1.13.1-alpha 仍然无声，进 设置 → TTS 设置 → 「TTS 调试日志」截图反馈。

---
