// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/repositories/settings_repository.dart';
import 'package:zhiyue/features/tts/providers/tts_playback_controller.dart';
import 'package:zhiyue/services/tts/flutter_tts_service.dart';
import 'package:zhiyue/services/tts/self_built_tts_service.dart';
import 'package:zhiyue/services/tts/tts_engine_preference.dart';

/// Fake [SettingsRepository] that pre-seeds tts.engine preference.
class _FakeSettingsRepoWithEngine implements SettingsRepository {
  _FakeSettingsRepoWithEngine([this._engine = TtsEnginePreference.system]);

  final TtsEnginePreference _engine;
  final Map<String, dynamic> _data = {};

  @override
  Future<T> get<T>(String key, T defaultValue) async {
    if (key == 'tts.engine') {
      return _engine.persistedValue as T;
    }
    return (_data[key] as T?) ?? defaultValue;
  }

  @override
  Future<T?> getOrNull<T>(String key) async {
    if (key == 'tts.engine') {
      return _engine.persistedValue as T;
    }
    return _data[key] as T?;
  }

  @override
  Future<void> set<T>(String key, T value) async {
    _data[key] = value;
  }
}

/// v1.13.1-alpha regression test: ensure [ttsServiceProvider] dispatches
/// via [createTtsService] (not hardcoded [FlutterTtsServiceImpl]).
///
/// v1.13.0-alpha shipped with the factory written but never wired — the
/// provider fell back to `FlutterTtsServiceImpl()` even on Android, which
/// silently broke TTS (flutter_tts plugin is intentionally unregistered
/// in MainActivity to dodge the Chinese-ROM startup kill). This test
/// prevents that regression by overriding [defaultTargetPlatform] and
/// asserting the provider returns the platform-appropriate concrete type.
void main() {
  // FlutterTtsServiceImpl.dispose() calls flutter_tts MethodChannel which
  // isn't registered in unit tests — stub it so container.dispose doesn't
  // throw MissingPluginException.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (_) async {});
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  group('ttsServiceProvider platform dispatch', () {
    test('returns SelfBuiltTtsServiceImpl on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider
              .overrideWithValue(_FakeSettingsRepoWithEngine()),
        ],
      );
      addTearDown(container.dispose);
      final svc = container.read(ttsServiceProvider);
      expect(svc, isA<SelfBuiltTtsServiceImpl>());
    });

    test('returns FlutterTtsServiceImpl on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider
              .overrideWithValue(_FakeSettingsRepoWithEngine()),
        ],
      );
      addTearDown(container.dispose);
      final svc = container.read(ttsServiceProvider);
      expect(svc, isA<FlutterTtsServiceImpl>());
    });

    test('returns FlutterTtsServiceImpl on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider
              .overrideWithValue(_FakeSettingsRepoWithEngine()),
        ],
      );
      addTearDown(container.dispose);
      final svc = container.read(ttsServiceProvider);
      expect(svc, isA<FlutterTtsServiceImpl>());
    });
  });
}
