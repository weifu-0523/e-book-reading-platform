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
import 'package:zhiyue/services/ai/book_chunker.dart';
import 'package:zhiyue/services/ai/prompt_builder.dart';

void main() {
  test('promptVersion is 3 (FEAT 5: chapter prompt 新增 book/author/title metadata)', () {
    expect(PromptBuilder.promptVersion, 3);
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

  // 2026-07-08 FEAT 5：chapter prompt 新增 bookTitle/author 支持。
  test('chapter with bookTitle + author + chapterTitle includes all metadata',
      () {
    final p = PromptBuilder.chapter(
      '章节文本',
      bookTitle: '概率论入门',
      author: '张三',
      chapterTitle: '第三章 期望值',
    );
    expect(p, contains('书名：概率论入门'));
    expect(p, contains('作者：张三'));
    expect(p, contains('章节标题：第三章 期望值'));
  });

  test('chapter with only bookTitle includes bookTitle but skips author/title',
      () {
    final p = PromptBuilder.chapter('文本', bookTitle: '书名');
    expect(p, contains('书名：书名'));
    expect(p.contains('作者'), isFalse);
    expect(p.contains('章节标题'), isFalse);
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
        const PassageChunk(
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
        const PassageChunk(
            chapterIndex: 3,
            charOffset: 0,
            charLength: 9,
            contentText: 'chunk-one',
            tokenEstimate: 3),
        const PassageChunk(
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
        const PassageChunk(
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

  group('PromptBuilder.review', () {
    test('includes book title, chapter ordinal, and highlights block', () {
      final p = PromptBuilder.review(
        bookTitle: '量子力学讲义',
        chapterOrdinal: 3,
        chapterTitle: '态叠加原理',
        truncatedChapterText: '本章正文…',
        highlightsBlock: '> 高亮1\n> 高亮2',
      );
      expect(p, contains('《量子力学讲义》'));
      expect(p, contains('第3章'));
      expect(p, contains('态叠加原理'));
      expect(p, contains('本章正文…'));
      expect(p, contains('> 高亮1'));
      expect(p, contains('"summary"'));
      expect(p, contains('"keyTakeaways"'));
    });

    test('uses fallback hint when highlightsBlock is empty', () {
      final p = PromptBuilder.review(
        bookTitle: 'T',
        chapterOrdinal: 1,
        chapterTitle: null,
        truncatedChapterText: 'text',
        highlightsBlock: '',
      );
      expect(p, contains('（读者未做高亮'));
      expect(p, contains('第1章'));
      // No "· " when chapterTitle is null.
      expect(p, isNot(contains('· ')));
    });
  });
}
