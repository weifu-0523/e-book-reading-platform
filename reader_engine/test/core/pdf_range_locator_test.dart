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

void main() {
  group('PdfRangeLocator', () {
    test('toJson serializes all fields', () {
      const loc = PdfRangeLocator(
        page: 5,
        startOffset: 10,
        endOffset: 20,
        quote: 'selected text',
      );
      expect(loc.toJson(), {
        'type': 'pdfRange',
        'page': 5,
        'startOffset': 10,
        'endOffset': 20,
        'quote': 'selected text',
      });
    });

    test('fromJson round-trips', () {
      const original = PdfRangeLocator(
        page: 3,
        startOffset: 0,
        endOffset: 5,
        quote: 'hello',
      );
      final restored = Locator.fromJson(original.toJson());
      expect(restored, original);
    });

    test('rejects zero-length quote', () {
      expect(
        () => PdfRangeLocator(
          page: 1,
          startOffset: 0,
          endOffset: 5,
          quote: '',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects endOffset <= startOffset', () {
      expect(
        () => PdfRangeLocator(
          page: 1,
          startOffset: 10,
          endOffset: 10,
          quote: 'x',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects page < 1', () {
      expect(
        () => PdfRangeLocator(
          page: 0,
          startOffset: 0,
          endOffset: 5,
          quote: 'x',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Locator.fromJson handles double-encoded ints (JS compat)', () {
      final restored = Locator.fromJson({
        'type': 'pdfRange',
        'page': 5.0,
        'startOffset': 10.0,
        'endOffset': 20.0,
        'quote': 'q',
      });
      expect(restored, isA<PdfRangeLocator>());
      expect((restored as PdfRangeLocator).page, 5);
    });
  });
}
