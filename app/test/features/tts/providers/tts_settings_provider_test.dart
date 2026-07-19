// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/features/tts/providers/tts_playback_controller.dart';
import 'package:zhiyue/features/tts/providers/tts_settings_provider.dart';
import 'package:zhiyue/services/tts/tts_service.dart';

class _MockTtsService extends Mock implements TtsService {}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tts_settings_test_');
    globalTtsSettingsDirOverride = tempDir;
    registerFallbackValue('voiceIdFallback');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    globalTtsSettingsDirOverride = null;
  });

  test('initial defaults: rate 0.0, pitch 1.0, volume 1.0, continuous', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Allow _load() to settle (it's async-from-constructor)
    await Future<void>.delayed(Duration.zero);
    final settings = container.read(ttsSettingsProvider);
    expect(settings.rate, 0.0);
    expect(settings.pitch, 1.0);
    expect(settings.volume, 1.0);
    expect(settings.chapterBoundary, TtsChapterBoundary.continuous);
  });

  test('setRate persists and propagates', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);
    await container.read(ttsSettingsProvider.notifier).setRate(0.5);
    expect(container.read(ttsSettingsProvider).rate, 0.5);

    // Verify persisted to file
    final file = File('${tempDir.path}/tts_settings.json');
    expect(await file.exists(), isTrue);
    final raw = await file.readAsString();
    expect(raw, contains('"rate":0.5'));
  });

  test('clamps rate to [-1.0, 1.0]', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);
    await container.read(ttsSettingsProvider.notifier).setRate(5.0);
    expect(container.read(ttsSettingsProvider).rate, 1.0);
    await container.read(ttsSettingsProvider.notifier).setRate(-5.0);
    expect(container.read(ttsSettingsProvider).rate, -1.0);
  });

  test('clamps pitch to [0.5, 2.0]', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);
    await container.read(ttsSettingsProvider.notifier).setPitch(0.0);
    expect(container.read(ttsSettingsProvider).pitch, 0.5);
    await container.read(ttsSettingsProvider.notifier).setPitch(10.0);
    expect(container.read(ttsSettingsProvider).pitch, 2.0);
  });

  test('clamps volume to [0.0, 1.0]', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);
    await container.read(ttsSettingsProvider.notifier).setVolume(-1.0);
    expect(container.read(ttsSettingsProvider).volume, 0.0);
    await container.read(ttsSettingsProvider.notifier).setVolume(2.0);
    expect(container.read(ttsSettingsProvider).volume, 1.0);
  });

  test('loads from existing file on construction', () async {
    // Pre-populate settings file
    final file = File('${tempDir.path}/tts_settings.json');
    await file.writeAsString(
        '{"rate":0.3,"pitch":1.5,"volume":0.8,"chapterBoundary":"askAtEnd"}');

    final container = ProviderContainer();
    addTearDown(container.dispose);
    // _load() is async-from-constructor (file exists + readAsString).
    // Poll up to ~1s for state to settle — fixed delays are flaky on
    // Windows where cold file I/O routinely exceeds 10ms.
    final deadline = DateTime.now().add(const Duration(seconds: 1));
    while (container.read(ttsSettingsProvider).rate != 0.3 &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final settings = container.read(ttsSettingsProvider);
    expect(settings.rate, 0.3);
    expect(settings.pitch, 1.5);
    expect(settings.volume, 0.8);
    expect(settings.chapterBoundary, TtsChapterBoundary.askAtEnd);
  });

  // === v1.14.0-alpha T5: voiceId persistence + setVoice notifier ===

  test('TtsSettings voiceId round-trips through json', () {
    const s = TtsSettings(voiceId: 'xiaoxiao|zh-CN');
    final j = s.toJson();
    expect(j['voiceId'], 'xiaoxiao|zh-CN');
    final restored = TtsSettings.fromJson(j);
    expect(restored.voiceId, 'xiaoxiao|zh-CN');
  });

  test('TtsSettings.fromJson tolerates missing voiceId (old settings)', () {
    final s = TtsSettings.fromJson({
      'rate': 0.0,
      'pitch': 1.0,
      'volume': 1.0,
      'chapterBoundary': 'continuous',
      // voiceId absent — old settings file
    });
    expect(s.voiceId, isNull);
  });

  test('setVoice persists voiceId and calls TtsService.setVoice', () async {
    final mockService = _MockTtsService();
    when(() => mockService.setVoice(any())).thenAnswer((_) async => true);

    final container = ProviderContainer(overrides: [
      ttsSettingsDirProvider.overrideWithValue(tempDir),
      ttsServiceProvider.overrideWithValue(mockService),
    ]);
    addTearDown(container.dispose);
    // Allow _load() to settle.
    await Future<void>.delayed(Duration.zero);

    final notifier = container.read(ttsSettingsProvider.notifier);
    await notifier.setVoice('xiaoxiao|zh-CN');

    expect(container.read(ttsSettingsProvider).voiceId, 'xiaoxiao|zh-CN');
    verify(() => mockService.setVoice('xiaoxiao|zh-CN')).called(1);

    // Verify persisted to disk.
    final file = File('${tempDir.path}/tts_settings.json');
    expect(await file.exists(), isTrue);
    final raw = await file.readAsString();
    expect(raw, contains('"voiceId":"xiaoxiao|zh-CN"'));
  });

  test('setVoice(null) clears voiceId and notifies service', () async {
    final mockService = _MockTtsService();
    when(() => mockService.setVoice(any())).thenAnswer((_) async => true);

    final container = ProviderContainer(overrides: [
      ttsSettingsDirProvider.overrideWithValue(tempDir),
      ttsServiceProvider.overrideWithValue(mockService),
    ]);
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);

    final notifier = container.read(ttsSettingsProvider.notifier);
    await notifier.setVoice('initial|zh-CN');
    expect(container.read(ttsSettingsProvider).voiceId, 'initial|zh-CN');

    await notifier.setVoice(null);
    expect(container.read(ttsSettingsProvider).voiceId, isNull);
    verify(() => mockService.setVoice(null)).called(1);
  });
}
