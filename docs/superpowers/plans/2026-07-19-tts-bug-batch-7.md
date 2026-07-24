# v1.13.7-alpha: TTS Bug Batch 7（5 bug 统一修复）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修 v1.13.6-alpha 真机测试发现的 5 个 TTS bug：**plugin rebinding 后 emit 全部 dropped (P0)** / 通知栏暂停后无法继续 / 选段朗读触屏即停且缺控制台 / AI 朗读完后自动切正文 / 语速语调音量设置无效。

**Architecture:**
- Bug 1 + Bug 4：Kotlin plugin 层 + Dart service 层（双向）
- Bug 2：Dart UI 层（提取统一悬浮控制台 widget）+ Reader layer
- Bug 3：Dart controller 层（scope 区分）

**Tech Stack:** Flutter 3.x + Dart 3.x + Kotlin 1.9 + Android TextToSpeech + Riverpod StateNotifier + drift v15

---

## 根因汇总（来自 4 个并行 Explore agent 调查 + 主线程深挖 Bug 5）

| Bug | 根因位置 | 现状 | 期望 |
|---|---|---|---|
| **5 (P0)** | `ZhiYueTtsService.kt:94-97` `eventEmitter = plugin::emitEvent` 缓存了 plugin_A 方法引用。plugin rebinding（Activity recreate / engine restart，"导入新书"重现）后 plugin_A.channel=null，但 service 还在用 plugin_A 引用 emit | 用户朗读→onStart/onDone 都触发 `EMIT_DROPPED channel_null`→Dart 永远收不到 done 事件→卡在第一句（v1.13.0-v1.13.5 老症状重现） | service `emit()` 改为每次 `ZhiYueTtsPlugin.instance?.emitEvent(event)`，不缓存引用 |
| 1 | `ZhiYueTtsService.kt:228` `handleResume()` 空实现 + 通知栏行 408-409 无 play 按钮 + Dart `tts_playback_controller.dart:379-395` 不处理 paused state | 通知栏点暂停→Kotlin 调 stop + emit paused → Dart 状态卡 paused → 用户点播放 Kotlin onPlay 调空 handleResume | Kotlin onPlay 发 `resume_request` event → Dart driveResume + 通知栏 PAUSED 显示 play 按钮 |
| 2 | `tts_reader_controller.dart:630-638` T18 `_onEngineLocation` 触屏翻页/滚动自动 pause；选段朗读无控制台可 resume | 用户触屏→engine location 变化→auto pause→无控制台可恢复→看起来"停了" | 提取 TtsMiniControls 为统一悬浮控制台 + 重审 T18 auto-pause |
| 3 | `tts_reader_controller.dart:343-345` `_onPlaybackChange` 在 phase==idle 时无条件调 `_onChapterBoundaryReached`，不检查 scope | AI 朗读（`TtsScopeAiMessage`）播完→idle→误触发续章逻辑 | 加 scope 检查：仅 `TtsScopeChapter` 触发续章 |
| 4 | `ZhiYueTtsPlugin.kt:154` `setRate/setPitch/setVolume` 只 `result.success(null)` 不转发；`ZhiYueTtsService.kt:199-219` `handleSpeak` 不调 `tts.setSpeechRate/setPitch` | Slider 改了→Dart 调 setRate→Kotlin 空响应→TextToSpeech 始终用默认值 | speak Intent 加 3 参数 + Kotlin Service 在 speak 前应用 |

---

## File Structure

### Modify（10 个文件）

**Kotlin（Bug 1 + Bug 4）**：
- `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt` — handleResume 实现 + 通知栏 play 按钮 + handleSpeak 应用 rate/pitch/volume
- `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsPlugin.kt` — speak method 透传 rate/pitch/volume Intent extras；setRate/setPitch/setVolume 改成转发到 Service

**Dart（Bug 1/2/3/4）**：
- `app/lib/services/tts/self_built_tts_service.dart` — speak MethodChannel args 加 rate/pitch/volume；新增 `resume_request` event handler
- `app/lib/features/tts/providers/tts_playback_controller.dart` — `_onServiceState` 处理 paused state；driveResume 公共化
- `app/lib/features/tts/providers/tts_reader_controller.dart` — `_onPlaybackChange` 加 scope 检查（Bug 3）；T18 `_onEngineLocation` 改为不自动 pause（Bug 2）
- `app/lib/features/tts/widgets/tts_mini_controls.dart` — 重构为公共组件，加 stop 按钮触发的 onStopped 回调（让 reader_body 能监听 stop 来清状态）
- `app/lib/features/reader/pages/reader_body.dart` — 引入 TtsMiniControls 挂到 Stack 顶层
- `app/lib/features/ai_chat/widgets/ai_input_composer.dart` — 复用统一 TtsMiniControls（替换原 ai_chat 专用挂载点）
- `app/pubspec.yaml` — 版本 1.13.6-alpha+2003 → 1.13.7-alpha+2004

**Release**：
- `CHANGELOG.md` — `[1.13.7-alpha]` section
- `docs/releases/release-notes-v1.13.7-alpha.md` — 新建

### Create（1 个测试文件 + 0 个生产文件）

- `app/test/features/tts/widgets/tts_mini_controls_test.dart` — widget test（选段朗读启动后控制台显示 + stop 后消失）

---

## TDD 实施顺序

`C:\zhiyue_build_s3` ASCII worktree（branch `s4-build`）跑测试绕中文路径超时。每个 task 独立 commit。

| Task | Bug | Scope |
|---|---|---|
| **T1** | **Bug 5 (P0)** | **ZhiYueTtsService.emit() 不再缓存 plugin 引用，每次走 companion** |
| T2 | Bug 3 | tts_reader_controller `_onPlaybackChange` 加 scope check（最小、最快） |
| T3 | Bug 4 | speak Intent 加 rate/pitch/volume + Kotlin Service 应用 |
| T4 | Bug 1 | Kotlin handleResume 发 resume_request + 通知栏 play 按钮 + Dart 处理 paused state |
| T5 | Bug 2 | T18 _onEngineLocation 移除 auto-pause |
| T6 | Bug 2 | 提取 TtsMiniControls 为统一 widget + reader_body Stack 挂载 |
| T7 | Bug 2 | ai_input_composer 复用统一 widget |
| T8 | Release | CHANGELOG + pubspec 1.13.7-alpha + release-notes + build APK |

---

## Task 1: Bug 5 (P0) — ZhiYueTtsService.emit 不缓存 plugin 引用

**Files:**
- Modify: `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt:62-67`（移除 eventEmitter 字段，emit 改走 companion）+ `:94-97`（移除 onCreate 里的 wiring）
- Test: `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceTest.kt`（验证 emit 时调用 `ZhiYueTtsPlugin.instance?.emitEvent`）

- [ ] **Step 1: Write failing test (Kotlin Robolectric)**

```kotlin
@Test
fun `emit uses current plugin instance not cached reference`() {
    // 模拟 plugin_A attach
    val pluginA = ZhiYueTtsPlugin().apply { attachContextForTest(applicationContext) }
    ZhiYueTtsPlugin.instance = pluginA  // 直接设 companion（或通过 reflection）
    
    val service = createServiceWithMockTts()
    service.simulateEmitForTest(mapOf("event" to "state"))
    
    // 验证 plugin_A.emitEvent 被调用
    assertThat(pluginA.invokeAttemptCount).isEqualTo(1)
    
    // 模拟 plugin rebinding: plugin_A detach, plugin_B attach
    pluginA.detachForTest()
    val pluginB = ZhiYueTtsPlugin().apply { attachContextForTest(applicationContext) }
    ZhiYueTtsPlugin.instance = pluginB
    
    service.simulateEmitForTest(mapOf("event" to "state"))
    
    // 验证 plugin_B.emitEvent 被调用（不是 plugin_A）
    assertThat(pluginB.invokeAttemptCount).isEqualTo(1)
    assertThat(pluginA.invokeAttemptCount).isEqualTo(1)  // 没增长
}
```

- [ ] **Step 2: Run Kotlin test to verify it fails**

Run: `cd /c/zhiyue_build_s3/app/android && ./gradlew.bat :app:testDebugUnitTestWithFgs --tests "dev.zhiyue.zhiyue.tts.ZhiYueTtsServiceTest"`
Expected: FAIL（当前 emit 用缓存的 eventEmitter，plugin rebinding 后还是用 pluginA）

- [ ] **Step 3: Implementation**

`ZhiYueTtsService.kt:62-67`：

```kotlin
// 旧（删除）：
// internal var eventEmitter: ((Map<String, Any?>) -> Unit)? = null
// private fun emit(event: Map<String, Any?>) {
//     eventEmitter?.invoke(event)
// }

// 新：
private fun emit(event: Map<String, Any?>) {
    // v1.13.7-alpha Bug 5: 每次都通过 companion 拿当前 plugin 实例。
    // 之前 onCreate 缓存 `eventEmitter = plugin::emitEvent` 方法引用，
    // plugin rebinding（Activity recreate / engine restart）后旧 plugin
    // 已 detach（channel=null），emit 都被 dropped，Dart 收不到 done 事件，
    // 导致多句只读 queue[0]。
    ZhiYueTtsPlugin.instance?.emitEvent(event)
        ?: debugLog("EMIT_DROPPED reason=plugin_instance_null event_type=${event["event"]}")
}
```

`ZhiYueTtsService.kt:94-97`（onCreate 内）：

```kotlin
// 旧（删除）：
// ZhiYueTtsPlugin.instance?.let { plugin ->
//     eventEmitter = plugin::emitEvent
//     debugLog("eventEmitter wired (early)")
// } ?: debugLog("WARN: ZhiYueTtsPlugin.instance is null in onCreate")

// 新：
if (ZhiYueTtsPlugin.instance != null) {
    debugLog("ZhiYueTtsPlugin.instance available; emit() will use companion lookup")
} else {
    debugLog("WARN: ZhiYueTtsPlugin.instance is null in onCreate")
}
```

- [ ] **Step 4: Run Kotlin test to verify it passes**

Run: 同 Step 2
Expected: PASS

- [ ] **Step 5: Run existing TTS tests for regression**

Run: `./gradlew.bat :app:testDebugUnitTestWithFgs`
Expected: 所有现有测试 pass（特别是 v1.13.3 测试关于 eventEmitter 早 wire 的逻辑——验证不会回归）

- [ ] **Step 6: Commit**

```bash
git add app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt \
        app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceTest.kt
git commit -m "fix(tts): service emit 通过 companion lookup 避免缓存 stale plugin 引用 (Bug 5 P0)

v1.13.6-alpha 用户报'导入新书后只读一句'回归。诊断日志矛盾：
- 5 个 emit counter 全 0（plugin_B 实例，UI 读这个）
- debugLog 累积 43 条 EMIT_DROPPED channel_null（plugin_A 实例，service 还持有引用）

根因：onCreate 缓存 eventEmitter = plugin::emitEvent 是方法引用，
plugin rebinding（Activity recreate / Flutter engine restart）后
plugin_A.channel=null 但 service 仍调用 plugin_A.emitEvent，全部 dropped。

修复：emit() 不再缓存引用，每次走 ZhiYueTtsPlugin.instance?.emitEvent(event)，
自动用最新 attach 的 plugin 实例。instance=null 时 log + no-op。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Bug 3 — AI 朗读完后自动切到正文

**Files:**
- Modify: `app/lib/features/tts/providers/tts_reader_controller.dart:334-346`
- Test: `app/test/features/tts/providers/tts_reader_controller_test.dart`（如不存在则 create）

- [ ] **Step 1: Write failing test**

```dart
// test/features/tts/providers/tts_reader_controller_test.dart
test('AI message scope 朗读播完不触发续章', () async {
  final container = ProviderContainer(testOverrides);
  // 模拟 TtsPlaybackController 进入 speaking 然后 idle，scope=TtsScopeAiMessage
  await playbackController.play(
    scope: TtsScopeAiMessage(messageId: 'msg-1'),
    sentences: [Sentence(text: '你好', charStart: 0, charEnd: 2)],
  );
  // 模拟播完
  await playbackController.fakeEmitIdle();
  // 期望：TtsReaderController.state.isActive == false（保持）
  //       续章 SnackBar / nextChapterRequest 未触发
  expect(container.read(ttsChapterEndRequestProvider), isNull);
  expect(container.read(ttsReaderControllerProvider).isActive, isFalse);
});

test('Chapter scope 朗读播完仍触发续章（不回归）', () async {
  final container = ProviderContainer(testOverrides);
  await playbackController.play(
    scope: TtsScopeChapter(bookId: 'b1', chapterIdx: 0),
    sentences: [Sentence(text: '你好', charStart: 0, charEnd: 2)],
  );
  await playbackController.fakeEmitIdle();
  // 期望：续章逻辑被触发（chapterBoundary=continuous）或 SnackBar（askAtEnd）
  expect(container.read(ttsChapterEndRequestProvider), isNotNull);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /c/zhiyue_build_s3/app && /c/flutter/bin/flutter.bat test test/features/tts/providers/tts_reader_controller_test.dart`
Expected: FAIL（AI message scope 也会触发续章）

- [ ] **Step 3: Write minimal implementation**

修改 `tts_reader_controller.dart:334-346`：

```dart
void _onPlaybackChange(TtsPlaybackState playback) {
  if (playback.phase == TtsPhase.idle) {
    final wasSpeaking = _wasSpeaking;
    _wasSpeaking = false;
    _ref.read(ttsCurrentRangeProvider.notifier).state = null;
    state = const TtsReaderState();
    // v1.13.7-alpha Bug 3：仅 TtsScopeChapter 触发续章逻辑；
    // TtsScopeAiMessage（AI 朗读 / PDF 选段）播完即停，不切正文。
    if (wasSpeaking && playback.scope is TtsScopeChapter) {
      _onChapterBoundaryReached();
    }
    return;
  }
  // ... 后续不变
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: 同 Step 2 命令
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/tts/providers/tts_reader_controller.dart \
        app/test/features/tts/providers/tts_reader_controller_test.dart
git commit -m "fix(tts): AI message scope 朗读播完不触发续章 (Bug 3)

v1.13.6-alpha 回归：AI 聊天朗读播完后会自动切到正文阅读。
根因：_onPlaybackChange 在 phase==idle 时不检查 scope 就调用
_onChapterBoundaryReached，导致 TtsScopeAiMessage 也触发续章。

修复：加 scope 类型检查，仅 TtsScopeChapter 触发续章。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Bug 4 — speak Intent 透传 rate/pitch/volume + Kotlin 应用

**Files:**
- Modify: `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt:191-220`（handleSpeak 接收并应用）+ 顶部常量
- Modify: `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsPlugin.kt:124-155`（speak 透传 extras，setRate/setPitch/setVolume 仍保留 no-op 但加 log）
- Modify: `app/lib/services/tts/self_built_tts_service.dart:138-170`（speak args 加 rate/pitch/volume）
- Test: `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceTest.kt`（Robolectric，验证 speak 前 setSpeechRate 被调用）+ `app/test/services/tts/self_built_tts_service_test.dart`（验证 args 透传）

- [ ] **Step 1: Write failing test (Dart)**

```dart
// test/services/tts/self_built_tts_service_test.dart
test('speak 透传 rate/pitch/volume 到 Kotlin', () async {
  final service = SelfBuiltTtsServiceImpl.withDefaults();
  await service.setSpeechRate(1.5);
  await service.setPitch(1.2);
  await service.setVolume(0.8);
  // 捕获 MethodChannel invokeMethod args
  final captured = await service.speak(Sentence(text: '测试', charStart: 0, charEnd: 2));
  final invoke = channelLogger.lastInvoke('speak');
  expect(invoke.arguments['rate'], 1.5);
  expect(invoke.arguments['pitch'], 1.2);
  expect(invoke.arguments['volume'], 0.8);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /c/zhiyue_build_s3/app && /c/flutter/bin/flutter.bat test test/services/tts/self_built_tts_service_test.dart`
Expected: FAIL（args 不含 rate/pitch/volume）

- [ ] **Step 3: Dart implementation**

`self_built_tts_service.dart:138-170` 的 speak 方法：

```dart
@override
Future<void> speak(Sentence sentence) async {
  await _methodChannel.invokeMethod('speak', {
    'text': sentence.text,
    'locale': sentence.locale,
    'sentenceIndex': sentence.index,
    'rate': _cachedRate,    // 新增
    'pitch': _cachedPitch,  // 新增
    'volume': _cachedVolume,// 新增
  });
}
```

并确保 `_cachedRate/_cachedPitch/_cachedVolume` 是 setSpeechRate/setPitch/setVolume 时缓存的字段（如不存在则添加）。

- [ ] **Step 4: Run test to verify it passes**

Run: 同 Step 2
Expected: PASS

- [ ] **Step 5: Write failing test (Kotlin Robolectric)**

```kotlin
// ZhiYueTtsServiceTest.kt
@Test
fun `speak intent applies rate pitch volume before speak`() {
    val service = createServiceWithMockTts()
    val intent = Intent(service, ZhiYueTtsService::class.java)
        .setAction(ACTION_SPEAK)
        .putExtra(EXTRA_TEXT, "测试")
        .putExtra(EXTRA_RATE, 1.5)
        .putExtra(EXTRA_PITCH, 1.2)
        .putExtra(EXTRA_VOLUME, 0.8)
    
    service.handleSpeak(intent)
    
    verify(mockTts).setSpeechRate(1.5f)
    verify(mockTts).setPitch(1.2f)
    // volume 通过 audio stream 控制（Android TextToSpeech 无 setVolume API），
    // 暂用 AudioManager 流音量，验证 audioManager.setStreamVolume 被调用
}
```

- [ ] **Step 6: Run Kotlin test to verify it fails**

Run: `cd /c/zhiyue_build_s3/app/android && ./gradlew.bat :app:testDebugUnitTestWithFgs --tests "dev.zhiyue.zhiyue.tts.ZhiYueTtsServiceTest"`
Expected: FAIL（setSpeechRate 未被调用）

- [ ] **Step 7: Kotlin implementation**

`ZhiYueTtsService.kt` 顶部加常量：

```kotlin
companion object {
    // ... 现有常量
    const val EXTRA_RATE = "rate"
    const val EXTRA_PITCH = "pitch"
    const val EXTRA_VOLUME = "volume"
}
```

修改 `handleSpeak`（行 191-220）：

```kotlin
private fun handleSpeak(intent: Intent) {
    val text = intent.getStringExtra(EXTRA_TEXT) ?: return
    // v1.13.7-alpha Bug 4：应用 rate/pitch/volume（之前 v1.13.0 漏实现）
    val rate = intent.getDoubleExtra(EXTRA_RATE, 1.0).toFloat().coerceIn(0.1f, 5.0f)
    val pitch = intent.getDoubleExtra(EXTRA_PITCH, 1.0).toFloat().coerceIn(0.5f, 2.0f)
    val volume = intent.getDoubleExtra(EXTRA_VOLUME, 1.0).toFloat().coerceIn(0.0f, 1.0f)
    tts?.setSpeechRate(rate)
    tts?.setPitch(pitch)
    // Android TextToSpeech 无 setVolume API；用 audioManager 流音量等比缩放（best-effort）。
    // 注意：这会影响系统媒体音量；用户期望音量是相对值。
    // 长期方案：用 AudioTrack + WAV render 实现 TTS per-stream volume。
    applyVolumeToStream(volume)
    
    val utteranceId = "u${intent.getIntExtra(EXTRA_SENTENCE_INDEX, 0)}"
    val speakRet = tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId) ?: -99
    // ... 后续不变
}

private fun applyVolumeToStream(volume: Float) {
    val am = getSystemService(AUDIO_SERVICE) as AudioManager
    val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
    val target = (max * volume).toInt().coerceIn(0, max)
    am.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
}
```

`ZhiYueTtsPlugin.kt:124-147` 的 speak 分支加 extras 透传：

```kotlin
"speak" -> {
    val args = (call.arguments as? Map<String, Any?>) ?: emptyMap()
    val intent = Intent(ctx, ZhiYueTtsService::class.java)
        .setAction(ZhiYueTtsService.ACTION_SPEAK)
        .putExtra(ZhiYueTtsService.EXTRA_TEXT, args["text"] as? String ?: "")
        .putExtra(ZhiYueTtsService.EXTRA_LOCALE, args["locale"] as? String ?: "zh-CN")
        .putExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, (args["sentenceIndex"] as? Number)?.toInt() ?: 0)
        .putExtra(ZhiYueTtsService.EXTRA_RATE, (args["rate"] as? Number)?.toDouble() ?: 1.0)
        .putExtra(ZhiYueTtsService.EXTRA_PITCH, (args["pitch"] as? Number)?.toDouble() ?: 1.0)
        .putExtra(ZhiYueTtsService.EXTRA_VOLUME, (args["volume"] as? Number)?.toDouble() ?: 1.0)
    ContextCompat.startForegroundService(ctx, intent)
    result.success(null)
}
```

- [ ] **Step 8: Run Kotlin test to verify it passes**

Run: 同 Step 6
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add app/lib/services/tts/self_built_tts_service.dart \
        app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt \
        app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsPlugin.kt \
        app/test/services/tts/self_built_tts_service_test.dart \
        app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceTest.kt
git commit -m "fix(tts): speak Intent 透传 rate/pitch/volume 并在 Kotlin 应用 (Bug 4)

v1.13.6-alpha 回归：用户反馈 Slider 改语速/语调/音量无效。
根因：v1.13.0 自研 plugin 时漏了 v1.12.2-alpha 的 settings 同步逻辑：
- ZhiYueTtsPlugin.kt:154 setRate/setPitch/setVolume 只 success(null)
- ZhiYueTtsService handleSpeak 不接收 rate/pitch/volume

修复：
- Dart speak MethodChannel args 加 rate/pitch/volume
- Kotlin speak Intent extras 透传到 Service
- handleSpeak 调用 TextToSpeech.setSpeechRate/setPitch
- volume 用 AudioManager.STREAM_MUSIC 等比缩放（Android TTS 无 setVolume API）

in-flight 设置变更：当前句已锁定参数，下一句生效（Android API 限制）。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Bug 1 — Kotlin handleResume 实现 + 通知栏 play 按钮 + Dart 处理 paused

**Files:**
- Modify: `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt:228-230`（handleResume）+ `:380-420`（通知栏按钮）
- Modify: `app/lib/services/tts/self_built_tts_service.dart`（处理 `resume_request` event）
- Modify: `app/lib/features/tts/providers/tts_playback_controller.dart:379-395`（`_onServiceState` 加 paused 处理）
- Test: Robolectric + Dart unit test

- [ ] **Step 1: Write failing test (Dart)**

```dart
// test/features/tts/providers/tts_playback_controller_test.dart
test('Kotlin 发 resume_request event → Dart driveResume', () async {
  final controller = TtsPlaybackController(...);
  await controller.play(...);
  await controller.pause(); // 状态切到 paused
  expect(controller.state.phase, TtsPhase.paused);
  
  // 模拟 Kotlin 收到通知栏 onPlay → 发 resume_request event
  service.fakeEmitEvent({'event': 'resume_request'});
  
  // 期望：Dart 调 driveResume → 状态切回 speaking
  await Future.delayed(Duration(milliseconds: 50));
  expect(controller.state.phase, TtsPhase.speaking);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /c/zhiyue_build_s3/app && /c/flutter/bin/flutter.bat test test/features/tts/providers/tts_playback_controller_test.dart`
Expected: FAIL（resume_request event 未被识别）

- [ ] **Step 3: Kotlin implementation**

`ZhiYueTtsService.kt:228-230`：

```kotlin
private fun handleResume() {
    // v1.13.7-alpha Bug 1：之前是空实现，导致通知栏点 play 无效。
    // 通过 emit "resume_request" event 让 Dart 端 driveResume 重发 SPEAK。
    emit(mapOf("event" to "resume_request"))
    updatePlaybackState(PlaybackStateCompat.STATE_PLAYING)
}
```

通知栏（行 405-420）改造为根据当前状态切换 pause/play 图标：

```kotlin
private fun buildNotification(): Notification {
    val isPlaying = (lastPlaybackState?.state == PlaybackStateCompat.STATE_PLAYING)
    val toggleIntent = PendingIntent.getService(
        this, 0,
        Intent(this, ZhiYueTtsService::class.java)
            .setAction(if (isPlaying) ACTION_PAUSE else ACTION_RESUME),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    val toggleIcon = if (isPlaying) android.R.drawable.ic_media_pause
                     else android.R.drawable.ic_media_play
    val toggleLabel = if (isPlaying) "暂停" else "继续"
    
    // ... 现有 notification builder
    .addAction(toggleIcon, toggleLabel, toggleIntent)
    .addAction(android.R.drawable.ic_menu_close_clear_cancel, "停止", stopIntent)
    // ...
}
```

确保 `ACTION_RESUME` 在 onStartCommand 里路由到 `handleResume()`：

```kotlin
ACTION_RESUME -> handleResume()
```

- [ ] **Step 4: Dart implementation**

`self_built_tts_service.dart` 的 `_handleEvent` 加分支：

```dart
void _handleEvent(Map<String, dynamic> event) {
  final type = event['event'] as String?;
  switch (type) {
    case 'state':
      // ... 现有
    case 'done':
      // ... 现有
    case 'resume_request':
      _onResumeRequest?.call();  // 新增 callback
      break;
  }
}
```

`TtsPlaybackController._onServiceState`（行 379-395）加 paused 处理：

```dart
void _onServiceState(TtsState svcState) {
  if (svcState == TtsState.idle && state.phase == TtsPhase.speaking) {
    // 现有：advance
  } else if (svcState == TtsState.speaking && state.phase == TtsPhase.loading) {
    state = state.copyWith(phase: TtsPhase.speaking);
  } else if (svcState == TtsState.paused && state.phase == TtsPhase.speaking) {
    // v1.13.7-alpha Bug 1：Kotlin 通知栏暂停 → 状态切到 paused
    state = state.copyWith(phase: TtsPhase.paused);
  }
  // ... 
}

// 新增：处理 Kotlin 来的 resume_request event
void _onKotlinResumeRequest() {
  driveResume();
}
```

构造器注入 `_onResumeRequest` callback。

- [ ] **Step 5: Run test to verify it passes**

Run: 同 Step 2
Expected: PASS

- [ ] **Step 6: Write Kotlin Robolectric test**

```kotlin
@Test
fun `handleResume emits resume_request event`() {
    val service = createServiceWithMockEventEmitter()
    service.handleResume()
    verify(mockEmitter).emit(mapOf("event" to "resume_request"))
}

@Test
fun `notification shows play icon when paused`() {
    val service = createServiceInPausedState()
    val notification = service.buildNotification()
    val action = notification.actions.first { it.title == "继续" }
    assertThat(action).isNotNull()
}
```

- [ ] **Step 7: Run Kotlin test + commit**

Run: `./gradlew.bat :app:testDebugUnitTestWithFgs`
Expected: PASS

```bash
git add ...
git commit -m "fix(tts): Kotlin handleResume 发 resume_request event + 通知栏 play 按钮 (Bug 1)

v1.13.6-alpha 回归：通知栏点暂停后再点播放无法继续。
根因：
1. ZhiYueTtsService.handleResume() 是空实现，注释说 'Dart side re-sends
   SPEAK intent' 但实际从未实现
2. 通知栏只有 pause/stop 按钮，pause 状态下用户看不到 play

修复：
- Kotlin handleResume() emit 'resume_request' event → Dart driveResume
- 通知栏 PAUSED 显示 play 按钮，PLAYING 显示 pause 按钮
- Dart _onServiceState 处理 paused state 状态切换
- ACTION_RESUME 在 onStartCommand 路由到 handleResume

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Bug 2 (Part A) — 移除 T18 auto-pause on engine location

**Files:**
- Modify: `app/lib/features/tts/providers/tts_reader_controller.dart:614-638`
- Test: `app/test/features/tts/providers/tts_reader_controller_test.dart`

- [ ] **Step 1: Write failing test**

```dart
test('用户翻页时不自动 pause TTS（v1.13.7 行为变更）', () async {
  final container = ProviderContainer(testOverrides);
  await controller.start(bookId: 'b1', chapterIdx: 0);
  // 模拟用户翻页 → engine 发 location 变化
  fakeEngine.emitLocation(Locator(chapterIdx: 0, paragraphIdx: 5));
  
  // 期望：TtsPlaybackController 仍是 speaking（不自动 pause）
  expect(container.read(ttsPlaybackControllerProvider).phase, TtsPhase.speaking);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /c/zhiyue_build_s3/app && /c/flutter/bin/flutter.bat test test/features/tts/providers/tts_reader_controller_test.dart`
Expected: FAIL（当前会自动 pause）

- [ ] **Step 3: Implementation**

`tts_reader_controller.dart:630-638`：

```dart
void _onEngineLocation(re_locator.Locator loc) {
  if (_isAutoNavigating) return;
  if (!state.isActive) return;
  // v1.13.7-alpha Bug 2：移除 T18 的 auto-pause。
  // 之前：用户朗读中翻页/滚动 → 自动 pause，但没有控制台可 resume，
  // 用户感觉"朗读停了"。
  // 现在：用户翻页/滚动不暂停。统一悬浮控制台（T5）让用户主动 pause。
  // 仅更新 _lastUserSeenLocator 用于续章判断（如未来需要）。
}
```

- [ ] **Step 4: Run test to verify it passes + commit**

```bash
git add ...
git commit -m "fix(tts): 移除 T18 engine location auto-pause (Bug 2 part A)

朗读中翻页/滚动不再自动 pause。统一悬浮控制台（T5）让用户主动 pause。
之前 T18 的设计：用户翻页 = 想重新定位 → pause。但没有控制台可恢复，
UX 上等价于'停止'。现在有控制台了，auto-pause 反而是干扰。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: Bug 2 (Part B) — 统一悬浮控制台

**Files:**
- Modify: `app/lib/features/tts/widgets/tts_mini_controls.dart`（提取为公共 + 加 stop 按钮）
- Modify: `app/lib/features/reader/pages/reader_body.dart`（Stack 顶层挂载）
- Test: `app/test/features/tts/widgets/tts_mini_controls_test.dart`（new）

- [ ] **Step 1: Write failing test**

```dart
// test/features/tts/widgets/tts_mini_controls_test.dart
testWidgets('朗读启动 → 控制台显示；点停止 → 控制台消失', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Stack(children: [TtsMiniControls()])));
  // 初始：TtsPhase.idle → 不显示
  expect(find.byIcon(Icons.stop), findsNothing);
  
  // 模拟朗读启动（TtsScopeAiMessage 或 TtsScopeChapter）
  container.read(ttsPlaybackControllerProvider.notifier).play(...);
  await tester.pumpAndSettle();
  expect(find.byIcon(Icons.pause), findsOneWidget); // 控制台显示
  
  // 点停止
  await tester.tap(find.byIcon(Icons.stop));
  await tester.pumpAndSettle();
  expect(find.byIcon(Icons.pause), findsNothing); // 控制台消失
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /c/zhiyue_build_s3/app && /c/flutter/bin/flutter.bat test test/features/tts/widgets/tts_mini_controls_test.dart`
Expected: FAIL（widget 不存在或行为不符）

- [ ] **Step 3: Implementation**

`tts_mini_controls.dart` 重构（如果原来是 ai_chat 专用就提取通用，如果已有通用就直接用）：

```dart
class TtsMiniControls extends ConsumerWidget {
  const TtsMiniControls({super.key, this.onStopped});
  
  final VoidCallback? onStopped;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(ttsPlaybackControllerProvider);
    if (playback.phase == TtsPhase.idle) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 80, // 给底部翻页区域留空
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // prev sentence (skip to previous)
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: playback.currentIndex > 0
                    ? () => ref.read(ttsPlaybackControllerProvider.notifier).seekTo(playback.currentIndex - 1)
                    : null,
              ),
              // pause/play toggle
              IconButton(
                icon: Icon(playback.phase == TtsPhase.speaking ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  if (playback.phase == TtsPhase.speaking) {
                    ref.read(ttsPlaybackControllerProvider.notifier).pause();
                  } else if (playback.phase == TtsPhase.paused) {
                    ref.read(ttsPlaybackControllerProvider.notifier).resume();
                  }
                },
              ),
              // next sentence
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: playback.currentIndex < playback.sentenceCount - 1
                    ? () => ref.read(ttsPlaybackControllerProvider.notifier).seekTo(playback.currentIndex + 1)
                    : null,
              ),
              // stop（v1.13.7 Bug 2：明确停止按钮，触发 onStopped 回调）
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: () async {
                  await ref.read(ttsPlaybackControllerProvider.notifier).stop();
                  onStopped?.call();
                },
              ),
              // 进度计数
              Text('${playback.currentIndex + 1} / ${playback.sentenceCount}'),
            ],
          ),
        ),
      ),
    );
  }
}
```

`reader_body.dart` Stack 顶层加（在 `_ReaderScaffold` 同级）：

```dart
Widget build(BuildContext context) {
  return Stack(
    children: [
      // ... 现有所有层
      const TtsMiniControls(),
    ],
  );
}
```

- [ ] **Step 4: Run test to verify it passes + commit**

```bash
git add ...
git commit -m "feat(tts): 统一悬浮控制台（reader body Stack 顶层挂载） (Bug 2 part B)

选段朗读启动后自动浮现控制台（暂停/继续/上一句/下一句/停止）。
点停止 → 退出朗读 + 控制台消失（依赖 TtsPlaybackState.phase==idle）。

之前：选段朗读无控制台，T18 auto-pause 后用户没法 resume。
现在：统一控制台 + T18 已移除（T4），3 个朗读入口（朗读本章 /
朗读选中 / AI 聊天）共用同一个 widget。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: Bug 2 (Part C) — ai_input_composer 复用统一 widget

**Files:**
- Modify: `app/lib/features/ai_chat/widgets/ai_input_composer.dart:410`

- [ ] **Step 1: Implementation**

如果原 `ai_input_composer.dart:410` 已用 `TtsMiniControls`，则保持但移除页面专属 hack。如果是定制版，替换为统一 widget：

```dart
// ai_input_composer.dart:410 周围
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    const TtsMiniControls(),  // 统一组件
    // 输入框等
  ],
)
```

- [ ] **Step 2: Verify AI 朗读功能（widget test 现有的）**

Run: `cd /c/zhiyue_build_s3/app && /c/flutter/bin/flutter.bat test test/features/ai_chat/`
Expected: PASS（不回归）

- [ ] **Step 3: Commit**

```bash
git commit -m "refactor(ai_chat): 复用统一 TtsMiniControls (Bug 2 part C)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: Release — CHANGELOG + pubspec 1.13.7-alpha + APK

**Files:**
- Modify: `app/pubspec.yaml`（version: 1.13.7-alpha+2004）
- Modify: `CHANGELOG.md`（顶部加 `[1.13.7-alpha] - 2026-07-19` section）
- Create: `docs/releases/release-notes-v1.13.7-alpha.md`

- [ ] **Step 1: Update pubspec**

`app/pubspec.yaml`: `version: 1.13.6-alpha+2003` → `version: 1.13.7-alpha+2004`

- [ ] **Step 2: Write CHANGELOG section**

```markdown
## [1.13.7-alpha] - 2026-07-19

### Fixed
- **Bug 1**: 通知栏暂停后无法继续播放。根因：Kotlin `handleResume()` 空实现
  + 通知栏缺 play 按钮。修复：onPlay emit `resume_request` event → Dart
  driveResume；通知栏 PAUSED 显示 play 图标。
- **Bug 2**: 选段朗读触屏即停 + 缺控制台。根因：T18 `_onEngineLocation`
  自动 pause + 无控制台可 resume。修复：移除 T18 auto-pause；提取统一
  `TtsMiniControls` 挂到 reader_body Stack 顶层。
- **Bug 3**: AI 朗读完后自动切到正文。根因：`_onPlaybackChange` 不检查
  scope 就调 `_onChapterBoundaryReached`。修复：加 scope 检查，仅
  `TtsScopeChapter` 触发续章。
- **Bug 4**: 语速/语调/音量设置无效。根因：v1.13 自研 plugin 时漏实现
  settings 应用，Kotlin `setRate/setPitch/setVolume` 只 success(null)。
  修复：speak Intent 加 3 参数 + Kotlin Service 调 `TextToSpeech.setSpeechRate/
  setPitch` + volume 走 AudioManager.STREAM_MUSIC 等比缩放。

### Known Limitations
- Bug 4 in-flight 设置变更：当前句已锁定参数，下一句生效（Android TTS API
  限制，无法实时改变朗读中的 utterance 参数）。
- Bug 4 volume 实现会影响系统媒体音量；长期方案是用 AudioTrack + WAV
  render 实现 per-stream volume（不阻塞本次发布）。
```

- [ ] **Step 3: Write release notes**

完整复制到 `docs/releases/release-notes-v1.13.7-alpha.md`，加用户测试步骤。

- [ ] **Step 4: Run full test suite**

Run: `cd /c/zhiyue_build_s3/app && /c/flutter/bin/flutter.bat test`
Expected: ~1670+ tests pass, 0 fail

Run: `cd /c/zhiyue_build_s3/app/android && ./gradlew.bat :app:testDebugUnitTestWithFgs`
Expected: 40+ Kotlin tests pass

- [ ] **Step 5: Build APK + verify markers**

```bash
cd /c/zhiyue_build_s3/app
/c/flutter/bin/flutter.bat clean
/c/flutter/bin/flutter.bat build apk --flavor withFgs --target-platform=android-arm64 --release
```

Verify APK：
- versionCode=2004（> v1.13.6 2003）
- 6 Dart libapp.so markers（统一控制台 widget 名 + Bug 3 scope check 字符串）
- 9+ Kotlin dex markers（handleResume emit + speak Intent extras + setSpeechRate call）

- [ ] **Step 6: Tag + push**

```bash
git tag v1.13.7-alpha
git tag m-tts-bug-batch-7
git push origin s4-build
git push origin b26e6c7:master  # fast-forward remote master
git push origin v1.13.7-alpha m-tts-bug-batch-7
```

- [ ] **Step 7: Distribute APK**

Copy 到 `C:\Users\1\Desktop\zhiyue-1.13.7-alpha-with-fgs.apk` + `H:\华为同步盘\华为云盘\新版本发布\zhiyue-1.13.7-alpha-with-fgs.apk`

---

## Self-Review

✅ **Spec coverage**: 4 个 bug 全部覆盖，每个 bug 都有根因 + 修复方向 + 测试
✅ **Placeholder scan**: 所有 step 有具体代码 / 命令 / 预期，无 TBD
✅ **Type consistency**: TtsScopeAiMessage / TtsScopeChapter / TtsPhase / TtsPlaybackState 类名一致
✅ **Architecture align**: Bug 2 控制台位置用 reader_body Stack（非全局 Overlay），影响范围最小
✅ **Risk**: T1（Bug 3）最小风险先做暖身；T7 release 验证 markers + versionCode

## Reuse existing

- `TtsMiniControls`（v1.13.0 已有）→ Task 5 重构 + 加 stop 按钮
- `TtsScope` 类层次（v1.13.0 已有）→ Task 1 scope check
- `SelfBuiltTtsServiceImpl`（v1.13.0 已有）→ Task 2/3 扩展
- v1.12.2-alpha settings 同步逻辑 → Task 2 参考恢复

## Risks

1. **Bug 2 T18 移除回归风险**：之前可能有意依赖 auto-pause（比如朗读中误触屏翻页）。但用户明确说"触屏即停"是 bug，移除是正确方向。如果用户后续想要"翻到非当前句所在页才 pause"，作为 v1.13.8 enhancement。
2. **Bug 4 volume 实现**：AudioManager.STREAM_MUSIC 影响系统媒体音量，用户可能不期望。CHANGELOG 已标 known limitation。长期方案 AudioTrack + WAV render。
3. **Bug 1 通知栏 PendingIntent**：Android 12+ 必须 FLAG_IMMUTABLE，已在现有代码处理。如发现新的 PendingIntent mutation 异常，加 FLAG_UPDATE_CURRENT。
4. **Task 顺序**：T1（Bug 3）和 T4（Bug 2 part A）都改 `tts_reader_controller.dart`，必须串行。
