// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/repositories/settings_repository.dart';
import 'package:zhiyue/features/settings/pages/tts_settings_section.dart';
import 'package:zhiyue/features/tts/providers/tts_engine_provider.dart';
import 'package:zhiyue/features/tts/providers/tts_playback_controller.dart';
import 'package:zhiyue/features/tts/providers/tts_settings_provider.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';
import 'package:zhiyue/services/tts/tts_engine_preference.dart';

import '../../../helpers/stub_tts_service.dart';

// In-memory settings repo (follows pattern from tts_engine_provider_test.dart).
// Honours the persisted tts.engine key so the harness can pre-set engine
// before the widget builds.
class _FakeSettingsRepo implements SettingsRepository {
  _FakeSettingsRepo({String? initialEngine}) : _data = {
        if (initialEngine != null) 'tts.engine': initialEngine,
      };

  final Map<String, dynamic> _data;

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
// TtsSettingsSection is a Column that expects a scrollable parent
// (grew past default 800x600 viewport after v1.15.0-alpha T7 added the
// engine selector Card).
Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tts_settings_section_test_');
    globalTtsSettingsDirOverride = tempDir;
    globalTtsServiceOverride = StubTtsService();
  });

  tearDown(() {
    // Best-effort: TtsSettingsNotifier._persist is async; on Windows the
    // File handle may still be open when we try to delete the temp dir,
    // producing errno 32. Swallow the deletion failure — the OS will
    // reap the temp dir on its own schedule.
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

  group('TtsSettingsSection', () {
    testWidgets('renders 朗读 header + 3 sliders (rate/pitch/volume)',
        (tester) async {
      await tester
          .pumpWidget(ProviderScope(child: _wrap(const TtsSettingsSection())));
      // Let TtsSettingsNotifier._load() settle.
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsNWidgets(3),
          reason: 'T8: rate/pitch/volume sliders must be present');
    });

    testWidgets('chapter boundary SegmentedButton switches mode on tap',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _wrap(const TtsSettingsSection()),
      ));
      await tester.pumpAndSettle();

      // Default is continuous; tap Ask segment → state flips to askAtEnd.
      expect(container.read(ttsSettingsProvider).chapterBoundary,
          TtsChapterBoundary.continuous);

      // Find SegmentedButton. We expect 2 segments.
      expect(find.byType(SegmentedButton<TtsChapterBoundary>), findsOneWidget);

      // Tap on the second segment (Ask at end). Segments render their label
      // text; tapping the label pointer works.
      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();

      expect(container.read(ttsSettingsProvider).chapterBoundary,
          TtsChapterBoundary.askAtEnd);
    });

    testWidgets('测试朗读 button dispatches play to TtsPlaybackController',
        (tester) async {
      final stub = StubTtsService();
      addTearDown(stub.dispose);
      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(stub),
      ]);
      addTearDown(container.dispose);
      // Watch so StateNotifier listeners are active.
      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _wrap(const TtsSettingsSection()),
      ));
      await tester.pumpAndSettle();

      // Before tapping: phase is idle.
      expect(
          container.read(ttsPlaybackControllerProvider).phase, TtsPhase.idle);

      // The Test Speak button's text comes from l10n key ttsTestSpeak.
      // In en locale fallback that's "Test Speak".
      final btn = find.byType(ElevatedButton);
      expect(btn, findsOneWidget,
          reason: 'T8: 测试朗读 ElevatedButton must be present');

      await tester.tap(btn);
      await tester.pumpAndSettle();

      // Verify controller entered the speaking pipeline. StubTtsService
      // synchronously emits TtsState.speaking inside speakSentence, so
      // the state machine transitions loading → speaking within the
      // pump cycle.
      final phase = container.read(ttsPlaybackControllerProvider).phase;
      expect(phase, TtsPhase.speaking,
          reason: 'T8: 测试朗读 must dispatch play() to TtsPlaybackController');

      // Scope must be an AI message scope with a sentinel id so it doesn't
      // collide with real chat messages.
      final scope = container.read(ttsPlaybackControllerProvider).scope
          as TtsScopeAiMessage;
      expect(scope.messageId, '__tts_test__',
          reason: 'T8: 测试朗读 playback scope must use sentinel messageId');

      // Stop playback to clean up engine state.
      await container.read(ttsPlaybackControllerProvider.notifier).stop();
      await tester.pumpAndSettle();
    });

    testWidgets('slider changes update ttsSettingsProvider', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _wrap(const TtsSettingsSection()),
      ));
      await tester.pumpAndSettle();

      // Initial rate is 0.0.
      expect(container.read(ttsSettingsProvider).rate, 0.0);

      // Drag rate slider (first Slider in tree) to the right.
      final rateSlider = tester.widget<Slider>(find.byType(Slider).first);
      // Sanity: divisions matches spec (20).
      expect(rateSlider.min, -1.0);
      expect(rateSlider.max, 1.0);
      expect(rateSlider.divisions, 20);

      // Tap far right of the slider track.
      final trackRect = tester.getRect(find.byType(Slider).first);
      await tester.tapAt(Offset(trackRect.right - 4, trackRect.center.dy));
      await tester.pumpAndSettle();

      // Rate should have changed (best-effort — divisions + tap location
      // introduce some variance, so we just check it's no longer 0.0).
      expect(container.read(ttsSettingsProvider).rate, isNot(0.0));
    });


    // v1.15.4-alpha T6 regression guard: system engine preserves original
    // behaviour (pitch slider enabled + voice tile routes to voice page).
    testWidgets(
        'system engine keeps pitch slider enabled and voice tile tappable',
        (tester) async {
      final container = ProviderContainer(overrides: [
        settingsRepositoryProvider
            .overrideWithValue(_FakeSettingsRepo(initialEngine: 'system')),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _wrap(const TtsSettingsSection()),
      ));
      await tester.pumpAndSettle();

      expect(
          container.read(ttsEngineProvider), TtsEnginePreference.system);

      // Pitch slider must be enabled.
      final sliders = tester.widgetList<Slider>(find.byType(Slider));
      final pitchSlider = sliders.elementAt(1);
      expect(pitchSlider.onChanged, isNotNull,
          reason: 'T6 regression: pitch slider must be enabled for system');

      // No hint text.
      expect(find.text('SherpaOnnx MeloTTS 不支持音调调整（POC 限制）'),
          findsNothing);

      // Voice tile must be tappable.
      final voiceIconFinder = find.byIcon(Icons.record_voice_over);
      final voiceTile = tester.widget<ListTile>(
          find.ancestor(of: voiceIconFinder, matching: find.byType(ListTile)));
      expect(voiceTile.onTap, isNotNull,
          reason: 'T6 regression: voice tile must be tappable for system');
    });

    testWidgets('shows 3 engine options, no SherpaOnnx', (tester) async {
      final container = ProviderContainer(overrides: [
        settingsRepositoryProvider
            .overrideWithValue(_FakeSettingsRepo(initialEngine: 'system')),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _wrap(const TtsSettingsSection()),
      ));
      await tester.pumpAndSettle();

      // Find dropdown, tap to open
      await tester.tap(find.byType(DropdownButtonFormField<TtsEnginePreference>));
      await tester.pumpAndSettle();

      // After opening dropdown, we should see all 3 options in the menu.
      // Use findsAtLeastNWidgets(2) because the selected value appears twice
      // (once in collapsed form, once in expanded menu).
      expect(find.text('系统（默认）'), findsAtLeastNWidgets(2));
      expect(find.text('火山引擎（云端）'), findsOneWidget);
      expect(find.text('阿里云 Qwen（云端）'), findsOneWidget);
      expect(find.textContaining('SherpaOnnx'), findsNothing);
    });

    // v1.16.0-alpha B8: cloud credentials forms appear only for their engine.
    testWidgets('volcengineCloud engine shows Volcengine credentials form',
        (tester) async {
      final container = ProviderContainer(overrides: [
        settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepo(initialEngine: 'volcengineCloud')),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _wrap(const TtsSettingsSection()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('火山引擎凭证'), findsOneWidget);
      expect(find.text('App ID'), findsOneWidget);
      expect(find.text('Access Token'), findsOneWidget);
      expect(find.text('声音'), findsOneWidget);
      expect(find.text('测试连接'), findsOneWidget);
      // Qwen form must NOT be visible.
      expect(find.text('阿里云 Qwen 凭证'), findsNothing);
    });

    testWidgets('qwenCloud engine shows Qwen credentials form',
        (tester) async {
      final container = ProviderContainer(overrides: [
        settingsRepositoryProvider
            .overrideWithValue(_FakeSettingsRepo(initialEngine: 'qwenCloud')),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _wrap(const TtsSettingsSection()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('阿里云 Qwen 凭证'), findsOneWidget);
      expect(find.text('API Key'), findsOneWidget);
      expect(find.text('Model'), findsOneWidget);
      expect(find.text('声音'), findsOneWidget);
      expect(find.text('测试连接'), findsOneWidget);
      // Volcengine form must NOT be visible.
      expect(find.text('火山引擎凭证'), findsNothing);
    });

    testWidgets('system engine shows neither cloud credentials form',
        (tester) async {
      final container = ProviderContainer(overrides: [
        settingsRepositoryProvider
            .overrideWithValue(_FakeSettingsRepo(initialEngine: 'system')),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _wrap(const TtsSettingsSection()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('火山引擎凭证'), findsNothing);
      expect(find.text('阿里云 Qwen 凭证'), findsNothing);
    });

    // v1.16.3-alpha: replaced v1.16.2-alpha OPPO/小米 autostart guidance +
    // 「打开系统 TTS 设置」action with engine-list-aware guidance and a
    // 「改用云端引擎」action that switches ttsEngineProvider to qwenCloud.
    // The system-settings path didn't actually fix the ROM binding rejection;
    // switching engine is the actionable fix.
    testWidgets(
        'OPPO/Xiaomi init_error shows SnackBar with 改用云端引擎 button',
        (tester) async {
      final stub = StubTtsService();
      addTearDown(stub.dispose);
      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(stub),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _wrap(const TtsSettingsSection()),
      ));
      await tester.pumpAndSettle();

      // Simulate Kotlin init_error event being surfaced through the
      // TtsService.error stream — engines list present (ROM rejected binding).
      stub.emitError(
          '系统 TTS 初始化失败（status=-1, device=Xiaomi）。已尝试引擎：com.google.android.tts。'
          '建议改用云端 TTS 引擎或检查系统 TTS 设置。');
      await tester.pumpAndSettle();

      // SnackBar visible with error message + ROM-rejection guidance.
      expect(find.textContaining('系统 TTS 初始化失败'), findsOneWidget);
      expect(find.textContaining('ROM 拒绝第三方 app 绑定'), findsOneWidget);
      expect(find.text('改用云端引擎'), findsOneWidget);
      // Old action removed.
      expect(find.text('打开系统 TTS 设置'), findsNothing);
    });

    testWidgets(
        'init_error SnackBar with empty engines list shows install guidance',
        (tester) async {
      final stub = StubTtsService();
      addTearDown(stub.dispose);
      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(stub),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _wrap(const TtsSettingsSection()),
      ));
      await tester.pumpAndSettle();

      stub.emitError(
          '系统 TTS 初始化失败（status=-1, device=Xiaomi）。未检测到可用 TTS 引擎。'
          '建议改用云端 TTS 引擎或检查系统 TTS 设置。');
      await tester.pumpAndSettle();

      expect(find.textContaining('未安装标准 TTS 引擎'), findsOneWidget);
      expect(find.textContaining('Google TTS'), findsOneWidget);
    });

    // v1.16.3-alpha: tapping 「改用云端引擎」switches engine to qwenCloud
    // (deviation from plan: sherpaOnnxMelo removed in v1.16.0-alpha POC
    // cleanup; qwenCloud picked as the more accessible cloud engine — only
    // needs API key, vs Volcengine which needs App ID + Token + Voice).
    testWidgets(
        'init_error SnackBar 改用云端引擎 button switches engine on tap',
        (tester) async {
      final stub = StubTtsService();
      addTearDown(stub.dispose);
      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(stub),
        settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _wrap(const TtsSettingsSection()),
      ));
      await tester.pumpAndSettle();

      expect(container.read(ttsEngineProvider), TtsEnginePreference.system);

      stub.emitError(
          '系统 TTS 初始化失败（status=-1, device=Xiaomi）。已尝试引擎：com.google.android.tts。'
          '建议改用云端 TTS 引擎或检查系统 TTS 设置。');
      await tester.pumpAndSettle();

      await tester.tap(find.text('改用云端引擎'));
      // setEngine is async: awaits _loaded, sets state, then awaits repo.set.
      // Pump a frame + settle so microtask queue drains.
      await tester.pump();
      await tester.pumpAndSettle();

      expect(container.read(ttsEngineProvider), TtsEnginePreference.qwenCloud,
          reason: 'v1.16.3-alpha: 改用云端引擎 button must switch ttsEngineProvider '
              'to qwenCloud for graceful degradation when system TTS cannot bind.');
    });

    testWidgets('init_error SnackBar uses 15s duration for guidance reading',
        (tester) async {
      final stub = StubTtsService();
      addTearDown(stub.dispose);
      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(stub),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _wrap(const TtsSettingsSection()),
      ));
      await tester.pumpAndSettle();

      stub.emitError(
          '系统 TTS 初始化失败（status=-1, device=OPPO）。已尝试引擎：com.heytap.speechservice。'
          '建议改用云端 TTS 引擎或检查系统 TTS 设置。');
      await tester.pumpAndSettle();

      // Find the SnackBar widget and verify it has the longer 15s duration
      // (v1.16.3-alpha: extended from 10s → 15s to give users time to read
      // both the diagnosis text and the action button label).
      final snackbar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackbar.duration, const Duration(seconds: 15),
          reason: 'v1.16.3-alpha: SnackBar must persist 15s so users can '
              'read the ROM-rejection diagnosis + action label.');
    });
  });
}
