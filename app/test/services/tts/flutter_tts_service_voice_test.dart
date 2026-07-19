// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/services/tts/flutter_tts_service.dart';
import 'package:zhiyue/services/tts/tts_voice.dart';

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
}
