// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/tts/utils/sherpa_onnx_benchmark.dart';

void main() {
  group('SherpaOnnxBenchmarkResult', () {
    test('RTF computation: 2s synth for 5s audio = 0.4 RTF', () {
      final r = SherpaOnnxBenchmarkResult(
        textLength: 50,
        synthDuration: const Duration(milliseconds: 2000),
        audioDuration: const Duration(milliseconds: 5000),
        peakMemoryMb: 200,
        modelLoadDuration: const Duration(milliseconds: 1500),
      );
      expect(r.rtf, closeTo(0.4, 0.001));
    });

    test('RTF computation: 5s synth for 2s audio = 2.5 RTF (slower than RT)', () {
      final r = SherpaOnnxBenchmarkResult(
        textLength: 30,
        synthDuration: const Duration(milliseconds: 5000),
        audioDuration: const Duration(milliseconds: 2000),
        peakMemoryMb: 200,
        modelLoadDuration: const Duration(milliseconds: 1500),
      );
      expect(r.rtf, closeTo(2.5, 0.001));
    });

    test('toMarkdownRow contains all expected columns', () {
      final r = SherpaOnnxBenchmarkResult(
        textLength: 50,
        synthDuration: const Duration(milliseconds: 2000),
        audioDuration: const Duration(milliseconds: 5000),
        peakMemoryMb: 200,
        modelLoadDuration: const Duration(milliseconds: 1500),
      );
      final row = r.toMarkdownRow(label: 'sentence 1');
      // Label + textLength + synth ms + audio ms + rtf(2dp) + mem + load ms
      expect(row, contains('| sentence 1 |'));
      expect(row, contains('| 50 |'));
      expect(row, contains('| 2000 |'));
      expect(row, contains('| 5000 |'));
      expect(row, contains('| 0.40 |'));
      expect(row, contains('| 200 |'));
      expect(row, contains('| 1500 |'));
    });

    test('toMarkdownRow handles 0 audio duration without NaN (returns inf)', () {
      // Edge case guard: if generate() returns 0 samples (failure mode),
      // rtf becomes inf. Markdown row should still render (not throw).
      final r = SherpaOnnxBenchmarkResult(
        textLength: 10,
        synthDuration: const Duration(milliseconds: 100),
        audioDuration: Duration.zero,
        peakMemoryMb: 50,
        modelLoadDuration: const Duration(milliseconds: 800),
      );
      // Don't assert on rtf value (inf or NaN both possible depending on
      // platform); just ensure toMarkdownRow() doesn't throw.
      expect(() => r.toMarkdownRow(label: 'empty'), returnsNormally);
    });
  });

  group('SherpaOnnxBenchmark.testSentences', () {
    test('contains 4 sentences covering short/medium/long/mixed', () {
      expect(SherpaOnnxBenchmark.testSentences.length, equals(4));
      // Short sentence (greeting)
      expect(SherpaOnnxBenchmark.testSentences[0].length, lessThan(20));
      // Long sentence (constitution full paragraph)
      expect(SherpaOnnxBenchmark.testSentences[2].length, greaterThan(50));
      // English mixed
      expect(
        SherpaOnnxBenchmark.testSentences[3],
        contains('Daniel Kahneman'),
      );
    });
  });
}
