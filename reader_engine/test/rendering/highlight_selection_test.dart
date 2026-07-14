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
import 'package:reader_engine/rendering/highlight_selection.dart';

void main() {
  test('HighlightSelection equality', () {
    const a = HighlightSelection(
        text: 'abc', chapterIndex: 1, startOffset: 0, endOffset: 3);
    const b = HighlightSelection(
        text: 'abc', chapterIndex: 1, startOffset: 0, endOffset: 3);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('HighlightSelection props exposure', () {
    const s = HighlightSelection(
        text: 'x', chapterIndex: 0, startOffset: 5, endOffset: 6);
    expect(s.text, 'x');
    expect(s.chapterIndex, 0);
    expect(s.startOffset, 5);
    expect(s.endOffset, 6);
  });
}
