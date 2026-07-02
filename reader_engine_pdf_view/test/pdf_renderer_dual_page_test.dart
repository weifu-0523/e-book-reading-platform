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
import 'package:reader_engine_pdf_view/pdf_renderer.dart';

/// T13: PDF dual-page layout unit tests.
///
/// Widget-level assertions (two PdfViewer widgets rendered side-by-side)
/// can't run under `flutter test` because PdfViewer requires the PDFium
/// native binary, which isn't available in the headless test runner (see
/// `app/test/features/reader/reader_page_pdf_integration_test.dart` for
/// the same constraint). So we cover the testable invariants:
///
/// - `dualPageMode` defaults to false (no behavior change for narrow screens).
/// - `isScanned` getter returns false until FutureBuilder resolves.
/// - `setPage` is guarded against no-doc / negative input in dual mode.
void main() {
  group('PdfRenderer.dualPageMode flag', () {
    test('defaults to false (backward compatible)', () {
      final r = PdfRenderer();
      expect(r.dualPageMode, isFalse);
    });

    test('is mutable (reader side sets it each build)', () {
      final r = PdfRenderer();
      r.dualPageMode = true;
      expect(r.dualPageMode, isTrue);
      r.dualPageMode = false;
      expect(r.dualPageMode, isFalse);
    });

    test('isScanned getter returns false until FutureBuilder resolves', () {
      final r = PdfRenderer();
      expect(r.isScanned, isFalse);
    });
  });

  group('PdfRenderer.setPage dual-mode guards', () {
    test('dual mode does not throw on no-doc', () {
      final r = PdfRenderer();
      r.dualPageMode = true;
      r.setPage(3);
      expect(r.currentPage, 0);
    });

    test('dual mode does not throw on negative page', () {
      final r = PdfRenderer();
      r.dualPageMode = true;
      r.setPage(-5);
      expect(r.currentPage, 0);
    });

    test('single mode (default) also guards no-doc', () {
      final r = PdfRenderer();
      r.setPage(99);
      expect(r.currentPage, 0);
    });
  });
}
