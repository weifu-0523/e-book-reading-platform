// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../services/tts/tts_service.dart';
import 'tts_playback_controller.dart' show ttsServiceProvider;

/// Chapter-boundary behaviour when TTS reaches the end of a chapter.
///
/// - [continuous]: immediately advance to the next chapter and keep reading.
/// - [askAtEnd]: pause and prompt the user before continuing.
enum TtsChapterBoundary { continuous, askAtEnd }

/// User-configurable TTS parameters persisted across sessions.
///
/// Ranges match `flutter_tts` native defaults:
/// - [rate]: -1.0 (slower) .. 1.0 (faster); 0.0 = normal.
/// - [pitch]: 0.5 .. 2.0; 1.0 = normal.
/// - [volume]: 0.0 .. 1.0; 1.0 = full.
/// - [voiceId]: null = system default; otherwise opaque platform voice id
///   returned by [TtsService.getVoices] (e.g. `"xiaoxiao|zh-CN"`).
class TtsSettings {
  final double rate;
  final double pitch;
  final double volume;
  final TtsChapterBoundary chapterBoundary;
  final String? voiceId;

  const TtsSettings({
    this.rate = 0.0,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.chapterBoundary = TtsChapterBoundary.continuous,
    this.voiceId,
  });

  Map<String, dynamic> toJson() => {
        'rate': rate,
        'pitch': pitch,
        'volume': volume,
        'chapterBoundary': chapterBoundary.name,
        'voiceId': voiceId,
      };

  factory TtsSettings.fromJson(Map<String, dynamic> j) => TtsSettings(
        rate: _clamp((j['rate'] as num?)?.toDouble() ?? 0.0, -1.0, 1.0),
        pitch: _clamp((j['pitch'] as num?)?.toDouble() ?? 1.0, 0.5, 2.0),
        volume: _clamp((j['volume'] as num?)?.toDouble() ?? 1.0, 0.0, 1.0),
        chapterBoundary: TtsChapterBoundary.values.firstWhere(
          (e) => e.name == j['chapterBoundary'],
          orElse: () => TtsChapterBoundary.continuous,
        ),
        voiceId: j['voiceId'] as String?,
      );

  /// [clearVoiceId]: pass `true` to explicitly set [voiceId] back to null
  /// (since `voiceId: null` alone would be interpreted as "unchanged").
  TtsSettings copyWith({
    double? rate,
    double? pitch,
    double? volume,
    TtsChapterBoundary? chapterBoundary,
    String? voiceId,
    bool clearVoiceId = false,
  }) =>
      TtsSettings(
        rate: rate ?? this.rate,
        pitch: pitch ?? this.pitch,
        volume: volume ?? this.volume,
        chapterBoundary: chapterBoundary ?? this.chapterBoundary,
        voiceId: clearVoiceId ? null : (voiceId ?? this.voiceId),
      );

  static double _clamp(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);
}

/// Resolves the directory where `tts_settings.json` is stored.
/// Tests inject a temp dir via [globalTtsSettingsDirOverride].
final ttsSettingsDirProvider = Provider<Directory>((ref) {
  return globalTtsSettingsDirOverride!;
});

/// [StateNotifier] that owns [TtsSettings] and round-trips them to a JSON file.
///
/// Load is async-from-constructor — first frame observes defaults until the
/// file read settles (typically one microtask). Persistence is best-effort:
/// any I/O error is swallowed so a read-only filesystem never breaks the UI.
///
/// v1.14.0-alpha T5: also owns [TtsService] so [setVoice] can persist +
/// eagerly push the change to the live engine in one call. Failures from
/// the engine sync are swallowed here — the user-visible error surfaces via
/// [TtsService.error] stream.
class TtsSettingsNotifier extends StateNotifier<TtsSettings> {
  final Directory _dir;
  final TtsService _ttsService;
  File? _file;

  TtsSettingsNotifier(this._dir, this._ttsService) : super(const TtsSettings()) {
    _load();
  }

  File get _settingsFile {
    _file ??= File('${_dir.path}/tts_settings.json');
    return _file!;
  }

  Future<void> _load() async {
    try {
      if (await _settingsFile.exists()) {
        final raw = await _settingsFile.readAsString();
        final j = jsonDecode(raw) as Map<String, dynamic>;
        state = TtsSettings.fromJson(j);
      }
    } catch (_) {
      // corrupted file — keep defaults
    }
  }

  Future<void> _persist() async {
    try {
      await _settingsFile.writeAsString(jsonEncode(state.toJson()));
    } catch (_) {
      // best-effort
    }
  }

  Future<void> setRate(double v) async {
    state = state.copyWith(rate: TtsSettings._clamp(v, -1.0, 1.0));
    await _persist();
  }

  Future<void> setPitch(double v) async {
    state = state.copyWith(pitch: TtsSettings._clamp(v, 0.5, 2.0));
    await _persist();
  }

  Future<void> setVolume(double v) async {
    state = state.copyWith(volume: TtsSettings._clamp(v, 0.0, 1.0));
    await _persist();
  }

  Future<void> setChapterBoundary(TtsChapterBoundary mode) async {
    state = state.copyWith(chapterBoundary: mode);
    await _persist();
  }

  /// v1.14.0-alpha T5: sets [voiceId], persists it, and best-effort pushes
  /// the change to the live TtsService so the next sentence uses the new
  /// voice without an app restart. Pass `null` to revert to system default.
  Future<void> setVoice(String? voiceId) async {
    if (voiceId == null) {
      state = state.copyWith(clearVoiceId: true);
    } else {
      state = state.copyWith(voiceId: voiceId);
    }
    await _persist();
    try {
      await _ttsService.setVoice(voiceId);
    } catch (_) {
      // ignored — state still persisted; user can retry via UI.
    }
  }
}

final ttsSettingsProvider =
    StateNotifierProvider<TtsSettingsNotifier, TtsSettings>(
  (ref) => TtsSettingsNotifier(
    ref.watch(ttsSettingsDirProvider),
    ref.watch(ttsServiceProvider),
  ),
);
