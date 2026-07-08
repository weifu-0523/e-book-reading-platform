// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/ai/prompt_builder_ext.dart';

void main() {
  group('buildChatPrompt', () {
    test('normal mode: system prompt + history + pending user content', () {
      final prompt = PromptBuilderExt.buildChatPrompt(
        history: const [
          ChatTurn(role: 'user', content: '你好'),
          ChatTurn(role: 'ai', content: '你好！'),
        ],
        mode: 'normal',
        pendingUserContent: '接下来问个问题',
      );
      // Contains user message
      expect(prompt, contains('你好'));
      // Contains AI reply
      expect(prompt, contains('你好！'));
      // Contains current question
      expect(prompt, contains('接下来问个问题'));
    });

    test('normal mode: no socratic marker', () {
      final prompt = PromptBuilderExt.buildChatPrompt(
        history: const [],
        mode: 'normal',
        pendingUserContent: 'hi',
      );
      expect(prompt, isNot(contains('苏格拉底')));
    });

    test('socratic mode: prepends tutor system prompt', () {
      final prompt = PromptBuilderExt.buildChatPrompt(
        history: const [ChatTurn(role: 'user', content: 'why?')],
        mode: 'socratic',
        pendingUserContent: '继续问',
      );
      expect(prompt, contains('苏格拉底'));
      expect(prompt, contains('why?'));
      expect(prompt, contains('继续问'));
    });

    test('attachment snapshot appended after history', () {
      final prompt = PromptBuilderExt.buildChatPrompt(
        history: const [],
        mode: 'normal',
        pendingUserContent: '结合笔记回答',
        attachmentSnapshot: 'NOTE_BODY_HERE',
      );
      expect(prompt, contains('NOTE_BODY_HERE'));
      expect(prompt, contains('结合笔记回答'));
    });

    test('system role turns are filtered out (not echoed as user/ai)', () {
      final prompt = PromptBuilderExt.buildChatPrompt(
        history: const [
          ChatTurn(role: 'system', content: '苏格拉底模式启动'),
          ChatTurn(role: 'user', content: 'hi'),
        ],
        mode: 'socratic',
      );
      // The system marker should not be rendered as 用户:/AI: line.
      expect(prompt, isNot(contains('用户: 苏格拉底模式启动')));
      expect(prompt, isNot(contains('AI: 苏格拉底模式启动')));
    });

    test('empty history + no pending content still produces a prompt', () {
      final prompt = PromptBuilderExt.buildChatPrompt(
        history: const [],
        mode: 'normal',
      );
      expect(prompt, isNotEmpty);
    });
  });

  group('buildSocraticBootstrapPrompt', () {
    test('includes recap content', () {
      final prompt = PromptBuilderExt.buildSocraticBootstrapPrompt(
        recap: '章节关键点：A、B、C',
      );
      expect(prompt, contains('章节关键点'));
      expect(prompt, contains('A'));
    });

    test('asks for a single open-ended question (not explanation)', () {
      final prompt = PromptBuilderExt.buildSocraticBootstrapPrompt(
        recap: 'recap text',
      );
      // The prompt should instruct the model to ASK, not explain.
      // Use a Chinese keyword that signals "ask".
      final looksLikeAskInstruction =
          prompt.contains('问') || prompt.toLowerCase().contains('question');
      expect(looksLikeAskInstruction, isTrue,
          reason: 'prompt must instruct model to ask, not explain');
    });

    test('does not directly explain the recap', () {
      final prompt = PromptBuilderExt.buildSocraticBootstrapPrompt(
        recap: 'recap text',
      );
      // Heuristic: "直接讲解" / "directly explain" should be forbidden.
      // A correctly-worded prompt either forbids it or just doesn't contain it as instruction.
      // This test guards against regression to "explain mode".
      expect(prompt.contains('请直接讲解'), isFalse);
    });

    // 2026-07-08 FEAT 5：苏格拉底 bootstrap prompt 新增 bookTitle/author/chapterTitle。
    test('FEAT 5: 包含 bookTitle/author/chapterTitle metadata 行', () {
      final prompt = PromptBuilderExt.buildSocraticBootstrapPrompt(
        recap: '章节内容',
        bookTitle: '概率论入门',
        author: '张三',
        chapterTitle: '第三章 期望值',
      );
      expect(prompt, contains('书名：概率论入门'));
      expect(prompt, contains('作者：张三'));
      expect(prompt, contains('章节标题：第三章 期望值'));
    });

    test('FEAT 5: 不传 metadata 时仍正常生成（向后兼容）', () {
      final prompt = PromptBuilderExt.buildSocraticBootstrapPrompt(
        recap: 'recap',
      );
      expect(prompt, contains('recap'));
      expect(prompt.contains('书名'), isFalse);
    });
  });

  group('buildRecapPrompt', () {
    test('includes chapter text', () {
      final prompt = PromptBuilderExt.buildRecapPrompt(
        chapterText: 'Once upon a time...',
      );
      expect(prompt, contains('Once upon a time'));
    });

    test('asks for 3-5 bullet points', () {
      final prompt = PromptBuilderExt.buildRecapPrompt(
        chapterText: 'chapter content',
      );
      // Look for "3-5" or "3" "5" range indication, or "关键点" / "bullet".
      final hasBulletIndication =
          prompt.contains('3') && prompt.contains('5') ||
              prompt.contains('关键点') ||
              prompt.contains('•');
      expect(hasBulletIndication, isTrue);
    });
  });
}
