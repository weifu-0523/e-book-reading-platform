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
