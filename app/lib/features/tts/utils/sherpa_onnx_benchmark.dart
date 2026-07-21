// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import '../../../services/tts/sherpa_onnx_tts_service.dart';

/// Single-sentence benchmark snapshot for SherpaOnnx TTS POC (T8).
///
/// Real-Time Factor (RTF) = synthDuration / audioDuration.
/// * RTF < 1.0 → faster than real-time (mobile-usable; threshold ≈ 0.5).
/// * RTF = 1.0 → real-time.
/// * RTF > 1.0 → slower than real-time (synthesis can't keep up with playback).
///
/// Markdown row schema (T9 POC report consumes this):
/// `| label | textLength | synthMs | audioMs | rtf | peakMemMb | modelLoadMs |`
class SherpaOnnxBenchmarkResult {
  final int textLength;
  final Duration synthDuration;
  final Duration audioDuration;
  final int peakMemoryMb;
  final Duration modelLoadDuration;

  const SherpaOnnxBenchmarkResult({
    required this.textLength,
    required this.synthDuration,
    required this.audioDuration,
    required this.peakMemoryMb,
    required this.modelLoadDuration,
  });

  /// synthDuration / audioDuration. Returns [double.infinity] when
  /// audioDuration is zero (failure mode: generate() returned 0 samples).
  double get rtf {
    if (audioDuration.inMilliseconds == 0) return double.infinity;
    return synthDuration.inMilliseconds / audioDuration.inMilliseconds;
  }

  /// Render as a markdown table row. RTF formatted to 2 dp; `inf` renders
  /// as `inf` (caller decides how to surface degenerate cases).
  String toMarkdownRow({required String label}) {
    final rtfStr = rtf.isInfinite ? 'inf' : rtf.toStringAsFixed(2);
    return '| $label | $textLength | ${synthDuration.inMilliseconds} | '
        '${audioDuration.inMilliseconds} | $rtfStr | $peakMemoryMb | '
        '${modelLoadDuration.inMilliseconds} |';
  }
}

/// Standard 4-sentence benchmark suite covering the regimes real reading
/// hits: short UI feedback, medium paragraph, long formal text, and
/// Chinese-English mix (common in technical books).
class SherpaOnnxBenchmark {
  const SherpaOnnxBenchmark._();

  static const testSentences = <String>[
    '你好,这是一个测试。',
    '当夜幕降临,星光点点,伴随着微风拂面,我在静谧中感受着时光的流转。',
    '中华人民共和国是工人阶级领导的、以工农联盟为基础的人民民主专政的社会主义共和国。'
        '《中华人民共和国宪法》是国家的根本法,具有最高的法律效力。',
    '我在读 Thinking, Fast and Slow 这本书,作者是 Daniel Kahneman。',
  ];

  /// Run [service.benchmark] against each sentence in [testSentences].
  /// [onProgress] fires before each sentence (index + text) for UI hooks.
  ///
  /// Service must be [SherpaOnnxTtsService] and already initialized —
  /// cold-start model load time is captured separately at init() site
  /// (T9 POC report combines both numbers).
  static Future<List<SherpaOnnxBenchmarkResult>> run({
    required SherpaOnnxTtsService service,
    void Function(int index, String sentence)? onProgress,
  }) async {
    final results = <SherpaOnnxBenchmarkResult>[];
    for (var i = 0; i < testSentences.length; i++) {
      onProgress?.call(i, testSentences[i]);
      results.add(await service.benchmark(testSentences[i]));
    }
    return results;
  }
}
