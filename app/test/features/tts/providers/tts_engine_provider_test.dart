// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/repositories/settings_repository.dart';
import 'package:zhiyue/services/tts/tts_engine_preference.dart';
import 'package:zhiyue/features/tts/providers/tts_engine_provider.dart';

/// 简单 in-memory fake，给 ttsEngineProvider 提供 mock 仓储。
class _FakeSettingsRepo implements SettingsRepository {
  final Map<String, dynamic> _data = {};
  @override
  Future<T> get<T>(String key, T defaultValue) async =>
      (_data[key] as T?) ?? defaultValue;
  @override
  Future<T?> getOrNull<T>(String key) async => _data[key] as T?;
  @override
  Future<void> set<T>(String key, T value) async {
    _data[key] = value;
  }
}

void main() {
  group('ttsEngineProvider', () {
    late ProviderContainer container;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('default preference is system', () {
      expect(
        container.read(ttsEngineProvider),
        TtsEnginePreference.system,
      );
    });

    test('setEngine updates state in-memory', () async {
      await container
          .read(ttsEngineProvider.notifier)
          .setEngine(TtsEnginePreference.sherpaOnnxMelo);

      expect(
        container.read(ttsEngineProvider),
        TtsEnginePreference.sherpaOnnxMelo,
      );
    });
  });
}
