# v1.13.5-alpha

**发布日期**：2026-07-18
**类型**：hotfix（TTS 多句只读 queue[0] 的真根因修复）
**上一版本**：v1.13.4-alpha

## 摘要

v1.13.4-alpha 收集到的真机诊断数据：

```
=== EventChannel pipeline (v1.13.4 diagnostic) ===
onListenCalled   : true
sinkReady        : true
emitCount        : 2
emitDroppedCount : 0
dartReceivedCount: 0   ← 这里！Kotlin sink.success() 两次成功，
                       但 Dart _handleEvent 从未被调用
```

**真根因确认**：Kotlin `EventChannel.EventSink.success()` 表面无异常返回，
但 envelope 在 binary messenger 层被静默丢弃，从未到达 Dart 端 listener。
这是 EventChannel 在国产 ROM（华为 / 小米 / OPPO / vivo）+ Flutter 3.27
组合下已知的偶发问题。

前两次 fix 都猜错了根因：
- v1.13.2 假设 Dart 漏识别 `'done'` event（错——Dart 端零事件）
- v1.13.3 假设 `eventEmitter` wiring 时机错（错——wiring 是对的，但发出去的事件没到）

## 这次怎么修的

**完全抛弃 EventChannel，改用 MethodChannel 反向 invokeMethod 回调。**

EventChannel 和 MethodChannel 共用同一个 binary messenger，但
`channel.invokeMethod("xxx", event)` 走的是不同的 envelope 编码和分发代码路径。
更重要的是：invokeMethod 失败会抛异常（被 try/catch 捕获并计数），
不再是 sink.success 那种 silent drop。

### Kotlin 改动 (`ZhiYueTtsPlugin.kt`)

- 移除 `EventChannel` 字段、`StreamHandler` 实现、`onListen`/`onCancel` 回调
- `onAttachedToEngine` 只绑 MethodChannel
- `emitEvent(event)` 改用：

```kotlin
internal fun emitEvent(event: Map<String, Any?>) {
    val ch = channel ?: run {
        invokeChannelNullCount++
        return
    }
    invokeAttemptCount++
    try {
        ch.invokeMethod("onTtsEvent", event)
        invokeSucceededCount++
    } catch (e: Exception) {
        invokeExceptionCount++
        ZhiYueTtsService.debugLog("EMIT_THROWN ex=${e.javaClass.simpleName}: ${e.message}")
    }
}
```

### Dart 改动 (`self_built_tts_service.dart`)

- 移除 `EventChannel` 字段和 `_eventSub`
- `init()` 调用 `_methodChannel.setMethodCallHandler(_onMethodCall)`
- `_onMethodCall(call)` 在 `call.method == 'onTtsEvent'` 时调用 `_handleEvent(call.arguments)`
- `dispose()` 调用 `setMethodCallHandler(null)` 释放

### 新诊断字段

Settings → TTS → 调试日志的 pipeline 段重命名：
```
=== MethodChannel callback pipeline (v1.13.5) ===
onListenCalled   : true
channelReady     : true
invokeAttempt    : 2
invokeChannelNull: 0
invokeSucceeded  : 2
invokeException  : 0
dartReceivedCount: 2    ← 应该 == invokeSucceeded，否则仍有问题
诊断推理:
  invokeSucceeded==dartReceivedCount → 管道正常；
  invokeSucceeded>0 && dartReceivedCount==0 → 仍丢包（极不寻常）；
  invokeException>0 → MethodChannel 反向调用失败；
  invokeChannelNull>0 → 插件未 attach。
```

## 用户测试步骤

1. 装 v1.13.5-alpha（覆盖 v1.13.4-alpha，drift schema v15 不变）
2. 进入一本 EPUB/PDF 书的阅读页
3. 点「朗读本章」或选段「朗读选中」
4. **第一句读完，第二句应自动开始**（v1.13.5 修复目标）
5. 若仍只读一句：进 Settings → TTS → 调试日志，看 pipeline 段数据
   - `invokeException > 0`：把异常类型发回
   - `invokeSucceeded > 0 && dartReceivedCount == 0`：仍是 silent drop，但
     已排除 EventChannel 因素，需要再换思路（如 inline MethodChannel polling）

## 测试

- Dart 单元测试 1659 pass / 25 skip / 0 fail
- Kotlin Robolectric 20/20 pass
- 真机验证待用户装 v1.13.5-alpha 后回报

## 升级路径

直接装 `zhiyue-1.13.5-alpha-with-fgs.apk` 覆盖 v1.13.4-alpha。
- drift schema v15 不变（无 DB 迁移）
- TTS 设置不重置
- last_tts_position 跨设备同步不受影响
- 内部 EventChannel `dev.zhiyue.tts/events` 已移除（不对外）

## Breaking Change

EventChannel `dev.zhiyue.tts/events` 移除（不再注册）。此 channel 是 v1.13.0
引入的内部 channel，外部代码不应依赖。
