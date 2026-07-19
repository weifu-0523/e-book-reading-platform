// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/services/tts/flutter_tts_service.dart';

class _MockFlutterTts extends Mock implements FlutterTts {}

void main() {
  late _MockFlutterTts mock;
  late FlutterTtsServiceImpl service;

  setUp(() {
    mock = _MockFlutterTts();
    // FlutterTtsServiceImpl constructs `FlutterTts()` internally; the
    // `withTts` test constructor accepts an injected instance.
    when(() => mock.awaitSpeakCompletion(any())).thenAnswer((_) async => 1);
    service = FlutterTtsServiceImpl.withTts(mock);
  });

  test('getVoices returns empty when plugin returns null', () async {
    when(() => mock.getVoices).thenAnswer((_) async => null);
    final voices = await service.getVoices();
    expect(voices, isEmpty);
  });

  test('getVoices maps plugin List<Map> to List<TtsVoice>', () async {
    when(() => mock.getVoices).thenAnswer((_) async => [
          {'name': 'Microsoft HuiHui', 'locale': 'zh-CN'},
          {'name': 'Microsoft Zira', 'locale': 'en-US'},
        ]);
    final voices = await service.getVoices();
    expect(voices.length, 2);
    expect(voices[0].name, 'Microsoft HuiHui');
    expect(voices[0].locale, 'zh-CN');
    // Desktop SAPI5: TtsVoice.id == name (no engine-level voice id).
    expect(voices[0].id, 'Microsoft HuiHui');
  });

  test('getVoices returns empty list when plugin throws', () async {
    when(() => mock.getVoices).thenThrow(Exception('plugin died'));
    final voices = await service.getVoices();
    expect(voices, isEmpty);
  });

  test('setVoice(id) looks up voice map and calls plugin.setVoice(Map)',
      () async {
    when(() => mock.getVoices).thenAnswer((_) async => [
          {'name': 'Microsoft HuiHui', 'locale': 'zh-CN'},
          {'name': 'Microsoft Zira', 'locale': 'en-US'},
        ]);
    when(() => mock.setVoice(any())).thenAnswer((_) async => 1);

    final ok = await service.setVoice('Microsoft HuiHui');

    expect(ok, isTrue);
    // Verify plugin.setVoice was called with the matched Map.
    final captured = verify(() => mock.setVoice(captureAny())).captured;
    expect(captured.length, 1);
    final arg = captured.single as Map<String, String>;
    expect(arg['name'], 'Microsoft HuiHui');
    expect(arg['locale'], 'zh-CN');
  });

  test('setVoice(null) clears voice via setVoice(empty map) and returns true',
      () async {
    when(() => mock.setVoice(any())).thenAnswer((_) async => 1);
    final ok = await service.setVoice(null);
    expect(ok, isTrue);
    verify(() => mock.setVoice(any())).called(1);
  });

  test('setVoice returns false when voiceId not in plugin voice list',
      () async {
    when(() => mock.getVoices).thenAnswer((_) async => [
          {'name': 'Microsoft HuiHui', 'locale': 'zh-CN'},
        ]);
    when(() => mock.setVoice(any())).thenAnswer((_) async => 1);

    final ok = await service.setVoice('nonexistent-voice');

    expect(ok, isFalse);
    verifyNever(() => mock.setVoice(any()));
  });

  test('setVoice returns false when plugin returns 0', () async {
    when(() => mock.getVoices).thenAnswer((_) async => [
          {'name': 'Microsoft HuiHui', 'locale': 'zh-CN'},
        ]);
    when(() => mock.setVoice(any())).thenAnswer((_) async => 0);

    final ok = await service.setVoice('Microsoft HuiHui');

    expect(ok, isFalse);
  });

  test('setVoice returns false when plugin throws', () async {
    when(() => mock.getVoices).thenAnswer((_) async => [
          {'name': 'Microsoft HuiHui', 'locale': 'zh-CN'},
        ]);
    when(() => mock.setVoice(any())).thenThrow(Exception('boom'));

    final ok = await service.setVoice('Microsoft HuiHui');

    expect(ok, isFalse);
  });

  // v1.14.0-alpha review fixup: setVoice must cache the voiceId on success
  // so previewVoice can restore to the user's persistent selection. Without
  // this caching, a user who permanently picked voice X via UI then previewed
  // voice Y would have X silently discarded (revert to system default).
  test('setVoice caches voiceId on success (visible via currentVoiceIdForTest)',
      () async {
    when(() => mock.getVoices).thenAnswer((_) async => [
          {'name': 'Microsoft HuiHui', 'locale': 'zh-CN'},
          {'name': 'Microsoft Zira', 'locale': 'en-US'},
        ]);
    when(() => mock.setVoice(any())).thenAnswer((_) async => 1);

    // Initial state: no explicit selection.
    expect(service.currentVoiceIdForTest, isNull);

    // Permanently pick HuiHui.
    final ok = await service.setVoice('Microsoft HuiHui');
    expect(ok, isTrue);
    expect(service.currentVoiceIdForTest, 'Microsoft HuiHui');

    // Switching to another voice updates the cache.
    final ok2 = await service.setVoice('Microsoft Zira');
    expect(ok2, isTrue);
    expect(service.currentVoiceIdForTest, 'Microsoft Zira');

    // Reverting to system default via setVoice(null) clears the cache.
    final ok3 = await service.setVoice(null);
    expect(ok3, isTrue);
    expect(service.currentVoiceIdForTest, isNull);
  });

  test(
      'previewVoice restores to user\'s persistent voice, not system default',
      () async {
    when(() => mock.getVoices).thenAnswer((_) async => [
          {'name': 'Microsoft HuiHui', 'locale': 'zh-CN'},
          {'name': 'Microsoft Zira', 'locale': 'en-US'},
        ]);
    when(() => mock.setVoice(any())).thenAnswer((_) async => 1);
    when(() => mock.speak(any())).thenAnswer((_) async => 1);
    when(() => mock.awaitSpeakCompletion(any())).thenAnswer((_) async => 1);

    // Capture the completion handler so we can simulate the platform firing
    // `idle` after preview playback completes.
    void Function()? completion;
    when(() => mock.setCompletionHandler(any())).thenAnswer((invocation) {
      completion = invocation.positionalArguments[0] as void Function()?;
    });

    // init() wires the completion handler into the mock.
    await service.init();

    // Step 1: User permanently picks voice A (HuiHui).
    await service.setVoice('Microsoft HuiHui');
    expect(service.currentVoiceIdForTest, 'Microsoft HuiHui');

    // Clear mock call log so we can inspect calls made during preview.
    reset(mock);
    when(() => mock.getVoices).thenAnswer((_) async => [
          {'name': 'Microsoft HuiHui', 'locale': 'zh-CN'},
          {'name': 'Microsoft Zira', 'locale': 'en-US'},
        ]);
    when(() => mock.setVoice(any())).thenAnswer((_) async => 1);
    when(() => mock.speak(any())).thenAnswer((_) async => 1);

    // Step 2: Preview voice B (Zira).
    await service.previewVoice('Microsoft Zira');

    // Verify the plugin was asked to apply Zira (the preview voice).
    final captured = verify(() => mock.setVoice(captureAny())).captured;
    expect(captured.length, 1);
    final previewArg = captured.single as Map<String, String>;
    expect(previewArg['name'], 'Microsoft Zira');

    // Step 3: Simulate the platform's completion handler firing. The handler
    // restores to the user's persistent voice (HuiHui), NOT system default.
    expect(completion, isNotNull,
        reason: 'init() should have wired setCompletionHandler');
    completion!();

    // Allow the fire-and-forget setVoice(saved) microtask to complete.
    await Future<void>.delayed(Duration.zero);

    // After restore: plugin should have been called with HuiHui (user's
    // persistent voice), NOT empty map (which would mean system default).
    final restoreCalls =
        verify(() => mock.setVoice(captureAny())).captured;
    expect(restoreCalls.length, 1,
        reason: 'completion handler should fire exactly one restore setVoice');
    final restoreArg = restoreCalls.single as Map<String, String>;
    expect(restoreArg['name'], 'Microsoft HuiHui',
        reason: 'restore target must be user\'s persistent voice, not '
            'system default (empty map)');
    // And _currentVoiceId reflects HuiHui again.
    expect(service.currentVoiceIdForTest, 'Microsoft HuiHui');
  });

  test('previewVoice restores to null when user never picked a voice',
      () async {
    // Regression for the sentinel-wrapper fix: a user with no explicit voice
    // (system default) previews a voice. The completion handler must restore
    // to system default, NOT skip restore (which would leave the preview
    // voice as the new persistent selection).
    when(() => mock.getVoices).thenAnswer((_) async => [
          {'name': 'Microsoft HuiHui', 'locale': 'zh-CN'},
          {'name': 'Microsoft Zira', 'locale': 'en-US'},
        ]);
    when(() => mock.setVoice(any())).thenAnswer((_) async => 1);
    when(() => mock.speak(any())).thenAnswer((_) async => 1);
    when(() => mock.awaitSpeakCompletion(any())).thenAnswer((_) async => 1);

    void Function()? completion;
    when(() => mock.setCompletionHandler(any())).thenAnswer((invocation) {
      completion = invocation.positionalArguments[0] as void Function()?;
    });

    await service.init();

    // Initial state: no voice selected.
    expect(service.currentVoiceIdForTest, isNull);

    // Preview Zira without prior persistent selection.
    await service.previewVoice('Microsoft Zira');
    expect(service.currentVoiceIdForTest, 'Microsoft Zira');

    reset(mock);
    when(() => mock.setVoice(any())).thenAnswer((_) async => 1);

    // Simulate completion — restore target was null (system default).
    expect(completion, isNotNull);
    completion!();
    await Future<void>.delayed(Duration.zero);

    // Verify restore called setVoice with an empty map (system default),
    // NOT skipped entirely. The old `if (saved != null)` check would have
    // skipped restore when prior was null, leaving Zira as the new persistent
    // voice.
    final restoreCalls = verify(() => mock.setVoice(captureAny())).captured;
    expect(restoreCalls.length, 1,
        reason: 'completion handler must restore even when prior was null');
    final restoreArg = restoreCalls.single as Map<String, String>;
    expect(restoreArg.isEmpty, isTrue,
        reason: 'empty map = system default restore target');
    expect(service.currentVoiceIdForTest, isNull);
  });

  test('previewVoice restores to null when user never picked a voice',
      () async {
    // Regression for the sentinel-wrapper fix: a user with no explicit voice
    // (system default) previews a voice. The completion handler must restore
    // to system default, NOT skip restore (which would leave the preview
    // voice as the new persistent selection).
    when(() => mock.getVoices).thenAnswer((_) async => [
          {'name': 'Microsoft HuiHui', 'locale': 'zh-CN'},
          {'name': 'Microsoft Zira', 'locale': 'en-US'},
        ]);
    when(() => mock.setVoice(any())).thenAnswer((_) async => 1);
    when(() => mock.speak(any())).thenAnswer((_) async => 1);

    // Initial state: no voice selected.
    expect(service.currentVoiceIdForTest, isNull);

    // Preview Zira without prior persistent selection.
    await service.previewVoice('Microsoft Zira');
    expect(service.currentVoiceIdForTest, 'Microsoft Zira');

    // Manually trigger restore by simulating the completion handler: the
    // snapshot voiceId was null (system default), so setVoice(null) runs.
    await service.setVoice(null);
    expect(service.currentVoiceIdForTest, isNull);
  });
}
