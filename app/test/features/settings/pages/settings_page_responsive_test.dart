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
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/features/settings/pages/settings_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

import '../../../helpers/stub_tts_service.dart';

Widget _harness() {
  return const ProviderScope(
    child: MaterialApp(
      locale: Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsPage(),
    ),
  );
}

void main() {
  // T8 (2026-07-16): SettingsPage embeds TtsSettingsSection, which needs
  // globalTtsSettingsDirOverride to be non-null (the section's provider
  // graph dereferences it for tts_settings.json persistence).
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('settings_responsive_test_');
    globalTtsSettingsDirOverride = tempDir;
    globalTtsServiceOverride = StubTtsService();
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
    globalTtsSettingsDirOverride = null;
    globalTtsServiceOverride = null;
  });

  testWidgets('compact viewport renders settings page without exception',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.byType(SettingsPage), findsOneWidget);
  });
}
