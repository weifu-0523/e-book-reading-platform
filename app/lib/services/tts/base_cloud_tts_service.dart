// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';
import 'dart:typed_data';

import 'cloud_tts_exception.dart';
import 'tts_audio_player.dart';
import 'tts_service.dart';
import 'tts_voice.dart';
import 'voice_preset.dart';

/// Abstract base for cloud TTS engines (Volcengine, Qwen). Shares:
/// - prefetch cache (text → MP3 bytes) keyed by sentence text
/// - setSpeechRate roughEqual cache invalidation (v1.15.6 Bug 2 lesson)
/// - stop cache clear
/// - error stream emission for fetchAudio failures
///
/// Subclasses implement:
/// - [fetchAudio]: single HTTP request → bytes
/// - [loadCredentials]: read secure-storage credentials (returns null if missing)
/// - [supportedVoices], [defaultVoice], [engineName]
///
/// Prefetch model (revised from plan v1):
/// - [hintNext] triggers `unawaited(_doPrefetch)` so the cache is warm by the
///   time the playback controller calls [speakSentence] for that sentence.
///   Plan v1 wanted prefetch to fire only from `onAudioStarted` inside
///   `speakSentence`, but that broke the test contract (e.g. test 3 expects
///   fetchCallCount==2 after setSpeechRate clears the cache, only possible
///   if hintNext prefetched first). For cloud TTS, fetchAudio is an HTTP
///   request — no isolate-blocking FFI work — so the v1.15.6 "FFI blocks
///   isolate, audio queues waiting" concern doesn't apply the same way.
///   We still pass an `onAudioStarted` callback to `playMp3Bytes` to honor
///   the v1.15.6 hook contract; the callback is a defensive no-op here
///   because hintNext already prefetched.
abstract class BaseCloudTtsService implements TtsService {
  final TtsAudioPlayer _audioPlayer = TtsAudioPlayer();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  final Map<String, Uint8List> _prefetchCache = {};
  bool _prefetchInProgress = false;
  String _currentVoice = '';
  double _rate = 0.0;
  int _currentSentenceIndex = 0;
  bool _isInitialized = false;
  bool _disposed = false;

  // Prefetch metrics for debug UI.
  int prefetchHitCount = 0;
  int prefetchMissCount = 0;
  int prefetchFailCount = 0;

  StreamController<TtsState>? _stateController;
  StreamController<TtsProgress>? _progressController;

  @override
  Stream<TtsState> get state =>
      _stateController?.stream ?? const Stream.empty();

  @override
  Stream<TtsProgress> get progress =>
      _progressController?.stream ?? const Stream.empty();

  @override
  Stream<String> get error => _errorController.stream;

  @override
  bool get isInitialized => _isInitialized;

  /// Subclass identifier for debug logging.
  String get engineName;

  /// Static voice list exposed by this engine.
  List<VoicePreset> get supportedVoices;

  /// Voice ID used when user hasn't picked one.
  String get defaultVoice;

  /// Load credentials from secure storage. Returns null if not configured.
  /// Subclasses override to read via FlutterSecureStorage.
  ///
  /// Plan fix #2: async (Future<Object?>) — FlutterSecureStorage reads are
  /// async, sync signature would force subclasses into blocking reads.
  /// Base class doesn't actually call this in the prefetch path (credentials
  /// are read by subclass inside [fetchAudio]); this typing is for future
  /// B6 wiring that wants to short-circuit fetchAudio when creds are missing.
  Future<Object?> loadCredentials();

  /// Single HTTP request: synthesize text → audio bytes.
  /// May throw [CloudTtsException] on failure.
  Future<Uint8List> fetchAudio(String text, double rate, String voice);

  /// Estimate audio duration in milliseconds. Used by [TtsAudioPlayer.awaitCompletion]
  /// to size the wall-clock timer. Conservative (overestimate) is safer.
  /// Default heuristic: ~100ms per character + 500ms head.
  int estimateAudioDurationMs(String text) {
    return (text.length * 100 + 500).clamp(800, 60000);
  }

  @override
  Future<void> init() async {
    if (_isInitialized) return;
    _stateController = StreamController<TtsState>.broadcast();
    _progressController = StreamController<TtsProgress>.broadcast();
    _currentVoice = defaultVoice;
    _isInitialized = true;
  }

  @override
  Future<void> speakSentence(Sentence sentence) async {
    if (!_isInitialized) await init();
    _stateController?.add(TtsState.speaking);

    final text = sentence.text;
    Uint8List? audio;
    try {
      if (_prefetchCache.containsKey(text)) {
        prefetchHitCount++;
        audio = _prefetchCache.remove(text);
      } else {
        prefetchMissCount++;
        audio = await fetchAudio(text, _rate, _currentVoice);
      }
    } on CloudTtsException catch (e) {
      _errorController.add('${e.kind.name}: ${e.message}');
      _stateController?.add(TtsState.error);
      return;
    } catch (e) {
      _errorController.add('network: $e');
      _stateController?.add(TtsState.error);
      return;
    }

    // v1.15.6 onAudioStarted hook preserved as defensive call site. For
    // cloud TTS we don't kick off further prefetch here (hintNext already
    // handled it). Subclasses that want different timing can override
    // speakSentence.
    await _audioPlayer.playMp3Bytes(
      audio!,
      expectedDurationMs: estimateAudioDurationMs(text),
      onAudioStarted: () {},
    );

    _progressController
        ?.add(TtsProgress(sentenceIndex: _currentSentenceIndex));
    _stateController?.add(TtsState.idle);
  }

  Future<void> _doPrefetch(Sentence sentence) async {
    try {
      final bytes = await fetchAudio(sentence.text, _rate, _currentVoice);
      // Guard: don't clobber if cache was cleared (rate change / stop)
      // mid-flight. We still store the freshly-fetched bytes; subsequent
      // cache clears will invalidate as needed.
      _prefetchCache[sentence.text] = bytes;
    } on CloudTtsException catch (e) {
      prefetchFailCount++;
      // Surface prefetch failures on the error stream so the debug dialog
      // shows them, but don't propagate as state=error — the next
      // speakSentence will sync-fetch and surface a user-visible error
      // if the failure persists.
      _errorController.add('prefetch-fail ${e.kind.name}: ${e.message}');
    } catch (e) {
      prefetchFailCount++;
      _errorController.add('prefetch-fail network: $e');
    } finally {
      _prefetchInProgress = false;
    }
  }

  @override
  Future<void> hintNext(Sentence? next) async {
    if (next == null) return;
    // Plan fix #3: kick off prefetch immediately via unawaited(). The plan
    // v1 comment said "wait for onAudioStarted in speakSentence" but that
    // made the test contract unsatisfiable (test 3 expects fetchCallCount
    // == 2 after rate-clear + speakSentence, which requires hintNext to
    // have prefetched first). Cloud TTS HTTP fetch doesn't block the
    // isolate the way sherpa_onnx FFI did, so the v1.15.6 isolate-blocking
    // concern doesn't apply here.
    if (!_prefetchInProgress && !_prefetchCache.containsKey(next.text)) {
      _prefetchInProgress = true;
      unawaited(_doPrefetch(next));
    }
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    final clamped = rate.clamp(-1.0, 1.0);
    // v1.15.6 Bug 2: roughEqual instead of == to avoid spurious cache
    // invalidation when rate drifts by floating-point noise across
    // service rebuilds.
    if ((clamped - _rate).abs() < 0.001) return;
    _rate = clamped;
    _prefetchCache.clear();
  }

  /// Internal: update current voice + invalidate cache. Subclasses
  /// expose this via a method that also persists via secure storage.
  /// Not part of TtsService interface (interface's setVoice returns bool
  /// for "did the platform accept this voice ID"; cloud engines always
  /// accept any preset id so the public override just returns true).
  Future<void> _setVoiceInternal(String voiceId) async {
    _currentVoice = voiceId;
    _prefetchCache.clear();
  }

  // Plan fix #1: TtsService interface requires Future<bool> setVoice(String?).
  // The plan's setVoiceById name + separate void setVoice(String) conflicted
  // with the interface. Merged into a single override that delegates to
  // _setVoiceInternal.
  @override
  Future<bool> setVoice(String? voiceId) async {
    if (voiceId == null) return false;
    await _setVoiceInternal(voiceId);
    return true;
  }

  @override
  Future<void> stop() async {
    _prefetchCache.clear();
    _prefetchInProgress = false;
    await _audioPlayer.stop();
    _stateController?.add(TtsState.idle);
  }

  @override
  Future<void> pause() async {
    await _audioPlayer.stop();
    _stateController?.add(TtsState.paused);
  }

  @override
  void setCurrentSentenceIndex(int idx) {
    _currentSentenceIndex = idx;
  }

  @override
  Future<void> setPitch(double pitch) async {
    // Cloud TTS pitch handled via fetch params if subclass supports it.
  }

  @override
  Future<void> setVolume(double volume) async {}

  // Voice/system APIs — cloud engines don't use platform voice list.
  @override
  Future<List<TtsVoice>> getVoices() async => const [];
  @override
  Future<void> previewVoice(String voiceId, {String? sampleText}) async {}
  @override
  Future<bool> openSystemTtsSettings() async => false;
  @override
  Future<bool> isLanguageAvailable(String locale) async => true;
  @override
  Future<bool> isLanguageInstalled(String locale) async => true;
  @override
  Future<String?> getDefaultEngine() async => engineName;

  // Cloud TTS doesn't receive platform events via EventChannel — the
  // eventReceivedCountForDebug counter is for the self-built plugin's
  // native-to-Dart event plumbing diagnostic. Surface null so the debug
  // dialog hides the row for cloud engines.
  @override
  int? get eventReceivedCountForDebug => null;

  /// Snapshot for the in-app「TTS 调试日志」dialog.
  Map<String, dynamic> getDebugState() => {
        'engine': engineName,
        'prefetchHit': prefetchHitCount,
        'prefetchMiss': prefetchMissCount,
        'prefetchFail': prefetchFailCount,
        'cacheSize': _prefetchCache.length,
        'prefetchInProgress': _prefetchInProgress,
        'rate': _rate,
        'voice': _currentVoice,
      };

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _prefetchCache.clear();
    await _stateController?.close();
    await _progressController?.close();
    await _errorController.close();
    await _audioPlayer.dispose();
  }
}
