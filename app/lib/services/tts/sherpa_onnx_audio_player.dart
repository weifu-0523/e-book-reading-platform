// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 把 sherpa_onnx OfflineTts.generate() 输出的 Float32List samples 转 PCM16 WAV
/// 并用 audioplayers 播放。POC v1.15.0-alpha：单实例,无 voice queue。
///
/// v1.15.1-alpha hotfix: 用 [AudioPlayer.onPlayerStateChanged] 替代
/// [AudioPlayer.onPlayerComplete] 作为播放完成信号 —— 后者在 Android 部分
/// ROM + BytesSource(WAV) 场景不 emit（audioplayers 历史问题），导致
/// `await p.onPlayerComplete.first` 永远挂起、speakSentence 永不返回、
/// UI 卡在 speaking phase。同时 [stop] 改为 fire-and-forget 避免被
/// audioplayers 内部 lock 拖死。
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
    final totalMs = (samples.length / sampleRate * 1000).round();

    final p = _p;
    await p.setReleaseMode(ReleaseMode.stop);
    await p.setVolume(1.0);

    debugPrint(
      '[SherpaOnnxAudioPlayer] play start '
      'samples=${samples.length} sampleRate=$sampleRate '
      'durationMs=$totalMs',
    );

    // Subscribe BEFORE play() so we don't miss the initial state transition.
    // onPlayerStateChanged fires on every phase change; we want the terminal
    // completed/stopped state. v1.15.1-alpha: was onPlayerComplete.first which
    // silently never fires on some Android ROMs.
    final doneCompleter = Completer<void>();
    late StreamSubscription sub;
    sub = p.onPlayerStateChanged.listen(
      (s) {
        debugPrint('[SherpaOnnxAudioPlayer] state=$s');
        if (s == PlayerState.completed || s == PlayerState.stopped) {
          if (!doneCompleter.isCompleted) doneCompleter.complete();
        }
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[SherpaOnnxAudioPlayer] state stream error=$e');
        if (!doneCompleter.isCompleted) doneCompleter.completeError(e, st);
      },
      cancelOnError: true,
    );

    try {
      await p.play(BytesSource(wavBytes));
      debugPrint('[SherpaOnnxAudioPlayer] play() returned, awaiting state');
      // Safety timeout: 2x expected duration + 5s buffer. If audioplayers
      // silently fails to emit any state change, the caller still gets to
      // advance instead of hanging forever.
      final timeout = Duration(milliseconds: totalMs * 2 + 5000);
      await doneCompleter.future.timeout(timeout, onTimeout: () {
        debugPrint(
          '[SherpaOnnxAudioPlayer] state timeout after ${timeout.inMilliseconds}ms '
          '(expected ${totalMs}ms) — forcing completion',
        );
      });
    } finally {
      await sub.cancel();
    }

    debugPrint('[SherpaOnnxAudioPlayer] play done stopped=$_stopped');
  }

  /// 中断当前播放。后续 play() 调用会重新开始。
  ///
  /// v1.15.1-alpha: 不 await audioplayers.stop() —— 如果 play() 当前卡在
  /// 内部 lock，stop() 也会 await 同一个 lock 让调用方（driveStop）卡死，
  /// 表现为 UI 上的「关闭」按钮按下后 mini control 不消失。fire-and-forget
  /// 让 driveStop 立即返回，UI 立即响应。
  Future<void> stop() async {
    _stopped = true;
    final p = _player;
    if (p != null) {
      debugPrint('[SherpaOnnxAudioPlayer] stop() issued (fire-and-forget)');
      unawaited(
        p.stop().catchError((Object e) {
          debugPrint('[SherpaOnnxAudioPlayer] audioplayers.stop error=$e');
        }),
      );
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
