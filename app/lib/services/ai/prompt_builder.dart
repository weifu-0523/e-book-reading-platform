import 'book_chunker.dart';

/// Prompt templates for the 3 AI guide modes.
///
/// `promptVersion` is part of the cache lookup key — bump it whenever wording
/// changes so old cache rows automatically miss.
class PromptBuilder {
  const PromptBuilder._();

  static const int promptVersion = 1;

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
