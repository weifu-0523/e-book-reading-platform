// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 把 sherpa_onnx OfflineTts.generate() 输出的 Float32List samples 转 PCM16 WAV
/// 并用 audioplayers 播放。POC v1.15.0-alpha：单实例,无 voice queue。
///
/// Phase 2 如 audioplayers 延迟过大可换 soundpool / flutter_soloud。
class SherpaOnnxAudioPlayer {
  SherpaOnnxAudioPlayer();

  // Lazy-init: AudioPlayer() ctor invokes MethodChannel which fails in test
  // env without mock. Create on first play() call.
  AudioPlayer? _player;
  bool _stopped = false;

  AudioPlayer get _p => _player ??= AudioPlayer();

  /// 播放 [samples]（范围 -1.0..1.0,mono）。
  /// 阻塞至播放完成（或 [stop] 被调用）。
  Future<void> play(Float32List samples, int sampleRate) async {
    _stopped = false;
    final wavBytes = buildWavFromFloat32(samples, sampleRate);

    final p = _p;
    await p.setReleaseMode(ReleaseMode.stop);
    await p.setVolume(1.0);
    await p.play(BytesSource(wavBytes));

    // 等播放完成或被 stop 中断
    await p.onPlayerComplete.first;
  }

  /// 中断当前播放。后续 play() 调用会重新开始。
  Future<void> stop() async {
    _stopped = true;
    final p = _player;
    if (p != null) {
      await p.stop();
    }
  }

  Future<void> dispose() async {
    final p = _player;
    _player = null;
    if (p != null) {
      await p.dispose();
    }
  }

  /// Float32 (-1..1) → Int16 → WAV 容器（mono,PCM16,44-byte header）。
  /// 暴露为 public static 便于单元测试（不需要 audioplayers 平台通道）。
  @visibleForTesting
  static Uint8List buildWavFromFloat32(Float32List samples, int sampleRate) {
    final pcm = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      pcm[i] = (clamped * 32767).round();
    }
    final pcmBytes = pcm.buffer.asUint8List();
    return _buildWav(pcmBytes, sampleRate, 1, 16);
  }

  /// 拼 44-byte WAV header + PCM body。
  /// 参考 RIFF/WAVE spec: http://soundfile.sapp.org/doc/WaveFormat/
  static Uint8List _buildWav(
    Uint8List pcmBytes,
    int sampleRate,
    int numChannels,
    int bitsPerSample,
  ) {
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataChunkSize = pcmBytes.length;
    final riffChunkSize = 36 + dataChunkSize;

    final out = BytesBuilder();
    out.add(_ascii('RIFF'));
    out.add(_u32le(riffChunkSize));
    out.add(_ascii('WAVE'));
    out.add(_ascii('fmt '));
    out.add(_u32le(16));
    out.add(_u16le(1));
    out.add(_u16le(numChannels));
    out.add(_u32le(sampleRate));
    out.add(_u32le(byteRate));
    out.add(_u16le(blockAlign));
    out.add(_u16le(bitsPerSample));
    out.add(_ascii('data'));
    out.add(_u32le(dataChunkSize));
    out.add(pcmBytes);
    return out.toBytes();
  }

  static Uint8List _ascii(String s) => Uint8List.fromList(s.codeUnits);
  static Uint8List _u32le(int v) =>
      Uint8List.view((Uint32List(1)..[0] = v).buffer);
  static Uint8List _u16le(int v) =>
      Uint8List.view((Uint16List(1)..[0] = v).buffer);
}
