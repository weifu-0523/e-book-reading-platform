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

import 'book_chunker.dart';

/// Prompt templates for the 3 AI guide modes.
///
/// `promptVersion` is part of the cache lookup key — bump it whenever wording
/// changes so old cache rows automatically miss.
class PromptBuilder {
  const PromptBuilder._();

  /// 2026-07-08 FEAT 5：bump 2→3。chapter prompt 模板新增 bookTitle / author /
  /// chapterTitle metadata 行，让 LLM 在生成章节导读时能看到书的整体上下文
  /// （书名、作者、当前章节）。旧缓存（key 含 promptVersion=2）自动 miss。
  static const int promptVersion = 3;

  static String fullBook(String truncatedText) {
    return '请用与原文相同的语言，用约 300 字总结以下书籍的核心论点和主要观点。'
        '只输出总结，不要任何前置说明。\n\n'
        '--- 原文（可能已截断）---\n'
        '$truncatedText\n'
        '--- 原文结束 ---';
  }

  /// 2026-07-08 FEAT 5：扩展 metadata 行，包含 [bookTitle] / [author] /
  /// [chapterTitle]。任一为 null/空 都跳过对应行，保证向后兼容（不传 metadata
  /// 时输出与旧模板一致——除了 promptVersion bumped）。LLM 看到完整书 + 章
  /// 上下文后，回答更精准（用户报告"AI 不知道在讲哪本书的哪一章"）。
  static String chapter(
    String truncatedText, {
    String? bookTitle,
    String? author,
    String? chapterTitle,
  }) {
    final buf = StringBuffer();
    if (bookTitle != null && bookTitle.isNotEmpty) {
      buf.writeln('书名：$bookTitle');
    }
    if (author != null && author.isNotEmpty) {
      buf.writeln('作者：$author');
    }
    if (chapterTitle != null && chapterTitle.isNotEmpty) {
      buf.writeln('章节标题：$chapterTitle');
    }
    final metadataBlock = buf.isEmpty ? '' : buf.toString();
    return '请用与原文相同的语言，输出两部分：\n'
        '1. 用约 300 字总结本章的核心论点和论证脉络\n'
        '2. 列出 3-5 条本章核心要点（用 "- " markdown bullet 格式）\n\n'
        '${metadataBlock.isEmpty ? "" : "$metadataBlock\n"}'
        '只输出上述内容，不要任何前置说明。\n\n'
        '--- 本章原文（可能已截断）---\n'
        '$truncatedText\n'
        '--- 原文结束 ---';
  }

  static String selection(String selectedText, {String? chapterTitle}) {
    final ctx = chapterTitle == null ? '' : '（用户正在阅读章节：$chapterTitle）\n';
    return '请用与原文相同的语言，简洁地解读以下读者选中的文字$ctx。'
        '重点解释含义、上下文、可能的引申，不超过 200 字。\n\n'
        '--- 选中文字 ---\n'
        '$selectedText\n'
        '--- 选中文字结束 ---';
  }

  /// Prompt for chapter learning review. Asks LLM to produce a JSON object
  /// with summary + keyTakeaways, grounded in chapter text and reader's
  /// highlights.
  ///
  /// [chapterOrdinal] is 1-based. [highlightsBlock] is the pre-formatted
  /// multi-line string of reader's highlights in this chapter; pass '' to
  /// trigger the no-highlights fallback branch.
  static String review({
    required String bookTitle,
    required int chapterOrdinal,
    required String? chapterTitle,
    required String truncatedChapterText,
    required String highlightsBlock,
  }) {
    final titleLine = chapterTitle == null || chapterTitle.isEmpty
        ? '第$chapterOrdinal章'
        : '第$chapterOrdinal章 · $chapterTitle';
    final highlightsSection = highlightsBlock.isEmpty
        ? '（读者未做高亮，请基于本章正文做通用回顾）'
        : highlightsBlock;
    return '你是一位学习导师，帮读者回顾刚读完的章节。\n\n'
        '## 本章信息\n'
        '书名：《$bookTitle》\n'
        '章节：$titleLine\n\n'
        '## 本章正文（节选）\n'
        '$truncatedChapterText\n\n'
        '## 读者在本章的高亮与笔记\n'
        '$highlightsSection\n\n'
        '## 任务\n'
        '1. 写一段 100-200 字的本章核心摘要，聚焦读者通过高亮关注的部分\n'
        '2. 提炼 3-5 条可执行/可记忆的要点，每条一句话\n\n'
        '## 输出格式（严格遵守，输出纯 JSON，不要 Markdown 围栏）\n'
        '{\n'
        '  "summary": "...",\n'
        '  "keyTakeaways": ["...", "..."]\n'
        '}';
  }

  /// Bump independently from [promptVersion] so Q&A cache misses don't
  /// invalidate full/chapter/selection caches (and vice versa).
  static const int qaPromptVersion = 1;

  /// Prompt for same-book Q&A. Each context chunk is prefixed with its
  /// chapter index in [ch=N] form; the LLM is instructed to embed the
  /// same markers in its answer so QaCitationParser (T9) can recover them.
  ///
  /// Chunk content is truncated to 800 chars to keep the prompt within
  /// typical 8K-token context budgets when 5 chunks are passed.
  static String qa(String question, List<PassageChunk> contextChunks) {
    final contextBlock = contextChunks.map((c) {
      final preview = c.contentText.length > 800
          ? c.contentText.substring(0, 800)
          : c.contentText;
      return '[ch=${c.chapterIndex}]\n$preview';
    }).join('\n\n---\n\n');

    return '请用与原文相同的语言，基于下方书内节选回答问题。'
        '在引用具体段落处插入 [ch=N] 标记（N 是节选开头的章节号）。'
        '若上下文不足以回答，请明说。\n\n'
        '--- 问题 ---\n$question\n'
        '--- 书内节选 ---\n$contextBlock\n'
        '--- 节选结束 ---';
  }
}
