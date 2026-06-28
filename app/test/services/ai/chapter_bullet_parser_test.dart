import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/ai/chapter_bullet_parser.dart';

void main() {
  test('parses summary + 3 bullets', () {
    const text = '本章讨论了 X、Y、Z。\n\n'
        '- 要点一：foo\n'
        '- 要点二：bar\n'
        '- 要点三：baz\n';
    final result = ChapterBulletParser.parse(text);
    expect(result.summary, '本章讨论了 X、Y、Z。');
    expect(result.bullets, ['要点一：foo', '要点二：bar', '要点三：baz']);
  });

  test('handles * as bullet marker', () {
    const text = '概要\n\n* 第一条\n* 第二条';
    final result = ChapterBulletParser.parse(text);
    expect(result.bullets, ['第一条', '第二条']);
  });

  test('no bullets degrades to whole-text summary', () {
    const text = '一段没有 bullet 的总结文字。';
    final result = ChapterBulletParser.parse(text);
    expect(result.bullets, isEmpty);
    expect(result.summary, text);
  });

  test('trims whitespace', () {
    const text = '  summary  \n\n-  bullet 1  \n';
    final result = ChapterBulletParser.parse(text);
    expect(result.summary, 'summary');
    expect(result.bullets, ['bullet 1']);
  });

  test('empty text returns empty result', () {
    final result = ChapterBulletParser.parse('');
    expect(result.summary, '');
    expect(result.bullets, isEmpty);
  });
}
