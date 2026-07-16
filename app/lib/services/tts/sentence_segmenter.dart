// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'tts_service.dart';
import 'locale_detector.dart';

/// CFI 范围（start/end 是章节纯文本的 char offset）。
typedef ParagraphCfiRange = ({String startCfi, String endCfi});
typedef ParagraphCharSpan = ({int start, int end});

/// 句子切分器：按中英标点 + 段落边界切。
class SentenceSegmenter {
  const SentenceSegmenter._();

  static const int _maxSentenceLength = 200;

  // RegExp cannot be `const` (non-const factory) — use a static final field
  // which is lazily initialized on first access.
  static final _punctuation = RegExp(r'[。！？\.!?;；]');

  static List<Sentence> split(
    String text, {
    List<ParagraphCfiRange>? paragraphCfiRanges,
    List<ParagraphCharSpan>? paragraphCharSpans,
  }) {
    if (text.isEmpty) return const [];

    final List<Sentence> result = [];
    int cursor = 0;

    while (cursor < text.length) {
      // 找下一个段落边界
      final nextParaNewline = text.indexOf('\n', cursor);
      final paraEnd = nextParaNewline == -1 ? text.length : nextParaNewline;

      // 在当前段落内找句号
      final matchEnd = _findSentenceEnd(text, cursor, paraEnd);

      // 如果找到的句子超过 max，强制切
      var emitStart = cursor;
      var emitEnd = matchEnd;
      while (emitEnd - emitStart > _maxSentenceLength) {
        final forceEnd = emitStart + _maxSentenceLength;
        _emit(result, text, emitStart, forceEnd, paragraphCfiRanges, paragraphCharSpans);
        emitStart = forceEnd;
      }
      _emit(result, text, emitStart, emitEnd, paragraphCfiRanges, paragraphCharSpans);

      cursor = matchEnd;

      // 跳过空白和换行
      while (cursor < text.length &&
          (text[cursor] == '\n' ||
              text[cursor] == ' ' ||
              text[cursor] == '\t' ||
              text[cursor] == '\r')) {
        cursor++;
      }
    }

    return result;
  }

  static int _findSentenceEnd(String text, int start, int paraEnd) {
    for (var i = start; i < paraEnd; i++) {
      if (_punctuation.hasMatch(text[i])) {
        return i + 1;
      }
    }
    return paraEnd;
  }

  static void _emit(
    List<Sentence> result,
    String text,
    int start,
    int end,
    List<ParagraphCfiRange>? cfiRanges,
    List<ParagraphCharSpan>? charSpans,
  ) {
    if (start >= end) return;
    final sentenceText = text.substring(start, end);
    final locale = LocaleDetector.detect(sentenceText);

    String? startCfi;
    String? endCfi;
    if (cfiRanges != null && charSpans != null) {
      for (var i = 0; i < charSpans.length; i++) {
        final span = charSpans[i];
        if (start >= span.start && start < span.end) {
          startCfi = cfiRanges[i].startCfi;
        }
        if (end > span.start && end <= span.end) {
          endCfi = cfiRanges[i].endCfi;
          break;
        }
      }
    }

    result.add(Sentence(
      text: sentenceText,
      locale: locale,
      charStart: start,
      charEnd: end,
      startCfi: startCfi,
      endCfi: endCfi,
    ));
  }
}
