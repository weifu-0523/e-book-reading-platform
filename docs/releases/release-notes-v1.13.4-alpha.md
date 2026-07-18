# v1.13.4-alpha

**发布日期**：2026-07-18
**类型**：诊断版本（无功能修复——为下一次 fix 收集证据）
**上一版本**：v1.13.3-alpha

## 摘要

v1.13.3-alpha 修了 `eventEmitter` wiring，用户装上后**依旧只读一句**。

新 debug log 显示：
- `serviceOnCreateDone: true`（v1.13.3 修的部分生效）
- `eventEmitter wired (early)`（v1.13.3 fix 确认在跑）
- `phoneStateSkipped: true`（v1.13.3 try/catch 降级生效）
- Kotlin `utteranceCallbacks` 显示 onStart/onDone 全部成对触发
- speakCallCount=5 全是用户**手动点击**（间隔 7-8 秒），不是自动推进

按 systematic-debugging Iron Law：**这是第二次 fix 失败，禁止继续猜测**。
v1.13.4-alpha 是**纯诊断版本**——只加 instrumentation，不改 emit 路径逻辑。
等用户重新测试，根据真实数据再做 v1.13.5 真正的 fix。

## 加了什么

Kotlin `ZhiYueTtsPlugin` 4 个 counter + 时序日志：

| Counter | 含义 |
|---|---|
| `onListenCalled` | EventChannel.onListen 是否曾被触发（Dart 是否成功订阅） |
| `realEventSinkReady` | 当前 sink 是否非 null |
| `emitCount` | Kotlin 成功调 sink.success() 的次数 |
| `emitDroppedCount` | sink 为 null 时静默丢弃的次数（v1.13.3 之前完全静默，这是导致前两次 fix 误判的关键盲区） |

`emitEvent` 每次 emit 写 debugLog：
```
[1784354161952] EMIT_OK type=speaking total_emit=1
[1784354163936] EMIT_OK type=done total_emit=2
```
或失败时：
```
[1784354161952] EMIT_DROPPED type=speaking total_dropped=1
```

Dart `SelfBuiltTtsServiceImpl._eventReceivedCount`：_handleEvent 被调用的次数。
`TtsService` 接口加 `eventReceivedCountForDebug` getter。

UI: Settings → TTS → 「TTS 调试日志」对话框新增 **EventChannel pipeline** 段：

```
=== EventChannel pipeline (v1.13.4 diagnostic) ===
onListenCalled   : true
sinkReady        : true
emitCount        : 10
emitDroppedCount : 0
dartReceivedCount: 0   ← 这里！如果 emitCount>0 但 dartReceivedCount=0
                        说明 binary messenger 丢包
诊断推理: emitCount>0 && dartReceivedCount==0 → binary messenger 丢包；
emitCount==0 && emitDroppedCount>0 → sink null（Dart 没 listen）；
emitCount==0 && emitDroppedCount==0 → Kotlin 端 emit 根本没被调用。
```

## 用户测试步骤

1. 装 v1.13.4-alpha（覆盖 v1.13.3-alpha，drift schema v15 不变）
2. 进入一本 EPUB/PDF 书的阅读页
3. 点「朗读本章」或选段「朗读选中」（让多句队列跑起来）
4. 等第一句读完、第二句**没自动开始**（确认 bug 复现）
5. 不要点任何按钮，直接进 Settings → TTS → 「TTS 调试日志」
6. 截图或复制全文贴回来

## 预期结果

debug log 会直接指出断点位置：

| 现象 | 真根因 | 下一步 fix |
|---|---|---|
| emitCount > 0 && dartReceivedCount == 0 | binary messenger 丢包（跨线程 / EventChannel 注册 race） | 强制在 main thread 调 sink.success；或重设 stream handler |
| emitCount == 0 && emitDroppedCount > 0 | sink null（Dart 没 listen 或 onCancel 被触发） | 改 init() 时序，确保 listen 先于 service onCreate |
| emitCount == 0 && emitDroppedCount == 0 | Kotlin emit 根本没被调用（虽然 onStart/onDone 触发了） | 检查 emit() 调用栈，看是不是 emit 函数本身有问题 |

## 教训

**Iron Law：连续两次 fix 失败必须停止猜测，先收集证据。**

v1.13.2 我假设 "Dart 收到 onStart 但 onDone case 没写"——错了，Dart 端零事件。
v1.13.3 我假设 "eventEmitter wiring 被中断"——错了（onCreate 完整跑完），但 fix 生效后还是无效。

每次 fix 我都跳过了 instrumentation 直接做修复。这次必须先 instrumentation。
4 个 counter + 4 个时序日志点 = 把整个 emit 链路照亮，让数据说话。

## 测试

- Kotlin Robolectric 13 PASS（增量编译）
- Dart analyze 0 issues on modified files
- 真机验证待用户装 v1.13.4-alpha 后回报

## 升级路径

直接装 `zhiyue-1.13.4-alpha-with-fgs.apk` 覆盖 v1.13.3-alpha。
- drift schema v15 不变（无 DB 迁移）
- TTS 设置不重置
- 已有 last_tts_position 跨设备同步不受影响
