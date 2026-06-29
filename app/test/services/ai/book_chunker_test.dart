import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/ai/book_chunker.dart';
import 'package:zhiyue/services/ai/token_truncator.dart';

void main() {
  group('BookChunker.chunk', () {
    test('short chapter produces one chunk covering entire text', () {
      const text = 'Hello world.';
      final chunks = BookChunker.chunk(text, 0);
      expect(chunks, hasLength(1));
      expect(chunks.first.chapterIndex, 0);
      expect(chunks.first.charOffset, 0);
      expect(chunks.first.charLength, text.length);
      expect(chunks.first.contentText, text);
    });

    test('empty text produces no chunks', () {
      expect(BookChunker.chunk('', 0), isEmpty);
    });

    test('whitespace-only text produces no chunks', () {
      expect(BookChunker.chunk('   \n  \t ', 0), isEmpty);
    });

    test('chapterIndex is propagated to every chunk', () {
      final chunks = BookChunker.chunk('Hello.', 7);
      expect(chunks, hasLength(1));
      expect(chunks.first.chapterIndex, 7);
    });

    test('long text (>100K tokens) is sliced into multiple chunks', () {
      // 200K CJK chars == 200K tokens (1 token per CJK char). Over 100K limit.
      final paragraph = '段落内容' * 10;
      final text = List.generate(6000, (_) => paragraph).join('\n\n');
      final chunks = BookChunker.chunk(text, 0);
      expect(chunks.length, greaterThan(1));
      for (final c in chunks) {
        expect(c.tokenEstimate, lessThanOrEqualTo(BookChunker.sliceTargetTokens));
      }
      final total = chunks.fold<int>(0, (a, c) => a + c.charLength);
      expect(total, text.length);
    });

    test('long text: chunk offsets are contiguous (no gap, no overlap)', () {
      final paragraph = '内容' * 100;
      final text = List.generate(2000, (_) => paragraph).join('\n\n');
      final chunks = BookChunker.chunk(text, 3);
      var expectedOffset = 0;
      for (final c in chunks) {
        expect(c.charOffset, expectedOffset);
        expectedOffset += c.charLength;
        expect(c.contentText, text.substring(c.charOffset, c.charOffset + c.charLength));
      }
    });

    test('final tiny tail-paragraph is merged into previous chunk', () {
      final big = '内容' * 200;
      const tail = '末';
      final text = '$big\n\n$tail';
      final chunks = BookChunker.chunk(text, 0);
      expect(chunks, hasLength(1));
      expect(chunks.first.contentText, contains('末'));
    });

    test('tokenEstimate matches TokenTruncator.estimateTokens for each chunk', () {
      // 11 CJK chars + 1 '。' (U+3002, outside CJK range) = 11 tokens.
      const text = '人是为了活着本身而活着。';
      final chunks = BookChunker.chunk(text, 0);
      expect(chunks, hasLength(1));
      expect(chunks.first.tokenEstimate, 11);
      expect(chunks.first.tokenEstimate, TokenTruncator.estimateTokens(text));
    });
  });
}
