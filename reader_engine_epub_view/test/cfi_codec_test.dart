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
import 'package:reader_engine_epub_view/cfi_codec.dart';

void main() {
  group('encode', () {
    test('encodes chapter 0 offset 0', () {
      expect(encode(0, 0), '0:0');
    });

    test('encodes typical case', () {
      expect(encode(4, 1024), '4:1024');
    });

    test('encodes large offset', () {
      expect(encode(12, 999999), '12:999999');
    });
  });

  group('decode', () {
    test('decodes valid cfi', () {
      expect(decode('4:1024'), (chapterIndex: 4, charOffset: 1024));
    });

    test('decodes boundary chapter 0 offset 0', () {
      expect(decode('0:0'), (chapterIndex: 0, charOffset: 0));
    });

    test('decodes large offset', () {
      expect(decode('12:999999'), (chapterIndex: 12, charOffset: 999999));
    });

    test('returns null for empty string', () {
      expect(decode(''), isNull);
    });

    test('returns null for missing colon', () {
      expect(decode('41024'), isNull);
    });

    test('returns null for non-numeric chapter', () {
      expect(decode('abc:10'), isNull);
    });

    test('returns null for non-numeric offset', () {
      expect(decode('4:xyz'), isNull);
    });

    test('returns null for negative numbers', () {
      expect(decode('-1:10'), isNull);
      expect(decode('4:-1'), isNull);
    });
  });

  group('isValid', () {
    test('accepts valid cfi', () {
      expect(isValid('4:1024'), isTrue);
    });

    test('accepts boundary', () {
      expect(isValid('0:0'), isTrue);
    });

    test('rejects empty', () {
      expect(isValid(''), isFalse);
    });

    test('rejects malformed', () {
      expect(isValid('abc'), isFalse);
      expect(isValid(':10'), isFalse);
      expect(isValid('4:'), isFalse);
      expect(isValid('4:10:20'), isFalse);
    });
  });

  group('round-trip integrity', () {
    test('encode → decode → equals input', () {
      for (final original in const [
        (chapterIndex: 0, charOffset: 0),
        (chapterIndex: 4, charOffset: 1024),
        (chapterIndex: 99, charOffset: 123456),
      ]) {
        final encoded = encode(original.chapterIndex, original.charOffset);
        final decoded = decode(encoded);
        expect(decoded, original, reason: 'round-trip failed for $original');
      }
    });
  });
}
