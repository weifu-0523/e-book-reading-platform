// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/sentence_segmenter.dart';
import 'package:zhiyue/services/tts/tts_service.dart';

void main() {
  group('SentenceSegmenter', () {
    test('splits Chinese by 。', () {
      final sents = SentenceSegmenter.split('你好。世界。再见。');
      expect(sents.length, 3);
      expect(sents[0].text, '你好。');
      expect(sents[0].locale, 'zh-CN');
      expect(sents[0].charStart, 0);
      expect(sents[0].charEnd, 3);
    });

    test('splits English by .', () {
      final sents = SentenceSegmenter.split('Hello. World. Bye.');
      expect(sents.length, 3);
      expect(sents[0].text, 'Hello.');
      expect(sents[0].locale, 'en-US');
    });

    test('splits by ! and ?', () {
      final sents = SentenceSegmenter.split('What? Yes! No.');
      expect(sents.length, 3);
    });

    test('splits by paragraph boundary even without punctuation', () {
      final sents = SentenceSegmenter.split(
        'line one\nline two\nline three',
      );
      expect(sents.length, 3);
    });

    test('force-splits sentences > 200 chars', () {
      final long = 'a' * 250;
      final sents = SentenceSegmenter.split(long);
      expect(sents.length, greaterThan(1));
      for (final s in sents) {
        expect(s.text.length, lessThanOrEqualTo(200));
      }
    });

    test('empty text → empty list', () {
      expect(SentenceSegmenter.split(''), isEmpty);
    });

    test('attaches CFI range when provided', () {
      final sents = SentenceSegmenter.split(
        '你好。',
        paragraphCfiRanges: [
          (startCfi: '/6/4[chap01ref]!/4[body01]/10/2/1:0', endCfi: '/6/4[chap01ref]!/4[body01]/10/2/1:10'),
        ],
        paragraphCharSpans: [(start: 0, end: 3)],
      );
      expect(sents[0].startCfi, isNotNull);
      expect(sents[0].endCfi, isNotNull);
    });
  });
}
