// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/self_built_tts_service.dart';
import 'package:zhiyue/services/tts/tts_service.dart';

const _eventChannelName = 'dev.zhiyue.tts/events';
const _methodChannelName = 'dev.zhiyue.tts';
const _codec = StandardMethodCodec();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SelfBuiltTtsServiceImpl svc;
  final List<MethodCall> methodCalls = [];

  setUp(() {
    methodCalls.clear();
    svc = SelfBuiltTtsServiceImpl();

    MethodChannel(_methodChannelName).setMockMethodCallHandler((call) async {
      methodCalls.add(call);
      // EventChannel internally invokes 'listen'/'cancel' on a MethodChannel
      // that shares its name with the EventChannel — but since our EventChannel
      // name differs from the MethodChannel name, those go to the event name.
      if (call.method == 'init') return null;
      if (call.method == 'isLanguageAvailable') return true;
      if (call.method == 'isLanguageInstalled') return true;
      if (call.method == 'getDefaultEngine') return 'com.google.android.tts';
      return null;
    });

    // Handle the EventChannel's internal 'listen'/'cancel' method calls.
    // EventChannel.receiveBroadcastStream invokes these on a MethodChannel
    // sharing the EventChannel's name; return null to acknowledge.
    MethodChannel(_eventChannelName).setMockMethodCallHandler((call) async {
      return null;
    });
  });

  tearDown(() async {
    await svc.dispose();
    MethodChannel(_methodChannelName).setMockMethodCallHandler(null);
    MethodChannel(_eventChannelName).setMockMethodCallHandler(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMessageHandler(_eventChannelName, null);
  });

  /// Emits a single event as if the platform plugin sent it on the
  /// EventChannel. Encodes [event] as a success envelope and forwards it
  /// to whatever handler the EventChannel registered with the binary messenger.
  Future<void> emit(dynamic event) async {
    final ByteData encoded = _codec.encodeSuccessEnvelope(event);
    // The EventChannel's onListen callback calls setMessageHandler(name, h).
    // Dispatch through the binding so the captured handler runs.
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(_eventChannelName, encoded, null);
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
    // Broadcast StreamController delivers asynchronously — flush microtasks
    // before asserting on the error stream.
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

  test('EventChannel state events mapped to TtsState', () async {
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

  test('EventChannel progress events mapped to TtsProgress', () async {
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
}
