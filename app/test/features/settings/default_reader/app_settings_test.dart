// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/settings/default_reader/app_settings.dart';

void main() {
  test('AppSettings round-trip through json', () {
    const s = AppSettings(promptedDefaultReader: true);
    final j = s.toJson();
    expect(j['promptedDefaultReader'], true);
    expect(AppSettings.fromJson(j).promptedDefaultReader, true);
  });

  test('AppSettings.fromJson tolerates missing field (old files)', () {
    final s = AppSettings.fromJson({});
    expect(s.promptedDefaultReader, false);
  });

  test('Notifier persists promptedDefaultReader to disk', () async {
    final tmpDir = await Directory.systemTemp.createTemp('app_settings_test');
    addTearDown(() => tmpDir.delete(recursive: true));
    final notifier = AppSettingsNotifier(tmpDir);
    await notifier.setPromptedDefaultReader(true);
    final file = File('${tmpDir.path}/app_settings.json');
    expect(await file.exists(), isTrue);
    final raw = await file.readAsString();
    expect(raw, contains('"promptedDefaultReader":true'));
  });
}
