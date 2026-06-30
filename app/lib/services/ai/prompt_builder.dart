import 'book_chunker.dart';

/// Prompt templates for the 3 AI guide modes.
///
/// `promptVersion` is part of the cache lookup key — bump it whenever wording
/// changes so old cache rows automatically miss.
class PromptBuilder {
  const PromptBuilder._();

  static const int promptVersion = 2;

  static String fullBook(String truncatedText) {
    return '请用与原文相同的语言，用约 300 字总结以下书籍的核心论点和主要观点。'
        '只输出总结，不要任何前置说明。\n\n'
        '--- 原文（可能已截断）---\n'
        '$truncatedText\n'
        '--- 原文结束 ---';
  }

  static String chapter(String truncatedText, {String? chapterTitle}) {
    final titleLine = chapterTitle == null ? '' : '章节标题：$chapterTitle\n';
    return '请用与原文相同的语言，$titleLine输出两部分：\n'
        '1. 用约 300 字总结本章的核心论点和论证脉络\n'
        '2. 列出 3-5 条本章核心要点（用 "- " markdown bullet 格式）\n\n'
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
