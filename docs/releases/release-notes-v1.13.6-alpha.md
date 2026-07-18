# v1.13.6-alpha

**发布日期**：2026-07-18
**类型**：hotfix（v1.13.5 真根因修复 — TTS invokeMethod 切到 main thread）
**上一版本**：v1.13.5-alpha

## 摘要

v1.13.5-alpha 上线后用户回报诊断数据决定性证明：v1.13.5 之前的所有
猜测都错了，包括 v1.13.5 自己的猜测（EventChannel silent drop）。

```
=== MethodChannel callback pipeline (v1.13.5) ===
onListenCalled   : true
channelReady     : true
invokeAttempt    : 6
invokeChannelNull: 0
invokeSucceeded  : 0       ← 全部失败！
invokeException  : 6       ← invokeMethod 抛了 6 次异常
dartReceivedCount: 0

=== Service debugLogs ===
EMIT_ATTEMPT type=state total_attempt=1
EMIT_THROWN type=state ex=RuntimeException: Methods marked with @UiThread must be
  executed on the main thread. Current thread: binder:29456_2 total_thrown=1
```

**真根因确认**：Android `TextToSpeech.UtteranceProgressListener` 的
`onStart` / `onDone` 回调从 **binder 线程**（`binder:PID_X`）触发，但
Flutter `MethodChannel.invokeMethod` 标注 `@UiThread` 必须在 main thread
调用。v1.13.5 的 try/catch 把 silent drop 变成可见异常是正确的方向，
让 systematic-debugging Iron Law Phase 1 终于收集到了证据。

v1.13.4 的 EventChannel `sink.success()` 也有同样的 main thread 约束，
但失败是 silent drop——这就是 v1.13.4 看到的 `emitCount=2,
dartReceivedCount=0` 的真根因。**不是 binary messenger 静默丢包**，
是 sink.success 在 binder 线程上 throw 了，但 EventChannel 把异常吞了。

## 这次怎么修的

`ZhiYueTtsPlugin.emitEvent` 加 thread 检测，非 main thread 时用
`Handler(Looper.getMainLooper()).post { ... }` 切到 main thread：

```kotlin
internal fun emitEvent(event: Map<String, Any?>) {
    val ch = channel ?: run {
        invokeChannelNullCount++
        return
    }
    invokeAttemptCount++
    // v1.13.6-alpha: Android TTS callbacks fire on binder threads;
    // MethodChannel.invokeMethod must run on the main thread. Post
    // when not already there.
    if (Looper.myLooper() != Looper.getMainLooper()) {
        invokePostedToMainThreadCount++
        Handler(Looper.getMainLooper()).post {
            try {
                ch.invokeMethod("onTtsEvent", event)
                invokeSucceededCount++
            } catch (e: Exception) {
                invokeExceptionCount++
            }
        }
        return
    }
    // 已在 main thread：直接 invoke
    try {
        ch.invokeMethod("onTtsEvent", event)
        invokeSucceededCount++
    } catch (e: Exception) {
        invokeExceptionCount++
    }
}
```

### 新诊断字段

Settings → TTS → 调试日志的 pipeline 段升级为 v1.13.5/v1.13.6 双标：

```
=== MethodChannel callback pipeline (v1.13.5/v1.13.6) ===
onListenCalled     : true
channelReady       : true
invokeAttempt      : 6
invokeChannelNull  : 0
invokePostedToMain : 6    ← v1.13.6 新增：post 到 main thread 次数
invokeSucceeded    : 6    ← 期望 > 0
invokeException    : 0    ← 期望 == 0
dartReceivedCount  : 6    ← 期望 == invokeSucceeded
诊断推理:
  invokePostedToMain>0 → TTS callback 来自 binder 线程（v1.13.6 已 post 到 main）
  invokeSucceeded==dartReceivedCount → 管道正常
  invokeSucceeded>0 && dartReceivedCount==0 → 仍丢包（极不寻常）
  invokeException>0 → invokeMethod 在 main thread 仍失败（看日志异常类型）
  invokeChannelNull>0 → 插件未 attach
```

## 用户测试步骤

1. 装 v1.13.6-alpha（覆盖 v1.13.5-alpha，versionCode 2003 > 2002）
2. 进入一本 EPUB/PDF 书的阅读页
3. 点「朗读本章」或选段「朗读选中」
4. **第一句读完，第二句应自动开始**（v1.13.6 修复目标）
5. 若仍只读一句：进 Settings → TTS → 调试日志，看 pipeline 段数据
   - `invokePostedToMain == 0`：TTS callback 没走 binder 线程（很奇怪，
     说明 Android 系统行为和 v1.13.5 数据不一致）
   - `invokeSucceeded == 0 && invokeException > 0`：把异常类型发回，
     main thread 上 invokeMethod 失败是更深层的 binary messenger 问题
   - `invokeSucceeded > 0 && dartReceivedCount == 0`：极不寻常，
     MethodChannel 反向 callback 也丢包，可能需要 inline polling 兜底

## 测试

- Dart 单元测试 ~1659 pass / 25 skip / 0 fail（不直接测 main thread post，
  Robolectric 默认 main thread 走 fast path）
- Kotlin Robolectric 20/20 pass（null channel 路径覆盖；post 路径靠 production
  诊断字段验证）
- 真机验证待用户装 v1.13.6-alpha 后回报

## 升级路径

直接装 `zhiyue-1.13.6-alpha-with-fgs.apk` 覆盖 v1.13.5-alpha。
- drift schema v15 不变（无 DB 迁移）
- TTS 设置不重置
- last_tts_position 跨设备同步不受影响
- versionCode 2003 > v1.13.5 的 2002，可覆盖安装

## Breaking Change

无。MethodChannel `dev.zhiyue.tts` 接口不变，只是 Kotlin 内部 emitEvent
行为变化（自动 post 到 main thread）。
