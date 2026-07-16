import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/locale_detector.dart';

void main() {
  group('LocaleDetector', () {
    test('pure Chinese → zh-CN', () {
      expect(LocaleDetector.detect('你好世界'), 'zh-CN');
    });

    test('pure English → en-US', () {
      expect(LocaleDetector.detect('Hello world'), 'en-US');
    });

    test('Chinese > 30% → zh-CN', () {
      expect(LocaleDetector.detect('你好世界 hello'), 'zh-CN');
    });

    test('Chinese < 30% → en-US', () {
      expect(LocaleDetector.detect('Hello world 你好'), 'en-US');
    });

    test('numbers only → en-US (fallback)', () {
      expect(LocaleDetector.detect('123 456'), 'en-US');
    });

    test('empty → en-US (fallback)', () {
      expect(LocaleDetector.detect(''), 'en-US');
    });

    test('Japanese hiragana → en-US (no ja-JP support configured)', () {
      // Default fallback for non-CJK-Chinese
      expect(LocaleDetector.detect('こんにちは'), 'en-US');
    });
  });
}
