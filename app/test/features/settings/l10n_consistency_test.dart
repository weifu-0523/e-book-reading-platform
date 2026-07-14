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

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('arb zh and en contain the same keys', () {
    final zh = _loadKeys('lib/l10n/app_zh.arb');
    final en = _loadKeys('lib/l10n/app_en.arb');
    expect(en.keys.toSet(), equals(zh.keys.toSet()),
        reason: 'zh and en arb must have identical key sets');
  });

  test('critical keys present in both arb files', () {
    for (final arb in ['lib/l10n/app_zh.arb', 'lib/l10n/app_en.arb']) {
      final keys = _loadKeys(arb).keys.toSet();
      for (final required in [
        'appTitle',
        'settingsTitle',
        'settingsSectionReading',
        'settingsSectionFonts',
        'settingsSectionAppearance',
        'settingsSectionLanguage',
        'settingsSectionAbout',
      ]) {
        expect(keys, contains(required),
            reason: '$arb missing required key: $required');
      }
    }
  });
}

Map<String, dynamic> _loadKeys(String relPath) {
  final file = File(relPath);
  final raw = file.readAsStringSync();
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return Map.fromEntries(
      decoded.entries.where((e) => !e.key.startsWith('@')));
}
