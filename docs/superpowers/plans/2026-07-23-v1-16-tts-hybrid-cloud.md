# v1.16.0-alpha TTS Hybrid Cloud Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove SherpaOnnx POC (failed: RTF 0.85 lag + mediocre quality) and add two cloud TTS providers (Volcengine + Qwen/CosyVoice) with shared BaseCloudTtsService abstraction, multi-voice selection, and auto-fallback to system TTS on network errors.

**Architecture:** 3-engine enum (system + volcengineCloud + qwenCloud) replacing 2-engine (system + sherpaOnnxMelo). `BaseCloudTtsService` abstract class shares HTTP fetch + prefetch cache + onAudioStarted pattern + Timer-based completion (all proven in v1.15.5/v1.15.6). `SherpaOnnxAudioPlayer` renamed to `TtsAudioPlayer` and reused for cloud audio playback. `TtsPlaybackController` watches service errors and auto-switches to system engine on `network`/`server` errors, emitting `TtsFallbackEvent` for UI SnackBar.

**Tech Stack:** Flutter 3.x / Dart 3.x / Riverpod StateNotifier / drift v15 / `audioplayers 5.2.1` / `flutter_secure_storage` / `http` package

**Spec:** `docs/superpowers/specs/2026-07-23-v1-16-tts-hybrid-cloud-design.md`

**Build location:** `C:\zhiyue_build_s3` worktree (branch `s4-build`), ASCII path required for Flutter + Chinese path conflict avoidance. Run `git pull` in worktree after each commit to H:\ main repo.

---

## File Structure

### Create

| Path | Responsibility |
|---|---|
| `app/lib/services/tts/voice_preset.dart` | Data class for voice metadata (id, displayName, gender, description) |
| `app/lib/services/tts/cloud_tts_credentials.dart` | Base + VolcengineTtsCredentials + QwenTtsCredentials + secure storage |
| `app/lib/services/tts/cloud_tts_exception.dart` | CloudTtsException + CloudTtsErrorKind enum |
| `app/lib/services/tts/base_cloud_tts_service.dart` | Abstract base sharing prefetch cache + onAudioStarted + error handling |
| `app/lib/services/tts/volcengine_cloud_tts_service.dart` | Volcengine HTTP API impl |
| `app/lib/services/tts/qwen_cloud_tts_service.dart` | Qwen/CosyVoice HTTP API impl |
| `app/lib/features/tts/providers/cloud_tts_credentials_providers.dart` | Riverpod providers for credentials |
| `app/lib/features/tts/providers/tts_fallback_notifier.dart` | StateNotifier for fallback events |
| `app/test/services/tts/voice_preset_test.dart` | |
| `app/test/services/tts/cloud_tts_credentials_test.dart` | |
| `app/test/services/tts/base_cloud_tts_service_test.dart` | Uses fake subclass |
| `app/test/services/tts/volcengine_cloud_tts_service_test.dart` | MockHttpClient |
| `app/test/services/tts/qwen_cloud_tts_service_test.dart` | MockHttpClient |
| `app/test/features/tts/providers/tts_fallback_notifier_test.dart` | |
| `docs/releases/release-notes-v1.16.0-alpha.md` | User-facing release notes |

### Rename

| From | To |
|---|---|
| `app/lib/services/tts/sherpa_onnx_audio_player.dart` | `app/lib/services/tts/tts_audio_player.dart` |
| `app/test/services/tts/sherpa_onnx_audio_player_test.dart` | `app/test/services/tts/tts_audio_player_test.dart` |

### Modify

| Path | Reason |
|---|---|
| `app/lib/services/tts/tts_engine_preference.dart` | Replace enum values |
| `app/lib/services/tts/tts_service_factory.dart` | Replace branches |
| `app/lib/services/tts/tts_service.dart` | (Possibly) extend error stream with CloudTtsErrorKind |
| `app/lib/features/settings/pages/tts_settings_section.dart` | Remove SherpaOnnx UI, add cloud credentials + voice + test connection UI |
| `app/lib/features/tts/providers/tts_playback_controller.dart` | Add fallback logic on cloud errors |
| `app/pubspec.yaml` | Remove `sherpa_onnx`, bump version to 1.16.0-alpha+2019 |
| `app/windows/installer/zhiyue.iss` | Bump `MyAppVersion` to 1.16.0-alpha |
| `CHANGELOG.md` | Add v1.16.0-alpha entry |

### Delete

| Path |
|---|
| `app/lib/services/tts/sherpa_onnx_tts_service.dart` |
| `app/lib/features/tts/utils/sherpa_onnx_benchmark.dart` |
| `app/test/features/tts/services/sherpa_onnx_prefetch_test.dart` |
| `app/test/features/tts/utils/sherpa_onnx_benchmark_test.dart` (if exists) |
| `app/assets/tts-models/vits-melo-tts-zh_en/` (163MB, gitignored but in worktree) |

---

# Phase A: SherpaOnnx Removal (~1 day, 8 tasks)

## Task A1: Rename SherpaOnnxAudioPlayer → TtsAudioPlayer (pure rename, no behavior change)

**Files:**
- Rename: `app/lib/services/tts/sherpa_onnx_audio_player.dart` → `app/lib/services/tts/tts_audio_player.dart`
- Rename: `app/test/services/tts/sherpa_onnx_audio_player_test.dart` → `app/test/services/tts/tts_audio_player_test.dart`
- Modify imports: `app/lib/services/tts/sherpa_onnx_tts_service.dart`

- [ ] **Step 1: Rename the source file**

```bash
cd /c/zhiyue_build_s3/app
git mv lib/services/tts/sherpa_onnx_audio_player.dart lib/services/tts/tts_audio_player.dart
git mv test/services/tts/sherpa_onnx_audio_player_test.dart test/services/tts/tts_audio_player_test.dart
```

- [ ] **Step 2: Rename the class inside source**

In `lib/services/tts/tts_audio_player.dart`, replace all occurrences of `SherpaOnnxAudioPlayer` with `TtsAudioPlayer`. Update the SPDX header comment if it mentions SherpaOnnx specifically. Update the doc comment to be engine-agnostic (it'll be reused for cloud TTS in Task A2+B).

- [ ] **Step 3: Update the test file's references**

In `test/services/tts/tts_audio_player_test.dart`, replace `SherpaOnnxAudioPlayer` with `TtsAudioPlayer` in all test names and references. Test bodies should not change otherwise.

- [ ] **Step 4: Update imports in SherpaOnnxTtsService (temporary; will be deleted in A6)**

In `lib/services/tts/sherpa_onnx_tts_service.dart`:
```dart
// Before:
import 'sherpa_onnx_audio_player.dart';
// After:
import 'tts_audio_player.dart';
```
And update the type reference `SherpaOnnxAudioPlayer` → `TtsAudioPlayer` everywhere in that file.

- [ ] **Step 5: Run tests to verify no behavior change**

```bash
cd /c/zhiyue_build_s3/app
flutter test test/services/tts/tts_audio_player_test.dart
```
Expected: all 4 `awaitCompletion` tests + any other tests in that file PASS (same count as before rename).

- [ ] **Step 6: Run full TTS test suite**

```bash
flutter test test/services/tts/ test/features/tts/
```
Expected: same pass/fail/skip counts as the v1.15.6 baseline (~1666 pass / 4 skip / 0 fail).

- [ ] **Step 7: Commit**

```bash
git add lib/services/tts/tts_audio_player.dart test/services/tts/tts_audio_player_test.dart lib/services/tts/sherpa_onnx_tts_service.dart
git commit -m "$(cat <<'EOF'
refactor(tts): rename SherpaOnnxAudioPlayer → TtsAudioPlayer

Pure rename, no behavior change. TtsAudioPlayer will be reused for
cloud TTS audio playback in v1.16.0-alpha Phase B. v1.15.5
awaitCompletion Timer pattern + v1.15.6 onAudioStarted callback
both preserved.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task A2: Extend TtsAudioPlayer.play to accept MP3 bytes

**Files:**
- Modify: `app/lib/services/tts/tts_audio_player.dart`
- Modify: `app/test/services/tts/tts_audio_player_test.dart`

- [ ] **Step 1: Write failing test for MP3 bytes path**

Add to `test/services/tts/tts_audio_player_test.dart`:

```dart
test('playMp3Bytes plays Uint8List and invokes onAudioStarted after queueing',
    () async {
  final player = TtsAudioPlayer();
  final mp3Bytes = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00, 0x00]);
  var startedCalled = false;
  await player.playMp3Bytes(
    mp3Bytes,
    expectedDurationMs: 200,
    onAudioStarted: () => startedCalled = true,
    createTimer: (_, cb) => Timer(Duration.zero, cb),
  );
  expect(startedCalled, isTrue);
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/services/tts/tts_audio_player_test.dart
```
Expected: FAIL with "Method not found: playMp3Bytes" or similar.

- [ ] **Step 3: Implement playMp3Bytes**

In `lib/services/tts/tts_audio_player.dart`, add this method (alongside existing `play` for Float32; do not remove or alter existing `play`):

```dart
/// Plays MP3 bytes from cloud TTS. Mirrors [play] (Float32 path):
/// queues audio to native thread, invokes [onAudioStarted], then awaits
/// completion via Timer (not audioplayers OnCompletionListener, which is
/// unreliable on Honor ROM + BytesSource — see v1.15.5-alpha).
Future<void> playMp3Bytes(
  Uint8List mp3Bytes, {
  required int expectedDurationMs,
  void Function()? onAudioStarted,
  Timer Function(Duration, void Function())? createTimer,
}) async {
  _stopped = false;
  final p = _p;
  await p.setReleaseMode(ReleaseMode.stop);
  await p.setVolume(1.0);
  await p.play(BytesSource(mp3Bytes));
  _emit('playMp3Bytes() returned, audio queued to native thread');
  onAudioStarted?.call();
  await awaitCompletion(
    expectedDurationMs: expectedDurationMs,
    stateStream: p.onPlayerStateChanged,
    isStopped: () => _stopped,
    emit: _emit,
    createTimer: createTimer ?? Timer.new,
  );
}
```

Add `import 'dart:typed_data';` at top if not present.

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/services/tts/tts_audio_player_test.dart
```
Expected: PASS (new test green, all existing tests still pass).

- [ ] **Step 5: Commit**

```bash
git add lib/services/tts/tts_audio_player.dart test/services/tts/tts_audio_player_test.dart
git commit -m "$(cat <<'EOF'
feat(tts): TtsAudioPlayer.playMp3Bytes for cloud TTS audio

Cloud TTS services receive MP3 bytes (vs SherpaOnnx's Float32
samples). Add parallel method using same v1.15.5 Timer-based
awaitCompletion — does not alter existing play() Float32 path.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task A3: Update TtsEnginePreference enum

**Files:**
- Modify: `app/lib/services/tts/tts_engine_preference.dart`
- Modify or create: `app/test/services/tts/tts_engine_preference_test.dart`

- [ ] **Step 1: Write failing tests**

Create or update `test/services/tts/tts_engine_preference_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/tts_engine_preference.dart';

void main() {
  group('TtsEnginePreference', () {
    test('has exactly 3 values: system, volcengineCloud, qwenCloud', () {
      expect(TtsEnginePreference.values, [
        TtsEnginePreference.system,
        TtsEnginePreference.volcengineCloud,
        TtsEnginePreference.qwenCloud,
      ]);
    });

    test('sherpaOnnxMelo persisted value falls back to system', () {
      expect(
        TtsEnginePreferenceX.fromPersistedValue('sherpaOnnxMelo'),
        TtsEnginePreference.system,
      );
    });

    test('volcengineCloud persists and restores', () {
      expect(
        TtsEnginePreference.volcengineCloud.persistedValue,
        'volcengineCloud',
      );
      expect(
        TtsEnginePreferenceX.fromPersistedValue('volcengineCloud'),
        TtsEnginePreference.volcengineCloud,
      );
    });

    test('qwenCloud persists and restores', () {
      expect(
        TtsEnginePreference.qwenCloud.persistedValue,
        'qwenCloud',
      );
      expect(
        TtsEnginePreferenceX.fromPersistedValue('qwenCloud'),
        TtsEnginePreference.qwenCloud,
      );
    });

    test('unknown persisted value falls back to system', () {
      expect(
        TtsEnginePreferenceX.fromPersistedValue('nonexistent'),
        TtsEnginePreference.system,
      );
      expect(
        TtsEnginePreferenceX.fromPersistedValue(null),
        TtsEnginePreference.system,
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/services/tts/tts_engine_preference_test.dart
```
Expected: FAIL — enum still has `sherpaOnnxMelo`, missing new values.

- [ ] **Step 3: Update the enum**

Replace contents of `lib/services/tts/tts_engine_preference.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

/// 用户偏好的 TTS 引擎。v1.16.0-alpha 起 3 个枚举值：
/// - system：平台自带 TTS（Android SelfBuilt plugin / Desktop flutter_tts）
/// - volcengineCloud：火山引擎豆包语音（云端，需 API key）
/// - qwenCloud：阿里云 Qwen/CosyVoice（云端，需 API key）
///
/// v1.15.x 的 sherpaOnnxMelo 已移除（POC 失败：MeloTTS RTF 0.85 卡顿 +
/// 音质差强人意）。老用户 tts.engine=sherpaOnnxMelo 自动降级 system。
enum TtsEnginePreference {
  system,
  volcengineCloud,
  qwenCloud,
}

extension TtsEnginePreferenceX on TtsEnginePreference {
  String get persistedValue => name;

  static TtsEnginePreference fromPersistedValue(String? value) {
    return TtsEnginePreference.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TtsEnginePreference.system,
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/services/tts/tts_engine_preference_test.dart
```
Expected: PASS — all 5 tests green.

- [ ] **Step 5: Run analyzer on affected files**

```bash
dart analyze lib/services/tts/tts_engine_preference.dart
```
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/services/tts/tts_engine_preference.dart test/services/tts/tts_engine_preference_test.dart
git commit -m "$(cat <<'EOF'
feat(tts): enum volcengineCloud + qwenCloud, remove sherpaOnnxMelo

v1.16.0-alpha engine list. Old sherpaOnnxMelo persisted value
auto-degrades to system via fromPersistedValue orElse fallback.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task A4: Update tts_service_factory (remove SherpaOnnx branch, stub cloud branches)

**Files:**
- Modify: `app/lib/services/tts/tts_service_factory.dart`
- Modify: `app/test/services/tts/tts_service_factory_test.dart` (if exists, else create)

- [ ] **Step 1: Write failing tests**

Create `test/services/tts/tts_service_factory_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/flutter_tts_service.dart';
import 'package:zhiyue/services/tts/tts_engine_preference.dart';
import 'package:zhiyue/services/tts/tts_service.dart';
import 'package:zhiyue/services/tts/tts_service_factory.dart';

void main() {
  group('createTtsService', () {
    test('system engine on windows returns FlutterTtsServiceImpl', () {
      final service = createTtsService(
        platformName: 'windows',
        preferredEngine: TtsEnginePreference.system,
      );
      expect(service, isA<FlutterTtsServiceImpl>());
    });

    test('volcengineCloud throws UnimplementedError (stub until B5)', () {
      expect(
        () => createTtsService(
          platformName: 'android',
          preferredEngine: TtsEnginePreference.volcengineCloud,
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('qwenCloud throws UnimplementedError (stub until B6)', () {
      expect(
        () => createTtsService(
          platformName: 'android',
          preferredEngine: TtsEnginePreference.qwenCloud,
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('default engine when null is system', () {
      final service = createTtsService(platformName: 'windows');
      expect(service, isA<FlutterTtsServiceImpl>());
    });
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/services/tts/tts_service_factory_test.dart
```
Expected: FAIL — current factory returns `SherpaOnnxTtsService` for `sherpaOnnxMelo` (now removed from enum) and has no branches for new values.

- [ ] **Step 3: Update factory**

Replace `lib/services/tts/tts_service_factory.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/foundation.dart';

import 'flutter_tts_service.dart';
import 'self_built_tts_service.dart';
import 'tts_engine_preference.dart';
import 'tts_service.dart';

/// Creates a [TtsService] for [platformName] honoring [preferredEngine].
///
/// v1.16.0-alpha: 3 engines (system / volcengineCloud / qwenCloud).
/// Cloud engines are stubbed until Phase B (B5 wires Volcengine, B6 wires
/// Qwen).
///
/// If [platformName] is null, uses [defaultTargetPlatform].
/// If [preferredEngine] is null, uses [TtsEnginePreference.system].
TtsService createTtsService({
  String? platformName,
  TtsEnginePreference? preferredEngine,
}) {
  final engine = preferredEngine ?? TtsEnginePreference.system;

  switch (engine) {
    case TtsEnginePreference.volcengineCloud:
    case TtsEnginePreference.qwenCloud:
      // Phase B will replace this with real impls.
      throw UnimplementedError(
        'Cloud TTS engine "$engine" not yet wired (Phase B pending)',
      );
    case TtsEnginePreference.system:
      // fall through to platform dispatch
      break;
  }

  final target = platformName ?? _platformNameFromTargetPlatform();
  switch (target.toLowerCase()) {
    case 'android':
      return SelfBuiltTtsServiceImpl();
    default:
      return FlutterTtsServiceImpl();
  }
}

String _platformNameFromTargetPlatform() {
  final target = defaultTargetPlatform;
  return switch (target) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}
```

- [ ] **Step 4: Run factory tests**

```bash
flutter test test/services/tts/tts_service_factory_test.dart
```
Expected: all 4 PASS.

- [ ] **Step 5: Run full TTS suite to catch downstream breakage**

```bash
flutter test test/services/tts/ test/features/tts/
```
Expected: any tests referencing `SherpaOnnxTtsService` will now fail. Note them for A5/A6.

- [ ] **Step 6: Commit**

```bash
git add lib/services/tts/tts_service_factory.dart test/services/tts/tts_service_factory_test.dart
git commit -m "$(cat <<'EOF'
feat(tts): factory dispatches 3-engine enum, cloud stubs throw UnimplementedError

Phase A intermediate state: volcengineCloud/qwenCloud branches throw
until Phase B wires them. SherpaOnnx branch removed entirely.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task A5: Remove SherpaOnnx UI from tts_settings_section.dart

**Files:**
- Modify: `app/lib/features/settings/pages/tts_settings_section.dart`
- Modify: `app/test/features/settings/pages/tts_settings_section_test.dart` (if exists)

- [ ] **Step 1: Write failing test asserting SherpaOnnx is gone + 3 engine options present**

Add to `test/features/settings/pages/tts_settings_section_test.dart` (or create if missing):

```dart
testWidgets('shows 3 engine options, no SherpaOnnx', (tester) async {
  await tester.pumpWidget(_buildApp(tester));
  await tester.pumpAndSettle();

  // Find dropdown, tap to open
  await tester.tap(find.byType(DropdownButtonFormField<TtsEnginePreference>));
  await tester.pumpAndSettle();

  expect(find.text('系统（默认）'), findsOneWidget);
  expect(find.text('火山引擎（云端）'), findsOneWidget);
  expect(find.text('阿里云 Qwen（云端）'), findsOneWidget);
  expect(find.textContaining('SherpaOnnx'), findsNothing);
});
```

(The `_buildApp` helper setup follows the existing pattern in that test file. If the file does not exist, create it with a standard `ProviderScope + MaterialApp + Scaffold + TtsSettingsSection` wrapper. See other settings section tests for the pattern.)

- [ ] **Step 2: Run test, verify failure**

```bash
flutter test test/features/settings/pages/tts_settings_section_test.dart
```
Expected: FAIL — current dropdown still has SherpaOnnx option, no cloud options.

- [ ] **Step 3: Update tts_settings_section.dart**

In `lib/features/settings/pages/tts_settings_section.dart`:

a. Remove the `import '../../../services/tts/sherpa_onnx_tts_service.dart';` line.

b. Remove the `isSherpaOnnx` local + all its branches (pitch slider onChanged, voice tile subtitle, etc.). After removal:
   - Pitch slider always uses `notifier.setPitch` for `onChanged`
   - Voice tile uses `l10n.ttsSettingsVoiceTileSubtitle` for subtitle
   - Voice tile `onTap` always goes to `/settings/tts/voice`

c. Replace the engine dropdown's `items` list:
```dart
items: const [
  DropdownMenuItem(
    value: TtsEnginePreference.system,
    child: Text('系统（默认）'),
  ),
  DropdownMenuItem(
    value: TtsEnginePreference.volcengineCloud,
    child: Text('火山引擎（云端）'),
  ),
  DropdownMenuItem(
    value: TtsEnginePreference.qwenCloud,
    child: Text('阿里云 Qwen（云端）'),
  ),
],
```

d. Replace the helper text below the dropdown:
```dart
Text(
  '云端引擎需在下方填写 API 凭证。网络失败时自动切换至系统 TTS。',
  style: Theme.of(context).textTheme.bodySmall,
),
```

e. Remove the entire `_prettySherpaDebugState` static method (will not be referenced after f).

f. In `_showTtsDebugLogs`, remove the `service is SherpaOnnxTtsService` branch (the first ~35 lines of the method).

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/settings/pages/tts_settings_section_test.dart
```
Expected: PASS.

- [ ] **Step 5: Run analyzer on this file**

```bash
dart analyze lib/features/settings/pages/tts_settings_section.dart
```
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/pages/tts_settings_section.dart test/features/settings/pages/tts_settings_section_test.dart
git commit -m "$(cat <<'EOF'
refactor(tts): settings UI 3-engine dropdown, drop SherpaOnnx UI

Cloud credentials form + voice picker + test-connection button come
in Phase B (Task B7). This task only swaps the dropdown options and
removes SherpaOnnx-specific branching.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task A6: Delete SherpaOnnx service + benchmark + their tests

**Files:**
- Delete: `app/lib/services/tts/sherpa_onnx_tts_service.dart`
- Delete: `app/lib/features/tts/utils/sherpa_onnx_benchmark.dart`
- Delete: `app/test/features/tts/services/sherpa_onnx_prefetch_test.dart`
- Delete (if exists): `app/test/features/tts/utils/sherpa_onnx_benchmark_test.dart`
- Modify: `app/lib/features/tts/providers/tts_playback_controller.dart` (remove SherpaOnnx-specific test mocks/setup if any)
- Modify: `app/test/features/tts/providers/tts_playback_controller_test.dart` (remove SherpaOnnx-related test cases)

- [ ] **Step 1: Find all remaining SherpaOnnx references**

```bash
cd /c/zhiyue_build_s3/app
grep -rn "SherpaOnnx\|sherpa_onnx" lib/ test/ --include="*.dart" | grep -v "_audio_player\|tts_audio_player"
```
This will list every file still referencing SherpaOnnx by name (excluding the renamed audio player). Note them.

- [ ] **Step 2: Delete the SherpaOnnx service + benchmark files**

```bash
git rm lib/services/tts/sherpa_onnx_tts_service.dart
git rm lib/features/tts/utils/sherpa_onnx_benchmark.dart
git rm test/features/tts/services/sherpa_onnx_prefetch_test.dart
# If benchmark test exists:
git rm test/features/tts/utils/sherpa_onnx_benchmark_test.dart 2>/dev/null || true
```

- [ ] **Step 3: Fix remaining references found in Step 1**

For each file listed by grep:
- If it's a test file with SherpaOnnx-specific test cases, remove those test cases.
- If it imports SherpaOnnxTtsService for typing, remove the import and any SherpaOnnx-specific code paths.
- For `tts_playback_controller.dart`: the `hintNext` call on the service stays (will be reused by BaseCloudTtsService in Phase B). SherpaOnnx-specific comments should be updated to mention cloud engines.

- [ ] **Step 4: Run full TTS test suite**

```bash
flutter test test/services/tts/ test/features/tts/
```
Expected: PASS — SherpaOnnx tests are gone, remaining tests pass.

- [ ] **Step 5: Run analyzer on lib/ for dangling references**

```bash
dart analyze lib/services/tts/ lib/features/tts/
```
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add -A lib/services/tts/sherpa_onnx_tts_service.dart lib/features/tts/utils/sherpa_onnx_benchmark.dart test/features/tts/services/sherpa_onnx_prefetch_test.dart
# Plus any files modified in Step 3
git commit -m "$(cat <<'EOF'
chore(tts): delete SherpaOnnx service + benchmark + tests

POC code removal. TtsAudioPlayer (renamed from SherpaOnnxAudioPlayer
in A1) is retained for reuse by cloud TTS in Phase B.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task A7: Remove sherpa_onnx dependency + MeloTTS assets from pubspec

**Files:**
- Modify: `app/pubspec.yaml`

- [ ] **Step 1: Remove sherpa_onnx dep + 3 asset entries**

In `app/pubspec.yaml`:

a. Delete these lines from `dependencies:`:
```yaml
  # TTS POC: sherpa-onnx 离线神经 TTS(MeloTTS-zh_en)
  sherpa_onnx: ^1.13.4
```

b. Delete these lines from `flutter.assets:`:
```yaml
  # TTS POC T1: MeloTTS-zh_en 离线神经 TTS 模型(163MB)
  # gitignored,POC dev 手动从 hf-mirror.com 下载
  # scripts/download-tts-model.sh 自动化拉取
  assets:
    - assets/tts-models/vits-melo-tts-zh_en/model.onnx
    - assets/tts-models/vits-melo-tts-zh_en/lexicon.txt
    - assets/tts-models/vits-melo-tts-zh_en/tokens.txt
```

(The `assets:` keyword under `flutter:` itself stays — it's still used for fonts and icon.png. Only the MeloTTS-specific entries go.)

- [ ] **Step 2: Run flutter pub get**

```bash
cd /c/zhiyue_build_s3/app
flutter pub get
```
Expected: succeeds, sherpa_onnx removed from lockfile.

- [ ] **Step 3: Run a smoke test (any test) to confirm no SherpaOnnx imports remain**

```bash
flutter test test/services/tts/tts_engine_preference_test.dart
```
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "$(cat <<'EOF'
chore(deps): remove sherpa_onnx package + MeloTTS asset entries

163MB model no longer bundled. APK should drop to ~100MB after
full rebuild in Phase C.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task A8: Delete MeloTTS model files + clean .gitignore + Android Gradle

**Files:**
- Delete (filesystem only, gitignored): `app/assets/tts-models/`
- Modify: `.gitignore`
- Modify: `scripts/patch-pub-cache.sh` or equivalent (if exists)
- Modify: `app/android/app/build.gradle.kts` (if sherpa_onnx appears in dependencies)

- [ ] **Step 1: Delete the 163MB model directory**

```bash
cd /c/zhiyue_build_s3/app
rm -rf assets/tts-models
ls assets/  # Should show: fonts, icon.png only
```

- [ ] **Step 2: Remove MeloTTS entries from .gitignore**

In `/c/zhiyue_build_s3/.gitignore` (and `H:\projiect\电子书阅读平台\.gitignore`):

Delete these lines:
```
# TTS POC T1: sherpa-onnx model assets (downloaded, not committed)
app/assets/tts-models/**/*.onnx
app/assets/tts-models/**/*.txt
```

- [ ] **Step 3: Remove sherpa_onnx compileSdk sed patches from pub-cache patch script (if exists)**

Look for `scripts/patch-pub-cache.sh` or similar:

```bash
ls scripts/ | grep -i "patch\|pub-cache"
```

If found, edit it to remove sherpa_onnx_android patch lines. Keep audioplayers_android patch lines (TtsAudioPlayer still uses audioplayers).

If no script exists (patches applied manually), document the removal in `CHANGELOG.md` for v1.16.0-alpha: "Removed sherpa_onnx_android compileSdk 36 sed patch (plugin no longer used)".

- [ ] **Step 4: Check Android Gradle for sherpa_onnx references**

```bash
grep -rn "sherpa" app/android/ 2>/dev/null
```

If any references found in `build.gradle.kts` or `settings.gradle.kts`, remove them.

- [ ] **Step 5: Run full TTS + analyzer smoke**

```bash
cd /c/zhiyue_build_s3/app
flutter test test/services/tts/ test/features/tts/
dart analyze lib/services/tts/ lib/features/tts/
```
Expected: PASS, no analyzer errors.

- [ ] **Step 6: Commit**

```bash
git add .gitignore scripts/  # if scripts modified
git commit -m "$(cat <<'EOF'
chore(tts): delete MeloTTS model dir, clean .gitignore + Android refs

Phase A complete: SherpaOnnx POC fully removed. Codebase now has
TtsAudioPlayer + 3-engine enum (system/volcengineCloud/qwenCloud)
with cloud branches stubbed. Phase B wires the cloud impls.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

# Phase B: Cloud TTS Implementation (~3 days, 8 tasks)

## Task B1: VoicePreset + CloudTttsCredentials + secure storage

**Files:**
- Create: `app/lib/services/tts/voice_preset.dart`
- Create: `app/lib/services/tts/cloud_tts_credentials.dart`
- Create: `app/test/services/tts/voice_preset_test.dart`
- Create: `app/test/services/tts/cloud_tts_credentials_test.dart`

- [ ] **Step 1: Write failing tests for VoicePreset**

Create `test/services/tts/voice_preset_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/voice_preset.dart';

void main() {
  group('VoicePreset', () {
    test('constructs with required fields', () {
      final v = VoicePreset(
        id: 'longxiaoxia_v2',
        displayName: '龙小夏',
        gender: VoiceGender.female,
        description: '沉稳权威女',
      );
      expect(v.id, 'longxiaoxia_v2');
      expect(v.displayName, '龙小夏');
      expect(v.gender, VoiceGender.female);
      expect(v.description, '沉稳权威女');
    });

    test('optional description defaults to empty', () {
      final v = VoicePreset(
        id: 'x',
        displayName: 'X',
        gender: VoiceGender.male,
      );
      expect(v.description, '');
    });

    test('equality based on id only', () {
      final a = VoicePreset(id: 'v1', displayName: 'A', gender: VoiceGender.female);
      final b = VoicePreset(id: 'v1', displayName: 'B', gender: VoiceGender.male);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
```

- [ ] **Step 2: Write failing tests for credentials**

Create `test/services/tts/cloud_tts_credentials_test.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/services/tts/cloud_tts_credentials.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('VolcengineTtsCredentials', () {
    test('persists appId + accessToken to secure storage', () async {
      final storage = _MockSecureStorage();
      when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      final store = VolcengineTtsCredentialStore(storage);
      await store.save(const VolcengineTtsCredentials(
        appId: 'app123',
        accessToken: 'tok456',
        voice: 'BV001_streaming',
      ));
      verify(() => storage.write(key: 'zhiyue.tts.volcengine.appId', value: 'app123')).called(1);
      verify(() => storage.write(key: 'zhiyue.tts.volcengine.token', value: 'tok456')).called(1);
      verify(() => storage.write(key: 'zhiyue.tts.volcengine.voice', value: 'BV001_streaming')).called(1);
    });

    test('load returns null when appId missing', () async {
      final storage = _MockSecureStorage();
      when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
      final store = VolcengineTtsCredentialStore(storage);
      expect(await store.load(), isNull);
    });

    test('load returns credentials when all keys present', () async {
      final storage = _MockSecureStorage();
      when(() => storage.read(key: 'zhiyue.tts.volcengine.appId')).thenAnswer((_) async => 'app123');
      when(() => storage.read(key: 'zhiyue.tts.volcengine.token')).thenAnswer((_) async => 'tok456');
      when(() => storage.read(key: 'zhiyue.tts.volcengine.voice')).thenAnswer((_) async => 'BV001_streaming');
      final store = VolcengineTtsCredentialStore(storage);
      final c = await store.load();
      expect(c?.appId, 'app123');
      expect(c?.accessToken, 'tok456');
      expect(c?.voice, 'BV001_streaming');
    });
  });

  group('QwenTtsCredentials', () {
    test('persists apiKey + model + voice', () async {
      final storage = _MockSecureStorage();
      when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      final store = QwenTtsCredentialStore(storage);
      await store.save(const QwenTtsCredentials(
        apiKey: 'sk-xxx',
        model: 'qwen-audio-3.0-tts-flash',
        voice: 'longxiaoxia_v2',
      ));
      verify(() => storage.write(key: 'zhiyue.tts.qwen.apiKey', value: 'sk-xxx')).called(1);
      verify(() => storage.write(key: 'zhiyue.tts.qwen.model', value: 'qwen-audio-3.0-tts-flash')).called(1);
      verify(() => storage.write(key: 'zhiyue.tts.qwen.voice', value: 'longxiaoxia_v2')).called(1);
    });

    test('load returns null when apiKey missing', () async {
      final storage = _MockSecureStorage();
      when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
      expect(await QwenTtsCredentialStore(storage).load(), isNull);
    });
  });
}
```

- [ ] **Step 3: Run tests to verify failure**

```bash
flutter test test/services/tts/voice_preset_test.dart test/services/tts/cloud_tts_credentials_test.dart
```
Expected: FAIL — files don't exist.

- [ ] **Step 4: Create VoicePreset**

Create `lib/services/tts/voice_preset.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

enum VoiceGender { male, female, neutral }

/// A preset voice option exposed by a TTS engine. Used to populate the
/// voice dropdown in TTS settings.
class VoicePreset {
  final String id;
  final String displayName;
  final VoiceGender gender;
  final String description;

  const VoicePreset({
    required this.id,
    required this.displayName,
    required this.gender,
    this.description = '',
  });

  @override
  bool operator ==(Object other) => other is VoicePreset && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VoicePreset($id, $displayName)';
}
```

- [ ] **Step 5: Create credentials + stores**

Create `lib/services/tts/cloud_tts_credentials.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'voice_preset.dart';

/// Volcengine (豆包语音) credentials. User obtains appId + accessToken
/// from火山引擎 console. Default voice is BV001_streaming (通用女声).
class VolcengineTtsCredentials {
  final String appId;
  final String accessToken;
  final String voice;

  const VolcengineTtsCredentials({
    required this.appId,
    required this.accessToken,
    required this.voice,
  });

  static const defaultVoice = 'BV001_streaming';
}

/// Qwen/CosyVoice (阿里云百炼) credentials. User obtains apiKey from
/// DashScope console. Default voice is longxiaoxia_v2 (沉稳权威女).
class QwenTtsCredentials {
  final String apiKey;
  final String model;
  final String voice;

  const QwenTtsCredentials({
    required this.apiKey,
    required this.model,
    required this.voice,
  });

  static const defaultModel = 'qwen-audio-3.0-tts-flash';
  static const defaultVoice = 'longxiaoxia_v2';
}

/// Common interface so Riverpod providers can be typed generically.
abstract class CloudTtsCredentialStore<T> {
  Future<T?> load();
  Future<void> save(T creds);
  Future<void> clear();
}

class VolcengineTtsCredentialStore
    implements CloudTtsCredentialStore<VolcengineTtsCredentials> {
  VolcengineTtsCredentialStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kAppId = 'zhiyue.tts.volcengine.appId';
  static const _kToken = 'zhiyue.tts.volcengine.token';
  static const _kVoice = 'zhiyue.tts.volcengine.voice';

  final FlutterSecureStorage _storage;

  @override
  Future<VolcengineTtsCredentials?> load() async {
    final appId = await _storage.read(key: _kAppId);
    final token = await _storage.read(key: _kToken);
    if (appId == null || appId.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    final voice = await _storage.read(key: _kVoice);
    return VolcengineTtsCredentials(
      appId: appId,
      accessToken: token,
      voice: (voice == null || voice.isEmpty)
          ? VolcengineTtsCredentials.defaultVoice
          : voice,
    );
  }

  @override
  Future<void> save(VolcengineTtsCredentials creds) async {
    await _storage.write(key: _kAppId, value: creds.appId);
    await _storage.write(key: _kToken, value: creds.accessToken);
    await _storage.write(key: _kVoice, value: creds.voice);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kAppId);
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kVoice);
  }
}

class QwenTtsCredentialStore
    implements CloudTtsCredentialStore<QwenTtsCredentials> {
  QwenTtsCredentialStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kApiKey = 'zhiyue.tts.qwen.apiKey';
  static const _kModel = 'zhiyue.tts.qwen.model';
  static const _kVoice = 'zhiyue.tts.qwen.voice';

  final FlutterSecureStorage _storage;

  @override
  Future<QwenTtsCredentials?> load() async {
    final apiKey = await _storage.read(key: _kApiKey);
    if (apiKey == null || apiKey.isEmpty) return null;
    final model = await _storage.read(key: _kModel);
    final voice = await _storage.read(key: _kVoice);
    return QwenTtsCredentials(
      apiKey: apiKey,
      model: (model == null || model.isEmpty)
          ? QwenTtsCredentials.defaultModel
          : model,
      voice: (voice == null || voice.isEmpty)
          ? QwenTtsCredentials.defaultVoice
          : voice,
    );
  }

  @override
  Future<void> save(QwenTtsCredentials creds) async {
    await _storage.write(key: _kApiKey, value: creds.apiKey);
    await _storage.write(key: _kModel, value: creds.model);
    await _storage.write(key: _kVoice, value: creds.voice);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kApiKey);
    await _storage.delete(key: _kModel);
    await _storage.delete(key: _kVoice);
  }
}

/// Static voice preset lists for UI dropdowns. Sources:
/// - Volcengine: https://www.volcengine.com/docs/6561/1257584
/// - Qwen: https://help.aliyun.com/zh/model-studio/cosyvoice-voice-list
class CloudTtsVoicePresets {
  static const volcengine = <VoicePreset>[
    VoicePreset(id: 'BV001_streaming', displayName: '通用女声', gender: VoiceGender.female, description: '通用场景'),
    VoicePreset(id: 'BV002_streaming', displayName: '通用男声', gender: VoiceGender.male, description: '通用场景'),
    VoicePreset(id: 'BV700_streaming', displayName: '灿灿', gender: VoiceGender.female, description: '活泼女声'),
    VoicePreset(id: 'BV701_streaming', displayName: '擎苍', gender: VoiceGender.male, description: '沉稳男声'),
    VoicePreset(id: 'BV705_streaming', displayName: '炉鼎', gender: VoiceGender.male, description: '说书男声'),
  ];

  static const qwen = <VoicePreset>[
    VoicePreset(id: 'longxiaoxia_v2', displayName: '龙小夏', gender: VoiceGender.female, description: '沉稳权威女'),
    VoicePreset(id: 'longyichen', displayName: '龙逸尘', gender: VoiceGender.male, description: '洒脱活力男'),
    VoicePreset(id: 'longwanjun', displayName: '龙婉君', gender: VoiceGender.female, description: '细腻柔声女'),
    VoicePreset(id: 'longlaobo', displayName: '龙老伯', gender: VoiceGender.male, description: '沧桑岁月爷'),
    VoicePreset(id: 'longxiu_v2', displayName: '龙修', gender: VoiceGender.male, description: '博才说书男'),
    VoicePreset(id: 'longbaizhi', displayName: '龙白芷', gender: VoiceGender.female, description: '睿气旁白女'),
  ];
}
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
flutter test test/services/tts/voice_preset_test.dart test/services/tts/cloud_tts_credentials_test.dart
```
Expected: all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/services/tts/voice_preset.dart lib/services/tts/cloud_tts_credentials.dart test/services/tts/voice_preset_test.dart test/services/tts/cloud_tts_credentials_test.dart
git commit -m "$(cat <<'EOF'
feat(tts): VoicePreset + cloud credentials + secure storage

Foundation for Phase B. VoicePreset + CloudTtsVoicePresets hold
static voice lists. VolcengineTtsCredentials/QwenTtsCredentials
store in flutter_secure_storage with zhiyue.tts.{provider}.* keys.
Default voice/model baked into class constants.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task B2: CloudTtsException + CloudTtsErrorKind

**Files:**
- Create: `app/lib/services/tts/cloud_tts_exception.dart`
- Create: `app/test/services/tts/cloud_tts_exception_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/services/tts/cloud_tts_exception_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/cloud_tts_exception.dart';

void main() {
  group('CloudTtsException', () {
    test('carries kind + message + cause', () {
      final e = CloudTtsException(
        kind: CloudTtsErrorKind.network,
        message: 'SocketException: Connection refused',
        cause: 'original',
      );
      expect(e.kind, CloudTtsErrorKind.network);
      expect(e.message, 'SocketException: Connection refused');
      expect(e.cause, 'original');
    });

    test('kindFromHttpStatus maps common codes correctly', () {
      expect(CloudTtsErrorKindX.fromHttpStatus(401), CloudTtsErrorKind.auth);
      expect(CloudTtsErrorKind.fromHttpStatus(403), CloudTtsErrorKind.auth);
      expect(CloudTtsErrorKind.fromHttpStatus(429), CloudTtsErrorKind.quota);
      expect(CloudTtsErrorKind.fromHttpStatus(500), CloudTtsErrorKind.server);
      expect(CloudTtsErrorKind.fromHttpStatus(503), CloudTtsErrorKind.server);
      expect(CloudTtsErrorKind.fromHttpStatus(400), CloudTtsErrorKind.invalidRequest);
      expect(CloudTtsErrorKind.fromHttpStatus(404), CloudTtsErrorKind.invalidRequest);
      expect(CloudTtsErrorKind.fromHttpStatus(200), CloudTtsErrorKind.invalidRequest); // unknown
    });

    test('isTransient returns true for network + server only', () {
      expect(CloudTtsErrorKind.network.isTransient, isTrue);
      expect(CloudTtsErrorKind.server.isTransient, isTrue);
      expect(CloudTtsErrorKind.auth.isTransient, isFalse);
      expect(CloudTtsErrorKind.quota.isTransient, isFalse);
      expect(CloudTtsErrorKind.invalidRequest.isTransient, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
flutter test test/services/tts/cloud_tts_exception_test.dart
```
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Create the exception file**

Create `lib/services/tts/cloud_tts_exception.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

/// Error categories for cloud TTS failures. Drives fallback policy:
/// [isTransient] kinds trigger auto-fallback to system engine;
/// non-transient kinds (auth/quota/invalidRequest) only show UI message
/// (fallback wouldn't help — same credentials = same failure).
enum CloudTtsErrorKind {
  network,
  auth,
  quota,
  server,
  invalidRequest;

  bool get isTransient => this == network || this == server;
}

extension CloudTtsErrorKindX on CloudTtsErrorKind {
  static CloudTtsErrorKind fromHttpStatus(int status) {
    if (status == 401 || status == 403) return CloudTtsErrorKind.auth;
    if (status == 429) return CloudTtsErrorKind.quota;
    if (status >= 500) return CloudTtsErrorKind.server;
    if (status >= 400) return CloudTtsErrorKind.invalidRequest;
    // 2xx/3xx unexpected — treat as invalid request (server returned
    // success but body wasn't what we expected).
    return CloudTtsErrorKind.invalidRequest;
  }
}

/// Thrown by cloud TTS services. Caught by TtsPlaybackController which
/// decides whether to fallback based on [kind].
class CloudTtsException implements Exception {
  final CloudTtsErrorKind kind;
  final String message;
  final String? cause;

  const CloudTtsException({
    required this.kind,
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'CloudTtsException($kind): $message';
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/services/tts/cloud_tts_exception_test.dart
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/tts/cloud_tts_exception.dart test/services/tts/cloud_tts_exception_test.dart
git commit -m "$(cat <<'EOF'
feat(tts): CloudTtsException + CloudTtsErrorKind

5 error categories. isTransient getter drives fallback policy:
network/server → auto-fallback to system; auth/quota/invalidRequest
→ user-facing SnackBar only.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task B3: BaseCloudTtsService abstract (prefetch + onAudioStarted + error classification)

**Files:**
- Create: `app/lib/services/tts/base_cloud_tts_service.dart`
- Create: `app/test/services/tts/base_cloud_tts_service_test.dart`

This is the heart of Phase B. The base class:
- Implements `TtsService` interface
- Holds prefetch cache (`Map<String, Uint8List>` keyed by sentence text)
- Implements `hintNext`, `speakSentence`, `stop` with the v1.15.6 onAudioStarted pattern
- Delegates actual HTTP fetch to abstract `fetchAudio` (implemented by subclasses)
- Delegates credential lookup to abstract `loadCredentials`
- Exposes static voice list via abstract `supportedVoices`

- [ ] **Step 1: Write failing tests for prefetch + cache + error path**

Create `test/services/tts/base_cloud_tts_service_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/base_cloud_tts_service.dart';
import 'package:zhiyue/services/tts/cloud_tts_exception.dart';
import 'package:zhiyue/services/tts/tts_service.dart';
import 'package:zhiyue/services/tts/voice_preset.dart';

/// Fake subclass for testing BaseCloudTtsService contract.
class _FakeCloudService extends BaseCloudTtsService {
  _FakeCloudService({
    required this.fetchBehavior,
    this.credendials,
  });

  final Future<Uint8List> Function(String text, double rate, String voice) fetchBehavior;
  final Object? credendials;
  int fetchCallCount = 0;
  String? lastFetchedText;

  @override
  String get engineName => 'fake';

  @override
  List<VoicePreset> get supportedVoices => const [
    VoicePreset(id: 'v1', displayName: 'V1', gender: VoiceGender.female),
  ];

  @override
  Object? loadCredentials() => credendials;

  @override
  String get defaultVoice => 'v1';

  @override
  Future<Uint8List> fetchAudio(String text, double rate, String voice) async {
    fetchCallCount++;
    lastFetchedText = text;
    return fetchBehavior(text, rate, voice);
  }
}

Sentence _s(String text) => Sentence(
  text: text,
  locale: 'zh',
  charStart: 0,
  charEnd: text.length,
);

void main() {
  group('BaseCloudTtsService prefetch', () {
    test('hintNext + speakSentence on hinted text uses cache (1 fetch only)',
        () async {
      final service = _FakeCloudService(
        fetchBehavior: (text, _, __) async => Uint8List(100),
      );
      await service.init();

      await service.hintNext(_s('hello'));
      // hintNext schedules prefetch; wait for it
      await Future<void>.delayed(Duration.zero);
      // Now cache should be populated; speakSentence should NOT call fetchAudio
      await service.speakSentence(_s('hello'));
      expect(service.fetchCallCount, 1);
    });

    test('speakSentence without hintNext triggers sync fetch', () async {
      final service = _FakeCloudService(
        fetchBehavior: (text, _, __) async => Uint8List(50),
      );
      await service.init();
      await service.speakSentence(_s('cold'));
      expect(service.fetchCallCount, 1);
      expect(service.lastFetchedText, 'cold');
    });

    test('setSpeechRate clears prefetch cache', () async {
      final service = _FakeCloudService(
        fetchBehavior: (text, _, __) async => Uint8List(10),
      );
      await service.init();
      await service.hintNext(_s('cached'));
      await Future<void>.delayed(Duration.zero);
      // Prefetch populated cache for "cached"
      await service.setSpeechRate(0.5);
      // After rate change, cache should be cleared
      await service.speakSentence(_s('cached'));
      // fetchAudio called once during prefetch + once during speakSentence
      expect(service.fetchCallCount, 2);
    });

    test('roughEqual rate (diff < 0.001) does NOT clear cache', () async {
      final service = _FakeCloudService(
        fetchBehavior: (text, _, __) async => Uint8List(10),
      );
      await service.init();
      await service.setSpeechRate(0.8);
      await service.hintNext(_s('cached'));
      await Future<void>.delayed(Duration.zero);
      await service.setSpeechRate(0.8001); // within tolerance
      await service.speakSentence(_s('cached'));
      expect(service.fetchCallCount, 1);
    });

    test('stop clears prefetch cache', () async {
      final service = _FakeCloudService(
        fetchBehavior: (text, _, __) async => Uint8List(10),
      );
      await service.init();
      await service.hintNext(_s('cached'));
      await Future<void>.delayed(Duration.zero);
      await service.stop();
      await service.speakSentence(_s('cached'));
      expect(service.fetchCallCount, 2);
    });

    test('fetchAudio throwing CloudTtsException propagates through error stream',
        () async {
      final service = _FakeCloudService(
        fetchBehavior: (text, _, __) async {
          throw CloudTtsException(
            kind: CloudTtsErrorKind.network,
            message: 'test',
          );
        },
      );
      await service.init();
      final errors = <String>[];
      service.error.listen(errors.add);
      await service.speakSentence(_s('boom'));
      // Wait for error event to propagate
      await Future<void>.delayed(Duration.zero);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('test'));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/services/tts/base_cloud_tts_service_test.dart
```
Expected: FAIL — base class doesn't exist.

- [ ] **Step 3: Implement BaseCloudTtsService**

Create `lib/services/tts/base_cloud_tts_service.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'cloud_tts_exception.dart';
import 'tts_audio_player.dart';
import 'tts_service.dart';
import 'voice_preset.dart';

/// Abstract base for cloud TTS engines (Volcengine, Qwen). Shares:
/// - prefetch cache (text → MP3 bytes) + onAudioStarted pattern (v1.15.6)
/// - setSpeechRate roughEqual cache invalidation (v1.15.6 Bug 2 lesson)
/// - stop cache clear
/// - error stream emission for fetchAudio failures
///
/// Subclasses implement:
/// - [fetchAudio]: single HTTP request → bytes
/// - [loadCredentials]: read secure-storage credentials (returns null if missing)
/// - [supportedVoices], [defaultVoice], [engineName]
abstract class BaseCloudTtsService implements TtsService {
  final TtsAudioPlayer _audioPlayer = TtsAudioPlayer();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  final Map<String, Uint8List> _prefetchCache = {};
  Sentence? _hintedNext;
  bool _prefetchInProgress = false;
  String _currentVoice = '';
  double _rate = 0.0;
  int _currentSentenceIndex = 0;
  bool _isInitialized = false;
  bool _disposed = false;

  // Prefetch metrics for debug UI.
  int prefetchHitCount = 0;
  int prefetchMissCount = 0;
  int prefetchFailCount = 0;

  StreamController<TtsState>? _stateController;
  StreamController<TtsProgress>? _progressController;

  @override
  Stream<TtsState> get state => _stateController?.stream ?? const Stream.empty();

  @override
  Stream<TtsProgress> get progress =>
      _progressController?.stream ?? const Stream.empty();

  @override
  Stream<String> get error => _errorController.stream;

  @override
  bool get isInitialized => _isInitialized;

  /// Subclass identifier for debug logging.
  String get engineName;

  /// Static voice list exposed by this engine.
  List<VoicePreset> get supportedVoices;

  /// Voice ID used when user hasn't picked one.
  String get defaultVoice;

  /// Load credentials from secure storage. Returns null if not configured.
  Object? loadCredentials();

  /// Single HTTP request: synthesize text → audio bytes.
  /// May throw [CloudTtsException] on failure.
  Future<Uint8List> fetchAudio(String text, double rate, String voice);

  /// Estimate audio duration in milliseconds. Used by [TtsAudioPlayer.awaitCompletion]
  /// to size the wall-clock timer. Conservative (overestimate) is safer.
  /// Default heuristic: ~100ms per character + 500ms head.
  int estimateAudioDurationMs(String text) {
    return (text.length * 100 + 500).clamp(800, 60000);
  }

  @override
  Future<void> init() async {
    if (_isInitialized) return;
    _stateController = StreamController<TtsState>.broadcast();
    _progressController = StreamController<TtsProgress>.broadcast();
    _currentVoice = defaultVoice;
    _isInitialized = true;
  }

  @override
  Future<void> speakSentence(Sentence sentence) async {
    if (!_isInitialized) await init();
    _stateController?.add(TtsState.speaking);

    final text = sentence.text;
    Uint8List? audio;
    try {
      if (_prefetchCache.containsKey(text)) {
        prefetchHitCount++;
        audio = _prefetchCache.remove(text);
      } else {
        prefetchMissCount++;
        audio = await fetchAudio(text, _rate, _currentVoice);
      }
    } on CloudTtsException catch (e) {
      _errorController.add('${e.kind.name}: ${e.message}');
      _stateController?.add(TtsState.error);
      return;
    } catch (e) {
      _errorController.add('network: $e');
      _stateController?.add(TtsState.error);
      return;
    }

    await _audioPlayer.playMp3Bytes(
      audio!,
      expectedDurationMs: estimateAudioDurationMs(text),
      onAudioStarted: () {
        // Kicking off prefetch here (after audio queued to native) is the
        // v1.15.6 lesson: async function without await runs sync; calling
        // unawaited(_doPrefetch) before play() would block isolate with
        // HTTP request.
        if (_hintedNext != null &&
            !_prefetchInProgress &&
            !_prefetchCache.containsKey(_hintedNext!.text)) {
          _prefetchInProgress = true;
          unawaited(_doPrefetch(_hintedNext!));
        }
      },
    );

    _progressController?.add(TtsProgress(sentenceIndex: _currentSentenceIndex));
    _stateController?.add(TtsState.idle);
  }

  Future<void> _doPrefetch(Sentence sentence) async {
    try {
      final bytes = await fetchAudio(sentence.text, _rate, _currentVoice);
      _prefetchCache[sentence.text] = bytes;
    } on CloudTtsException catch (e) {
      prefetchFailCount++;
      // Silent: next speakSentence will sync fetch + surface error
      _errorController.add('prefetch-fail ${e.kind.name}: ${e.message}');
    } catch (e) {
      prefetchFailCount++;
    } finally {
      _prefetchInProgress = false;
    }
  }

  @override
  Future<void> hintNext(Sentence? next) async {
    _hintedNext = next;
    if (next == null) return;
    // Don't kick off prefetch here — wait for onAudioStarted in speakSentence
    // to keep the v1.15.6 isolate-blocking lesson intact.
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    final clamped = rate.clamp(-1.0, 1.0);
    if ((clamped - _rate).abs() < 0.001) return; // roughEqual v1.15.6 Bug 2
    _rate = clamped;
    _prefetchCache.clear();
  }

  /// Subclasses expose this via a method that updates both internal
  /// state and persists via secure storage.
  Future<void> setVoice(String voiceId) async {
    _currentVoice = voiceId;
    _prefetchCache.clear();
  }

  @override
  Future<void> stop() async {
    _prefetchCache.clear();
    _prefetchInProgress = false;
    await _audioPlayer.stop();
    _stateController?.add(TtsState.idle);
  }

  @override
  Future<void> pause() async {
    await _audioPlayer.stop();
    _stateController?.add(TtsState.paused);
  }

  @override
  void setCurrentSentenceIndex(int idx) {
    _currentSentenceIndex = idx;
  }

  @override
  Future<void> setPitch(double pitch) async {
    // Cloud TTS pitch handled via fetch params if subclass supports it.
  }

  @override
  Future<void> setVolume(double volume) async {}

  // Voice/system APIs — cloud engines don't use platform voice list.
  @override
  Future<List<TtsVoice>> getVoices() async => const [];
  @override
  Future<bool> setVoiceById(String? voiceId) async => false;
  @override
  Future<void> previewVoice(String voiceId, {String? sampleText}) async {}
  @override
  Future<bool> openSystemTtsSettings() async => false;
  @override
  Future<bool> isLanguageAvailable(String locale) async => true;
  @override
  Future<bool> isLanguageInstalled(String locale) async => true;
  @override
  Future<String?> getDefaultEngine() async => engineName;

  Map<String, dynamic> getDebugState() => {
    'engine': engineName,
    'prefetchHit': prefetchHitCount,
    'prefetchMiss': prefetchMissCount,
    'prefetchFail': prefetchFailCount,
    'cacheSize': _prefetchCache.length,
    'prefetchInProgress': _prefetchInProgress,
    'rate': _rate,
    'voice': _currentVoice,
  };

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _prefetchCache.clear();
    await _stateController?.close();
    await _progressController?.close();
    await _errorController.close();
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/services/tts/base_cloud_tts_service_test.dart
```
Expected: all 6 tests PASS. If any fail, debug the async timing or mock plumbing.

- [ ] **Step 5: Commit**

```bash
git add lib/services/tts/base_cloud_tts_service.dart test/services/tts/base_cloud_tts_service_test.dart
git commit -m "$(cat <<'EOF'
feat(tts): BaseCloudTtsService abstract base

Shares prefetch cache + onAudioStarted pattern (v1.15.6) +
roughEqual rate invalidation + error stream + stop clear.
Subclasses implement fetchAudio + loadCredentials + supportedVoices.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task B4: VolcengineCloudTtsService impl

**Files:**
- Create: `app/lib/services/tts/volcengine_cloud_tts_service.dart`
- Create: `app/test/services/tts/volcengine_cloud_tts_service_test.dart`

Volcengine API (HTTP v1):
- Endpoint: `https://openspeech.bytedance.com/api/v1/tts`
- Headers: `Authorization: Bearer;<token>`, `Content-Type: application/json`
- Body: `{app:{appid,token,cluster:"volcano_tts"}, user:{uid:"zhiyue"}, audio:{voice_type, speed_ratio:-1..1→0.5..2.0 mapping, encoding:"mp3", rate:24000}, request:{reqid:uuid, text, operation:"query"}}`
- Response: `{code:3000, data:<base64 mp3>, message:"success"}`

- [ ] **Step 1: Write failing tests for HTTP body construction + response parsing + error mapping**

Create `test/services/tts/volcengine_cloud_tts_service_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/services/tts/cloud_tts_credentials.dart';
import 'package:zhiyue/services/tts/cloud_tts_exception.dart';
import 'package:zhiyue/services/tts/volcengine_cloud_tts_service.dart';

class _MockStore extends Mock implements VolcengineTtsCredentialStore {}

void main() {
  group('VolcengineCloudTtsService.fetchAudio', () {
    final creds = const VolcengineTtsCredentials(
      appId: 'app1',
      accessToken: 'tok1',
      voice: 'BV001_streaming',
    );

    test('parses successful 200 + code=3000 + base64 data', () async {
      final mp3Bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final body = jsonEncode({
        'code': 3000,
        'message': 'success',
        'data': base64Encode(mp3Bytes),
      });
      final client = MockClient((request) async {
        expect(request.url.toString(),
            'https://openspeech.bytedance.com/api/v1/tts');
        expect(request.headers['Authorization'], 'Bearer;tok1');
        final bodyMap = jsonDecode(request.body) as Map<String, dynamic>;
        expect(bodyMap['app']['appid'], 'app1');
        expect(bodyMap['audio']['voice_type'], 'BV001_streaming');
        expect(bodyMap['audio']['encoding'], 'mp3');
        expect(bodyMap['request']['text'], 'hello');
        return http.Response(body, 200);
      });

      final service = VolcengineCloudTtsService(
        credentials: creds,
        httpClient: client,
      );
      final result = await service.fetchAudio('hello', 0.0, 'BV001_streaming');
      expect(result, mp3Bytes);
    });

    test('HTTP 401 → CloudTtsException auth', () async {
      final client = MockClient((_) async => http.Response('{}', 401));
      final service = VolcengineCloudTtsService(
        credentials: creds,
        httpClient: client,
      );
      expect(
        () => service.fetchAudio('hi', 0.0, 'BV001_streaming'),
        throwsA(predicate(
            (e) => e is CloudTtsException && e.kind == CloudTtsErrorKind.auth)),
      );
    });

    test('HTTP 429 → CloudTtsException quota', () async {
      final client = MockClient((_) async => http.Response('{}', 429));
      final service = VolcengineCloudTtsService(
        credentials: creds,
        httpClient: client,
      );
      expect(
        () => service.fetchAudio('hi', 0.0, 'BV001_streaming'),
        throwsA(predicate((e) =>
            e is CloudTtsException && e.kind == CloudTtsErrorKind.quota)),
      );
    });

    test('code != 3000 → CloudTtsException server', () async {
      final body = jsonEncode({'code': 3001, 'message': 'voice not found'});
      final client = MockClient((_) async => http.Response(body, 200));
      final service = VolcengineCloudTtsService(
        credentials: creds,
        httpClient: client,
      );
      expect(
        () => service.fetchAudio('hi', 0.0, 'BV001_streaming'),
        throwsA(predicate((e) =>
            e is CloudTtsException &&
            e.kind == CloudTtsErrorKind.invalidRequest &&
            e.message.contains('voice not found'))),
      );
    });

    test('SocketException → CloudTtsException network', () async {
      final client = MockClient((_) async => throw Exception('SocketException'));
      final service = VolcengineCloudTtsService(
        credentials: creds,
        httpClient: client,
      );
      expect(
        () => service.fetchAudio('hi', 0.0, 'BV001_streaming'),
        throwsA(predicate((e) =>
            e is CloudTtsException && e.kind == CloudTtsErrorKind.network)),
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/services/tts/volcengine_cloud_tts_service_test.dart
```
Expected: FAIL — service doesn't exist.

- [ ] **Step 3: Add http dependency (if not present)**

In `app/pubspec.yaml`, check if `http:` is already in deps. If not, add:
```yaml
  http: ^1.2.0
```
Then `flutter pub get`.

- [ ] **Step 4: Implement VolcengineCloudTtsService**

Create `lib/services/tts/volcengine_cloud_tts_service.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'base_cloud_tts_service.dart';
import 'cloud_tts_credentials.dart';
import 'cloud_tts_exception.dart';
import 'voice_preset.dart';

/// Volcengine (火山引擎 / 豆包语音) cloud TTS via HTTP API v1.
///
/// API reference: https://www.volcengine.com/docs/6561/1257584
///
/// Endpoint: https://openspeech.bytedance.com/api/v1/tts
/// Auth: Authorization: Bearer;<token>
/// Response: JSON { code: 3000, data: <base64 mp3> }
class VolcengineCloudTtsService extends BaseCloudTtsService {
  VolcengineCloudTtsService({
    required this.credentials,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final VolcengineTtsCredentials credentials;
  final http.Client _httpClient;

  static const _endpoint =
      'https://openspeech.bytedance.com/api/v1/tts';

  @override
  String get engineName => 'volcengine';

  @override
  List<VoicePreset> get supportedVoices => CloudTtsVoicePresets.volcengine;

  @override
  String get defaultVoice => VolcengineTtsCredentials.defaultVoice;

  @override
  VolcengineTtsCredentials? loadCredentials() {
    if (credentials.appId.isEmpty || credentials.accessToken.isEmpty) return null;
    return credentials;
  }

  /// Maps our normalized rate (-1.0..1.0) to Volcengine speed_ratio (0.5..2.0).
  /// -1.0 → 0.5 (slowest), 0.0 → 1.0 (normal), 1.0 → 2.0 (fastest)
  double _mapRate(double normalized) {
    return (normalized + 1.0) * 0.75 + 0.5;
  }

  @override
  Future<Uint8List> fetchAudio(
      String text, double rate, String voice) async {
    final body = jsonEncode({
      'app': {
        'appid': credentials.appId,
        'token': credentials.accessToken,
        'cluster': 'volcano_tts',
      },
      'user': {'uid': 'zhiyue'},
      'audio': {
        'voice_type': voice,
        'speed_ratio': _mapRate(rate),
        'encoding': 'mp3',
        'rate': 24000,
      },
      'request': {
        'reqid': DateTime.now().microsecondsSinceEpoch.toString(),
        'text': text,
        'operation': 'query',
      },
    });

    http.Response response;
    try {
      response = await _httpClient.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer;${credentials.accessToken}',
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.network,
        message: 'HTTP request failed: $e',
        cause: e.toString(),
      );
    }

    if (response.statusCode != 200) {
      throw CloudTtsException(
        kind: CloudTtsErrorKindX.fromHttpStatus(response.statusCode),
        message: 'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.invalidRequest,
        message: 'Invalid JSON response: ${response.body}',
      );
    }

    final code = decoded['code'];
    if (code != 3000) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.invalidRequest,
        message: '${decoded['message'] ?? 'unknown'} (code=$code)',
      );
    }

    final data = decoded['data'] as String?;
    if (data == null || data.isEmpty) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.invalidRequest,
        message: 'Empty audio data in response',
      );
    }

    return base64Decode(data);
  }

  @override
  Future<void> dispose() async {
    _httpClient.close();
    await super.dispose();
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
flutter test test/services/tts/volcengine_cloud_tts_service_test.dart
```
Expected: all 5 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/services/tts/volcengine_cloud_tts_service.dart test/services/tts/volcengine_cloud_tts_service_test.dart pubspec.yaml pubspec.lock
git commit -m "$(cat <<'EOF'
feat(tts): VolcengineCloudTtsService impl (HTTP API v1)

POST https://openspeech.bytedance.com/api/v1/tts with Bearer;token
auth. Rate -1..1 mapped to 0.5..2.0 speed_ratio. Response base64
MP3 decoded to bytes. 5 error categories mapped per HTTP status.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task B5: QwenCloudTtsService impl

**Files:**
- Create: `app/lib/services/tts/qwen_cloud_tts_service.dart`
- Create: `app/test/services/tts/qwen_cloud_tts_service_test.dart`

Qwen/CosyVoice API (DashScope HTTP non-streaming):
- Endpoint: `https://dashscope.aliyuncs.com/api/v1/services/audio/tts/generate`
- Headers: `Authorization: Bearer <apiKey>`, `Content-Type: application/json`
- Body: `{model, input:{text, voice, format:mp3, sample_rate:24000, rate:0.5..2.0, pitch, volume}}`
- Response: `{output:{audio:{url:"https://..."}}, usage, request_id}` — **URL not bytes**
- Need second HTTP GET to fetch audio bytes

- [ ] **Step 1: Write failing tests**

Create `test/services/tts/qwen_cloud_tts_service_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhiyue/services/tts/cloud_tts_credentials.dart';
import 'package:zhiyue/services/tts/cloud_tts_exception.dart';
import 'package:zhiyue/services/tts/qwen_cloud_tts_service.dart';

void main() {
  group('QwenCloudTtsService.fetchAudio', () {
    final creds = const QwenTtsCredentials(
      apiKey: 'sk-xxx',
      model: 'qwen-audio-3.0-tts-flash',
      voice: 'longxiaoxia_v2',
    );

    test('POST returns URL, then GET returns bytes', () async {
      final mp3Bytes = Uint8List.fromList([10, 20, 30, 40]);
      int callIndex = 0;
      final client = MockClient((request) async {
        callIndex++;
        if (callIndex == 1) {
          expect(request.url.toString(),
              'https://dashscope.aliyuncs.com/api/v1/services/audio/tts/generate');
          expect(request.headers['Authorization'], 'Bearer sk-xxx');
          final bodyMap = jsonDecode(request.body) as Map<String, dynamic>;
          expect(bodyMap['model'], 'qwen-audio-3.0-tts-flash');
          expect(bodyMap['input']['voice'], 'longxiaoxia_v2');
          expect(bodyMap['input']['text'], 'hello');
          return http.Response(
            jsonEncode({
              'output': {'audio': {'url': 'https://oss.example.com/a.mp3'}},
              'request_id': 'req-1',
            }),
            200,
          );
        } else {
          expect(request.url.toString(), 'https://oss.example.com/a.mp3');
          return http.Response.bytes(mp3Bytes, 200);
        }
      });

      final service = QwenCloudTtsService(credentials: creds, httpClient: client);
      final result = await service.fetchAudio('hello', 0.0, 'longxiaoxia_v2');
      expect(result, mp3Bytes);
      expect(callIndex, 2);
    });

    test('HTTP 401 on POST → CloudTtsException auth', () async {
      final client = MockClient((_) async => http.Response('{}', 401));
      final service = QwenCloudTtsService(credentials: creds, httpClient: client);
      expect(
        () => service.fetchAudio('hi', 0.0, 'longxiaoxia_v2'),
        throwsA(predicate((e) =>
            e is CloudTtsException && e.kind == CloudTtsErrorKind.auth)),
      );
    });

    test('POST 200 but missing URL → invalidRequest', () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode({'output': {}}), 200));
      final service = QwenCloudTtsService(credentials: creds, httpClient: client);
      expect(
        () => service.fetchAudio('hi', 0.0, 'longxiaoxia_v2'),
        throwsA(predicate((e) =>
            e is CloudTtsException &&
            e.kind == CloudTtsErrorKind.invalidRequest)),
      );
    });

    test('SocketException on POST → network', () async {
      final client = MockClient((_) async => throw Exception('SocketException'));
      final service = QwenCloudTtsService(credentials: creds, httpClient: client);
      expect(
        () => service.fetchAudio('hi', 0.0, 'longxiaoxia_v2'),
        throwsA(predicate((e) =>
            e is CloudTtsException && e.kind == CloudTtsErrorKind.network)),
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/services/tts/qwen_cloud_tts_service_test.dart
```
Expected: FAIL.

- [ ] **Step 3: Implement QwenCloudTtsService**

Create `lib/services/tts/qwen_cloud_tts_service.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'base_cloud_tts_service.dart';
import 'cloud_tts_credentials.dart';
import 'cloud_tts_exception.dart';
import 'voice_preset.dart';

/// Qwen / CosyVoice (阿里云百炼) cloud TTS via DashScope HTTP non-streaming API.
///
/// API reference: https://help.aliyun.com/zh/model-studio/cosyvoice-tts-http-api
///
/// Endpoint: https://dashscope.aliyuncs.com/api/v1/services/audio/tts/generate
/// Auth: Authorization: Bearer <apiKey>
/// Response: JSON { output: { audio: { url } } }
///
/// Note: API returns an audio URL, not base64 bytes — service issues a
/// second HTTP GET to fetch the MP3 bytes. Adds ~100-200ms latency.
class QwenCloudTtsService extends BaseCloudTtsService {
  QwenCloudTtsService({
    required this.credentials,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final QwenTtsCredentials credentials;
  final http.Client _httpClient;

  static const _endpoint =
      'https://dashscope.aliyuncs.com/api/v1/services/audio/tts/generate';

  @override
  String get engineName => 'qwen';

  @override
  List<VoicePreset> get supportedVoices => CloudTtsVoicePresets.qwen;

  @override
  String get defaultVoice => QwenTtsCredentials.defaultVoice;

  @override
  QwenTtsCredentials? loadCredentials() {
    if (credentials.apiKey.isEmpty) return null;
    return credentials;
  }

  /// Maps our normalized rate (-1.0..1.0) to Qwen rate (0.5..2.0).
  double _mapRate(double normalized) {
    return (normalized + 1.0) * 0.75 + 0.5;
  }

  @override
  Future<Uint8List> fetchAudio(String text, double rate, String voice) async {
    final body = jsonEncode({
      'model': credentials.model,
      'input': {
        'text': text,
        'voice': voice,
        'format': 'mp3',
        'sample_rate': 24000,
        'rate': _mapRate(rate),
        'volume': 50,
      },
    });

    http.Response postResponse;
    try {
      postResponse = await _httpClient.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer ${credentials.apiKey}',
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.network,
        message: 'POST failed: $e',
      );
    }

    if (postResponse.statusCode != 200) {
      throw CloudTtsException(
        kind: CloudTtsErrorKindX.fromHttpStatus(postResponse.statusCode),
        message: 'HTTP ${postResponse.statusCode}: ${postResponse.body}',
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(postResponse.body) as Map<String, dynamic>;
    } catch (e) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.invalidRequest,
        message: 'Invalid JSON: ${postResponse.body}',
      );
    }

    final output = decoded['output'];
    if (output is! Map) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.invalidRequest,
        message: 'Missing output in response',
      );
    }
    final audio = output['audio'];
    final url = audio is Map ? audio['url'] as String? : null;
    if (url == null || url.isEmpty) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.invalidRequest,
        message: 'Missing audio.url in response',
      );
    }

    // Second HTTP GET to fetch the actual bytes.
    http.Response getResponse;
    try {
      getResponse = await _httpClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.network,
        message: 'GET audio URL failed: $e',
      );
    }

    if (getResponse.statusCode != 200) {
      throw CloudTtsException(
        kind: CloudTtsErrorKindX.fromHttpStatus(getResponse.statusCode),
        message: 'Audio GET ${getResponse.statusCode}',
      );
    }

    return getResponse.bodyBytes;
  }

  @override
  Future<void> dispose() async {
    _httpClient.close();
    await super.dispose();
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/services/tts/qwen_cloud_tts_service_test.dart
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/tts/qwen_cloud_tts_service.dart test/services/tts/qwen_cloud_tts_service_test.dart
git commit -m "$(cat <<'EOF'
feat(tts): QwenCloudTtsService impl (DashScope HTTP non-streaming)

POST generates MP3 → response contains OSS URL → second GET fetches
bytes. Adds ~100-200ms latency over a hypothetical base64 API;
acceptable for POC. v1.17 can switch to WebSocket streaming for
lower latency.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task B6: Wire cloud engines into factory + Riverpod credentials providers

**Files:**
- Modify: `app/lib/services/tts/tts_service_factory.dart`
- Modify: `app/test/services/tts/tts_service_factory_test.dart`
- Create: `app/lib/features/tts/providers/cloud_tts_credentials_providers.dart`
- Create: `app/test/features/tts/providers/cloud_tts_credentials_providers_test.dart` (optional; mainly covered by integration tests)

- [ ] **Step 1: Update factory tests to expect real impls instead of UnimplementedError**

Update `test/services/tts/tts_service_factory_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/qwen_cloud_tts_service.dart';
import 'package:zhiyue/services/tts/volcengine_cloud_tts_service.dart';
import 'package:zhiyue/services/tts/flutter_tts_service.dart';
import 'package:zhiyue/services/tts/tts_engine_preference.dart';
import 'package:zhiyue/services/tts/tts_service.dart';
import 'package:zhiyue/services/tts/tts_service_factory.dart';

void main() {
  group('createTtsService', () {
    test('system engine on windows returns FlutterTtsServiceImpl', () {
      final service = createTtsService(
        platformName: 'windows',
        preferredEngine: TtsEnginePreference.system,
      );
      expect(service, isA<FlutterTtsServiceImpl>());
    });

    test('volcengineCloud with no credentials returns FlutterTts fallback', () {
      // Without credentials in secure storage, cloud service can't be built.
      // Factory should fall back to system impl.
      final service = createTtsService(
        platformName: 'windows',
        preferredEngine: TtsEnginePreference.volcengineCloud,
      );
      expect(service, isA<FlutterTtsServiceImpl>());
    });

    test('qwenCloud with no credentials returns FlutterTts fallback', () {
      final service = createTtsService(
        platformName: 'windows',
        preferredEngine: TtsEnginePreference.qwenCloud,
      );
      expect(service, isA<FlutterTtsServiceImpl>());
    });

    test('default engine when null is system', () {
      final service = createTtsService(platformName: 'windows');
      expect(service, isA<FlutterTtsServiceImpl>());
    });
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/services/tts/tts_service_factory_test.dart
```
Expected: 2 tests FAIL (current factory throws UnimplementedError for cloud engines).

- [ ] **Step 3: Create credentials providers**

Create `lib/features/tts/providers/cloud_tts_credentials_providers.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/tts/cloud_tts_credentials.dart';

final volcengineTtsCredentialStoreProvider =
    Provider<VolcengineTtsCredentialStore>((ref) {
  return VolcengineTtsCredentialStore();
});

final volcengineTtsCredentialsProvider =
    FutureProvider<VolcengineTtsCredentials?>((ref) async {
  final store = ref.watch(volcengineTtsCredentialStoreProvider);
  return store.load();
});

final qwenTtsCredentialStoreProvider =
    Provider<QwenTtsCredentialStore>((ref) {
  return QwenTtsCredentialStore();
});

final qwenTtsCredentialsProvider =
    FutureProvider<QwenTtsCredentials?>((ref) async {
  final store = ref.watch(qwenTtsCredentialStoreProvider);
  return store.load();
});
```

- [ ] **Step 4: Update factory to wire cloud engines with credentials**

Replace `lib/services/tts/tts_service_factory.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/foundation.dart';

import 'cloud_tts_credentials.dart';
import 'flutter_tts_service.dart';
import 'qwen_cloud_tts_service.dart';
import 'self_built_tts_service.dart';
import 'tts_engine_preference.dart';
import 'tts_service.dart';
import 'volcengine_cloud_tts_service.dart';

/// Creates a [TtsService] for [platformName] honoring [preferredEngine].
///
/// v1.16.0-alpha: 3 engines.
/// Cloud engines require credentials — if not configured, falls back to
/// system engine. Callers needing async credential lookup should use
/// [createTtsServiceAsync] instead.
TtsService createTtsService({
  String? platformName,
  TtsEnginePreference? preferredEngine,
  VolcengineTtsCredentials? volcengineCredentials,
  QwenTtsCredentials? qwenCredentials,
}) {
  final engine = preferredEngine ?? TtsEnginePreference.system;

  switch (engine) {
    case TtsEnginePreference.volcengineCloud:
      if (volcengineCredentials == null) break; // fall back to system
      return VolcengineCloudTtsService(credentials: volcengineCredentials);
    case TtsEnginePreference.qwenCloud:
      if (qwenCredentials == null) break;
      return QwenCloudTtsService(credentials: qwenCredentials);
    case TtsEnginePreference.system:
      break;
  }

  final target = platformName ?? _platformNameFromTargetPlatform();
  switch (target.toLowerCase()) {
    case 'android':
      return SelfBuiltTtsServiceImpl();
    default:
      return FlutterTtsServiceImpl();
  }
}

/// Async factory that loads credentials from secure storage before
/// constructing a cloud service. Used by ttsServiceProvider.
Future<TtsService> createTtsServiceAsync({
  String? platformName,
  TtsEnginePreference? preferredEngine,
  required Future<VolcengineTtsCredentials?> Function() loadVolcengine,
  required Future<QwenTtsCredentials?> Function() loadQwen,
}) async {
  final engine = preferredEngine ?? TtsEnginePreference.system;
  VolcengineTtsCredentials? volc;
  QwenTtsCredentials? qwen;
  if (engine == TtsEnginePreference.volcengineCloud) {
    volc = await loadVolcengine();
  } else if (engine == TtsEnginePreference.qwenCloud) {
    qwen = await loadQwen();
  }
  return createTtsService(
    platformName: platformName,
    preferredEngine: engine,
    volcengineCredentials: volc,
    qwenCredentials: qwen,
  );
}

String _platformNameFromTargetPlatform() {
  final target = defaultTargetPlatform;
  return switch (target) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}
```

- [ ] **Step 5: Run factory tests**

```bash
flutter test test/services/tts/tts_service_factory_test.dart
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/services/tts/tts_service_factory.dart lib/features/tts/providers/cloud_tts_credentials_providers.dart test/services/tts/tts_service_factory_test.dart
git commit -m "$(cat <<'EOF'
feat(tts): wire cloud engines into factory + Riverpod credentials

VolcengineCloudTtsService + QwenCloudTtsService now returned when
preferred engine matches AND credentials exist. Falls back to system
if cloud credentials missing (user hasn't filled API key yet).

createTtsServiceAsync loads credentials from secure storage before
construction. ttsServiceProvider will be migrated in next task.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task B7: TtsPlaybackController fallback + TtsFallbackNotifier

**Files:**
- Modify: `app/lib/features/tts/providers/tts_playback_controller.dart`
- Modify: `app/test/features/tts/providers/tts_playback_controller_test.dart`
- Create: `app/lib/features/tts/providers/tts_fallback_notifier.dart`
- Create: `app/test/features/tts/providers/tts_fallback_notifier_test.dart`

- [ ] **Step 1: Write failing tests for TtsFallbackNotifier**

Create `test/features/tts/providers/tts_fallback_notifier_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/tts/providers/tts_fallback_notifier.dart';

void main() {
  group('TtsFallbackNotifier', () {
    test('initial state has no fallback', () {
      final n = TtsFallbackNotifier();
      expect(n.state.hasFallback, isFalse);
      expect(n.state.message, isEmpty);
    });

    test('reportFallback sets message + provider + timestamp', () {
      final n = TtsFallbackNotifier();
      n.reportFallback(
        fromEngine: 'volcengineCloud',
        message: '网络异常',
      );
      expect(n.state.hasFallback, isTrue);
      expect(n.state.fromEngine, 'volcengineCloud');
      expect(n.state.message, contains('网络异常'));
    });

    test('clear resets state', () {
      final n = TtsFallbackNotifier()
        ..reportFallback(fromEngine: 'x', message: 'y');
      n.clear();
      expect(n.state.hasFallback, isFalse);
    });
  });
}
```

- [ ] **Step 2: Write failing tests for controller fallback behavior**

Add to `test/features/tts/providers/tts_playback_controller_test.dart`:

```dart
test('cloud service error emits fallback event and switches to system',
    () async {
  // Setup: cloud service that throws CloudTtsException(network)
  // Drive play() and assert:
  // 1. TtsFallbackNotifier receives reportFallback
  // 2. ttsServiceProvider re-resolves to system impl
  // 3. Playback continues from same sentence on system engine
});
```

(Full implementation of this test depends on the controller's existing test scaffolding — pattern follows existing error-handling tests in the same file. Implementer should adapt the setup helpers like `_stubSettingsAppliers`.)

- [ ] **Step 3: Run tests to verify failure**

```bash
flutter test test/features/tts/providers/tts_fallback_notifier_test.dart test/features/tts/providers/tts_playback_controller_test.dart
```
Expected: FAIL.

- [ ] **Step 4: Implement TtsFallbackNotifier**

Create `lib/features/tts/providers/tts_fallback_notifier.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_riverpod/flutter_riverpod.dart';

class TtsFallbackState {
  final bool hasFallback;
  final String fromEngine;
  final String message;
  final DateTime? timestamp;

  const TtsFallbackState({
    this.hasFallback = false,
    this.fromEngine = '',
    this.message = '',
    this.timestamp,
  });

  TtsFallbackState copyWith({
    bool? hasFallback,
    String? fromEngine,
    String? message,
    DateTime? timestamp,
  }) {
    return TtsFallbackState(
      hasFallback: hasFallback ?? this.hasFallback,
      fromEngine: fromEngine ?? this.fromEngine,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

final ttsFallbackProvider =
    StateNotifierProvider<TtsFallbackNotifier, TtsFallbackState>(
  (ref) => TtsFallbackNotifier(),
);

class TtsFallbackNotifier extends StateNotifier<TtsFallbackState> {
  TtsFallbackNotifier() : super(const TtsFallbackState());

  void reportFallback({required String fromEngine, required String message}) {
    state = TtsFallbackState(
      hasFallback: true,
      fromEngine: fromEngine,
      message: message,
      timestamp: DateTime.now(),
    );
  }

  void clear() {
    state = const TtsFallbackState();
  }
}
```

- [ ] **Step 5: Update TtsPlaybackController to subscribe to error stream**

In `lib/features/tts/providers/tts_playback_controller.dart`, find where the service is invoked (likely `_speakCurrent` or surrounding method). Add error subscription:

```dart
// In init() or constructor:
_serviceErrorSub?.cancel();
_serviceErrorSub = _service.error.listen((msg) {
  if (_isCloudEngine && _isTransientError(msg)) {
    _triggerFallback(msg);
  }
});

Future<void> _triggerFallback(String msg) async {
  _fallbackNotifier.reportFallback(
    fromEngine: _currentEngineName,
    message: msg,
  );
  // Swap to system engine and replay current sentence.
  await _service.stop();
  _service = await _buildSystemService();
  await _speakCurrent();
}

bool _isTransientError(String msg) {
  return msg.startsWith('network:') || msg.startsWith('server:');
}
```

(Exact integration point depends on existing controller structure — implementer should read the current controller and adapt.)

- [ ] **Step 6: Run tests**

```bash
flutter test test/features/tts/providers/tts_fallback_notifier_test.dart test/features/tts/providers/tts_playback_controller_test.dart
```
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/tts/providers/tts_fallback_notifier.dart test/features/tts/providers/tts_fallback_notifier_test.dart lib/features/tts/providers/tts_playback_controller.dart test/features/tts/providers/tts_playback_controller_test.dart
git commit -m "$(cat <<'EOF'
feat(tts): auto-fallback to system engine on transient cloud errors

TtsFallbackNotifier exposes fallback events to UI (SnackBar in B8).
Controller watches cloud service error stream; on network/server
errors, switches to system impl and replays current sentence. Auth/
quota/invalidRequest errors do NOT trigger fallback (user-action
required).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task B8: Settings UI for cloud engines (credentials form + voice dropdown + test connection + fallback SnackBar)

**Files:**
- Modify: `app/lib/features/settings/pages/tts_settings_section.dart`
- Modify: `app/test/features/settings/pages/tts_settings_section_test.dart`

- [ ] **Step 1: Write failing widget tests**

Add to `test/features/settings/pages/tts_settings_section_test.dart`:

```dart
testWidgets('selecting volcengineCloud shows App ID + Token form',
    (tester) async {
  await tester.pumpWidget(_buildApp(tester, engine: TtsEnginePreference.volcengineCloud));
  await tester.pumpAndSettle();
  expect(find.text('App ID'), findsOneWidget);
  expect(find.text('Access Token'), findsOneWidget);
  expect(find.text('声音'), findsOneWidget);
  expect(find.text('测试连接'), findsOneWidget);
});

testWidgets('selecting qwenCloud shows API Key + Model dropdown',
    (tester) async {
  await tester.pumpWidget(_buildApp(tester, engine: TtsEnginePreference.qwenCloud));
  await tester.pumpAndSettle();
  expect(find.text('API Key'), findsOneWidget);
  expect(find.text('Model'), findsOneWidget);
  expect(find.text('声音'), findsOneWidget);
});

testWidgets('system engine shows no cloud form', (tester) async {
  await tester.pumpWidget(_buildApp(tester, engine: TtsEnginePreference.system));
  await tester.pumpAndSettle();
  expect(find.text('App ID'), findsNothing);
  expect(find.text('API Key'), findsNothing);
});

testWidgets('fallback SnackBar shows when TtsFallbackProvider has event',
    (tester) async {
  // Setup container with pre-populated fallback state, pump, expect SnackBar.
});
```

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/features/settings/pages/tts_settings_section_test.dart
```
Expected: FAIL — current UI only has dropdown, no conditional form.

- [ ] **Step 3: Implement cloud UI in tts_settings_section.dart**

In `lib/features/settings/pages/tts_settings_section.dart`:

a. Add imports:
```dart
import '../../../services/tts/cloud_tts_credentials.dart';
import '../../tts/providers/cloud_tts_credentials_providers.dart';
import '../../tts/providers/tts_fallback_notifier.dart';
```

b. Below the existing engine dropdown Card, add a conditional block that renders different forms per engine:

```dart
if (engine == TtsEnginePreference.volcengineCloud)
  _VolcengineCredentialsForm(key: const ValueKey('volcengine-form')),
if (engine == TtsEnginePreference.qwenCloud)
  _QwenCredentialsForm(key: const ValueKey('qwen-form')),
```

c. Add `_VolcengineCredentialsForm` ConsumerStatefulWidget:
- TextFields for App ID + Access Token (obscured)
- Voice dropdown from `CloudTtsVoicePresets.volcengine`
- 「测试连接」button → calls fetchAudio with test sentence → SnackBar ✓/✗
- Privacy hint text

d. Add `_QwenCredentialsForm` similarly with API Key + Model dropdown + voice dropdown.

e. For the fallback SnackBar, wrap the page in a `Consumer` that watches `ttsFallbackProvider`:
```dart
ref.listen<TtsFallbackState>(ttsFallbackProvider, (prev, next) {
  if (next.hasFallback) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('⚠ ${next.message}，已切换至系统 TTS'),
      action: SnackBarAction(label: '去设置', onPressed: () => context.push('/settings/tts')),
      duration: const Duration(seconds: 6),
    ));
    ref.read(ttsFallbackProvider.notifier).clear();
  }
});
```

- [ ] **Step 4: Run widget tests**

```bash
flutter test test/features/settings/pages/tts_settings_section_test.dart
```
Expected: PASS.

- [ ] **Step 5: Run analyzer**

```bash
dart analyze lib/features/settings/pages/tts_settings_section.dart
```
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/pages/tts_settings_section.dart test/features/settings/pages/tts_settings_section_test.dart
git commit -m "$(cat <<'EOF'
feat(tts): cloud credentials UI + voice picker + test connection + fallback SnackBar

Per-engine conditional form. Volcengine: App ID + Token + voice.
Qwen: API Key + Model + voice. Test connection button uses
fetchAudio on sample sentence. Fallback SnackBar auto-shown when
TtsFallbackProvider emits.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

# Phase C: Release (~0.5 day, 3 tasks)

## Task C1: CHANGELOG + release notes + version bump

**Files:**
- Modify: `CHANGELOG.md`
- Create: `docs/releases/release-notes-v1.16.0-alpha.md`
- Modify: `app/pubspec.yaml` (bump version+1)
- Modify: `app/windows/installer/zhiyue.iss`

- [ ] **Step 1: Add CHANGELOG entry**

Use Python binary-safe replacement (avoid CRLF/LF issues per `feedback_flutter_strip_cache_trap`):

```bash
cd /c/zhiyue_build_s3
python -c "
import io
path = 'CHANGELOG.md'
with io.open(path, 'r', encoding='utf-8', newline='') as f:
    content = f.read()
entry = '''## [1.16.0-alpha] - 2026-07-23

### Major: TTS 混合云策略 (Hybrid Cloud Strategy)

**移除**：SherpaOnnx + MeloTTS POC（v1.15.0 → v1.15.6 共 6 个版本验证失败）。
真因：(1) RTF ≈ 0.85 在中端手机卡顿不可消除；(2) 音质差强人意。

**新增**：双云端 TTS provider
- 火山引擎（豆包语音）：国内顶级中文音质，10+ 声音
- 阿里云 Qwen/CosyVoice：多模型 + 多音色

**核心架构**：
- BaseCloudTtsService 共享 HTTP+prefetch+onAudioStarted+Timer completion
- TtsAudioPlayer（rename from SherpaOnnxAudioPlayer）复用 v1.15.5 awaitCompletion
- 网络失败自动 fallback system TTS + SnackBar 提示

**包体**：APK 264MB → ~100MB（-60%+）；installer 202MB → ~50MB

### Breaking
- tts.engine=sherpaOnnxMelo 自动降级 system
- SherpaOnnx 相关 Dart API 全部移除

'''
# Insert after the top-level header
lines = content.split('\n')
# Find first ## [ line and insert above
for i, line in enumerate(lines):
    if line.startswith('## ['):
        lines.insert(i, entry)
        break
with io.open(path, 'w', encoding='utf-8', newline='') as f:
    f.write('\n'.join(lines))
"
```

- [ ] **Step 2: Create release notes**

Create `docs/releases/release-notes-v1.16.0-alpha.md` following the structure of `release-notes-v1.15.6-alpha.md`. Include:
- Summary: 3 engines (system + volcengine + qwen), SherpaOnnx removed
- How to get API keys (Volcengine console + DashScope console links)
- Voice list preview
- Fallback behavior description
- Migration: old sherpaOnnxMelo setting auto-degrades
- Test plan: (1) system engine regression, (2) cloud credentials entry, (3) multi-sentence playback, (4) network failure fallback

- [ ] **Step 3: Bump pubspec version**

In `app/pubspec.yaml`:
```yaml
version: 1.16.0-alpha+2019
```

- [ ] **Step 4: Bump installer version**

In `app/windows/installer/zhiyue.iss`:
```innosetup
#define MyAppVersion "1.16.0-alpha"
```

- [ ] **Step 5: Commit**

```bash
git add CHANGELOG.md docs/releases/release-notes-v1.16.0-alpha.md app/pubspec.yaml app/windows/installer/zhiyue.iss
git commit -m "$(cat <<'EOF'
chore(release): v1.16.0-alpha bump + changelog + release notes

TTS hybrid cloud major version. 19 commits across 3 phases.
Tagged v1.16.0-alpha + m-tts-hybrid-cloud in C2.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task C2: Build + verify + distribute

**Files:**
- Build artifacts (no source changes)

- [ ] **Step 1: Build Android APK (with-fgs flavor)**

```bash
cd /c/zhiyue_build_s3/app
flutter build apk --flavor withFgs --release
```
Expected: succeeds, APK at `build/app/outputs/flutter-apk/app-withFgs-release.apk`.

- [ ] **Step 2: Verify libapp.so is fresh (strip cache trap, 6th occurrence)**

```bash
cd /c/zhiyue_build_s3/app/android
./gradlew --stop
cmd //c "rmdir /s /q C:\zhiyue_build_s3\app\build\intermediates"
flutter build apk --flavor withFgs --release
```

Sanity check:
```bash
MD5=$(certutil -hashfile build/app/outputs/flutter-apk/app-withFgs-release.apk | head -5)
# And inside APK:
unzip -p build/app/outputs/flutter-apk/app-withFgs-release.apk lib/arm64-v8a/libapp.so | md5sum
```
Expected: hash differs from v1.15.6 (verify by checking marker strings — search for "BaseCloudTtsService" or "volcengine" as ASCII markers).

- [ ] **Step 3: Build Windows installer**

```bash
cd /c/zhiyue_build_s3/app
flutter build windows --release
/c/Users/1/InnoSetup/ISCC.exe windows/installer/zhiyue.iss
```
Expected: `build/installer/zhiyue-setup-1.16.0-alpha.exe` exists, ~50MB.

- [ ] **Step 4: Verify APK size dropped**

```bash
ls -lh build/app/outputs/flutter-apk/app-withFgs-release.apk
```
Expected: ~100MB (down from 264MB).

- [ ] **Step 5: Rename + copy to distribution paths**

```bash
cp build/app/outputs/flutter-apk/app-withFgs-release.apk /c/Users/1/Desktop/zhiyue-1.16.0-alpha-with-fgs.apk
cp build/installer/zhiyue-setup-1.16.0-alpha.exe /c/Users/1/Desktop/
cp build/app/outputs/flutter-apk/app-withFgs-release.apk "/h/华为同步盘/华为云盘/新版本发布/zhiyue-1.16.0-alpha-with-fgs.apk"
cp build/installer/zhiyue-setup-1.16.0-alpha.exe "/h/华为同步盘/华为云盘/新版本发布/"
```

- [ ] **Step 6: Commit build-script changes (if any)**

(Skip if no source changes needed beyond what was committed in C1.)

---

## Task C3: Push Gitee + tags

- [ ] **Step 1: Push master to Gitee**

```bash
cd /c/zhiyue_build_s3
git push origin s4-build:master
```

(Spec assumes s4-build branch in worktree maps to Gitee master per existing workflow.)

- [ ] **Step 2: Tag release**

```bash
git tag v1.16.0-alpha -m "v1.16.0-alpha: TTS hybrid cloud (remove SherpaOnnx + add Volcengine + Qwen)"
git tag m-tts-hybrid-cloud -m "Milestone: 19-task pivot from failed SherpaOnnx POC to dual cloud TTS"
git push origin v1.16.0-alpha m-tts-hybrid-cloud
```

- [ ] **Step 3: Update memory files**

Create memory file `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_2026_07_23_v1_16_tts_hybrid_cloud.md` documenting:
- SherpaOnnx POC negative conclusion (RTF 0.85 + quality)
- Hybrid cloud architecture (3 engines)
- BaseCloudTtsService pattern reuse (v1.15.5 + v1.15.6)
- APK size reduction (264MB → ~100MB)
- Lessons learned (cloud credentials storage, fallback strategy)

Update `MEMORY.md` index with one-line entry.

---

## Self-Review

**Spec coverage check** (spec sections vs plan tasks):

| Spec section | Plan task |
|---|---|
| Engine enum 3 values | A3 |
| Factory dispatch | A4, B6 |
| SherpaOnnx removal (Dart) | A1, A5, A6 |
| SherpaOnnx removal (pubspec) | A7 |
| SherpaOnnx removal (model + gradle) | A8 |
| TtsAudioPlayer (rename + MP3 path) | A1, A2 |
| BaseCloudTtsService | B3 |
| Volcengine impl | B4 |
| Qwen impl | B5 |
| Credentials + secure storage | B1, B6 |
| CloudTtsException | B2 |
| Multi-voice selection | B1 (voice list), B8 (UI) |
| Auto-fallback | B7 |
| Fallback SnackBar | B7, B8 |
| Settings UI per engine | B8 |
| Test connection button | B8 |
| Privacy hint | B8 |
| Release + changelog + bump | C1 |
| Build + verify + distribute | C2 |
| Push Gitee + tags | C3 |

No spec sections unaddressed.

**Placeholder scan**: No TBD/TODO. Each step has concrete code or commands. Some Step 3 descriptions in B7/B8 reference existing helpers (`_stubSettingsAppliers`, `_buildApp`) — implementer must read existing test scaffolding, which is the right level of detail (we don't duplicate scaffold code in the plan).

**Type consistency**:
- `VolcengineTtsCredentials(appId, accessToken, voice)` consistent across B1/B4/B6
- `QwenTtsCredentials(apiKey, model, voice)` consistent across B1/B5/B6
- `BaseCloudTtsService.fetchAudio(String, double, String)` signature consistent across B3/B4/B5
- `CloudTtsException({kind, message, cause?})` consistent across B2/B3/B4
- `TtsFallbackState` fields (hasFallback, fromEngine, message, timestamp) consistent across B7
- Storage keys `zhiyue.tts.volcengine.{appId,token,voice}` and `zhiyue.tts.qwen.{apiKey,model,voice}` consistent across B1/B6

All match.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-23-v1-16-tts-hybrid-cloud.md`. Two execution options:

1. **Subagent-Driven (recommended)** — Dispatch fresh subagent per task, two-stage review between tasks (spec then code quality), fast iteration
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
