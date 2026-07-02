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

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';

void main() {
  group('ReaderUiState.defaults', () {
    test('chromeVisible default true on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final s = ReaderUiState.defaults();
      expect(s.chromeVisible, true,
          reason: 'desktop readers should show chrome AppBar by default');
    });

    test('chromeVisible default true on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final s = ReaderUiState.defaults();
      expect(s.chromeVisible, true);
    });

    test('chromeVisible default true on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final s = ReaderUiState.defaults();
      expect(s.chromeVisible, true);
    });

    test('chromeVisible default false on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final s = ReaderUiState.defaults();
      expect(s.chromeVisible, false,
          reason:
              'mobile uses fullscreen mode (T9) instead of persistent chrome');
    });

    test('chromeVisible default false on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final s = ReaderUiState.defaults();
      expect(s.chromeVisible, false);
    });

    test('other fields retain default values', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final s = ReaderUiState.defaults();
      expect(s.tocDrawerOpen, false);
      expect(s.typographyPanelOpen, false);
    });
  });
}
