// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 通用 TTS 音频播放器。支持：
/// - SherpaOnnx Float32 samples (via [play])
/// - Cloud TTS MP3 bytes (via [playMp3Bytes], added in v1.16.0-alpha Task A2)
///
/// v1.15.5-alpha hotfix: 用 **Timer + expected duration** 替代
/// [AudioPlayer.onPlayerStateChanged] 作为播放完成信号。
///
/// v1.15.1-alpha 的 onPlayerStateChanged 修复基于错误前提 ——
/// `audioplayers/lib/src/audioplayer.dart:145-156` 显示 `PlayerState.completed`
/// 只在 `_onPlayerCompleteStreamSubscription`（即 [AudioPlayer.onPlayerComplete]
/// stream）里被 set，而 `onPlayerComplete` 最终走
/// `WrappedPlayer.onCompletion()`（`audioplayers_android/player/WrappedPlayer.kt:287`），
/// 依赖 Android `MediaPlayer.OnCompletionListener`。该 listener 在荣耀 ROM +
/// `BytesSource(WAV)` 模式下不触发 —— 与 v1.15.0-alpha 是**同一个根因**。
/// v1.15.1-alpha 改完看似"有声音了"只是因为加了 safety timeout 让 play()
/// 能返回，但每句 gap = safety timeout - 实际音频 ≈ 5-10 秒（用户感知"几秒"）。
///
/// v1.15.5-alpha 用纯 Timer（expectedMs + 200ms buffer）作为完成信号，
/// 完全不依赖 audioplayers completion event。监听 PlayerState.stopped
/// 仅作为 user stop 的 fast-path（`audioplayers.stop()` 同步 set state）。
/// Safety timeout 兜底极端情况（Timer 不应失败但 defensive）。
///
/// Phase 2 如 audioplayers 延迟过大可换 soundpool / flutter_soloud。
class TtsAudioPlayer {
  TtsAudioPlayer();

  // Lazy-init: AudioPlayer() ctor invokes MethodChannel which fails in test
  // env without mock. Create on first play() call.
  AudioPlayer? _player;
  bool _stopped = false;

  /// v1.15.2-alpha: optional static sink. When set by [TtsService]
  /// via `TtsAudioPlayer.onDebugLog = service._log;`, all internal
  /// log lines (play / state-change / stop / error) are forwarded here in
  /// addition to [debugPrint], so the in-app「TTS 调试日志」dialog can
  /// capture them without adb.
  static void Function(String)? onDebugLog;

  void _emit(String message) {
    debugPrint('[TtsAudioPlayer] $message');
    onDebugLog?.call('[AudioPlayer] $message');
  }

  AudioPlayer get _p => _player ??= AudioPlayer();

  /// 播放 [samples]（范围 -1.0..1.0,mono）。
  /// 阻塞至播放完成（或 [stop] 被调用）。
  ///
  /// v1.15.6-alpha: [onAudioStarted] 在 `p.play()` 返回后（audio 已 queue
  /// 到 native thread）触发，让调用方在 audio 渲染期间启动 prefetch。
  /// 预取操作同步阻塞 isolate 但 audio 在 native thread 不受影响——
  /// 核心机制让 prefetch 真正与播放并行。
  Future<void> play(
    Float32List samples,
    int sampleRate, {
    void Function()? onAudioStarted,
  }) async {
    _stopped = false;
    final wavBytes = buildWavFromFloat32(samples, sampleRate);
    final totalMs = (samples.length / sampleRate * 1000).round();

    final p = _p;
    await p.setReleaseMode(ReleaseMode.stop);
    await p.setVolume(1.0);

    _emit('play start samples=${samples.length} sampleRate=$sampleRate '
        'durationMs=$totalMs');

    await p.play(BytesSource(wavBytes));
    _emit('play() returned, audio queued to native thread');

    // v1.15.6-alpha: trigger prefetch NOW — audio is rendering on native
    // thread, isolate is free for FFI work. Caller's callback runs sync
    // (unawaited async function executes body until first await). FFI
    // blocks isolate but audio unaffected — this is the parallelism we
    // couldn't get with v1.15.4-alpha's design (which called prefetch
    // BEFORE play, blocking isolate before audio could even start).
    onAudioStarted?.call();

    await awaitCompletion(
      expectedDurationMs: totalMs,
      stateStream: p.onPlayerStateChanged,
      isStopped: () => _stopped,
      emit: _emit,
      createTimer: Timer.new,
    );

    _emit('play done stopped=$_stopped');
  }

  /// Plays MP3 bytes from cloud TTS. Mirrors [play] (Float32 path):
  /// queues audio to native thread, invokes [onAudioStarted], then awaits
  /// completion via Timer (not audioplayers OnCompletionListener, which is
  /// unreliable on Honor ROM + BytesSource — see v1.15.5-alpha).
  Future<void> playMp3Bytes(
    Uint8List mp3Bytes, {
    required int expectedDurationMs,
    void Function()? onAudioStarted,
    Timer Function(Duration, void Function())? createTimer,
  }) async {
    _stopped = false;
    final p = _p;
    await p.setReleaseMode(ReleaseMode.stop);
    await p.setVolume(1.0);
    await p.play(BytesSource(mp3Bytes));
    _emit('playMp3Bytes() returned, audio queued to native thread');
    onAudioStarted?.call();
    await awaitCompletion(
      expectedDurationMs: expectedDurationMs,
      stateStream: p.onPlayerStateChanged,
      isStopped: () => _stopped,
      emit: _emit,
      createTimer: createTimer ?? Timer.new,
    );
  }

  /// v1.15.5-alpha: pure helper extracted from [play] for testability.
  ///
  /// Waits for audio completion using a [Timer] based on expected duration,
  /// bypassing audioplayers' unreliable `onPlayerComplete` /
  /// `onPlayerStateChanged.completed` event path (see class doc).
  ///
  /// Early-terminates if [PlayerState.stopped] is observed on [stateStream]
  /// (user pressed [stop] — audioplayers.stop() sets state synchronously).
  /// Safety timeout (2x expected + 5s) guards against edge cases where the
  /// Timer itself somehow doesn't fire.
  ///
  /// [createTimer] is a factory parameter so tests can inject a fake timer
  /// without needing [FakeAsync]. In production, pass [Timer.new].
  @visibleForTesting
  static Future<void> awaitCompletion({
    required int expectedDurationMs,
    required Stream<PlayerState> stateStream,
    required bool Function() isStopped,
    required void Function(String) emit,
    required Timer Function(Duration duration, void Function() callback)
        createTimer,
  }) async {
    const bufferMs = 200;
    const safetyMultiplier = 2;
    const safetyBufferMs = 5000;

    final doneCompleter = Completer<void>();

    final sub = stateStream.listen(
      (s) {
        emit('state=$s');
        if (s == PlayerState.stopped && !doneCompleter.isCompleted) {
          emit('state=stopped (early termination)');
          doneCompleter.complete();
        }
      },
      onError: (Object e, StackTrace st) {
        emit('state stream error=$e');
        if (!doneCompleter.isCompleted) doneCompleter.completeError(e, st);
      },
    );

    final timer = createTimer(
      Duration(milliseconds: expectedDurationMs + bufferMs),
      () {
        if (!doneCompleter.isCompleted) {
          emit('expected-duration timer fired — completing');
          doneCompleter.complete();
        }
      },
    );

    try {
      final safetyTimeout = Duration(
        milliseconds: expectedDurationMs * safetyMultiplier + safetyBufferMs,
      );
      await doneCompleter.future.timeout(safetyTimeout, onTimeout: () {
        emit('safety timeout after ${safetyTimeout.inMilliseconds}ms '
            '(expected ${expectedDurationMs}ms) — forcing completion');
      });
    } finally {
      timer.cancel();
      await sub.cancel();
    }
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
      _emit('stop() issued (fire-and-forget)');
      unawaited(
        p.stop().catchError((Object e) {
          _emit('audioplayers.stop error=$e');
        }),
      );
    } else {
      _emit('stop() no-op (_player null)');
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
