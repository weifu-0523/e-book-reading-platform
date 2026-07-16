// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

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
class TtsSettings {
  final double rate;
  final double pitch;
  final double volume;
  final TtsChapterBoundary chapterBoundary;

  const TtsSettings({
    this.rate = 0.0,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.chapterBoundary = TtsChapterBoundary.continuous,
  });

  Map<String, dynamic> toJson() => {
        'rate': rate,
        'pitch': pitch,
        'volume': volume,
        'chapterBoundary': chapterBoundary.name,
      };

  factory TtsSettings.fromJson(Map<String, dynamic> j) => TtsSettings(
        rate: _clamp((j['rate'] as num?)?.toDouble() ?? 0.0, -1.0, 1.0),
        pitch: _clamp((j['pitch'] as num?)?.toDouble() ?? 1.0, 0.5, 2.0),
        volume: _clamp((j['volume'] as num?)?.toDouble() ?? 1.0, 0.0, 1.0),
        chapterBoundary: TtsChapterBoundary.values.firstWhere(
          (e) => e.name == j['chapterBoundary'],
          orElse: () => TtsChapterBoundary.continuous,
        ),
      );

  TtsSettings copyWith({
    double? rate,
    double? pitch,
    double? volume,
    TtsChapterBoundary? chapterBoundary,
  }) =>
      TtsSettings(
        rate: rate ?? this.rate,
        pitch: pitch ?? this.pitch,
        volume: volume ?? this.volume,
        chapterBoundary: chapterBoundary ?? this.chapterBoundary,
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
class TtsSettingsNotifier extends StateNotifier<TtsSettings> {
  final Directory _dir;
  File? _file;

  TtsSettingsNotifier(this._dir) : super(const TtsSettings()) {
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
}

final ttsSettingsProvider =
    StateNotifierProvider<TtsSettingsNotifier, TtsSettings>(
  (ref) => TtsSettingsNotifier(ref.watch(ttsSettingsDirProvider)),
);
