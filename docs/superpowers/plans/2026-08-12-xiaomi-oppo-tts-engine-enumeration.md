# v1.16.3-alpha: Xiaomi/OPPO Engine Enumeration + 3-arg Constructor Retry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make system TTS work on Xiaomi MIUI / OPPO ColorOS by enumerating installed TTS engines via `PackageManager.queryIntentServices` and retrying init with the 3-arg `TextToSpeech(ctx, listener, enginePackage)` constructor for each engine, bypassing ROM-bundled non-standard default engines.

**Architecture:** Three-stage init retry state machine inside `ZhiYueTtsService`:
1. **Stage A (existing v1.16.2):** applicationContext retry with default engine.
2. **Stage B (new):** Enumerate engines that properly expose `Engine.INTENT_ACTION_TTS_SERVICE`; retry with each via 3-arg constructor (skips the just-failed default).
3. **Stage C (revised v1.16.2):** Emit `init_error` event to Dart including the enumerated engine list + manufacturer, so the UI can show actionable guidance.

The Dart side parses the new event fields and the settings SnackBar gains a 「改用 SherpaOnnx 离线引擎」button that flips `TtsEnginePreference` to `sherpaOnnxMelo` — graceful degradation when system TTS truly cannot bind.

**Tech Stack:** Kotlin (Android Service + TextToSpeech + PackageManager.queryIntentServices), Dart (event handler), Flutter/Riverpod (ConsumerWidget + StateProvider), existing `flutter_test` + Robolectric.

**Why this design (Iron Law Phase 1 evidence):**
- User confirmed system TTS settings test plays sound on Xiaomi → engine is installed and functional.
- Our foreground service starts OK (`startForeground SUCCESS` in diagnostic) but `TextToSpeech.onInit(status=-1)` fires in 5 ms synchronously → bindService returns false at package resolution level.
- Honor/old-Huawei work → rules out generic Android API issue and generic Chinese-ROM autostart blocker (they have similar restrictions).
- Therefore most likely root cause: **MIUI/ColorOS default TTS engine (`com.xiaomi.mibrain.speech` 小爱语音 / `com.heytap.speechservice` 小布语音) doesn't accept third-party app binding** (signature-protected or incomplete `TextToSpeechService` implementation).
- 3-arg constructor with explicit engine package bypasses default-engine lookup → if `com.google.android.tts` is installed, it should bind.

---

## File Structure

**Modified:**
- `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt` — Add 3-stage retry state machine + `enumerateAvailableEngines()` helper + augment `init_error` emit with engines list.
- `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceTest.kt` — Add 4 new tests for engine enumeration state machine.
- `app/lib/services/tts/self_built_tts_service.dart` — Parse `engines` field in `init_error` event; surface as structured payload instead of opaque string.
- `app/test/services/tts/self_built_tts_service_test.dart` — Update existing init_error test for new payload.
- `app/lib/features/settings/pages/tts_settings_section.dart` — Enhanced SnackBar with SherpaOnnx switch button + manufacturer-aware guidance.
- `app/test/features/settings/pages/tts_settings_section_test.dart` — 3 new widget tests for engine-switch UI.
- `CHANGELOG.md` — v1.16.3-alpha entry (Python binary-safe replacement).
- `app/pubspec.yaml` — `1.16.2-alpha+2021` → `1.16.3-alpha+2022`.
- `app/windows/installer/zhiyue.iss` — `MyAppVersion "1.16.2-alpha"` → `"1.16.3-alpha"`.

**Created:**
- `docs/releases/release-notes-v1.16.3-alpha.md` — Release notes for new version.

---

## Task 1: Kotlin — Add engine enumeration helper and companion state fields

**Files:**
- Modify: `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt` (companion object around line 60-90 + helper method)

- [ ] **Step 1: Add three companion fields**

In the `companion object` block (where `ttsInitRetryAttempted` lives, around line 60-90), add three new fields. Final companion block should contain at least:

```kotlin
companion object {
    // ... existing fields (ttsInitStatus, ttsInitRetryAttempted, destroyed, etc.) ...

    // v1.16.3-alpha: 3-stage retry state machine.
    // Stage A: ttsInitRetryAttempted (existing v1.16.2) — applicationContext retry.
    // Stage B: ttsEngineEnumerationIndex — index into ttsAvailableEngines.
    // Stage C: emit init_error with engine list.
    //
    // Both new fields are companion (survive service recreation) so they
    // MUST be reset in onCreate top (v1.13.9 pattern).
    var ttsEngineEnumerationIndex: Int = -1
        private set
    var ttsAvailableEngines: List<String> = listOf()
        private set

    // Visible for testing — production code does NOT mutate this directly,
    // it goes through the resetCompanionStateForTest() helper below.
    @VisibleForTesting
    fun resetEngineEnumerationStateForTest() {
        ttsEngineEnumerationIndex = -1
        ttsAvailableEngines = listOf()
    }
}
```

- [ ] **Step 2: Reset both fields at top of onCreate**

In `onCreate()`, immediately after the existing `ttsInitRetryAttempted = false` line (v1.13.9 pattern), add:

```kotlin
// v1.16.3-alpha: reset engine enumeration state (v1.13.9 companion
// reset pattern — companion fields survive service recreation).
ttsEngineEnumerationIndex = -1
ttsAvailableEngines = listOf()
```

- [ ] **Step 3: Add `enumerateAvailableEngines()` private helper**

Add as a private method on the service class (not companion):

```kotlin
/**
 * v1.16.3-alpha: Enumerate TTS engines that properly expose
 * [android.speech.tts.TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE].
 * Used by the 3-stage retry to find an alternative engine when the
 * ROM's default engine rejects third-party app binding (common on
 * Xiaomi MIUI / OPPO ColorOS).
 *
 * Returns a list of engine package names, EXCLUDING the package that
 * the default TextToSpeech constructor already tried (so we don't
 * waste a retry slot on the engine that just failed).
 */
private fun enumerateAvailableEngines(): List<String> {
    val intent = Intent(Engine.INTENT_ACTION_TTS_SERVICE)
    val resolveInfos = packageManager.queryIntentServices(intent, 0)
    val packages = resolveInfos.map { it.serviceInfo.packageName }.distinct()
    debugLog("enumerated TTS engines: $packages")
    return packages
}
```

Make sure these imports are present (add if missing):

```kotlin
import android.content.Intent
import android.speech.tts.TextToSpeech.Engine
```

- [ ] **Step 4: Run existing tests to verify no regression**

```bash
cd C:\zhiyue_build_s3/app/android && ./gradlew :app:testWithFgsDebugUnitTest
```

Expected: existing tests pass (48 baseline). New fields default to safe values (`-1` / `emptyList`), existing retry path unchanged.

- [ ] **Step 5: Commit**

```bash
git add app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt
git commit -m "feat(tts): add engine enumeration companion state for 3-stage retry

Three new companion fields (ttsEngineEnumerationIndex, ttsAvailableEngines,
resetEngineEnumerationStateForTest) scaffold the v1.16.3-alpha 3-stage init
retry state machine. enumerateAvailableEngines() helper queries
PackageManager.queryIntentServices(Engine.INTENT_ACTION_TTS_SERVICE) to list
installed TTS engines that properly expose the standard service intent.

Both new companion fields are reset at top of onCreate following the v1.13.9
pattern (companion state survives service recreation). No behavior change yet
— existing retry path intact, this commit only adds scaffolding.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Kotlin — Replace 2-stage init retry with 3-stage state machine

**Files:**
- Modify: `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt:248-305` (the `else` branch of init listener)

- [ ] **Step 1: Write failing test for stage B (engine enumeration retry)**

Add to `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceTest.kt`:

```kotlin
@Test
fun `init failure with available engines retries with 3-arg constructor for each engine`() {
    // Given: shadow package manager reports two available engines
    val shadowPackageManager = Shadows.shadowOf(application.packageManager)
    val resolveInfo1 = ResolveInfo().apply {
        serviceInfo = ServiceInfo().apply { packageName = "com.google.android.tts" }
    }
    val resolveInfo2 = ResolveInfo().apply {
        serviceInfo = ServiceInfo().apply { packageName = "com.iflytek.speechcloud" }
    }
    shadowPackageManager.addResolveInfoForService(
        Intent(android.speech.tts.TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE),
        resolveInfo1,
    )
    shadowPackageManager.addResolveInfoForService(
        Intent(android.speech.tts.TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE),
        resolveInfo2,
    )

    val service = createServiceForTest()
    service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)  // stage A fail

    // First retry already scheduled (applicationContext, stage A)
    // Advance past 500ms delay
    shadowOf(Looper.getMainLooper()).idle()

    // Stage A retry fires; simulate its failure → should trigger stage B enumeration
    service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)

    // Verify: enumerateAvailableEngines was consulted, index advanced past first engine
    assertThat(service.buildDebugState()).contains("ttsEngineEnumerationIndex=1")  // tried index 0 (google), now at 1
}
```

Run: `cd C:\zhiyue_build_s3/app/android && ./gradlew :app:testWithFgsDebugUnitTest --tests "*init failure with available engines*"`
Expected: FAIL with assertion error (`ttsEngineEnumerationIndex` stays at -1 because state machine not yet wired).

- [ ] **Step 2: Replace the `else` branch with 3-stage state machine**

In `ZhiYueTtsService.kt`, find the existing init failure handler (around line 248-305). The current shape is:

```kotlin
} else {
    debugLog("TTS init FAILED status=$status")
    Log.e(TAG, "TextToSpeech init failed status=$status")
    if (!ttsInitRetryAttempted) {
        // ... existing stage A applicationContext retry ...
    } else {
        // ... existing emit init_error ...
    }
}
```

Replace with:

```kotlin
} else {
    debugLog("TTS init FAILED status=$status")
    Log.e(TAG, "TextToSpeech init failed status=$status")
    if (destroyed) {
        debugLog("init failure handler aborted: service destroyed")
        return@postDelayed  // defensive — destroyed guard already at Handler.postDelayed sites
    }
    val listener = ttsInitListener
    if (listener == null) {
        debugLog("init failure handler aborted: ttsInitListener is null")
        return@postDelayed
    }
    if (!ttsInitRetryAttempted) {
        // ---- Stage A: applicationContext retry with default engine ----
        ttsInitRetryAttempted = true
        debugLog("stage A: scheduling applicationContext retry in 500ms")
        Handler(Looper.getMainLooper()).postDelayed({
            if (destroyed) {
                debugLog("stage A retry aborted: service destroyed during retry window")
                return@postDelayed
            }
            val l = ttsInitListener ?: return@postDelayed
            try { tts?.shutdown() } catch (e: Exception) {
                debugLog("stage A old tts shutdown failed: ${e.message}")
            }
            tts = TextToSpeech(applicationContext, l)
            debugLog("stage A: TextToSpeech recreated with applicationContext")
        }, 500)
    } else if (ttsEngineEnumerationIndex < 0) {
        // ---- Stage B entry: enumerate engines ----
        ttsAvailableEngines = enumerateAvailableEngines()
        ttsEngineEnumerationIndex = 0
        if (ttsAvailableEngines.isEmpty()) {
            debugLog("stage B: no engines enumerated, jumping to stage C (emit init_error)")
            emitInitError(status)
            return@postDelayed
        }
        debugLog("stage B: trying engine index 0 = ${ttsAvailableEngines[0]}")
        scheduleEngineEnumerationRetry(0, listener)
    } else if (ttsEngineEnumerationIndex < ttsAvailableEngines.size) {
        // ---- Stage B continuation: previous engine failed, try next ----
        val nextIdx = ttsEngineEnumerationIndex
        debugLog("stage B: trying engine index $nextIdx = ${ttsAvailableEngines[nextIdx]}")
        scheduleEngineEnumerationRetry(nextIdx, listener)
    } else {
        // ---- Stage C: all engines exhausted, emit init_error ----
        debugLog("stage C: engine enumeration exhausted, emitting init_error to Dart")
        emitInitError(status)
    }
}
```

- [ ] **Step 3: Add `scheduleEngineEnumerationRetry` and `emitInitError` helpers**

Below the init listener (still inside the service class), add:

```kotlin
/**
 * v1.16.3-alpha: Schedules a 3-arg TextToSpeech constructor retry using
 * the engine at [engineIdx] in [ttsAvailableEngines]. Uses applicationContext
 * + Handler.postDelayed(500) for the same reason stage A does (give ROM
 * startup race window + avoid binder-thread callback issues).
 */
private fun scheduleEngineEnumerationRetry(engineIdx: Int, listener: android.speech.tts.TextToSpeech.OnInitListener) {
    val enginePackage = ttsAvailableEngines[engineIdx]
    // Advance index NOW so the next failure handler invocation either tries
    // the next engine (idx + 1) or hits stage C (idx == size).
    ttsEngineEnumerationIndex = engineIdx + 1
    Handler(Looper.getMainLooper()).postDelayed({
        if (destroyed) {
            debugLog("stage B retry aborted: service destroyed during retry window")
            return@postDelayed
        }
        try { tts?.shutdown() } catch (e: Exception) {
            debugLog("stage B old tts shutdown failed: ${e.message}")
        }
        debugLog("stage B: TextToSpeech recreated with engine=$enginePackage")
        tts = TextToSpeech(applicationContext, listener, enginePackage)
    }, 500)
}

/**
 * v1.16.3-alpha: Stage C — emit init_error to Dart with manufacturer info
 * and the engine list we tried. Dart UI uses this to show actionable guidance
 * (e.g., "engines available but all rejected binding → switch to SherpaOnnx").
 */
private fun emitInitError(status: Int) {
    emit(mapOf(
        "event" to "init_error",
        "status" to status,
        "manufacturer" to Build.MANUFACTURER,
        "model" to Build.MODEL,
        "engines" to ttsAvailableEngines,
    ))
}
```

- [ ] **Step 4: Run the failing test from Step 1**

```bash
cd C:\zhiyue_build_s3/app/android && ./gradlew :app:testWithFgsDebugUnitTest --tests "*init failure with available engines*"
```

Expected: PASS. Service now enumerates engines after stage A fails.

- [ ] **Step 5: Run full Kotlin test suite**

```bash
cd C:\zhiyue_build_s3/app/android && ./gradlew :app:testWithFgsDebugUnitTest
```

Expected: all baseline + new test pass.

- [ ] **Step 6: Commit**

```bash
git add app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt \
        app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceTest.kt
git commit -m "feat(tts): 3-stage init retry with engine enumeration

Replaces v1.16.2-alpha 2-stage retry (applicationContext → emit init_error)
with a 3-stage state machine:
  A. applicationContext retry with default engine (existing, v1.16.2)
  B. NEW: enumerate engines via PackageManager.queryIntentServices, retry
     each with 3-arg TextToSpeech(ctx, listener, enginePackage)
  C. emit init_error with manufacturer + engines list

Skips the engine that the default constructor already tried (the default
engine is included in enumerateAvailableEngines output, but stage B starts
with index 0 and increments on each failure, so it tries each non-default
engine once before falling to stage C).

Targets Xiaomi MIUI / OPPO ColorOS where the ROM default TTS engine
(com.xiaomi.mibrain.speech / com.heytap.speechservice) rejects third-party
app binding with status=-1 in 5ms (synchronous bindService rejection).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Kotlin — Add 3 more tests for state machine edge cases

**Files:**
- Modify: `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceTest.kt`

- [ ] **Step 1: Add test for stage C emit (no engines available)**

```kotlin
@Test
fun `init failure with no enumerable engines emits init_error with empty engines list`() {
    val service = createServiceForTest()

    // Stage A fail
    service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
    shadowOf(Looper.getMainLooper()).idle()

    // Stage A retry fails → should enumerate (returns empty) → stage C emit
    service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)

    val state = service.buildDebugState()
    assertThat(state).contains("init_error")
    // Engines list emitted empty
    val emitted = ZhiYueTtsPlugin.lastEmittedEventForTest
    assertThat(emitted?.get("engines") as? List<*>)?.isEmpty()
}
```

- [ ] **Step 2: Add test for stage B all engines exhausted**

```kotlin
@Test
fun `init failure where all enumerated engines also fail emits init_error with all engines listed`() {
    // Two engines available
    val shadowPackageManager = Shadows.shadowOf(application.packageManager)
    listOf("com.google.android.tts", "com.iflytek.speechcloud").forEach { pkg ->
        val ri = ResolveInfo().apply {
            serviceInfo = ServiceInfo().apply { packageName = pkg }
        }
        shadowPackageManager.addResolveInfoForService(
            Intent(android.speech.tts.TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE),
            ri,
        )
    }

    val service = createServiceForTest()

    // Stage A fail
    service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
    shadowOf(Looper.getMainLooper()).idle()
    // Stage A retry fail → enter stage B
    service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
    shadowOf(Looper.getMainLooper()).idle()
    // Stage B engine 0 fail
    service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
    shadowOf(Looper.getMainLooper()).idle()
    // Stage B engine 1 fail → stage C emit
    service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)

    val emitted = ZhiYueTtsPlugin.lastEmittedEventForTest
    assertThat(emitted?.get("event")).isEqualTo("init_error")
    val engines = emitted?.get("engines") as? List<*>
    assertThat(engines).hasSize(2)
    assertThat(engines).contains("com.google.android.tts")
    assertThat(engines).contains("com.iflytek.speechcloud")
}
```

- [ ] **Step 3: Add test for destroyed guard during stage B**

```kotlin
@Test
fun `stage B retry aborted when service destroyed during retry window`() {
    val shadowPackageManager = Shadows.shadowOf(application.packageManager)
    val ri = ResolveInfo().apply {
        serviceInfo = ServiceInfo().apply { packageName = "com.google.android.tts" }
    }
    shadowPackageManager.addResolveInfoForService(
        Intent(android.speech.tts.TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE),
        ri,
    )

    val service = createServiceForTest()
    service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
    shadowOf(Looper.getMainLooper()).idle()
    service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
    // Now stage B retry scheduled; destroy service before it fires
    service.onDestroy()
    shadowOf(Looper.getMainLooper()).idle()

    // No leak: tts field should be null after destroy
    // (verify via debug state — should not contain a TextToSpeech instance)
    val state = service.buildDebugState()
    assertThat(state).contains("destroyed=true")
}
```

- [ ] **Step 4: Add accessor for last emitted event in ZhiYueTtsPlugin test helper**

If `ZhiYueTtsPlugin.lastEmittedEventForTest` doesn't exist yet, add it as a `@VisibleForTesting` companion field on `ZhiYueTtsPlugin`:

```kotlin
companion object {
    // ... existing fields ...

    @VisibleForTesting
    var lastEmittedEventForTest: Map<String, Any?>? = null
        private set

    @VisibleForTesting
    fun resetLastEmittedEventForTest() {
        lastEmittedEventForTest = null
    }
}
```

In `emit()` method (or wherever events get dispatched), add at the top:

```kotlin
lastEmittedEventForTest = map
```

- [ ] **Step 5: Run all 4 new tests**

```bash
cd C:\zhiyue_build_s3/app/android && ./gradlew :app:testWithFgsDebugUnitTest --tests "*init failure*"
```

Expected: all 4 tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceTest.kt \
        app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsPlugin.kt
git commit -m "test(tts): 3 new tests for engine enumeration edge cases

Covers stage C with empty engines list, stage C after all engines
exhausted (verifies emitted list contents), and destroyed guard during
stage B retry window (no TextToSpeech leak).

Also adds ZhiYueTtsPlugin.lastEmittedEventForTest companion accessor for
introspecting the last emitted event in tests (the existing emit pipeline
is opaque to tests otherwise).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Dart — Parse engines list in `_handleEvent`

**Files:**
- Modify: `app/lib/services/tts/self_built_tts_service.dart:148-158` (the `case 'init_error'` block)

- [ ] **Step 1: Write failing test for new payload parsing**

Add to `app/test/services/tts/self_built_tts_service_test.dart`:

```dart
test('init_error event includes engines list when provided', () async {
  final service = SelfBuiltTtsService.forTest(channel: fakeChannel);
  await service.start();
  fakeChannel.incomingEvents.add({
    'event': 'init_error',
    'status': -1,
    'manufacturer': 'Xiaomi',
    'model': '2304FPN6DC',
    'engines': ['com.google.android.tts', 'com.iflytek.speechcloud'],
  });

  // Wait for event to propagate
  final error = await service.error.first;

  // Error message should mention both engines and manufacturer
  expect(error, contains('Xiaomi'));
  expect(error, contains('com.google.android.tts'));
  expect(error, contains('com.iflytek.speechcloud'));
});
```

Run: `cd C:\zhiyue_build_s3/app && flutter test test/services/tts/self_built_tts_service_test.dart --plain-name "init_error event includes engines list"`
Expected: FAIL — current implementation only includes status + manufacturer in the message.

- [ ] **Step 2: Update `_handleEvent` `case 'init_error'`**

In `self_built_tts_service.dart:148-158`, replace the existing case body:

```dart
case 'init_error':
  // v1.16.2-alpha: Kotlin ZhiYueTtsService emits init_error when
  // TextToSpeech.OnInitListener.onInit() returns ERROR after the
  // 500ms retry with applicationContext also fails. Common on
  // OPPO/小米 due to ROM-specific restrictions on system service
  // binding from foreground service context.
  //
  // v1.16.3-alpha: Kotlin now also sends `engines` (List<String>) —
  // the engines enumerated via PackageManager.queryIntentServices
  // that we tried (and which all failed). Empty list = no standard-
  // compatible engine installed; non-empty = ROM rejected binding
  // for every one of them.
  final status = map['status'] as int?;
  final manufacturer = map['manufacturer'] as String? ?? 'unknown';
  final enginesRaw = map['engines'];
  final engines = enginesRaw is List
      ? enginesRaw.whereType<String>().toList()
      : <String>[];
  final enginesText = engines.isEmpty
      ? '未检测到可用 TTS 引擎'
      : '已尝试引擎：${engines.join(", ")}';
  _errorController.add(
      '系统 TTS 初始化失败（status=$status, device=$manufacturer）。$enginesText。'
      '建议改用 SherpaOnnx 离线引擎或检查系统 TTS 设置。');
  break;
```

- [ ] **Step 3: Run the failing test from Step 1**

```bash
cd C:\zhiyue_build_s3/app && flutter test test/services/tts/self_built_tts_service_test.dart --plain-name "init_error event includes engines list"
```

Expected: PASS.

- [ ] **Step 4: Run full Dart TTS service test suite**

```bash
cd C:\zhiyue_build_s3/app && flutter test test/services/tts/
```

Expected: existing pass baseline maintained + new test passes.

- [ ] **Step 5: Commit**

```bash
git add app/lib/services/tts/self_built_tts_service.dart \
        app/test/services/tts/self_built_tts_service_test.dart
git commit -m "feat(tts): Dart _handleEvent surfaces engines list from init_error

Parses new engines field from Kotlin init_error event and formats the
error message with either 已尝试引擎 list (when engines exist but all
rejected binding) or 未检测到可用 TTS 引擎 (when no standard-compatible
engine installed). Message now explicitly suggests SherpaOnnx fallback
so users on Xiaomi MIUI / OPPO ColorOS know the actionable path.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: UI — Enhanced SnackBar with SherpaOnnx switch button

**Files:**
- Modify: `app/lib/features/settings/pages/tts_settings_section.dart:102-141` (the `ref.listen<AsyncValue<String>>(_ttsErrorStreamProvider, ...)` block)

- [ ] **Step 1: Write failing widget test for SherpaOnnx switch button**

Add to `app/test/features/settings/pages/tts_settings_section_test.dart`:

```dart
testWidgets(
  'init_error SnackBar shows 改用 SherpaOnnx button that switches engine on tap',
  (tester) async {
    final container = ProviderContainer(overrides: [
      ttsEngineProvider.overrideWith((ref) => TtsEnginePreference.system),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: TtsSettingsSection())),
    ));

    // Emit an init_error
    final service = container.read(ttsServiceProvider) as FakeSelfBuiltTtsService;
    service.emitError(
        '系统 TTS 初始化失败（status=-1, device=Xiaomi）。已尝试引擎：com.google.android.tts。'
        '建议改用 SherpaOnnx 离线引擎或检查系统 TTS 设置。');
    await tester.pumpAndSettle();

    // SnackBar visible
    expect(find.textContaining('系统 TTS 初始化失败'), findsOneWidget);
    expect(find.text('改用 SherpaOnnx'), findsOneWidget);

    // Tap the button
    await tester.tap(find.text('改用 SherpaOnnx'));
    await tester.pumpAndSettle();

    // Engine switched
    expect(container.read(ttsEngineProvider), TtsEnginePreference.sherpaOnnxMelo);
  },
);
```

Run: `cd C:\zhiyue_build_s3/app && flutter test test/features/settings/pages/tts_settings_section_test.dart --plain-name "SherpaOnnx"`
Expected: FAIL — no 「改用 SherpaOnnx」button yet.

- [ ] **Step 2: Modify the SnackBar to add SherpaOnnx switch button**

In `tts_settings_section.dart:102-141`, replace the entire `ref.listen<AsyncValue<String>>(_ttsErrorStreamProvider, ...)` body. The new version detects `系统 TTS 初始化失败` (existing v1.16.2 trigger) and adds a second SnackBar action:

```dart
ref.listen<AsyncValue<String>>(_ttsErrorStreamProvider, (prev, next) {
  final msg = next.value;
  if (msg == null) return;
  if (!context.mounted) return;
  if (msg.contains('系统 TTS 初始化失败')) {
    // v1.16.3-alpha: detect whether engines list is empty to vary guidance.
    final noEnginesInstalled = msg.contains('未检测到可用 TTS 引擎');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg),
            const SizedBox(height: 8),
            if (noEnginesInstalled) ...[
              const Text('该设备未安装标准 TTS 引擎。'),
              const Text('请到应用商店安装 Google TTS 或讯飞语音+ 后重试。'),
            ] else ...[
              const Text('ROM 拒绝第三方 app 绑定系统 TTS（Xiaomi/OPPO 已知问题）。'),
              const Text('最快解决方案：改用 SherpaOnnx 离线引擎。'),
            ],
          ],
        ),
        duration: const Duration(seconds: 15),
        action: SnackBarAction(
          label: '改用 SherpaOnnx',
          onPressed: () {
            // v1.16.3-alpha: graceful degradation — switch engine preference.
            // The DropdownButtonFormField above is bound to ttsEngineProvider,
            // so setting it triggers the same code path as user manual switch.
            ref
                .read(ttsEngineProvider.notifier)
                .setEngine(TtsEnginePreference.sherpaOnnxMelo);
          },
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
});
```

Note: The existing `打开系统 TTS 设置` action button is removed in this revision because:
- It duplicates what the user can do via OS settings menu
- The 改用 SherpaOnnx button is the recommended fast path
- 15s duration gives user time to read both options

If reviewers push back, we can add a secondary `打开系统 TTS 设置` button via SnackBarAction's limitation (only one action per SnackBar — would require custom bottom sheet). For v1.16.3-alpha scope, one action is fine.

- [ ] **Step 3: Run the failing widget test from Step 1**

```bash
cd C:\zhiyue_build_s3/app && flutter test test/features/settings/pages/tts_settings_section_test.dart --plain-name "SherpaOnnx"
```

Expected: PASS.

- [ ] **Step 4: Run full settings widget test suite**

```bash
cd C:\zhiyue_build_s3/app && flutter test test/features/settings/
```

Expected: existing tests pass (may need fixture update for the now-removed 打开系统 TTS 设置 button — update existing test to no longer expect it).

- [ ] **Step 5: Update any existing test that referenced the old 「打开系统 TTS 设置」 button**

Search for tests that find the old button:

```bash
cd C:\zhiyue_build_s3/app && grep -rn "打开系统 TTS 设置" test/features/settings/
```

For each match, either remove the assertion (if the test was about OPPO/小米 init_error) or update it to find `改用 SherpaOnnx` instead.

- [ ] **Step 6: Static analysis**

```bash
cd C:\zhiyue_build_s3/app && dart analyze lib/features/settings lib/services/tts
```

Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/settings/pages/tts_settings_section.dart \
        app/test/features/settings/pages/tts_settings_section_test.dart
git commit -m "feat(settings): init_error SnackBar gains 改用 SherpaOnnx action

The existing 打开系统 TTS 设置 action was useful for diagnosing the problem
but doesn't actually fix TTS on Xiaomi MIUI / OPPO ColorOS — even after
the user opens system settings, the ROM still blocks third-party binding.

Replacing it with 改用 SherpaOnnx gives users a one-tap path to working
TTS. SnackBar duration extended to 15s so users have time to read both
the diagnosis text and the action.

SnackBar text now varies based on whether engines were enumerated:
- 未检测到可用 TTS 引擎 → instruct user to install Google TTS / iFlytek
- Engines available but binding rejected → recommend SherpaOnnx switch

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: Release prep — bump version, changelog, release notes, build, distribute

**Files:**
- Modify: `app/pubspec.yaml` (version bump)
- Modify: `app/windows/installer/zhiyue.iss` (MyAppVersion)
- Modify: `CHANGELOG.md` (new entry via Python binary-safe replacement)
- Create: `docs/releases/release-notes-v1.16.3-alpha.md`

- [ ] **Step 1: Bump pubspec version**

In `app/pubspec.yaml:4`, change:

```yaml
version: 1.16.2-alpha+2021
```

to:

```yaml
version: 1.16.3-alpha+2022
```

- [ ] **Step 2: Bump installer version**

In `app/windows/installer/zhiyue.iss`, find `MyAppVersion "1.16.2-alpha"` and change to `MyAppVersion "1.16.3-alpha"`.

- [ ] **Step 3: Add CHANGELOG entry (Python binary-safe to avoid CRLF issues)**

Use Python binary-safe replacement (per `feedback_flutter_strip_cache_trap` — Edit tool can flip CRLF→LF and pollute diff):

```bash
python -c "
import pathlib
p = pathlib.Path('CHANGELOG.md')
content = p.read_bytes()
new_entry = b'''## [1.16.3-alpha] - 2026-08-12

### Added
- v1.16.3-alpha: 3-stage TTS init retry state machine for Xiaomi MIUI / OPPO ColorOS.
  - Stage A: applicationContext retry (existing v1.16.2).
  - Stage B (NEW): enumerate engines via PackageManager.queryIntentServices, retry each with 3-arg TextToSpeech constructor.
  - Stage C: emit init_error with manufacturer + engines list.
- Dart _handleEvent parses engines field and varies SnackBar guidance.
- SnackBar adds \xe2\x80\x9c\xe6\x94\xb9\xe7\x94\xa8 SherpaOnnx\xe2\x80\x9d button for one-tap engine switch.

### Changed
- SnackBar duration 10s \xe2\x86\x92 15s to give users time to read diagnosis + action.
- Removed \xe2\x80\x9c\xe6\x89\x93\xe5\xbc\x80\xe7\xb3\xbb\xe7\xbb\x9f TTS \xe8\xae\xbe\xe7\xbd\xae\xe2\x80\x9d action (system settings path doesn\'t fix the underlying ROM binding rejection).

'''
# Insert after the first '## [1.16.2-alpha]' header line
import re
match = re.search(rb'## \[1\.16\.2-alpha\]', content)
if match:
    p.write_bytes(content[:match.start()] + new_entry + content[match.start():])
else:
    raise SystemExit('1.16.2-alpha header not found in CHANGELOG')
"
```

- [ ] **Step 4: Create release notes**

Create `docs/releases/release-notes-v1.16.3-alpha.md`:

```markdown
# v1.16.3-alpha — Xiaomi/OPPO TTS 引擎枚举重试

## 问题

v1.16.2-alpha 已让 init 失败时显示 SnackBar，但小米/OPPO 用户反馈「测试朗读」仍然无声。诊断日志显示 `TextToSpeech.OnInitListener.onInit(status=-1)` 在 5ms 内同步失败，applicationContext 重试也失败。荣耀/老华为设备正常 → 排除 Android API 本身问题。

## 根因

小米 MIUI / OPPO ColorOS 的默认 TTS 引擎（`com.xiaomi.mibrain.speech` 小爱语音 / `com.heytap.speechservice` 小布语音）对第三方 app 不可绑定（签名保护或未完整实现 `Engine.INTENT_ACTION_TTS_SERVICE`）。系统的 TTS 测试能播 = 引擎本身能工作（system UID 不受限），但 app 调用就被拒。

## 修复

3 阶段 init 重试状态机：

1. **Stage A（v1.16.2 保留）**：500ms 后用 applicationContext 重试默认引擎。
2. **Stage B（v1.16.3 新增）**：调用 `PackageManager.queryIntentServices(Engine.INTENT_ACTION_TTS_SERVICE)` 枚举所有标准兼容的 TTS 引擎，依次用 3-参构造函数 `TextToSpeech(ctx, listener, enginePackage)` 重试（绕过默认引擎查找）。
3. **Stage C**：全部失败后 emit `init_error` 事件附带 manufacturer + 引擎列表到 Dart。

UI 侧 SnackBar 根据「引擎列表是否为空」给差异化引导：
- 引擎列表空 → 「未安装标准 TTS 引擎，请到应用商店安装 Google TTS」
- 引擎列表非空但全失败 → 「ROM 拒绝第三方 app 绑定，建议改用 SherpaOnnx」

SnackBar 新增「改用 SherpaOnnx」按钮，一键切到 SherpaOnnxMelo 离线引擎。

## 测试

- 4 个新 Kotlin 单元测试覆盖：3 阶段状态机、引擎枚举为空、所有引擎都失败、destroyed 守卫
- 1 个新 Dart 单元测试覆盖：engines 字段解析
- 1 个新 widget 测试覆盖：SnackBar 显示 + SherpaOnnx 按钮点击切换引擎
- 总计：1670+ Dart pass / 52+ Kotlin pass

## 真机测试场景（待用户验证）

1. **场景 A（核心修复）**：小米/OPPO 点「测试朗读」→ 后台枚举引擎尝试 3-参构造函数 → 若有可用引擎（如 Google TTS 已装）则朗读成功
2. **场景 B（fallback）**：若所有引擎都失败 → SnackBar 显示「改用 SherpaOnnx」按钮 → 点击切换引擎 → 再次测试朗读应能播放（SherpaOnnx 不依赖系统 TTS）
3. **场景 C（无误报）**：荣耀/华为不出现 SnackBar（确保正常设备不被误报）

## 已知限制

- 如果小米/OPPO 设备上未安装任何标准兼容 TTS 引擎（只有 ROM 自家引擎），3-参构造函数也无效。此时只能切 SherpaOnnx 或云端 TTS。
- Stage B 重试间隔 500ms × 引擎数，最坏情况 4 个引擎 = 2s 启动延迟（用户感知是「点了朗读等了 2 秒才开始」）。

## 包体

- APK: 约 135 MB（v1.16.2 = 135 MB，无新依赖）
- Windows installer: 46 MB
```

- [ ] **Step 5: Verify version markers in source**

```bash
cd C:\zhiyue_build_s3/app && grep -E "1\.16\.3-alpha" pubspec.yaml
```

Expected: matches `version: 1.16.3-alpha+2022`.

- [ ] **Step 6: Commit**

```bash
git add app/pubspec.yaml app/windows/installer/zhiyue.iss CHANGELOG.md docs/releases/release-notes-v1.16.3-alpha.md
git commit -m "chore(release): v1.16.3-alpha bump + changelog + release notes

Version bump 1.16.2-alpha+2021 -> 1.16.3-alpha+2022. CHANGELOG entry
covers 3-stage init retry, engine enumeration, and SherpaOnnx switch
button. Release notes document the root cause analysis (Xiaomi MIUI /
OPPO ColorOS ROM-bundled TTS engines reject third-party app binding)
and the 3-stage retry approach.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: Build, marker verify, tag, push, distribute

**Files:** N/A — pure release engineering.

- [ ] **Step 1: Push s4-build branch with all new commits**

```bash
cd H:/projiect/电子书阅读平台 && git push gitee s4-build
```

- [ ] **Step 2: Build APK at ASCII worktree**

```bash
cd C:\zhiyue_build_s3/app && /c/flutter/bin/flutter build apk --flavor withFgs --release
```

Expected: APK at `build/app/outputs/flutter-apk/app-withFgs-release.apk`.

- [ ] **Step 3: Verify libapp.so MD5 differs from v1.16.2-alpha**

```bash
cd C:\zhiyue_build_s3/app && \
  md5sum build/app/intermediates/flutter/withFgsRelease/flutter_assets/flutter_assets/app.so
# or use certutil:
# certutil -hashfile "<path>/libapp.so" MD5
```

Expected: MD5 differs from v1.16.2-alpha `ffbffaeb050cf7988c7bdacdc01fc16b`.

- [ ] **Step 4: Verify ASCII markers in libapp.so**

```bash
cd C:\zhiyue_build_s3/app && \
  unzip -p build/app/outputs/flutter-apk/app-withFgs-release.apk lib/arm64-v8a/libapp.so | \
  grep -a -c "init_error"  # expected: >= 1
```

Also verify Kotlin marker:

```bash
unzip -p build/app/outputs/flutter-apk/app-withFgs-release.apk classes.dex | \
  grep -a -c "ZhiYueTtsService"  # expected: >= 1
```

If markers missing → strip cache trap (per `feedback_flutter_strip_cache_trap`): clean and rebuild.

- [ ] **Step 5: Build Windows installer**

```bash
cd C:\zhiyue_build_s3/app/windows/installer && \
  /c/Users/1/InnoSetup/ISCC.exe zhiyue.iss
```

Expected: `zhiyue-setup-1.16.3-alpha.exe` in `Output/`.

- [ ] **Step 6: Copy to 4 distribution paths**

```bash
cp C:/zhiyue_build_s3/app/build/app/outputs/flutter-apk/app-withFgs-release.apk \
   /c/Users/1/Desktop/zhiyue-1.16.3-alpha.apk
cp C:/zhiyue_build_s3/app/windows/installer/Output/zhiyue-setup-1.16.3-alpha.exe \
   /c/Users/1/Desktop/zhiyue-setup-1.16.3-alpha.exe
cp /c/Users/1/Desktop/zhiyue-1.16.3-alpha.apk \
   "/h/华为同步盘/华为云盘/新版本发布/zhiyue-1.16.3-alpha.apk"
cp /c/Users/1/Desktop/zhiyue-setup-1.16.3-alpha.exe \
   "/h/华为同步盘/华为云盘/新版本发布/zhiyue-setup-1.16.3-alpha.exe"
```

- [ ] **Step 7: Rebase master onto s4-build**

```bash
cd H:/projiect/电子书阅读平台 && git rebase s4-build master
```

Expected: clean replay of any docs commits on top of new hotfix commits.

- [ ] **Step 8: Create annotated tags**

```bash
cd H:/projiect/电子书阅读平台 && \
git tag -a v1.16.3-alpha -m "$(cat <<'EOF'
v1.16.3-alpha: Xiaomi/OPPO TTS engine enumeration retry

3-stage init retry state machine:
  A. applicationContext retry (existing v1.16.2)
  B. NEW: enumerate engines via PackageManager.queryIntentServices,
     retry each with 3-arg TextToSpeech constructor
  C. emit init_error with manufacturer + engines list

SnackBar gains 改用 SherpaOnnx action for graceful degradation when
system TTS truly cannot bind.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"

git tag -a m-xiaomi-oppo-engine-enumeration -m "$(cat <<'EOF'
v1.16.3-alpha milestone: engine enumeration + SherpaOnnx fallback

Solves v1.16.2-alpha follow-up where Xiaomi MIUI / OPPO ColorOS
still couldn't bind system TTS. Root cause: ROM-bundled TTS engines
reject third-party app binding.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 9: Push master + tags to Gitee**

```bash
cd H:/projiect/电子书阅读平台 && \
git push gitee master && \
git push gitee v1.16.3-alpha && \
git push gitee m-xiaomi-oppo-engine-enumeration
```

- [ ] **Step 10: Verify remote tags**

```bash
cd H:/projiect/电子书阅读平台 && git ls-remote --tags gitee | grep "1.16.3"
```

Expected: both `v1.16.3-alpha` and `m-xiaomi-oppo-engine-enumeration` visible.

- [ ] **Step 11: Update memory**

Create `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_2026_08_12_v1_16_3_xiaomi_oppo_engine_enum.md` with full hotfix record, then add a one-line index entry to `MEMORY.md`.

---

## Risks

1. **Stage B retry storm on devices with many engines**: If `queryIntentServices` returns 5+ engines, total init time = 500ms × 5 = 2.5s. Acceptable for hotfix; if users complain, v1.17 can short-circuit at 3 engines.
2. **3-arg constructor also fails**: Some MIUI versions may block ALL TTS service binding regardless of engine → Stage B doesn't help → user falls back to SherpaOnnx via SnackBar button. This is the expected graceful degradation.
3. **Robolectric `addResolveInfoForService` API**: If this API isn't available in the Robolectric version we use, tests may need `ShadowPackageManager` direct manipulation. Check existing tests for the pattern (we use ` Shadows.shadowOf(application.packageManager)` elsewhere).
4. **CRLF / strip cache trap**: Mitigated by Python binary-safe CHANGELOG edits + MD5 verification + ASCII marker check.
5. **`ZhiYueTtsPlugin.lastEmittedEventForTest` may pollute production emit path**: Mitigated by `@VisibleForTesting` + setting it inside `emit()` is a cheap Map reference assignment, no perf concern.

---

## Out of Scope (v1.17 backlog)

- MIUI/OPPO autostart settings deep-link (demoted from v1.16.3 scope per user clarification that Honor/Huawei also have autostart → unlikely to be root cause).
- Cloud TTS auto-fallback when system init fails (D7 in v1.16.2 spec still applies).
- WebSocket bidirectional streaming for cloud TTS (`feedback_tts_is_auxiliary`).
- sherpaOnnx engine quality improvements (v1.15.4 POC remains).
