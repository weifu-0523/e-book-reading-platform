# v1.13.3-alpha

**发布日期**：2026-07-18
**类型**：hotfix（Android TTS 多句只读一句 — v1.13.2 修复无效后的真根因）
**上一版本**：v1.13.2-alpha

## 摘要

v1.13.2-alpha 修了**错误的根因**——加的 Dart 端 `case 'done'` 代码本身没错，
但事件根本到不了 Dart，所以 fix 完全无效。

用户真机调试日志（Settings → TTS section → 「TTS 调试日志」）揭示了真相：

```
=== Service onCreate ===
completed         : false
exception         : SecurityException: listen
startForegroundOk : false

=== onStartCommand ===
utteranceCallbacks: [onStart:sent_21, onDone:sent_21, onStart:sent_21, ...]
speakCallCount: 5
```

Kotlin 端 `UtteranceProgressListener.onStart/onDone` 全部成对触发，但
`serviceOnCreateException: SecurityException: listen`。

## 真根因

`ZhiYueTtsService.onCreate()` 调用顺序问题：

```
try {
    TextToSpeech(...)              ✓
    MediaSession                   ✓
    setupAudioFocus()              ✓
    setupPhoneStateListener()      ❌ SecurityException (国产 ROM 默认拒 READ_PHONE_STATE)
    eventEmitter = plugin::emitEvent  ← 永远到不了这行
    startForeground(...)              ← 永远到不了
} catch (e) { 记录但不 rethrow }
```

`setupPhoneStateListener()` 调用 `TelephonyManager.listen()`，国产 ROM
（荣耀/小米/OPPO/vivo）默认不授予 `READ_PHONE_STATE` 权限 →
`SecurityException` → catch 接住但 onCreate 后续步骤被跳过 →
**`eventEmitter` 始终为 null**。

后果链：
1. `emit(event)` 函数 `eventEmitter?.invoke(event)` 是个 **no-op**
2. 所有 `onStart` / `onDone` / `onError` 事件**被静默丢弃**
3. Dart 端 `_handleEvent` 从未被调用
4. `TtsPlaybackController.phase` 一直停在 `loading`
5. `_onServiceState` 的第一个 if（需要 `phase == speaking`）永不满足
6. **多句队列永不自动推进**

声音还能播是因为 `tts.speak` 在异常抛出**之前**已经构造好，引擎独立于
service lifecycle 运行。所以"听到第一句"和"Dart 收到事件"是两件事。

v1.13.2 改的 `case 'done'` 代码本身没错，但 **done event 从未到 Dart**，
所以 fix 无效。

## 修复

1. **`eventEmitter` wiring 移到 onCreate try 块最前**（在任何可能抛异常的
   setup 之前）。
2. **`setupPhoneStateListener` 用 try/catch 包起来**捕获 `SecurityException`：
   - 标记 `phoneStateListenerSetupSkipped = true`
   - 不让"来电自动暂停"这个 nice-to-have 中断关键路径
3. `phoneStateListenerSetupSkipped` 加入 `getDebugState` 输出，用户在
   Settings → TTS → 调试日志里能看到 `phoneStateSkipped: true/false`。

## 教训

用户反馈"fix 没生效"时，**必须重做 systematic-debugging Phase 1**，不要
假设上一个 fix 是部分对：

- 这次如果直接信"v1.13.2 应该有效"，会再次错过真根因（onCreate
  SecurityException）
- TTS 调试日志的 `utteranceCallbacks + serviceOnCreateException` 组合
  揭示了 Kotlin 端完整工作而 Dart 端零事件的事实，直接定位到 emit 流向
  断点
- **Iron Law：第一次 fix 失败后不能继续猜测加 fix**，必须重做 root cause
  investigation

## 测试

- Kotlin：13 Robolectric 测试 PASS（增量编译 14s）
- Dart analyze：0 issues on modified files（23 info 全部为既有 cascade 风格）
- 真机验证待用户装 v1.13.3-alpha 后回报

## 升级路径

直接装 `zhiyue-1.13.3-alpha-with-fgs.apk` 覆盖 v1.13.2-alpha。
- drift schema v15 不变（无 DB 迁移）
- TTS 设置不重置
- 已有 last_tts_position 跨设备同步不受影响

## 已知 trade-off

- **未来重构若把 `eventEmitter` wiring 移回 try 块尾部，bug 会重现**。
  Code review 需注意 onCreate 顺序约束：eventEmitter 必须在
  setupPhoneStateListener 之前。
- **来电自动暂停功能在国产 ROM 上可能不可用**（READ_PHONE_STATE 被拒）。
  这是已知降级，不影响朗读核心功能。
