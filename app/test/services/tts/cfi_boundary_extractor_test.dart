// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/cfi_boundary_extractor.dart';
import 'package:zhiyue/services/tts/sentence_segmenter.dart';

void main() {
  group('CFIBoundaryExtractor', () {
    test('extracts 3 paragraphs separated by \\n\\n', () {
      // 三段：与 HtmlToInlineSpanConverter 的 plainText 输出格式一致
      // （段落之间插入 "\n\n"）。
      const plainText = '第一段内容。\n\n第二段内容。\n\n第三段内容。';
      const chapterIndex = 4;

      final result = CFIBoundaryExtractor.extract(
        chapterPlainText: plainText,
        chapterIndex: chapterIndex,
      );

      expect(result.cfiRanges.length, 3);
      expect(result.charSpans.length, 3);

      // Paragraph 0: [0, 6)  "第一段内容。"
      expect(result.charSpans[0], (start: 0, end: 6));
      expect(result.cfiRanges[0].startCfi, '4:0');
      expect(result.cfiRanges[0].endCfi, '4:6');

      // Paragraph 1: [8, 14)  "第二段内容。"
      //  (\n\n 占 2 个 char，所以从 8 开始)
      expect(result.charSpans[1], (start: 8, end: 14));
      expect(result.cfiRanges[1].startCfi, '4:8');
      expect(result.cfiRanges[1].endCfi, '4:14');

      // Paragraph 2: [16, 22)  "第三段内容。"
      expect(result.charSpans[2], (start: 16, end: 22));
      expect(result.cfiRanges[2].startCfi, '4:16');
      expect(result.cfiRanges[2].endCfi, '4:22');
    });

    test('single paragraph without separators', () {
      const plainText = '只有一段。';
      const chapterIndex = 0;

      final result = CFIBoundaryExtractor.extract(
        chapterPlainText: plainText,
        chapterIndex: chapterIndex,
      );

      expect(result.cfiRanges.length, 1);
      expect(result.charSpans.length, 1);
      expect(result.charSpans[0], (start: 0, end: plainText.length));
      expect(result.cfiRanges[0].startCfi, '0:0');
      expect(result.cfiRanges[0].endCfi, '0:${plainText.length}');
    });

    test('empty chapter returns empty lists', () {
      final result = CFIBoundaryExtractor.extract(
        chapterPlainText: '',
        chapterIndex: 7,
      );
      expect(result.cfiRanges, isEmpty);
      expect(result.charSpans, isEmpty);
    });

    test('paragraph index 0 encodes chapterIndex in CFI', () {
      const plainText = 'abc';
      final result = CFIBoundaryExtractor.extract(
        chapterPlainText: plainText,
        chapterIndex: 12,
      );
      expect(result.cfiRanges.single.startCfi, '12:0');
      expect(result.cfiRanges.single.endCfi, '12:3');
    });

    test('whitespace-only paragraphs are skipped', () {
      // 渲染层 PlainTextUtils 不会产生空段；但调用方（如 TXT 加载器）
      // 可能传入连续空行。Extractor 应过滤空段，保持 charSpans 与
      // SentenceSegmenter 的段落扫描对齐（segmenter 把空白当段落边界跳过）。
      const plainText = '段一。\n\n\n\n段二。';
      final result = CFIBoundaryExtractor.extract(
        chapterPlainText: plainText,
        chapterIndex: 0,
      );
      // 只应识别到两个非空段落
      expect(result.charSpans.length, 2);
      expect(result.charSpans[0].start, 0);
      expect(result.charSpans[1].start, 7); // '段一。'(3) + '\n\n\n\n'(4) = 7
    });

    test('integration with SentenceSegmenter — sentence binds to paragraph CFI', () {
      // 端到端：SentenceSegmenter 接收 extractor 输出后，每个 sentence 的
      // startCfi/endCfi 应落在所属段落的 CFI 范围内。
      const plainText = '段一句一。句二。\n\n段二句一。';
      final boundaries = CFIBoundaryExtractor.extract(
        chapterPlainText: plainText,
        chapterIndex: 3,
      );

      final sentences = SentenceSegmenter.split(
        plainText,
        paragraphCfiRanges: boundaries.cfiRanges,
        paragraphCharSpans: boundaries.charSpans,
      );

      expect(sentences.length, 3);

      // 段一句一。 — charStart=0 → 落在 para[0]
      expect(sentences[0].text, '段一句一。');
      expect(sentences[0].startCfi, '3:0');

      // 句二。 — 仍在 para[0]
      expect(sentences[1].text, '句二。');
      expect(sentences[1].startCfi, '3:0');
      expect(sentences[1].endCfi, '3:8'); // para[0].end

      // 段二句一。 — 在 para[1]
      expect(sentences[2].text, '段二句一。');
      expect(sentences[2].startCfi, '3:10');
    });

    test('chapterIndex negative throws ArgumentError', () {
      // 防御：上游传入 -1（理论上不应发生，但 reader_engine 跨 book-switch
      // race 时 _currentChapterIndex 可能短暂为 -1）时立即失败而非静默产出
      // 非法 CFI "-1:0"。
      expect(
        () => CFIBoundaryExtractor.extract(
          chapterPlainText: 'abc',
          chapterIndex: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
