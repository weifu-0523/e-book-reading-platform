# OPPO/小米 System TTS Init Failure Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 OPPO/小米手机用户在系统默认 TTS 初始化失败时看到清晰的引导 SnackBar（而不是静默无反应），并尝试 1 次 applicationContext retry 绕过 ROM 限制。

**Architecture:** Kotlin service init listener 增加失败分支：第 1 次失败 → 500ms postDelayed 用 applicationContext 重试；第 2 次失败 → emit `init_error` 事件到 Dart。Dart `_handleEvent` 加 `init_error` case → `_errorController.add(...)`。Widget 监听 error stream 显示 SnackBar 含 OPPO/小米引导 + 「打开系统 TTS 设置」按钮。

**Tech Stack:** Kotlin + Android `TextToSpeech` / Dart MethodChannel reverse callback / Flutter Riverpod StateNotifier / `flutter_test` widget tests / Robolectric Kotlin tests / Inno Setup ISCC.exe / Python binary-safe 替换 CRLF。

**Worktree:** `C:\zhiyue_build_s3`（branch `s4-build`，ASCII 路径绕中文+Flutter analyze 冲突）

---

## File Structure

| 文件 | 改动类型 | 责任 |
|---|---|---|
| `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt` | Modify | init listener retry + emit init_error event |
| `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceTest.kt` | Modify | 4 新测试：retry 调度 / retry 失败 emit / retry 成功不 emit / ttsInitRetryAttempted 重置 |
| `app/lib/services/tts/self_built_tts_service.dart` | Modify | _handleEvent 加 init_error case + 透传 status/manufacturer |
| `app/test/services/tts/self_built_tts_service_test.dart` | Modify | 2 新测试：init_error event → error stream / 字段透传 |
| `app/lib/features/settings/pages/tts_settings_section.dart` | Modify | 监听 error stream 显示 SnackBar + 引导文案 + 打开系统 TTS 设置按钮 |
| `app/test/features/settings/pages/tts_settings_section_test.dart` | Modify | widget test：error stream emit → SnackBar 显示 + 按钮可点击 |
| `CHANGELOG.md` | Modify | v1.16.2-alpha entry（Python binary-safe 替换） |
| `app/pubspec.yaml` | Modify | `1.16.1-alpha+2020` → `1.16.2-alpha+2021` |
| `app/windows/installer/zhiyue.iss` | Modify | `MyAppVersion "1.16.1-alpha"` → `"1.16.2-alpha"` |
| `docs/releases/release-notes-v1.16.2-alpha.md` | Create | 用户友好的 release notes |

---

## Task 1: Kotlin emit init_error + 500ms retry with applicationContext

**Files:**
- Modify: `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt`
- Modify: `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceTest.kt`

**Scene-setting context for implementer:** 当前 `ZhiYueTtsService.kt:236-239` 的 init listener 失败分支只 `debugLog` + `Log.e`，不通知 Dart。OPPO/小米用户日志显示 init 在 5ms 内同步失败（不是 timing race），11 个 SPEAK intent 全部静默 deferred。本 task 加：(1) 第 1 次失败 → 500ms 后用 `applicationContext` 重试 1 次（部分国产 ROM 对 service context 绑定 system TTS service 有限制）；(2) 第 2 次失败 → emit `init_error` 事件到 Dart，payload 含 `status` + `manufacturer` + `model`；(3) 新增 companion field `ttsInitRetryAttempted` 在 `onCreate` 顶部重置（沿用 v1.13.9 模式）。必须**不破坏** v1.13.8 init race 修复（`pendingSpeak` + `ttsInitStatus` guard）。

- [ ] **Step 1: 写失败测试 — init 第 1 次失败调度 retry**

File: `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceTest.kt`

在文件末尾（最后一个 `@Test` 方法后）加：

```kotlin
@Test
fun `init failure schedules retry with applicationContext`() {
    // v1.16.2-alpha: OPPO/Xiaomi TTS init fails synchronously (5ms callback).
    // First failure should schedule a 500ms retry using applicationContext
    // (instead of service context) to bypass ROM restrictions.
    val service = createServiceAndAttach()
    shadowMainLooper.idleMainLooper()

    // First init callback with ERROR
    service.ttsInitListener?.invoke(TextToSpeech.ERROR)
    shadowMainLooper.idleMainLooper()

    // Verify retry is scheduled (postDelayed 500ms)
    val scheduled = shadowMainLooper.nextScheduledTime
    assertTrue("retry should be scheduled within 1000ms",
        scheduled in 1..1000)
    assertTrue("ttsInitRetryAttempted should be true after first failure",
        service.ttsInitRetryAttempted)
}
```

- [ ] **Step 2: Run test — verify FAIL**

```bash
cd C:\zhiyue_build_s3/app/android && ./gradlew :app:testWithFgsDebugUnitTest --tests "*ZhiYueTtsServiceTest.init failure schedules retry*"
```

Expected: FAIL with `ttsInitRetryAttempted field does not exist` or `nextScheduledTime returns 0` (因为代码还没改).

- [ ] **Step 3: 实现最小代码让测试通过**

File: `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt`

Step 3a: 在 companion object 加新字段（紧挨 `ttsInitStatus`，约 line 806）：

```kotlin
companion object {
    // ... existing fields ...
    @Volatile var ttsInitStatus: Int = -999
    @Volatile var ttsInitRetryAttempted: Boolean = false  // v1.16.2-alpha
    // ... rest ...
}
```

Step 3b: 在 `onCreate` 顶部 reset 列表加 `ttsInitRetryAttempted = false`（紧挨 line 184 `ttsInitStatus = -999`）：

```kotlin
ttsInitStatus = -999
ttsInitRetryAttempted = false  // v1.16.2-alpha: reset per onCreate
ttsLastSpeakReturn = -999
```

Step 3c: 改 init listener 的 `else` 分支（约 line 236-239），替换为：

```kotlin
} else {
    debugLog("TTS init FAILED status=$status")
    Log.e(TAG, "TextToSpeech init failed status=$status")
    if (!ttsInitRetryAttempted) {
        ttsInitRetryAttempted = true
        debugLog("scheduling TTS init retry in 500ms with applicationContext")
        Handler(Looper.getMainLooper()).postDelayed(500) {
            try {
                tts?.shutdown()
            } catch (e: Exception) {
                debugLog("old tts shutdown failed: ${e.message}")
            }
            tts = TextToSpeech(applicationContext, ttsInitListener!!)
            debugLog("retry: TextToSpeech recreated with applicationContext")
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

Step 3d: 加 imports（文件顶部）：

```kotlin
import android.os.Handler
import android.os.Looper
```

- [ ] **Step 4: Run test — verify PASS**

```bash
cd C:\zhiyue_build_s3/app/android && ./gradlew :app:testWithFgsDebugUnitTest --tests "*ZhiYueTtsServiceTest.init failure schedules retry*"
```

Expected: PASS

- [ ] **Step 5: 写失败测试 — retry 失败后 emit init_error**

File: `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceTest.kt`

```kotlin
@Test
fun `init retry failure emits init_error event with manufacturer`() {
    val service = createServiceAndAttach()
    shadowMainLooper.idleMainLooper()

    // First failure schedules retry
    service.ttsInitListener?.invoke(TextToSpeech.ERROR)
    shadowMainLooper.idleMainLooper()

    // Advance past 500ms retry delay
    shadowMainLooper.idleMainLooper(600)

    // Second failure (retry exhausted)
    service.ttsInitListener?.invoke(TextToSpeech.ERROR)
    shadowMainLooper.idleMainLooper()

    // Verify init_error emitted
    val errorEvents = emittedEvents.filter { it["event"] == "init_error" }
    assertEquals("should emit exactly one init_error", 1, errorEvents.size)
    val evt = errorEvents.first()
    assertEquals(TextToSpeech.ERROR, evt["status"])
    assertNotNull(evt["manufacturer"])
    assertNotNull(evt["model"])
}
```

- [ ] **Step 6: Run test — verify PASS**（代码已在 Step 3 实现，应直接通过）

```bash
cd C:\zhiyue_build_s3/app/android && ./gradlew :app:testWithFgsDebugUnitTest --tests "*init retry failure emits*"
```

Expected: PASS（如果 FAIL，检查 `emittedEvents` 收集逻辑 + emit() 是否被 mock 拦截）

- [ ] **Step 7: 写测试 — retry 成功不 emit init_error**

```kotlin
@Test
fun `init retry success does not emit init_error`() {
    val service = createServiceAndAttach()
    shadowMainLooper.idleMainLooper()

    // First failure → schedule retry
    service.ttsInitListener?.invoke(TextToSpeech.ERROR)
    shadowMainLooper.idleMainLooper()

    // Advance past 500ms
    shadowMainLooper.idleMainLooper(600)

    // Retry succeeds
    service.ttsInitListener?.invoke(TextToSpeech.SUCCESS)
    shadowMainLooper.idleMainLooper()

    val errorEvents = emittedEvents.filter { it["event"] == "init_error" }
    assertEquals("init_error should NOT be emitted on retry success",
        0, errorEvents.size)
}
```

- [ ] **Step 8: Run test — verify PASS**

```bash
cd C:\zhiyue_build_s3/app/android && ./gradlew :app:testWithFgsDebugUnitTest --tests "*init retry success*"
```

Expected: PASS

- [ ] **Step 9: 写测试 — ttsInitRetryAttempted onCreate 重置**

```kotlin
@Test
fun `ttsInitRetryAttempted resets across onCreate`() {
    val service1 = createServiceAndAttach()
    service1.ttsInitListener?.invoke(TextToSpeech.ERROR)
    shadowMainLooper.idleMainLooper()
    assertTrue(service1.ttsInitRetryAttempted)

    // Simulate service recreation (STOP + user re-click)
    service1.onDestroy()

    val service2 = createServiceAndAttach()
    shadowMainLooper.idleMainLooper()
    assertFalse("retry flag must reset on new onCreate (v1.13.9 pattern)",
        service2.ttsInitRetryAttempted)
}
```

- [ ] **Step 10: Run test — verify PASS**

```bash
cd C:\zhiyue_build_s3/app/android && ./gradlew :app:testWithFgsDebugUnitTest --tests "*ttsInitRetryAttempted resets*"
```

Expected: PASS

- [ ] **Step 11: 跑完整 Kotlin 测试套件确保无回归**

```bash
cd C:\zhiyue_build_s3/app/android && ./gradlew :app:testWithFgsDebugUnitTest
```

Expected: 所有测试 PASS（v1.16.1 基线 40 + 4 新 = 44 pass / 0 fail）

- [ ] **Step 12: 静态分析**

```bash
cd C:\zhiyue_build_s3/app && /c/flutter/bin/dart analyze lib/services/tts
```

Expected: No issues

- [ ] **Step 13: Commit**

```bash
cd C:\zhiyue_build_s3 && git add app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceTest.kt && git commit -m "$(cat <<'EOF'
feat(tts): emit init_error on OPPO/Xiaomi system TTS init failure

v1.16.2-alpha Bug fix: OPPO/Xiaomi system default TTS produces no sound.
Honor/old-Huawei work fine — decisive comparison rules out Android
TextToSpeech API itself; 5ms synchronous init failure signature points to
ROM-specific behavior (service context binding restriction).

Previous code (ZhiYueTtsService.kt:236-239) silently logged init failure
without emitting any event to Dart — 11 SPEAK intents deferred forever in
pendingSpeak queue. User saw no feedback.

Fix:
- Add companion field `ttsInitRetryAttempted`, reset on onCreate
- On first init failure: schedule 500ms retry with applicationContext
  (bypasses some ROM restrictions on service-context binding)
- On second failure: emit init_error event with status + manufacturer + model
- v1.13.8 init race fix (pendingSpeak + ttsInitStatus guard) preserved

Tests: 4 new Kotlin unit tests covering retry schedule / retry exhausted
emit / retry success no-emit / companion field reset across onCreate.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Dart _handleEvent handle init_error event

**Files:**
- Modify: `app/lib/services/tts/self_built_tts_service.dart`
- Modify: `app/test/services/tts/self_built_tts_service_test.dart`

**Scene-setting context for implementer:** Kotlin 现在会在 init retry 失败时 emit `{"event":"init_error","status":-1,"manufacturer":"Xiaomi","model":"..."}` 通过 MethodChannel reverse callback（v1.13.5 路径）。Dart 侧 `_handleEvent` (`self_built_tts_service.dart:114-130`) 当前只处理 `state` / `progress` / `error` / `done` 事件。本 task 加 `init_error` case → push 到 `_errorController`（已有 stream）。

- [ ] **Step 1: 写失败测试 — init_error 触发 error stream**

File: `app/test/services/tts/self_built_tts_service_test.dart`

在文件末尾加：

```dart
test('init_error event pushes to error stream with status and manufacturer',
    () async {
  // v1.16.2-alpha: Kotlin emits init_error when TextToSpeech init fails
  // after retry. Dart should surface this on the error stream so UI can
  // show guidance SnackBar.
  final service = SelfBuiltTtsServiceImpl();
  await service.init();

  final errors = <String>[];
  service.error.listen(errors.add);

  // Simulate Kotlin reverse callback
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'dev.zhiyue.tts',
    const MethodChannelCodec().encodeMethodCall(
      const MethodCall('onTtsEvent', {
        'event': 'init_error',
        'status': -1,
        'manufacturer': 'Xiaomi',
        'model': '23040RA0AC',
      }),
    ),
    (_) {},
  );
  await Future<void>.delayed(Duration.zero);

  expect(errors.length, 1);
  expect(errors.first, contains('系统 TTS'));
  expect(errors.first, contains('-1'));
  expect(errors.first, contains('Xiaomi'));
});
```

- [ ] **Step 2: Run test — verify FAIL**

```bash
cd C:\zhiyue_build_s3/app && /c/flutter/bin/flutter test test/services/tts/self_built_tts_service_test.dart --plain-name "init_error event*"
```

Expected: FAIL with `errors.length` = 0（因为 case 还没加）

- [ ] **Step 3: 实现 — 加 init_error case**

File: `app/lib/services/tts/self_built_tts_service.dart`

在 `_handleEvent` 的 switch 块（约 line 120-130）找最后一个 `case`，在 default 之前加：

```dart
case 'init_error':
    // v1.16.2-alpha: Kotlin ZhiYueTtsService emits init_error when
    // TextToSpeech.OnInitListener.onInit() returns ERROR after the
    // 500ms retry with applicationContext also fails. Common on
    // OPPO/小米 due to ROM-specific restrictions on system service
    // binding from foreground service context.
    final status = map['status'] as int?;
    final manufacturer = map['manufacturer'] as String? ?? 'unknown';
    _errorController.add(
        '系统 TTS 初始化失败（status=$status, device=$manufacturer）');
    break;
```

- [ ] **Step 4: Run test — verify PASS**

```bash
cd C:\zhiyue_build_s3/app && /c/flutter/bin/flutter test test/services/tts/self_built_tts_service_test.dart --plain-name "init_error event*"
```

Expected: PASS

- [ ] **Step 5: 写测试 — init_error 不影响 state stream**

```dart
test('init_error event does not change TtsState', () async {
  final service = SelfBuiltTtsServiceImpl();
  await service.init();

  final states = <TtsState>[];
  service.state.listen(states.add);

  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'dev.zhiyue.tts',
    const MethodChannelCodec().encodeMethodCall(
      const MethodCall('onTtsEvent', {
        'event': 'init_error',
        'status': -1,
        'manufacturer': 'OPPO',
      }),
    ),
    (_) {},
  );
  await Future<void>.delayed(Duration.zero);

  // init_error pushes to error stream only — does NOT transition state.
  // State transition is the widget's decision (e.g., show SnackBar but
  // stay in idle).
  expect(states, isEmpty);
});
```

- [ ] **Step 6: Run test — verify PASS**

```bash
cd C:\zhiyue_build_s3/app && /c/flutter/bin/flutter test test/services/tts/self_built_tts_service_test.dart --plain-name "init_error event does not change*"
```

Expected: PASS

- [ ] **Step 7: 跑完整 Dart TTS 单元测试套件**

```bash
cd C:\zhiyue_build_s3/app && /c/flutter/bin/flutter test test/services/tts/
```

Expected: 所有测试 PASS（v1.16.1 基线 + 2 新）

- [ ] **Step 8: Commit**

```bash
cd C:\zhiyue_build_s3 && git add app/lib/services/tts/self_built_tts_service.dart app/test/services/tts/self_built_tts_service_test.dart && git commit -m "$(cat <<'EOF'
feat(tts): Dart _handleEvent handles init_error event from Kotlin

Adds case 'init_error' to switch in _handleEvent (self_built_tts_service.dart).
When Kotlin ZhiYueTtsService emits init_error (after retry exhaustion on
OPPO/Xiaomi), pushes message to _errorController with status + manufacturer.

State stream is NOT touched — UI widgets decide how to react (show SnackBar
without transitioning playback state, since user hasn't started playback yet).

Tests: 2 new — init_error event pushes to error stream with fields / init_error
does not affect TtsState.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: tts_settings_section SnackBar with OPPO/Xiaomi guidance

**Files:**
- Modify: `app/lib/features/settings/pages/tts_settings_section.dart`
- Modify: `app/test/features/settings/pages/tts_settings_section_test.dart`

**Scene-setting context for implementer:** `tts_settings_section.dart` 是设置页的 TTS 部分，有「测试朗读」按钮。当前点击测试后，如果 init 失败，UI 完全无反应（因为 Kotlin 不 emit）。现在 Kotlin 会 emit `init_error` → Dart `_errorController.add(...)` → 需要在 widget 层显示 SnackBar 含：(1) OPPO/小米引导步骤；(2)「打开系统 TTS 设置」按钮（已有 `service.openSystemTtsSettings()` API）；(3) 「知道了」按钮 dismiss。

- [ ] **Step 1: 调研现有 error stream listener（implementer 第一步必做）**

```bash
cd C:\zhiyue_build_s3 && grep -rn "\.error\.listen\|errorStream\|TtsService.*error" app/lib/features/settings/ app/lib/features/tts/ app/lib/features/reader/
```

了解：
- 测试朗读按钮当前如何处理错误？
- 是否已有 error stream listener 可复用？
- SnackBar 用 ScaffoldMessenger 还是其他 widget？

如果已有 listener，集成；没有就新建。

- [ ] **Step 2: 写失败 widget test — init_error SnackBar 显示**

File: `app/test/features/settings/pages/tts_settings_section_test.dart`

加（如果文件不存在则创建）：

```dart
testWidgets(
    'OPPO/Xiaomi init_error shows SnackBar with system TTS settings button',
    (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: TtsSettingsSection(service: fakeService)),
  ));

  // Simulate init_error pushed from Kotlin via service.error stream
  fakeService.emitError('系统 TTS 初始化失败（status=-1, device=Xiaomi）');
  await tester.pumpAndSettle();

  // SnackBar visible
  expect(find.text(contains('系统 TTS 初始化失败')), findsOneWidget);
  expect(find.text(contains('允许自启动')), findsOneWidget);
  expect(find.text(contains('切换引擎')), findsOneWidget);
  expect(find.text('打开系统 TTS 设置'), findsOneWidget);

  // Tap button calls service.openSystemTtsSettings
  await tester.tap(find.text('打开系统 TTS 设置'));
  await tester.pumpAndSettle();
  expect(fakeService.openSystemTtsSettingsCalled, isTrue);
});
```

（Fake service 需暴露 `emitError(String)` + `openSystemTtsSettingsCalled`）

- [ ] **Step 3: Run test — verify FAIL**

```bash
cd C:\zhiyue_build_s3/app && /c/flutter/bin/flutter test test/features/settings/pages/tts_settings_section_test.dart --plain-name "init_error*"
```

Expected: FAIL with `find.text(...)` 找不到（SnackBar 还没实现）

- [ ] **Step 4: 实现 — 加 error stream listener + SnackBar**

File: `app/lib/features/settings/pages/tts_settings_section.dart`

Step 4a: 在 `_TtsSettingsSectionState.initState`（或等价 build setup）加：

```dart
Service?.error.listen((msg) {
  if (!mounted) return;
  if (msg.contains('系统 TTS 初始化失败')) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(msg),
          const SizedBox(height: 8),
          const Text('OPPO/小米请检查：'),
          const Text('① 系统设置 → 应用 → 智阅 → 允许自启动'),
          const Text('② 系统设置 → 语言和输入法 → 文字转语音输出 → 切换引擎'),
        ],
      ),
      duration: const Duration(seconds: 10),
      action: SnackBarAction(
        label: '打开系统 TTS 设置',
        onPressed: () async {
          final ok = await service.openSystemTtsSettings();
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('无法打开系统 TTS 设置')),
            );
          }
        },
      ),
    ));
  } else {
    // other errors — existing handler
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
});
```

Step 4b: dispose 时取消 subscription（标准 Riverpod/State pattern）。

- [ ] **Step 5: Run test — verify PASS**

```bash
cd C:\zhiyue_build_s3/app && /c/flutter/bin/flutter test test/features/settings/pages/tts_settings_section_test.dart --plain-name "init_error*"
```

Expected: PASS

- [ ] **Step 6: 写测试 — 知道了按钮 dismiss**

```dart
testWidgets('SnackBar can be dismissed', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: TtsSettingsSection(service: fakeService)),
  ));

  fakeService.emitError('系统 TTS 初始化失败（status=-1, device=OPPO）');
  await tester.pumpAndSettle();
  expect(find.text(contains('系统 TTS 初始化失败')), findsOneWidget);

  // Wait for default duration + dismiss
  await tester.pump(const Duration(seconds: 10));
  await tester.pumpAndSettle();
  expect(find.text(contains('系统 TTS 初始化失败')), findsNothing);
});
```

- [ ] **Step 7: Run test — verify PASS**

```bash
cd C:\zhiyue_build_s3/app && /c/flutter/bin/flutter test test/features/settings/pages/tts_settings_section_test.dart
```

Expected: PASS

- [ ] **Step 8: 静态分析**

```bash
cd C:\zhiyue_build_s3/app && /c/flutter/bin/dart analyze lib/features/settings
```

Expected: No issues

- [ ] **Step 9: Commit**

```bash
cd C:\zhiyue_build_s3 && git add app/lib/features/settings/pages/tts_settings_section.dart app/test/features/settings/pages/tts_settings_section_test.dart && git commit -m "$(cat <<'EOF'
feat(settings): tts_settings_section shows OPPO/Xiaomi init_error SnackBar

When SelfBuiltTtsServiceImpl.error stream emits a message containing
'系统 TTS 初始化失败' (originating from Kotlin init_error event),
shows a SnackBar with:
- Error message + device info
- OPPO/Xiaomi guidance steps (allow autostart / switch TTS engine)
- '打开系统 TTS 设置' action button (calls service.openSystemTtsSettings)
- 10s duration (longer than default 4s for reading the steps)

Non-init errors fall through to existing SnackBar handler.

Tests: 2 new widget tests — SnackBar visible with guidance + button works /
SnackBar auto-dismisses after duration.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: CHANGELOG + pubspec bump + release notes

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `app/pubspec.yaml`
- Modify: `app/windows/installer/zhiyue.iss`
- Create: `docs/releases/release-notes-v1.16.2-alpha.md`

**Scene-setting context for implementer:** Release prep. 所有代码改动（Task 1-3）已完成。pubspec version 格式 `MAJOR.MINOR.PATCH-alpha+buildNumber`，本版本 `1.16.1-alpha+2020` → `1.16.2-alpha+2021`。Inno Setup `MyAppVersion` 只接 `1.16.2-alpha`（不含 buildNumber）。CHANGELOG 必须 Python binary-safe 替换（避免 CRLF→LF 翻车）。

- [ ] **Step 1: Python binary-safe CHANGELOG 编辑**

File: `CHANGELOG.md`（在 worktree `C:\zhiyue_build_s3` 里编辑，跟 Task 1-3 同 branch）

加在最顶部（v1.16.1-alpha 之前）：

```python
path = r'C:\zhiyue_build_s3\CHANGELOG.md'
new_entry = """## v1.16.2-alpha — 2026-07-24

### Fixed
- **OPPO/小米 系统默认 TTS 初始化失败反馈**: 用户报告 OPPO/小米手机系统默认 TTS 没声音，设置页测试也无反应。诊断显示 `TextToSpeech.onInit(status=-1)` 在 5ms 内同步失败（ROM 限制 service context 绑定 system TTS service）。荣耀/老华为正常（EMUI/MagicOS 限制宽松）。
  - 新增 500ms retry 用 `applicationContext` 重试 1 次，绕过部分 ROM 限制
  - retry 失败后 emit `init_error` 事件到 Dart（含 manufacturer + model）
  - UI 显示 SnackBar：「系统 TTS 引擎初始化失败 + OPPO/小米引导 + 打开系统 TTS 设置按钮」
  - 不破坏 v1.13.8 init race 修复（pendingSpeak + ttsInitStatus guard）

"""
with open(path, 'rb') as f:
    content = f.read().decode('utf-8')
if 'v1.16.2-alpha' not in content:
    # Insert after first H1 / before first ## entry
    lines = content.split('\n', 1)
    if len(lines) == 2:
        new_content = lines[0] + '\n\n' + new_entry + lines[1]
    else:
        new_content = new_entry + content
    with open(path, 'wb') as f:
        f.write(new_content.encode('utf-8'))
    print('CHANGELOG updated')
else:
    print('v1.16.2-alpha already in CHANGELOG, skipping')
```

Run from worktree：

```bash
cd C:\zhiyue_build_s3 && python -c "<paste above>"
```

Expected: `CHANGELOG updated`

- [ ] **Step 2: Verify CHANGELOG diff (no CRLF)**

```bash
git diff --stat CHANGELOG.md
```

Expected: `1 file changed, X insertions(+)` — only insertions, no deletions.

- [ ] **Step 3: Edit pubspec.yaml**

Edit `app/pubspec.yaml`: 找 `version:` 字段，把 `1.16.1-alpha+2020` 改成 `1.16.2-alpha+2021`.

- [ ] **Step 4: Edit installer version**

Edit `app/windows/installer/zhiyue.iss`: 找 `#define MyAppVersion` 行，把 `"1.16.1-alpha"` 改成 `"1.16.2-alpha"`.

- [ ] **Step 5: Create release notes**

File: `docs/releases/release-notes-v1.16.2-alpha.md`

```markdown
# v1.16.2-alpha Release Notes

## OPPO/小米 系统默认 TTS 初始化失败反馈

### 背景

用户反馈 OPPO 和小米手机上「系统默认 TTS」没声音，设置页测试朗读也无反应。

诊断日志关键证据：
- `TTS init callback status=-1` 在 5ms 内同步失败
- 11 个 SPEAK intent 全部静默 deferred
- 荣耀 / 老华为（EMUI/MagicOS）正常

荣耀/老华为正常是**决定性证据**——问题不在 Android 原生 `TextToSpeech` API 本身，而在 **OPPO ColorOS / 小米 MIUI ROM** 对 foreground service 内绑定 system TTS service 的限制。

### 本次修复

| 改动 | 说明 |
|---|---|
| init 失败 500ms 后用 `applicationContext` 重试 1 次 | 绕过部分 ROM 对 service context 的限制 |
| retry 失败 emit `init_error` 事件到 Dart | 之前完全静默，用户无任何反馈 |
| UI SnackBar 含 OPPO/小米引导 | 「允许自启动」+「切换 TTS 引擎」+ 「打开系统 TTS 设置」按钮 |

### 用户测试场景

**场景 A（核心修复验证）**：
1. 设置 → 朗读 → 引擎选「系统默认」
2. 点击「测试朗读」
3. **预期**：弹出 SnackBar「系统 TTS 初始化失败 + OPPO/小米引导」+ 「打开系统 TTS 设置」按钮
4. 点「打开系统 TTS 设置」 → 跳转系统设置页

**场景 B（根因 #2 验证）**：
1. 在系统 TTS 设置切换默认引擎（如 Google TextToSpeech 或 iflytek 讯飞）
2. 重启智阅
3. **预期**：测试朗读成功 → 证明根因是引擎（候选 #2）
4. 如仍失败 → 根因是 ROM 限制 service binding（候选 #1），需在「应用启动管理」授权

**场景 C（不误报）**：
1. 荣耀 / 华为设备测试
2. **预期**：测试朗读直接成功，**不出现 SnackBar**

### 不做的（参考 feedback_tts_is_auxiliary）

- ROM 检测 + 自动跳转 OPPO/小米「自启动」Intent（维护成本高，每 ROM 版本路径不同）
- 自动 fallback 到 SherpaOnnx 或云端 TTS（用户应显式切换，避免困惑）

### 已知限制

- v1.16.0-alpha 升级用户：如持久化了 V1 火山音色，需在音色 Dropdown 重选（v1.16.1 已知问题）
- 13 个 tts_reader_controller_test.dart 测试 v1.16.0-alpha 起失败，本版本未修（不阻塞）

### 升级路径

- v1.16.0-alpha → v1.16.1-alpha：火山引擎云端 TTS V1→V3 协议升级（不影响系统 TTS）
- v1.16.1-alpha → v1.16.2-alpha：OPPO/小米系统 TTS init 失败反馈（本版本）

### 包体

- Android APK: ~135 MB（无新依赖）
- Windows installer: ~46 MB（无新依赖）
- libapp.so MD5 v1.16.1-alpha → v1.16.2-alpha 不同（确认 Dart 改动进 so）
```

- [ ] **Step 6: Commit**

```bash
cd C:\zhiyue_build_s3 && git add CHANGELOG.md app/pubspec.yaml app/windows/installer/zhiyue.iss docs/releases/release-notes-v1.16.2-alpha.md && git commit -m "$(cat <<'EOF'
chore(release): v1.16.2-alpha bump + changelog + release notes

Version bump 1.16.1-alpha+2020 → 1.16.2-alpha+2021.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Build APK + Windows installer, verify, distribute, push tags

**Files:** None modified, artifacts produced.

**Scene-setting context for implementer:** Task 1-4 已 commit。本 task 执行双端构建 + marker 验证（feedback_flutter_strip_cache_trap 第 5+ 次触发风险）+ 分发 4 路径 + push tags。**必须在 worktree `C:\zhiyue_build_s3`**（branch `s4-build`）跑构建，最后 rebase 回 master。

- [ ] **Step 1: 切到 worktree 拉最新 master**

```bash
cd C:\zhiyue_build_s3 && git fetch origin && git checkout s4-build && git rebase origin/master
```

Expected: 无冲突（task 1-4 都在 master 上）

- [ ] **Step 2: 跑 Dart 测试套件确保整体 PASS**

```bash
cd C:\zhiyue_build_s3/app && /c/flutter/bin/flutter test test/services/tts/ test/features/settings/ test/features/tts/
```

Expected: 所有测试 PASS（基线 + 7 新）

- [ ] **Step 3: 跑 Kotlin 测试**

```bash
cd C:\zhiyue_build_s3/app/android && ./gradlew :app:testWithFgsDebugUnitTest
```

Expected: 所有测试 PASS（基线 40 + 4 新 = 44）

- [ ] **Step 4: Build APK**

```bash
cd C:\zhiyue_build_s3/app && /c/flutter/bin/flutter build apk --flavor withFgs --release
```

Expected: `app/build/app/outputs/flutter-apk/app-withFgs-release.apk`，~135 MB

- [ ] **Step 5: 验证 libapp.so freshness (feedback_flutter_strip_cache_trap)**

```bash
cd C:\zhiyue_build_s3 && python -c "
import hashlib
with open('app/build/app/intermediates/flutter/release/withFgs/arm64-v8a/libapp.so', 'rb') as f:
    md5 = hashlib.md5(f.read()).hexdigest()
print(f'libapp.so MD5: {md5}')
# v1.16.1-alpha was b2bf94a6cd1547058b2c37f7d968dfd2 — must differ
assert md5 != 'b2bf94a6cd1547058b2c37f7d968dfd2', 'libapp.so is stale (strip cache trap)!'
print('libapp.so fresh — OK')
"
```

Expected: MD5 不同 + `libapp.so fresh — OK`

如果失败（stale）：`flutter clean` → 重建

- [ ] **Step 6: 验证 4 ASCII markers 存在 libapp.so**

```bash
cd C:\zhiyue_build_s3 && python -c "
import re
with open('app/build/app/intermediates/flutter/release/withFgs/arm64-v8a/libapp.so', 'rb') as f:
    data = f.read()
# v1.16.2 新增 markers (from Task 1 + Task 2 + Task 3)
markers = [b'ttsInitRetryAttempted', b'init_error', b'系统 TTS 初始化失败']
for m in markers:
    if m in data:
        print(f'FOUND: {m.decode()}')
    else:
        # Chinese string might be in dex not so — check dex instead
        if m.startswith(b'\xe7'):  # UTF-8 Chinese first byte
            print(f'WARN: {m.decode()} not in libapp.so (Chinese strings live in dex/asset)')
        else:
            print(f'MISSING: {m.decode()}')
            raise SystemExit(1)
print('ASCII markers verification PASSED')
"
```

Expected: 所有 ASCII markers FOUND

- [ ] **Step 7: Build Windows installer**

```bash
cd C:\zhiyue_build_s3/app/windows/installer && /c/Users/1/InnoSetup/ISCC.exe zhiyue.iss
```

Expected: `app/build/installer/zhiyue-setup-1.16.2-alpha.exe`，~46 MB

- [ ] **Step 8: Distribute 4 paths**

```bash
cp C:/zhiyue_build_s3/app/build/app/outputs/flutter-apk/app-withFgs-release.apk /c/Users/1/Desktop/zhiyue-1.16.2-alpha.apk
cp C:/zhiyue_build_s3/app/build/installer/zhiyue-setup-1.16.2-alpha.exe /c/Users/1/Desktop/zhiyue-setup-1.16.2-alpha.exe
cp C:/zhiyue_build_s3/app/build/app/outputs/flutter-apk/app-withFgs-release.apk "/h/华为同步盘/华为云盘/新版本发布/zhiyue-1.16.2-alpha.apk"
cp C:/zhiyue_build_s3/app/build/installer/zhiyue-setup-1.16.2-alpha.exe "/h/华为同步盘/华为云盘/新版本发布/zhiyue-setup-1.16.2-alpha.exe"
ls -lh /c/Users/1/Desktop/zhiyue-1.16.2-alpha* "/h/华为同步盘/华为云盘/新版本发布/zhiyue-1.16.2-alpha"*
```

Expected: 4 文件大小一致

- [ ] **Step 9: Push worktree to Gitee + rebase master**

```bash
cd C:\zhiyue_build_s3 && git push origin s4-build
# Now rebase back to master
cd H:/projiect/电子书阅读平台 && git fetch origin && git rebase origin/s4-build
```

Expected: master fast-forward 或 rebase 完成

- [ ] **Step 10: Tag + push tags**

```bash
cd H:/projiect/电子书阅读平台 && git tag v1.16.2-alpha && git tag m-oppo-xiaomi-tts-init-feedback && git push origin v1.16.2-alpha && git push origin m-oppo-xiaomi-tts-init-feedback && git push origin master
```

Expected: 2 tags + master pushed

- [ ] **Step 11: 验证 Gitee remote 状态**

```bash
cd H:/projiect/电子书阅读平台 && git ls-remote --tags origin | grep "1.16.2"
```

Expected: 2 个新 tag 可见

---

## Reuse existing patterns

- v1.13.8 init race 修复模式（pendingSpeak + ttsInitStatus guard + ttsInitListener field）— Task 1 沿用
- v1.13.9 `companion field onCreate 重置` 模式 — Task 1 ttsInitRetryAttempted
- v1.13.5 MethodChannel reverse callback (`channel.invokeMethod("onTtsEvent", ...)`) — Task 2 复用
- v1.13.7 emit map pattern（`mapOf("event" to ...)`）— Task 1 emit init_error
- `feedback_flutter_strip_cache_trap` 模式 — Task 5 验证 libapp.so MD5 + ASCII markers
- `ZhiYueTtsPlugin.openSystemTtsSettings` API（v1.13 期实现）— Task 3 复用
- Python binary-safe CHANGELOG 替换（v1.13.10+ 教训）— Task 4

---

## Verification

1. **Dart 单元测试**: ~284 pass（v1.16.1 基线 277 + 7 新）/ 1 skip / 13 pre-existing fail
2. **Kotlin 单元测试**: 44 pass（v1.16.1 基线 40 + 4 新）/ 0 fail
3. **APK libapp.so MD5 ≠ v1.16.1**（`b2bf94a6...`）
4. **4 ASCII markers FOUND in libapp.so**（ttsInitRetryAttempted / init_error / 系统TTS初始化失败 — last 在 dex 也行）
5. **APK 135 MB ± 5% / Windows installer 46 MB ± 5%**
6. **4 分发路径文件存在且大小一致**
7. **2 tags pushed to Gitee** (`v1.16.2-alpha` + `m-oppo-xiaomi-tts-init-feedback`)
8. **真机验证（用户）**: 场景 A（核心修复）/ B（根因验证）/ C（不误报）

---

## Risks

1. **retry 用 applicationContext 可能仍失败**（50% 概率）→ 无所谓，主要价值是给用户清晰反馈。Mitigation: SnackBar 引导已覆盖。
2. **postDelayed(500) 在 Robolectric 测试中 idle**：Step 5/9 用 `shadowMainLooper.idleMainLooper(600)` 模拟时间流逝。如失败，参考 v1.13.8 测试模式。
3. **widget test fake service 需暴露 emitError + openSystemTtsSettingsCalled**：implementer 自己写 fake，参考 tts_settings_section_test.dart 现有 fake（如有）。
4. **libapp.so stale**：feedback_flutter_strip_cache_trap 第 N 次触发。Mitigation: Step 5 强制 MD5 验证。
5. **CHANGELOG CRLF 翻车**：Step 1 强制 Python binary-safe。
6. **OPPO/小米特定 Intent 路径**：本版本不做（D6 决策），用户教育价值由 `openSystemTtsSettings` 覆盖。
