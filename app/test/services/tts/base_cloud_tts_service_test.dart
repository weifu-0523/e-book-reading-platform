// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/base_cloud_tts_service.dart';
import 'package:zhiyue/services/tts/cloud_tts_exception.dart';
import 'package:zhiyue/services/tts/tts_service.dart';
import 'package:zhiyue/services/tts/voice_preset.dart';

/// Fake subclass for testing BaseCloudTtsService contract.
class _FakeCloudService extends BaseCloudTtsService {
  _FakeCloudService({
    required this.fetchBehavior,
  });

  final Future<Uint8List> Function(String text, double rate, String voice)
      fetchBehavior;
  int fetchCallCount = 0;
  String? lastFetchedText;

  @override
  String get engineName => 'fake';

  @override
  List<VoicePreset> get supportedVoices => const [
        VoicePreset(
            id: 'v1', displayName: 'V1', gender: VoiceGender.female),
      ];

  @override
  Future<Object?> loadCredentials() async => null;

  @override
  String get defaultVoice => 'v1';

  @override
  Future<Uint8List> fetchAudio(String text, double rate, String voice) async {
    fetchCallCount++;
    lastFetchedText = text;
    return fetchBehavior(text, rate, voice);
  }
}

Sentence _s(String text) => Sentence(
      text: text,
      locale: 'zh',
      charStart: 0,
      charEnd: text.length,
    );

/// PlayerIds for which we've seen a `create` method call. Used to know
/// which event channel to address when emitting mock events.
final Set<String> _createdPlayerIds = <String>{};

/// Emits an `audio.onPrepared value=true` event on the per-player
/// EventChannel so that `AudioPlayer.setSourceBytes` returns (it otherwise
/// awaits this event via `_completePrepared` with a 30s timeout).
///
/// We can't use `EventChannel.setMockStream` here because audioplayers
/// creates the EventChannel AFTER `create` returns, and each channel is
/// keyed by playerId. Instead we send a raw platform message on the
/// flutter side using the StandardMethodCodec's event envelope.
Future<void> _emitPreparedEvent(String playerId) async {
  final channelName = 'xyz.luan/audioplayers/events/$playerId';
  final data = const StandardMethodCodec().encodeSuccessEnvelope(
    <String, dynamic>{
      'event': 'audio.onPrepared',
      'value': true,
    },
  );
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(channelName, data, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // audioplayers uses two channels:
    //   MethodChannel('xyz.luan/audioplayers') — methods (create, setVolume,
    //     setReleaseMode, setSourceBytes, resume, stop, dispose).
    //   EventChannel('xyz.luan/audioplayers/events/$playerId') — events
    //     (audio.onPrepared, audio.onComplete, audio.onDuration, ...).
    //
    // AudioPlayer.setSourceBytes calls _completePrepared which awaits an
    // `audio.onPrepared value=true` event before returning. Without an
    // event-source mock, play() hangs for 30s (preparedCompleter's
    // timeout). We emit the prepared event by handling the binary message
    // on the events channel directly.
    Future<Object?> methodHandler(MethodCall call) async {
      switch (call.method) {
        case 'create':
          // Capture the playerId so we can address its event channel.
          final playerId = (call.arguments as Map?)?['playerId'] as String?;
          if (playerId != null) {
            _createdPlayerIds.add(playerId);
          }
          return null;
        case 'setSourceBytes':
          final playerId = (call.arguments as Map?)?['playerId'] as String?;
          if (playerId != null) {
            // Emit `audio.onPrepared value=true` on the per-player event
            // channel so _completePrepared's preparedCompleter completes.
            await _emitPreparedEvent(playerId);
          }
          return null;
        case 'setVolume':
        case 'setReleaseMode':
        case 'resume':
        case 'stop':
        case 'dispose':
        case 'release':
        case 'pause':
        case 'seek':
          return null;
        default:
          return null;
      }
    }

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers'), methodHandler);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers'), null);
    _createdPlayerIds.clear();
  });

  group('BaseCloudTtsService prefetch', () {
    test('hintNext + speakSentence on hinted text uses cache (1 fetch only)',
        () async {
      final service = _FakeCloudService(
        fetchBehavior: (text, _, __) async => Uint8List(100),
      );
      await service.init();

      await service.hintNext(_s('hello'));
      // hintNext schedules prefetch; wait for it
      await Future<void>.delayed(Duration.zero);
      // Now cache should be populated; speakSentence should NOT call fetchAudio
      await service.speakSentence(_s('hello'));
      expect(service.fetchCallCount, 1);
      await service.dispose();
    });

    test('speakSentence without hintNext triggers sync fetch', () async {
      final service = _FakeCloudService(
        fetchBehavior: (text, _, __) async => Uint8List(50),
      );
      await service.init();
      await service.speakSentence(_s('cold'));
      expect(service.fetchCallCount, 1);
      expect(service.lastFetchedText, 'cold');
      await service.dispose();
    });

    test('setSpeechRate clears prefetch cache', () async {
      final service = _FakeCloudService(
        fetchBehavior: (text, _, __) async => Uint8List(10),
      );
      await service.init();
      await service.hintNext(_s('cached'));
      await Future<void>.delayed(Duration.zero);
      // Prefetch populated cache for "cached"
      await service.setSpeechRate(0.5);
      // After rate change, cache should be cleared
      await service.speakSentence(_s('cached'));
      // fetchAudio called once during prefetch + once during speakSentence
      expect(service.fetchCallCount, 2);
      await service.dispose();
    });

    test('roughEqual rate (diff < 0.001) does NOT clear cache', () async {
      final service = _FakeCloudService(
        fetchBehavior: (text, _, __) async => Uint8List(10),
      );
      await service.init();
      await service.setSpeechRate(0.8);
      await service.hintNext(_s('cached'));
      await Future<void>.delayed(Duration.zero);
      await service.setSpeechRate(0.8001); // within tolerance
      await service.speakSentence(_s('cached'));
      expect(service.fetchCallCount, 1);
      await service.dispose();
    });

    test('stop clears prefetch cache', () async {
      final service = _FakeCloudService(
        fetchBehavior: (text, _, __) async => Uint8List(10),
      );
      await service.init();
      await service.hintNext(_s('cached'));
      await Future<void>.delayed(Duration.zero);
      await service.stop();
      await service.speakSentence(_s('cached'));
      expect(service.fetchCallCount, 2);
      await service.dispose();
    });

    test(
        'fetchAudio throwing CloudTtsException propagates through error stream',
        () async {
      final service = _FakeCloudService(
        fetchBehavior: (text, _, __) async {
          throw const CloudTtsException(
            kind: CloudTtsErrorKind.network,
            message: 'test',
          );
        },
      );
      await service.init();
      final errors = <String>[];
      service.error.listen(errors.add);
      await service.speakSentence(_s('boom'));
      // Wait for error event to propagate
      await Future<void>.delayed(Duration.zero);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('test'));
      await service.dispose();
    });
  });
}
