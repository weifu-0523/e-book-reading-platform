import 'package:flutter_test/flutter_test.dart';
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
}
