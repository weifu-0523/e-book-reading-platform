// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/repositories/settings_repository.dart';
import 'package:zhiyue/features/settings/pages/tts_settings_section.dart';
import 'package:zhiyue/features/tts/providers/tts_engine_provider.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';
import 'package:zhiyue/services/tts/tts_engine_preference.dart';

import '../../../helpers/stub_tts_service.dart';

/// In-memory settings repo (follows pattern from tts_engine_provider_test.dart)
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

// Wrap in SingleChildScrollView mirroring settings_page.dart's ListView —
// TtsSettingsSection is a Column that expects a scrollable parent.
Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: child,
        ),
      ),
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tts_settings_section_engine_test_');
    globalTtsSettingsDirOverride = tempDir;
    globalTtsServiceOverride = StubTtsService();
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {
      // best-effort cleanup
    }
    globalTtsSettingsDirOverride = null;
    globalTtsServiceOverride = null;
  });

  testWidgets('TtsSettingsSection shows engine dropdown with 2 options',
      (tester) async {
    final container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _wrap(const TtsSettingsSection()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('TTS 引擎（实验）'), findsOneWidget);
    expect(find.text('系统（默认）'), findsOneWidget);

    // Tap the dropdown
    await tester.tap(find.text('系统（默认）'));
    await tester.pumpAndSettle();

    expect(find.text('SherpaOnnx MeloTTS（163MB）'), findsOneWidget);
  });

  testWidgets('switching engine updates ttsEngineProvider state',
      (tester) async {
    final container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _wrap(const TtsSettingsSection()),
    ));
    await tester.pumpAndSettle();

    expect(
      container.read(ttsEngineProvider),
      TtsEnginePreference.system,
    );

    // Tap dropdown, select SherpaOnnx
    await tester.tap(find.text('系统（默认）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SherpaOnnx MeloTTS（163MB）'));
    await tester.pumpAndSettle();

    expect(
      container.read(ttsEngineProvider),
      TtsEnginePreference.sherpaOnnxMelo,
    );
  });
}
