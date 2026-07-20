// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

class AppSettings {
  final bool promptedDefaultReader;

  const AppSettings({this.promptedDefaultReader = false});

  Map<String, dynamic> toJson() => {
        'promptedDefaultReader': promptedDefaultReader,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        promptedDefaultReader: (j['promptedDefaultReader'] as bool?) ?? false,
      );

  AppSettings copyWith({bool? promptedDefaultReader}) => AppSettings(
        promptedDefaultReader: promptedDefaultReader ?? this.promptedDefaultReader,
      );
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  final Directory _dir;
  File? _file;

  AppSettingsNotifier(this._dir) : super(const AppSettings()) {
    _load();
  }

  File get _settingsFile {
    _file ??= File('${_dir.path}/app_settings.json');
    return _file!;
  }

  Future<void> _load() async {
    try {
      if (await _settingsFile.exists()) {
        final raw = await _settingsFile.readAsString();
        final j = jsonDecode(raw) as Map<String, dynamic>;
        state = AppSettings.fromJson(j);
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      await _settingsFile.writeAsString(jsonEncode(state.toJson()));
    } catch (_) {}
  }

  Future<void> setPromptedDefaultReader(bool value) async {
    state = state.copyWith(promptedDefaultReader: value);
    await _persist();
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (ref) => AppSettingsNotifier(ref.watch(appSettingsDirProvider)),
);
