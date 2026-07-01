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
import 'package:reader_engine_epub_view/src/chapter_end_event.dart';

void main() {
  group('ChapterEndEvent', () {
    test('fields exposed correctly', () {
      const event = ChapterEndEvent(chapterIndex: 3, isLastChapter: false);
      expect(event.chapterIndex, 3);
      expect(event.isLastChapter, isFalse);
    });

    test('equality holds for same fields', () {
      const a = ChapterEndEvent(chapterIndex: 5, isLastChapter: true);
      const b = ChapterEndEvent(chapterIndex: 5, isLastChapter: true);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('equality differs when chapterIndex differs', () {
      const a = ChapterEndEvent(chapterIndex: 5, isLastChapter: true);
      const b = ChapterEndEvent(chapterIndex: 6, isLastChapter: true);
      expect(a, isNot(equals(b)));
    });

    test('equality differs when isLastChapter differs', () {
      const a = ChapterEndEvent(chapterIndex: 5, isLastChapter: true);
      const b = ChapterEndEvent(chapterIndex: 5, isLastChapter: false);
      expect(a, isNot(equals(b)));
    });

    test('toString includes both fields', () {
      const event = ChapterEndEvent(chapterIndex: 2, isLastChapter: true);
      final s = event.toString();
      expect(s.contains('2'), isTrue);
      expect(s.contains('true'), isTrue);
    });
  });
}
