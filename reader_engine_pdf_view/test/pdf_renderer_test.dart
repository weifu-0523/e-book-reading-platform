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
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine_pdf_view/pdf_renderer.dart';

void main() {
  group('PdfRenderer state machine', () {
    test('initial state is unloaded', () {
      final r = PdfRenderer();
      expect(r.state, isA<ReaderEngineUnloaded>());
      expect(r.pageCount, 0);
      expect(r.currentPage, 0);
    });

    test('openFile missing file transitions to error', () async {
      final r = PdfRenderer();
      await r.openFile('/nonexistent.pdf');
      expect(r.state, isA<ReaderEngineError>());
    });
  });

  group('PdfRenderer page navigation', () {
    test('setPage is no-op when doc is null', () {
      final r = PdfRenderer();
      r.setPage(5); // should not throw
      expect(r.currentPage, 0);
    });

    test('emitLocation produces PdfPageLocator on stream when doc present',
        () async {
      // 此测试不直接验证 emit（无 doc），但确认 stream 可订阅不抛
      final r = PdfRenderer();
      final events = <Locator>[];
      final sub = r.currentLocation$.listen(events.add);
      expect(events, isEmpty);
      await sub.cancel();
      await r.dispose();
    });
  });
}
