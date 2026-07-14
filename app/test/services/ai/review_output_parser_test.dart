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
import 'package:zhiyue/services/ai/review_output_parser.dart';

void main() {
  group('ReviewOutputParser', () {
    test('parses valid JSON with summary + takeaways', () {
      const raw = '{"summary":"abc","keyTakeaways":["x","y","z"]}';
      final out = ReviewOutputParser.parse(raw);
      expect(out, isNotNull);
      expect(out!.summary, 'abc');
      expect(out.keyTakeaways, ['x', 'y', 'z']);
    });

    test('strips ```json fenced blocks', () {
      const raw = '```json\n{"summary":"hi","keyTakeaways":["a"]}\n```';
      final out = ReviewOutputParser.parse(raw);
      expect(out, isNotNull);
      expect(out!.summary, 'hi');
      expect(out.keyTakeaways, ['a']);
    });

    test('strips ``` fenced blocks without json label', () {
      const raw = '```\n{"summary":"hi","keyTakeaways":[]}\n```';
      final out = ReviewOutputParser.parse(raw);
      expect(out, isNotNull);
      expect(out!.summary, 'hi');
      expect(out.keyTakeaways, isEmpty);
    });

    test('returns null when summary field missing', () {
      const raw = '{"keyTakeaways":["x"]}';
      expect(ReviewOutputParser.parse(raw), isNull);
    });

    test('returns null when top-level is not an object', () {
      const raw = '["summary","keyTakeaways"]';
      expect(ReviewOutputParser.parse(raw), isNull);
    });

    test('filters non-String elements in keyTakeaways', () {
      const raw = '{"summary":"s","keyTakeaways":["ok",42,null,true]}';
      final out = ReviewOutputParser.parse(raw);
      expect(out, isNotNull);
      expect(out!.keyTakeaways, ['ok']);
    });

    test('returns null for unparseable garbage', () {
      const raw = '抱歉,无法完成';
      expect(ReviewOutputParser.parse(raw), isNull);
    });

    test('handles leading/trailing whitespace', () {
      const raw = '\n  {"summary":"s","keyTakeaways":["a"]}  \n';
      final out = ReviewOutputParser.parse(raw);
      expect(out, isNotNull);
      expect(out!.summary, 's');
    });
  });
}
