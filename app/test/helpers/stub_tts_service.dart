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

import 'dart:async';

import 'package:zhiyue/services/tts/tts_service.dart';

/// No-op [TtsService] stub for widget tests.
///
/// Use to override [ttsServiceProvider] in tests that render widgets
/// transitively depending on TTS (e.g., AiInputComposer → TtsMiniControls,
/// SettingsPage → 测试朗读 button). Without this, [ProviderContainer.dispose]
/// triggers [FlutterTtsServiceImpl.dispose] → flutter_tts platform channel →
/// [MissingPluginException] in widget-test env (no plugin registered).
///
/// Default behavior:
/// - [speakSentence] emits [TtsState.speaking] so the playback controller
///   transitions `loading → speaking` within a single pump cycle (matches
///   the contract `TtsMiniControls` widget tests rely on).
/// - All other methods are no-ops.
/// - [state] / [progress] / [error] are broadcast controllers so test code
///   can emit additional events via [emitState] (extensible).
///
/// History: Originally inlined as `_StubTtsService` / `_NoopTtsService` /
/// `_TtsServiceStubs` in T6/T7 test files. T8 extracted the shared helper
/// to prevent the platform-channel cascade from recurring in T9+ tests.
class StubTtsService implements TtsService {
  final StreamController<TtsState> _state =
      StreamController<TtsState>.broadcast();
  final StreamController<TtsProgress> _progress =
      StreamController<TtsProgress>.broadcast();
  final StreamController<String> _error = StreamController<String>.broadcast();

  @override
  Stream<TtsState> get state => _state.stream;
  @override
  Stream<TtsProgress> get progress => _progress.stream;
  @override
  Stream<String> get error => _error.stream;

  @override
  bool get isInitialized => true;

  @override
  int? get eventReceivedCountForDebug => null;

  /// Emit a state event from test code (e.g., to simulate speaking→idle
  /// queue advance). Default impl already emits [TtsState.speaking] inside
  /// [speakSentence], so most tests don't need to call this directly.
  void emitState(TtsState s) => _state.add(s);

  @override
  Future<void> init() async {}

  @override
  Future<void> speakSentence(Sentence s) async {
    _state.add(TtsState.speaking);
  }

  @override
  void setCurrentSentenceIndex(int idx) {}

  @override
  Future<void> stop() async {
    _state.add(TtsState.idle);
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> setSpeechRate(double r) async {}

  @override
  Future<void> setPitch(double p) async {}

  @override
  Future<void> setVolume(double v) async {}

  @override
  Future<bool> isLanguageAvailable(String l) async => true;

  @override
  Future<bool> isLanguageInstalled(String l) async => true;

  @override
  Future<String?> getDefaultEngine() async => null;

  @override
  Future<void> dispose() async {
    await _state.close();
    await _progress.close();
    await _error.close();
  }
}
