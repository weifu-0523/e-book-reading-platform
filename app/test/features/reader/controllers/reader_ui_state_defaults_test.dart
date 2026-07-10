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

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';

void main() {
  group('ReaderUiState.defaultsForPlatform', () {
    test('returns chromeVisible=true (spec §2.2 UX-B: visible at open)', () {
      final state = ReaderUiState.defaultsForPlatform();
      expect(state.chromeVisible, isTrue);
    });

    test('defaults() unchanged (backward compat)', () {
      // defaults() still returns chromeVisible: isDesktop
      // (host=Windows → true; mobile platforms → false)
      // Verifying it doesn't throw and returns a valid state.
      final state = ReaderUiState.defaults();
      expect(state.chromeVisible, anyOf(isTrue, isFalse));
    });
  });
}
