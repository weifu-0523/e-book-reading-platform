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
import 'package:zhiyue/services/ai/token_truncator.dart';

void main() {
  test('short text returns unchanged', () {
    final out = TokenTruncator.truncateToTokens('hello world', 8000);
    expect(out, 'hello world');
  });

  test('all-CJK text over budget gets truncated', () {
    final cjk = '字' * 10000;
    final out = TokenTruncator.truncateToTokens(cjk, 8000);
    expect(out.length, lessThan(cjk.length));
    expect(out, contains('省略'));
  });

  test('all-ASCII text over budget gets truncated', () {
    final text = 'a' * 40000;
    final out = TokenTruncator.truncateToTokens(text, 8000);
    expect(out.length, lessThan(text.length));
    expect(out, contains('省略'));
  });

  test('truncated output preserves head + tail with mid omitted', () {
    final text = '头' * 4000 + '中' * 4000 + '尾' * 4000;
    final out = TokenTruncator.truncateToTokens(text, 6000);
    expect(out.startsWith('头'), true);
    expect(out.endsWith('尾'), true);
    expect(out.contains('中'), false);
  });

  test('exactly at budget returns unchanged', () {
    final text = '字' * 8000;
    final out = TokenTruncator.truncateToTokens(text, 8000);
    expect(out, text);
  });
}
