import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/ai/book_chunker.dart';
import 'package:zhiyue/services/ai/prompt_builder.dart';

void main() {
  test('promptVersion is a constant', () {
    expect(PromptBuilder.promptVersion, 1);
  });

  test('fullBook renders source and 300-char instruction', () {
    final p = PromptBuilder.fullBook('原始文本');
    expect(p, contains('300 字'));
    expect(p, contains('原始文本'));
    expect(p, contains('--- 原文'));
  });

  test('chapter without title omits title line', () {
    final p = PromptBuilder.chapter('章节文本');
    expect(p, contains('300 字'));
    expect(p, contains('章节文本'));
    expect(p, contains('--- 本章原文'));
    expect(p.contains('章节标题'), isFalse);
  });

  test('chapter with title includes title line', () {
    final p = PromptBuilder.chapter('章节文本', chapterTitle: '第三章');
    expect(p, contains('章节标题：第三章'));
  });

  test('chapter requires 3-5 markdown bullets', () {
    final p = PromptBuilder.chapter('text');
    expect(p, contains('3-5'));
    expect(p, contains('bullet'));
  });

  test('selection without chapter context', () {
    final p = PromptBuilder.selection('selected');
    expect(p, contains('selected'));
    expect(p, contains('200 字'));
  });

  test('selection with chapter context includes it', () {
    final p = PromptBuilder.selection('selected', chapterTitle: '第二章');
    expect(p, contains('第二章'));
  });

  group('PromptBuilder.qa', () {
    test('qaPromptVersion is 1 (separate cache key from full/chapter/selection)',
        () {
      expect(PromptBuilder.qaPromptVersion, 1);
    });

    test('prompt embeds the question', () {
      final p = PromptBuilder.qa('Who is the protagonist?', [
        PassageChunk(
            chapterIndex: 0,
            charOffset: 0,
            charLength: 5,
            contentText: 'Hello',
            tokenEstimate: 2),
      ]);
      expect(p, contains('Who is the protagonist?'));
    });

    test('prompt embeds each chunk with [ch=N] marker', () {
      final p = PromptBuilder.qa('Question', [
        PassageChunk(
            chapterIndex: 3,
            charOffset: 0,
            charLength: 9,
            contentText: 'chunk-one',
            tokenEstimate: 3),
        PassageChunk(
            chapterIndex: 5,
            charOffset: 0,
            charLength: 9,
            contentText: 'chunk-two',
            tokenEstimate: 3),
      ]);
      expect(p, contains('[ch=3]'));
      expect(p, contains('[ch=5]'));
      expect(p, contains('chunk-one'));
      expect(p, contains('chunk-two'));
    });

    test('prompt instructs the LLM to use [ch=N] markers in answer', () {
      final p = PromptBuilder.qa('Q', [
        PassageChunk(
            chapterIndex: 0,
            charOffset: 0,
            charLength: 3,
            contentText: 'ctx',
            tokenEstimate: 1),
      ]);
      expect(p, contains('[ch=N]'));
    });

    test('long chunk content is truncated to 800 chars in prompt context', () {
      final long = 'a' * 2000;
      final p = PromptBuilder.qa('Q', [
        PassageChunk(
            chapterIndex: 0,
            charOffset: 0,
            charLength: long.length,
            contentText: long,
            tokenEstimate: 500),
      ]);
      expect(p, contains('a' * 800));
      expect(p, isNot(contains('a' * 801)));
    });
  });
}
