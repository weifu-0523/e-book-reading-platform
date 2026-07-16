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
import 'package:zhiyue/data/models/last_tts_position.dart';

void main() {
  group('LastTtsPosition', () {
    test('serialize/deserialize round-trip', () {
      final pos = LastTtsPosition(
          chapterIdx: 3, sentenceIdx: 42, updatedAt: 1721234567890);
      final json = pos.toJson();
      expect(LastTtsPosition.fromJson(json), pos);
    });

    test('fromJson tolerant to missing fields', () {
      expect(LastTtsPosition.fromJson({}), isNotNull);
      expect(LastTtsPosition.fromJson({}).chapterIdx, 0);
      expect(LastTtsPosition.fromJson({}).sentenceIdx, 0);
      expect(LastTtsPosition.fromJson({}).updatedAt, 0);
    });

    test('fromJson tolerant to wrong types', () {
      final pos = LastTtsPosition.fromJson({
        'chapterIdx': 'not a number',
        'sentenceIdx': true,
        'updatedAt': null,
      });
      expect(pos.chapterIdx, 0);
      expect(pos.sentenceIdx, 0);
      expect(pos.updatedAt, 0);
    });

    test('equality', () {
      final a = LastTtsPosition(chapterIdx: 1, sentenceIdx: 2, updatedAt: 3);
      final b = LastTtsPosition(chapterIdx: 1, sentenceIdx: 2, updatedAt: 3);
      final c = LastTtsPosition(chapterIdx: 1, sentenceIdx: 9, updatedAt: 3);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });
  });
}
