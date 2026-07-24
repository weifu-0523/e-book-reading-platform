# v1.16.2-alpha: OPPO/小米 系统默认 TTS 初始化失败反馈

## Context

用户报告 OPPO 和小米手机系统默认 TTS 没声音，设置页测试也无反应。诊断日志关键证据：

```
[1784595576939] TTS init callback status=-1     ← 5ms 内立即失败
[1784595576940] TTS init FAILED status=-1
[1784595576965] handleSpeak DEFER: tts not ready (initStatus=-1), queuing intent
[1784596309182] onCreate start (companion state reset: ttsInitStatus=-999)   ← 重启 service 后还是失败
[1784596309184] TTS init callback status=-1
[1784596309201] handleSpeak DEFER: tts not ready (initStatus=-1), queuing intent
```

11 个 SPEAK intent 全部静默 deferred，Dart 完全不知道 init 失败。荣耀/老华为（EMUI/MagicOS，鸿蒙 6 前）正常 → 排除 Android 原生 `TextToSpeech` API 本身问题，定位为 **OPPO ColorOS / 小米 MIUI ROM 特定行为**。

## Root Cause（候选，按可能性）

| # | 候选 | 备注 |
|---|---|---|
| 1 | ROM 限制 foreground service 内绑定 system TTS service | 5ms 立即失败特征支持此假设 |
| 2 | OPPO/小米默认 TTS 引擎（iflytek/ColorOS 自带）对 FGS init 不友好 | 荣耀/华为默认引擎是 peiyin，差异点 |
| 3 | 用户未在 ROM「自启动管理」授权 app | 国产 ROM 通病 |

无法直接调试用户设备 ROM，**修复目标不是消除根因**（ROM 层面，app 内无解），而是：
1. **让用户知道发生了什么**（当前完全静默）
2. **引导用户自救**（打开系统 TTS 设置 / ROM 自启动授权）
3. **轻量尝试绕过**（applicationContext + 1 次重试）

## Approach

### Part A（必做）：init 失败 emit error 事件到 Dart + UI SnackBar

**Kotlin** (`ZhiYueTtsService.kt:236-239` 当前 `else` 分支)：

```kotlin
} else {
    debugLog("TTS init FAILED status=$status")
    Log.e(TAG, "TextToSpeech init failed status=$status")
    if (!ttsInitRetryAttempted) {
        ttsInitRetryAttempted = true
        debugLog("scheduling TTS init retry in 500ms with applicationContext")
        Handler(Looper.getMainLooper()).postDelayed(500) {
            tts?.shutdown()
            tts = TextToSpeech(applicationContext, ttsInitListener!!)
        }
    } else {
        debugLog("TTS init retry exhausted, emitting init_error to Dart")
        emit(mapOf(
            "event" to "init_error",
            "status" to status,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL
        ))
    }
}
```

新增 companion field：
- `ttsInitRetryAttempted: Boolean = false`（每次 onCreate 重置，跟 v1.13.9 模式一致）

**Dart** (`self_built_tts_service.dart:120 switch(type)`)：

```dart
case 'init_error':
    final status = map['status'] as int?;
    final manufacturer = map['manufacturer'] as String? ?? 'unknown';
    _errorController.add(
        '系统 TTS 初始化失败（status=$status, device=$manufacturer）'
    );
    break;
```

### Part B（必做）：UI 监听 error stream 显示引导 SnackBar

`tts_settings_section.dart` 的「测试朗读」按钮 listener 已经监听 `service.error`（如果不存在就加）：

SnackBar 内容：
```
系统 TTS 引擎初始化失败
OPPO/小米请检查：
① 系统设置 → 应用 → 智阅 → 允许自启动
② 系统设置 → 语言和输入法 → 文字转语音输出 → 切换引擎
[打开系统 TTS 设置] [知道了]
```

- 「打开系统 TTS 设置」按钮调 `service.openSystemTtsSettings()`（已有 API）
- 「知道了」按钮 dismiss

### Part C（轻量 B）：applicationContext + 500ms 重试 1 次

详见 Part A 的 retry 分支：
- 用 `applicationContext` 替代 `this`（Service context）—— 部分国产 ROM 对 service context 绑定 system service 有限制
- 500ms 后重试 1 次（不无限，避免循环 bind 失败 spam 日志）
- 重试用同一个 `ttsInitListener` field（v1.13.8 引入的可测 listener 模式）

50% 概率无效（5ms 失败更像同步 bindService 拒绝，不像 timing race），但代码成本低（~20min）、不破坏现有 v1.13.8 init race 修复。

## Key Decisions

| ID | 决策 | 理由 |
|---|---|---|
| D1 | retry 用 `applicationContext` 而非 `this` | 国产 ROM 对 service context 绑定 system TTS service 可能有限制，applicationContext 是 app 全局 context，限制宽松。若仍失败 fallback 到 emit error |
| D2 | 只重试 1 次 | 避免无限循环 + 日志 spam；500ms 给 ROM 启动期 race 留时间 |
| D3 | `ttsInitRetryAttempted` 在 onCreate 顶部重置 | 沿用 v1.13.9 模式（companion field 跨实例共享，必须在 onCreate 重置） |
| D4 | emit `init_error` 而非现有 `error` 事件 | 现有 `error` 事件是 utterance-level（朗读中出错），init_error 是 service-level（启动期出错），语义不同；UI 侧处理也不同（init_error 显示引导，error 显示重试） |
| D5 | SnackBar 触发时机：error stream emit 时立即 | 不区分用户是否主动触发朗读——init_error 是 service-level，只发生一次，不会重复 spam |
| D6 | 不做 ROM 检测 + 自动跳转自启动 Intent | 方案 C 工作量过高（每个 ROM Intent 路径每个版本不同，维护成本高），openSystemTtsSettings 已覆盖大部分用户教育需求。遵守 feedback_tts_is_auxiliary |
| D7 | 不自动 fallback 到 sherpaOnnx 或 cloud TTS | 当前架构是 system/sherpaOnnx/cloud 三选一，自动切换会让用户困惑（点了 system 却跑 sherpaOnnx）；用户应显式切换 |

## Files

- `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt` — Kotlin init listener + retry
- `app/lib/services/tts/self_built_tts_service.dart` — Dart `_handleEvent` 加 `init_error` case
- `app/lib/features/settings/pages/tts_settings_section.dart` — SnackBar 监听 + 引导文案 + 打开系统设置按钮
- `app/test/features/settings/pages/tts_settings_section_test.dart` — widget test 验证 error stream → SnackBar
- `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceTest.kt` — Kotlin unit test 验证 retry + emit init_error
- `app/test/services/tts/self_built_tts_service_test.dart` — Dart unit test 验证 MethodChannel `init_error` → error stream
- `CHANGELOG.md` — v1.16.2-alpha entry（Python binary-safe 替换）
- `app/pubspec.yaml` — `1.16.1-alpha+2020` → `1.16.2-alpha+2021`
- `app/windows/installer/zhiyue.iss` — `MyAppVersion "1.16.1-alpha"` → `"1.16.2-alpha"`
- `docs/releases/release-notes-v1.16.2-alpha.md` — 新建

## Test Strategy

| 层 | 测试 | 数量 |
|---|---|---|
| Kotlin 单元 | (1) init status=-1 → schedule retry; (2) retry 后仍失败 → emit init_error event + verify manufacturer 字段; (3) retry 成功 → 不 emit init_error; (4) ttsInitRetryAttempted 跨 onCreate 重置 | 4 |
| Dart 单元 | (1) _handleEvent 收到 `init_error` → error stream emit; (2) status/manufacturer 字段透传 | 2 |
| Widget | tts_settings_section 监听 error stream 后 SnackBar 显示 + 「打开系统 TTS 设置」按钮可见 + 点击调 openSystemTtsSettings | 1 |

总计：**7 新测试**，预期基线 277 pass + 7 新 = 284 pass / 0 fail。

## Out of Scope

- ROM 检测 + 自动跳转自启动 Intent（方案 C）
- 自动 fallback 到 sherpaOnnx 或 cloud TTS（架构耦合，feedback_tts_is_auxiliary 否决）
- 检测默认 TTS 引擎并提示切换（需要 query `Settings.Secure.TTS_DEFAULT_SYNTH` 等 ROM-specific API）
- WebSocket bidirectional streaming（feedback_tts_is_auxiliary 否决）
- sherpaOnnx UI 改进（v1.15.4-alpha 已做）

## Verification

1. **Dart 单元**：`cd C:\zhiyue_build_s3/app && flutter test test/services/tts/ test/features/settings/ test/features/tts/`
2. **Kotlin 单元**：`cd C:\zhiyue_build_s3/app/android && ./gradlew :app:testWithFgsDebugUnitTest`
3. **静态分析**：`dart analyze lib/services/tts lib/features/settings`
4. **APK marker 验证**：libapp.so MD5 ≠ v1.16.1（确认 Dart 改动进 so）
5. **真机验证（用户）**：
   - 场景 A：OPPO/小米点击「测试朗读」→ 看到 SnackBar「系统 TTS 初始化失败」+ 「打开系统 TTS 设置」按钮 → 点按钮跳转系统设置
   - 场景 B：切换 TTS 引擎到 Google 后回来 → 重启 app → 测试朗读成功（验证候选 #2 是否为真根因）
   - 场景 C：荣耀/华为不出现 SnackBar（确保正常设备不误报）

## Version

- pubspec: `1.16.2-alpha+2021`
- tags: `v1.16.2-alpha` + `m-oppo-xiaomi-tts-init-feedback`
- 工作量预估：3-4h（设计 + 实施 + 测试 + release）
