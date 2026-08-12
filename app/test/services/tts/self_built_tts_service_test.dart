// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/self_built_tts_service.dart';
import 'package:zhiyue/services/tts/tts_service.dart';

const _methodChannelName = 'dev.zhiyue.tts';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SelfBuiltTtsServiceImpl svc;
  final List<MethodCall> methodCalls = [];

  setUp(() {
    methodCalls.clear();
    svc = SelfBuiltTtsServiceImpl();

    MethodChannel(_methodChannelName).setMockMethodCallHandler((call) async {
      methodCalls.add(call);
      if (call.method == 'init') return null;
      if (call.method == 'isLanguageAvailable') return true;
      if (call.method == 'isLanguageInstalled') return true;
      if (call.method == 'getDefaultEngine') return 'com.google.android.tts';
      return null;
    });
  });

  tearDown(() async {
    await svc.dispose();
    MethodChannel(_methodChannelName).setMockMethodCallHandler(null);
  });

  /// v1.13.5-alpha: simulates Kotlin side calling
  /// `channel.invokeMethod("onTtsEvent", event)` to deliver a TTS event
  /// to the Dart-side MethodCallHandler registered in init().
  Future<void> emit(dynamic event) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      _methodChannelName,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onTtsEvent', event),
      ),
      null,
    );
  }

  test('init invokes MethodChannel init', () async {
    await svc.init();
    expect(methodCalls,
        contains(predicate<MethodCall>((c) => c.method == 'init')));
    expect(svc.isInitialized, isTrue);
  });

  test('init failure propagates error and sets state to error', () async {
    MethodChannel(_methodChannelName).setMockMethodCallHandler((call) async {
      throw PlatformException(code: 'TTS_UNAVAILABLE', message: 'no engine');
    });
    final errors = <String>[];
    svc.error.listen(errors.add);
    await expectLater(svc.init(), throwsA(isA<PlatformException>()));
    await Future<void>.delayed(Duration.zero);
    expect(errors, isNotEmpty);
  });

  test('speakSentence routes through MethodChannel with text+locale', () async {
    await svc.init();
    await svc.speakSentence(const Sentence(
      text: '你好',
      locale: 'zh-CN',
      charStart: 0,
      charEnd: 2,
    ));
    expect(
      methodCalls,
      contains(predicate<MethodCall>((c) =>
          c.method == 'speak' &&
          (c.arguments as Map)['text'] == '你好' &&
          (c.arguments as Map)['locale'] == 'zh-CN')),
    );
  });

  test('reverse callback state events mapped to TtsState', () async {
    final states = <TtsState>[];
    svc.state.listen(states.add);
    await svc.init();
    await emit({'event': 'state', 'state': 'speaking'});
    await emit({'event': 'state', 'state': 'paused'});
    await emit({'event': 'state', 'state': 'idle'});
    await Future<void>.delayed(Duration.zero);
    expect(states, contains(TtsState.speaking));
    expect(states, contains(TtsState.paused));
    expect(states, contains(TtsState.idle));
  });

  test('reverse callback progress events mapped to TtsProgress', () async {
    final progress = <TtsProgress>[];
    svc.progress.listen(progress.add);
    await svc.init();
    svc.setCurrentSentenceIndex(3);
    await emit({'event': 'progress', 'start': 0, 'end': 5});
    await Future<void>.delayed(Duration.zero);
    expect(progress, isNotEmpty);
    expect(progress.last.sentenceIndex, 3);
    expect(progress.last.charStart, 0);
    expect(progress.last.charEnd, 5);
  });

  test('setSpeechRate / setPitch / setVolume routed', () async {
    await svc.init();
    await svc.setSpeechRate(0.5);
    await svc.setPitch(1.2);
    await svc.setVolume(0.8);
    expect(
        methodCalls.any((c) =>
            c.method == 'setRate' && (c.arguments as Map)['rate'] == 0.5),
        isTrue);
    expect(
        methodCalls.any((c) =>
            c.method == 'setPitch' && (c.arguments as Map)['pitch'] == 1.2),
        isTrue);
    expect(
        methodCalls.any((c) =>
            c.method == 'setVolume' && (c.arguments as Map)['volume'] == 0.8),
        isTrue);
  });

  // v1.13.7-alpha Bug 4: Slider 改 rate/pitch/volume 无效，根因是 Kotlin
  // 端 setRate/setPitch/setVolume 是 no-op。修复方案 A：speak Intent 透传
  // 缓存的 rate/pitch/volume 到 Kotlin，Service 在 speak 前应用。
  test('speak passes cached rate/pitch/volume to Kotlin (Bug 4)', () async {
    await svc.init();
    await svc.setSpeechRate(1.5);
    await svc.setPitch(1.2);
    await svc.setVolume(0.8);
    await svc.speakSentence(const Sentence(
      text: '测试',
      locale: 'zh-CN',
      charStart: 0,
      charEnd: 2,
    ));
    final speakCall = methodCalls.firstWhere(
      (c) => c.method == 'speak',
      orElse: () => throw StateError('no speak call captured'),
    );
    final args = speakCall.arguments as Map;
    expect(args['rate'], 1.5);
    expect(args['pitch'], 1.2);
    expect(args['volume'], 0.8);
  });

  // v1.13.7-alpha Bug 4: 默认值 1.0/1.0/1.0（用户从未改 Slider 时）。
  test('speak defaults rate/pitch/volume to 1.0 when unset (Bug 4)', () async {
    await svc.init();
    await svc.speakSentence(const Sentence(
      text: '测试',
      locale: 'zh-CN',
      charStart: 0,
      charEnd: 2,
    ));
    final speakCall = methodCalls.firstWhere(
      (c) => c.method == 'speak',
      orElse: () => throw StateError('no speak call captured'),
    );
    final args = speakCall.arguments as Map;
    expect(args['rate'], 1.0);
    expect(args['pitch'], 1.0);
    expect(args['volume'], 1.0);
  });

  test('stop / pause routed through channel', () async {
    await svc.init();
    await svc.stop();
    await svc.pause();
    expect(methodCalls.any((c) => c.method == 'stop'), isTrue);
    expect(methodCalls.any((c) => c.method == 'pause'), isTrue);
  });

  test('unknown state string falls back to idle', () async {
    final states = <TtsState>[];
    svc.state.listen(states.add);
    await svc.init();
    await emit({'event': 'state', 'state': 'wat'});
    await Future<void>.delayed(Duration.zero);
    expect(states, contains(TtsState.idle));
  });

  test('error event sets state to error', () async {
    final states = <TtsState>[];
    svc.state.listen(states.add);
    await svc.init();
    await emit({'event': 'error', 'message': 'boom'});
    await Future<void>.delayed(Duration.zero);
    expect(states, contains(TtsState.error));
  });

  // v1.13.2-alpha regression: Kotlin ZhiYueTtsService.onDone emits
  // {"event":"done"} (not {"event":"state","state":"idle"}). Without this
  // mapping, TtsPlaybackController._onServiceState never sees TtsState.idle
  // after a sentence finishes, so playback halts after queue[0].
  test('done event maps to TtsState.idle (regression v1.13.2-alpha)', () async {
    final states = <TtsState>[];
    svc.state.listen(states.add);
    await svc.init();
    await emit({'event': 'done', 'utteranceId': 'sent_0'});
    await Future<void>.delayed(Duration.zero);
    expect(states, contains(TtsState.idle));
  });

  // v1.13.5-alpha regression: ensures the new MethodChannel reverse callback
  // pipeline increments the diagnostic counter, so debug logs can confirm
  // events actually arrive at Dart (the v1.13.4 EventChannel bug pointed to
  // emitCount>0 && dartReceivedCount==0).
  test('eventReceivedCountForDebug increments on each reverse callback',
      () async {
    await svc.init();
    expect(svc.eventReceivedCountForDebug, 0);
    await emit({'event': 'state', 'state': 'speaking'});
    await emit({'event': 'done'});
    await Future<void>.delayed(Duration.zero);
    expect(svc.eventReceivedCountForDebug, 2);
  });

  // v1.13.10-alpha Bug 1: Kotlin ZhiYueTtsService.handleStop emits
  // {"event":"state","state":"stopped"} when the user taps the notification
  // bar stop button. Previously _parseState collapsed 'stopped' into
  // TtsState.idle, which made TtsPlaybackController think the current
  // sentence had completed naturally and auto-advanced to the next one.
  // That auto-advance fired a new SPEAK intent, recreated the destroyed
  // service, and manifested as "auto-resume ~845ms after stop" to the user.
  // 'stopped' MUST now map to its own TtsState.stopped (distinct from
  // TtsState.idle which still means natural-completion).
  test(
      'reverse callback state=stopped maps to TtsState.stopped (Bug 1)',
      () async {
    final states = <TtsState>[];
    svc.state.listen(states.add);
    await svc.init();
    await emit({'event': 'state', 'state': 'stopped'});
    await Future<void>.delayed(Duration.zero);
    // init() emits TtsState.idle as the initial state, then the stopped
    // event must arrive as TtsState.stopped (not collapse back to idle).
    expect(states, contains(TtsState.stopped));
    expect(states.last, TtsState.stopped,
        reason:
            'v1.13.10-alpha Bug 1: state=stopped MUST map to TtsState.stopped, '
            'not fall through to TtsState.idle.');
  });

  // v1.16.2-alpha Task 2: Kotlin ZhiYueTtsService emits init_error when
  // TextToSpeech.OnInitListener.onInit() returns ERROR after 500ms retry
  // with applicationContext also fails. Common on OPPO/小米 due to ROM-
  // specific restrictions on system service binding from foreground service
  // context. This event must push to error stream with status + manufacturer.
  test('init_error event pushes to error stream with status and manufacturer',
      () async {
    await svc.init();

    final errors = <String>[];
    svc.error.listen(errors.add);

    // Simulate Kotlin reverse callback for init_error
    await emit({
      'event': 'init_error',
      'status': -1,
      'manufacturer': 'Xiaomi',
      'model': 'Mi 10',
    });
    await Future<void>.delayed(Duration.zero);

    expect(errors.length, 1);
    expect(errors.first, contains('系统 TTS'));
    expect(errors.first, contains('-1'));
    expect(errors.first, contains('Xiaomi'));
  });

  // v1.16.2-alpha Task 2: init_error pushes to error stream but does NOT
  // transition TtsState. The UI decides how to react (e.g., show SnackBar
  // but stay in idle state, since user hasn't started playback yet).
  test('init_error event does not change TtsState', () async {
    await svc.init();

    final states = <TtsState>[];
    svc.state.listen(states.add);

    // Capture initial state (idle from init())
    final initialCount = states.length;

    // Simulate init_error event
    await emit({
      'event': 'init_error',
      'status': -1,
      'manufacturer': 'OPPO',
    });
    await Future<void>.delayed(Duration.zero);

    // init_error pushes to error stream only — does NOT transition state.
    // UI widgets decide how to react (show SnackBar without changing state).
    expect(states.length, initialCount,
        reason: 'init_error must not emit to state stream');
  });

  // v1.16.3-alpha Task 4: Kotlin ZhiYueTtsService now emits `engines` (the
  // list of TTS engine packages enumerated via PackageManager.queryIntentServices
  // that we tried in stage B and which all rejected binding). Empty list = no
  // standard-compatible engine installed. Dart must surface this list in the
  // error message so the UI/SnackBar can give actionable guidance (e.g.,
  // "switch to SherpaOnnx").
  test('init_error event includes engines list when provided', () async {
    await svc.init();

    final errors = <String>[];
    svc.error.listen(errors.add);

    // Simulate Kotlin reverse callback with engines list (non-empty case:
    // ROM had enumerable engines but rejected binding for all of them).
    await emit({
      'event': 'init_error',
      'status': -1,
      'manufacturer': 'Xiaomi',
      'model': '2304FPN6DC',
      'engines': ['com.google.android.tts', 'com.iflytek.speechcloud'],
    });
    await Future<void>.delayed(Duration.zero);

    expect(errors.length, 1);
    // Manufacturer preserved
    expect(errors.first, contains('Xiaomi'));
    // Both engine packages listed in the message
    expect(errors.first, contains('com.google.android.tts'));
    expect(errors.first, contains('com.iflytek.speechcloud'));
    // v1.16.3-alpha: cloud engine suggestion (sherpaOnnxMelo was removed in
    // v1.16.0-alpha POC cleanup; cloud engines are the only non-system fallback).
    expect(errors.first, contains('云端 TTS 引擎'));
  });

  // v1.16.3-alpha Task 4: When Kotlin emits an empty engines list (no
  // standard-compatible engine installed at all), the Dart message should
  // surface 未检测到可用 TTS 引擎 rather than the empty 已尝试引擎 list.
  test(
      'init_error event with empty engines list surfaces 未检测到可用 TTS 引擎',
      () async {
    await svc.init();

    final errors = <String>[];
    svc.error.listen(errors.add);

    await emit({
      'event': 'init_error',
      'status': -1,
      'manufacturer': 'Xiaomi',
      'engines': <String>[],
    });
    await Future<void>.delayed(Duration.zero);

    expect(errors.length, 1);
    expect(errors.first, contains('未检测到可用 TTS 引擎'));
    // Should NOT contain the 已尝试引擎 label since no engines were tried.
    expect(errors.first, isNot(contains('已尝试引擎')));
  });

  // v1.16.3-alpha Task 4: defensive parsing — Kotlin may omit the engines
  // field entirely in edge cases (e.g., older Kotlin build), so Dart must
  // treat missing/null/non-List as empty list and surface the
  // 未检测到可用 TTS 引擎 branch.
  test('init_error event without engines field falls back to empty-list branch',
      () async {
    await svc.init();

    final errors = <String>[];
    svc.error.listen(errors.add);

    // No 'engines' key at all (legacy Kotlin side or partial event).
    await emit({
      'event': 'init_error',
      'status': -1,
      'manufacturer': 'OPPO',
    });
    await Future<void>.delayed(Duration.zero);

    expect(errors.length, 1);
    expect(errors.first, contains('未检测到可用 TTS 引擎'));
  });
}
