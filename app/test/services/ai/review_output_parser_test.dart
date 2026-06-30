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
