// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/self_built_tts_service.dart';
import 'package:zhiyue/services/tts/tts_service.dart';
import 'package:zhiyue/services/tts/tts_voice.dart';

const _methodChannelName = 'dev.zhiyue.tts';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SelfBuiltTtsServiceImpl service;
  final List<MethodCall> calls = [];

  setUp(() {
    calls.clear();
    service = SelfBuiltTtsServiceImpl();

    MethodChannel(_methodChannelName).setMockMethodCallHandler((call) async {
      calls.add(call);
      if (call.method == 'init') return null;
      if (call.method == 'getVoices') {
        return [
          {
            'id': 'xiaoxiao|zh-CN',
            'name': 'Xiaoxiao',
            'locale': 'zh-CN',
            'isDefault': true,
          },
          {
            'id': 'yunyang|zh-CN',
            'name': 'Yunyang',
            'locale': 'zh-CN',
          },
        ];
      }
      if (call.method == 'setVoice') return true;
      if (call.method == 'openSystemTtsSettings') return true;
      if (call.method == 'speak') return null;
      return null;
    });
  });

  tearDown(() async {
    MethodChannel(_methodChannelName).setMockMethodCallHandler(null);
    await service.dispose();
  });

  test('getVoices maps Kotlin List<Map> to List<TtsVoice>', () async {
    final voices = await service.getVoices();
    expect(voices.length, 2);
    expect(voices[0].id, 'xiaoxiao|zh-CN');
    expect(voices[0].name, 'Xiaoxiao');
    expect(voices[0].locale, 'zh-CN');
    expect(voices[0].isDefault, isTrue);
    expect(voices[1].id, 'yunyang|zh-CN');
    expect(voices[1].isDefault, isFalse);
    expect(calls.any((c) => c.method == 'getVoices'), isTrue);
  });

  test('getVoices returns empty list when Kotlin returns null', () async {
    MethodChannel(_methodChannelName).setMockMethodCallHandler((call) async {
      calls.add(call);
      if (call.method == 'getVoices') return null;
      return null;
    });
    final voices = await service.getVoices();
    expect(voices, isEmpty);
  });

  test('getVoices returns empty list when channel throws', () async {
    MethodChannel(_methodChannelName).setMockMethodCallHandler((call) async {
      throw PlatformException(code: 'NO_ENGINE', message: 'TTS unavailable');
    });
    final voices = await service.getVoices();
    expect(voices, isEmpty);
  });

  test('setVoice invokes MethodChannel with voiceId arg', () async {
    final ok = await service.setVoice('xiaoxiao|zh-CN');
    expect(ok, isTrue);
    expect(
        calls.any((c) =>
            c.method == 'setVoice' &&
            (c.arguments as Map)['voiceId'] == 'xiaoxiao|zh-CN'),
        isTrue);
  });

  test('setVoice(null) invokes MethodChannel with voiceId=null', () async {
    final ok = await service.setVoice(null);
    expect(ok, isTrue);
    expect(
        calls.any((c) =>
            c.method == 'setVoice' &&
            (c.arguments as Map)['voiceId'] == null),
        isTrue);
  });

  test('setVoice returns false when channel throws', () async {
    MethodChannel(_methodChannelName).setMockMethodCallHandler((call) async {
      throw PlatformException(code: 'FAIL', message: 'rejected');
    });
    final ok = await service.setVoice('any');
    expect(ok, isFalse);
  });

  test('openSystemTtsSettings invokes Kotlin handler', () async {
    final ok = await service.openSystemTtsSettings();
    expect(ok, isTrue);
    expect(calls.any((c) => c.method == 'openSystemTtsSettings'), isTrue);
  });

  test('openSystemTtsSettings returns false when channel throws', () async {
    MethodChannel(_methodChannelName).setMockMethodCallHandler((call) async {
      throw PlatformException(code: 'NO_SETTINGS', message: 'no system page');
    });
    final ok = await service.openSystemTtsSettings();
    expect(ok, isFalse);
  });

  test('speakSentence piggy-backs cached voiceId when set', () async {
    await service.setVoice('xiaoxiao|zh-CN');
    calls.clear();
    await service.init();
    await service.speakSentence(const Sentence(
      text: '你好',
      locale: 'zh-CN',
      charStart: 0,
      charEnd: 2,
    ));
    final speakCall = calls.firstWhere((c) => c.method == 'speak');
    expect((speakCall.arguments as Map)['voiceId'], 'xiaoxiao|zh-CN');
  });

  test('speakSentence omits voiceId when never set', () async {
    await service.init();
    await service.speakSentence(const Sentence(
      text: '你好',
      locale: 'zh-CN',
      charStart: 0,
      charEnd: 2,
    ));
    final speakCall = calls.firstWhere((c) => c.method == 'speak');
    expect((speakCall.arguments as Map).containsKey('voiceId'), isFalse);
  });

  test('previewVoice sets + speaks + restores previous voiceId', () async {
    // Establish a baseline voiceId.
    await service.setVoice('initial|zh-CN');
    calls.clear();

    await service.previewVoice('preview|zh-CN',
        sampleText: '测试样本');

    // Verify speak call piggy-backed the preview voiceId.
    final speakCall = calls.firstWhere((c) => c.method == 'speak');
    expect((speakCall.arguments as Map)['voiceId'], 'preview|zh-CN');
    expect((speakCall.arguments as Map)['text'], '测试样本');

    // Verify restore: a setVoice call back to 'initial|zh-CN' must exist
    // (finally-block restoration).
    expect(
        calls.any((c) =>
            c.method == 'setVoice' &&
            (c.arguments as Map)['voiceId'] == 'initial|zh-CN'),
        isTrue);
  });

  test('previewVoice uses default sample text when none provided', () async {
    await service.previewVoice('zh-CN-xiaoxiao');

    final speakCall = calls.firstWhere((c) => c.method == 'speak');
    expect((speakCall.arguments as Map)['text'] as String, isNotEmpty);
  });

  // TtsVoice sanity check (mirrors tts_voice_test.dart expectation).
  test('TtsVoice re-export sanity: equality by id', () {
    const a = TtsVoice(id: 'x', name: 'A', locale: 'zh');
    const b = TtsVoice(id: 'x', name: 'B', locale: 'en', isDefault: true);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
