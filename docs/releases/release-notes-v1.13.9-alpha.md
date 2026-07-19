# v1.13.9-alpha

**发布日期**：2026-07-19
**类型**：hotfix（1 bug 续修：service 重建后 companion 残留）
**上一版本**：v1.13.8-alpha

## 摘要

v1.13.8-alpha 修了"首次 onCreate 后 init race"，但用户测试发现"很大的概率"
选段朗读仍从头开始播放。本版本修复 **service 重建场景** 的同一 bug 的另一面。

## Bug 2 (续)：service 重建后 companion ttsInitStatus 残留

### 决定性诊断证据

```
[1784429405949] onCreate start                            ← service 第 2 次重建
[1784429405950] after TextToSpeech ctor, tts=@b7bdbfa     ← 新 TextToSpeech 实例
[1784429405959] handleSpeak textLen=17 tts=@b7bdbfa initStatus=0   ← !!!
[1784429405961] setLanguage(zh-CN) -> -2 (NOT_SUPPORTED)  ← 实际未 init
[1784429405961] speak() returned -1 (ERROR)
[1784429406006] TTS init callback status=0                ← 47ms 后才真正 init
```

`handleSpeak` 看到 `initStatus=0`（SUCCESS）—— 但实际 `TextToSpeech` 是新构造的实例
（`@b7bdbfa`），还没真正 init 完成。`pendingSpeakActive: false` 也证实 handleSpeak
走的是 immediate 路径（没 defer）。

### 真根因

`ZhiYueTtsService.ttsInitStatus` 是 **companion object field**（static），跨 service
实例共享。第一个 service 实例的 SUCCESS 值在 onDestroy 后仍然保留。Android 重建
service 时（用户 STOP 后再点朗读、或系统回收），新 `TextToSpeech` 还没完成异步 init，
但 `ttsInitStatus` 仍是上次的 SUCCESS。

`handleSpeak` 的 init guard `if (ttsInitStatus != SUCCESS)` 误判已就绪 → 跳过
pendingSpeak defer → 直接调 `tts.speak()` → 新引擎未 init → 返回 -1 →
`UtteranceProgressListener` 不触发任何回调 → Dart state 卡 loading → 用户重触发 →
`play()` 重置 queue 从 0 → 现象即"从头播放"。

### 为什么是间歇性

- 首次启动 app → 第一次 onCreate → init SUCCESS → 后续 speak 都 OK
- 用户停止朗读 → service 可能 keep alive 或被 destroy
- 如果 service 还活着，下次 SPEAK 不触发 onCreate，init 仍是 SUCCESS → OK
- 如果 service 被 destroy + 重建（如导入新书、配置变化、系统回收）→ 新 TextToSpeech
  + 但 companion ttsInitStatus 仍是 SUCCESS → handleSpeak 立即调 speak → 失败

用户的"很大的概率"对应"service 被重建的频率"。

### 修复

`onCreate` 开头重置 per-instance companion fields：

```kotlin
override fun onCreate() {
    super.onCreate()
    ttsInitStatus = -999
    ttsLastSpeakReturn = -999
    pendingSpeakActive = false
    onCreateCompleted = false
    onCreateException = null
    startForegroundCompleted = false
    debugLog("onCreate start (companion state reset: ttsInitStatus=-999)")
    ...
}
```

每个新 service 实例都从"未 init"状态开始，handleSpeak 走 pendingSpeak 路径，
等 init callback 真正完成后 flush。

### 测试

- **+1 Robolectric 用例**：`service recreation resets ttsInitStatus so handleSpeak defers`
  - 第一 service 实例：onCreate + init SUCCESS + onDestroy
  - 验证 companion 仍持有 SUCCESS（v1.13.8 盲点）
  - 第二 service 实例：onCreate（fix 触发）
  - 验证 ttsInitStatus 重置为 -999
  - 调用 SPEAK → 验证 pendingSpeak 非空（defer 路径生效）

总计 33 Kotlin tests pass（v1.13.8 是 32）。

## 用户测试步骤

1. 装 v1.13.9-alpha（覆盖 v1.13.8-alpha，versionCode 2006 > 2005）
2. **回归 Bug 2（核心）**：
   - 彻底关闭 app → 启动 → 选段朗读 → 应**立即**播放选中句子（不是章节头）
   - 多句连续推进
3. **回归 Bug 2 变体（service 重建场景）**：
   - 朗读中下拉通知栏 → 点停止
   - 等 5-10 秒
   - 再次选段朗读 → 应**立即**播放选中句子（不是章节头）
   - 重复 3-5 次，每次都应从选中位置开始（不再"很大的概率"从头）
4. **回归 Bug 2 长时间使用**：
   - 朗读 + 停止 + 切换章节 + 朗读 + 停止 + 导入新书 + 朗读
   - 每次选段朗读都应从选中位置开始

## 升级路径

直接装 `zhiyue-1.13.9-alpha-with-fgs.apk` 覆盖 v1.13.8-alpha。

- drift schema v15 不变（无 DB 迁移）
- TTS 设置不重置
- versionCode 2006 > v1.13.8 的 2005

## Breaking Change

无。
