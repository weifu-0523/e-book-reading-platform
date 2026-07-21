// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart' show settingsRepositoryProvider;
import '../../../data/repositories/settings_repository.dart';
import '../../../services/tts/tts_engine_preference.dart';

const _storageKey = 'tts.engine';

/// POC v1.15.0-alpha：用户选择的 TTS 引擎。读 secure_storage 持久化。
/// Phase 2 会加更多引擎选项（theresa / aishell3 / cosyvoice-desktop）。
final ttsEngineProvider =
    StateNotifierProvider<TtsEngineNotifier, TtsEnginePreference>(
  (ref) => TtsEngineNotifier(ref.watch(settingsRepositoryProvider)),
);

class TtsEngineNotifier extends StateNotifier<TtsEnginePreference> {
  TtsEngineNotifier(this._repo) : super(TtsEnginePreference.system) {
    _loaded = _load();
  }

  final SettingsRepository _repo;
  late final Future<void> _loaded;

  Future<void> _load() async {
    final persisted = await _repo.getOrNull<String>(_storageKey);
    if (!mounted) return;
    state = TtsEnginePreferenceX.fromPersistedValue(persisted);
  }

  Future<void> setEngine(TtsEnginePreference pref) async {
    await _loaded;
    if (!mounted) return;
    state = pref;
    await _repo.set<String>(_storageKey, pref.persistedValue);
  }
}
