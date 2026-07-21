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

    // v1.15.4-alpha T6: pitch slider disabled + hint shown when engine
    // is SherpaOnnx (sherpa_onnx OfflineTts API has no pitch param).
    testWidgets(
        'pitch slider disabled when engine is sherpaOnnxMelo '
        'and shows hint text', (tester) async {
      final container = ProviderContainer(overrides: [
        settingsRepositoryProvider
            .overrideWithValue(_FakeSettingsRepo(initialEngine: 'sherpaOnnxMelo')),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _wrap(const TtsSettingsSection()),
      ));
      await tester.pumpAndSettle();

      // Sanity: engine is SherpaOnnx.
      expect(container.read(ttsEngineProvider),
          TtsEnginePreference.sherpaOnnxMelo);

      // Three sliders present (rate/pitch/volume). The pitch slider is the
      // second one in tree order.
      final sliders = tester.widgetList<Slider>(find.byType(Slider));
      expect(sliders.length, 3);
      final pitchSlider = sliders.elementAt(1);
      expect(pitchSlider.min, 0.5);
      expect(pitchSlider.max, 2.0);
      // T6: SherpaOnnx has no pitch API → slider must be disabled.
      expect(pitchSlider.onChanged, isNull,
          reason: 'T6: pitch slider must be disabled for SherpaOnnx engine');

      // Hint text shown below slider.
      expect(find.text('SherpaOnnx MeloTTS 不支持音调调整（POC 限制）'),
          findsOneWidget,
          reason: 'T6: pitch hint must be visible when engine is SherpaOnnx');
    });

    // v1.15.4-alpha T6: voice tile disabled + subtitle hint shown when
    // engine is SherpaOnnx (MeloTTS-zh_en single speaker only).
    testWidgets(
        'voice tile onTap null and subtitle hint shown when engine is '
        'sherpaOnnxMelo', (tester) async {
      final container = ProviderContainer(overrides: [
        settingsRepositoryProvider
            .overrideWithValue(_FakeSettingsRepo(initialEngine: 'sherpaOnnxMelo')),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _wrap(const TtsSettingsSection()),
      ));
      await tester.pumpAndSettle();

      // Find the voice tile by leading icon (Icons.record_voice_over).
      final voiceIconFinder = find.byIcon(Icons.record_voice_over);
      expect(voiceIconFinder, findsOneWidget);
      final voiceTile = tester.widget<ListTile>(
          find.ancestor(of: voiceIconFinder, matching: find.byType(ListTile)));
      expect(voiceTile.onTap, isNull,
          reason: 'T6: voice tile must be disabled for SherpaOnnx engine');

      // Subtitle hint must reflect single-voice limitation.
      expect(find.text('SherpaOnnx MeloTTS 仅单声音（POC 限制）'), findsOneWidget,
          reason: 'T6: voice tile subtitle hint must be present');
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
  });
}
