import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhiyue/services/tts/cloud_tts_credentials.dart';
import 'package:zhiyue/services/tts/cloud_tts_exception.dart';
import 'package:zhiyue/services/tts/volcengine_cloud_tts_service.dart';

void main() {
  group('VolcengineCloudTtsService.fetchAudio', () {
    // ----- V3 auth headers -----
    test('fetchAudio sends correct V3 auth headers', () async {
      String? capturedAppId;
      String? capturedAccessKey;
      String? capturedResourceId;
      String? capturedRequestId;
      String? capturedContentType;
      String? capturedAccept;

      final mockClient = MockClient((request) async {
        capturedAppId = request.headers['X-Api-App-Id'];
        capturedAccessKey = request.headers['X-Api-Access-Key'];
        capturedResourceId = request.headers['X-Api-Resource-Id'];
        capturedRequestId = request.headers['X-Api-Request-Id'];
        capturedContentType = request.headers['Content-Type'];
        capturedAccept = request.headers['Accept'];
        final chunk = base64Encode([0x01, 0x02, 0x03]);
        return http.Response(
          'data: {"data":"$chunk"}\n\ndata: {"code":20000000,"message":"ok"}\n\n',
          200,
          headers: {'Content-Type': 'text/event-stream'},
        );
      });

      final service = VolcengineCloudTtsService(
        credentials: VolcengineTtsCredentials(
            appId: '6885189822',
            accessToken: 'mytoken',
            voice: 'zh_male_shenyeboke_moon_bigtts'),
        httpClient: mockClient,
      );
      await service.fetchAudio('hi', 0.0, 'zh_male_shenyeboke_moon_bigtts');

      expect(capturedAppId, '6885189822');
      expect(capturedAccessKey, 'mytoken');
      expect(capturedResourceId, 'seed-tts-2.0');
      expect(capturedContentType, 'application/json');
      expect(capturedAccept, 'text/event-stream');
      expect(capturedRequestId, isNotNull);
      expect(capturedRequestId!.length, 36); // UUID v4 string length
      expect(capturedRequestId!.split('-').length, 5); // 5 hyphen-separated groups
    });

    // ----- V3 body schema -----
    test('fetchAudio sends V3 body schema with speaker + audio_params', () async {
      String? capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        final chunk = base64Encode([0x01]);
        return http.Response(
          'data: {"data":"$chunk"}\n\ndata: {"code":20000000,"message":"ok"}\n\n',
          200,
        );
      });

      final service = VolcengineCloudTtsService(
        credentials: VolcengineTtsCredentials(
            appId: 'x',
            accessToken: 'x',
            voice: 'zh_male_shenyeboke_moon_bigtts'),
        httpClient: mockClient,
      );
      await service.fetchAudio('hello world', 0.0, 'zh_male_shenyeboke_moon_bigtts');

      final decoded = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(decoded['user'], {'uid': 'zhiyue'});
      expect(decoded['req_params']?['text'], 'hello world');
      expect(decoded['req_params']?['speaker'], 'zh_male_shenyeboke_moon_bigtts');
      // V1 fields must NOT exist
      expect(decoded['app'], isNull);
      expect(decoded['audio'], isNull);
      expect(decoded['request'], isNull);
      // V3 audio_params fields
      final audioParams =
          decoded['req_params']?['audio_params'] as Map<String, dynamic>?;
      expect(audioParams?['format'], 'mp3');
      expect(audioParams?['sample_rate'], 24000);
      expect(audioParams?['speech_rate'], isA<int>());
      // V1 field names must NOT leak
      expect(audioParams?.containsKey('voice_type'), isFalse);
      expect(audioParams?.containsKey('encoding'), isFalse);
      expect(audioParams?.containsKey('rate'), isFalse);
      expect(audioParams?.containsKey('speed_ratio'), isFalse);
    });

    // ----- HTTP error classification -----
    test('HTTP 401 -> auth error', () async {
      final mockClient = MockClient((request) async =>
          http.Response('{"code":3001,"message":"Unauthorized"}', 401));
      final service = VolcengineCloudTtsService(
        credentials: VolcengineTtsCredentials(
            appId: 'x',
            accessToken: 'x',
            voice: 'zh_male_shenyeboke_moon_bigtts'),
        httpClient: mockClient,
      );
      await expectLater(
        () => service.fetchAudio('hi', 0.0, 'zh_male_shenyeboke_moon_bigtts'),
        throwsA(predicate((e) =>
            e is CloudTtsException && e.kind == CloudTtsErrorKind.auth)),
      );
    });

    test('HTTP 403 -> auth error (resource not granted)', () async {
      final mockClient = MockClient((request) async =>
          http.Response('{"code":3001,"message":"resource not granted"}', 403));
      final service = VolcengineCloudTtsService(
        credentials: VolcengineTtsCredentials(
            appId: 'x',
            accessToken: 'x',
            voice: 'zh_male_shenyeboke_moon_bigtts'),
        httpClient: mockClient,
      );
      await expectLater(
        () => service.fetchAudio('hi', 0.0, 'zh_male_shenyeboke_moon_bigtts'),
        throwsA(predicate((e) =>
            e is CloudTtsException && e.kind == CloudTtsErrorKind.auth)),
      );
    });

    test('HTTP 429 -> quota error', () async {
      final mockClient = MockClient(
          (request) async => http.Response('rate limited', 429));
      final service = VolcengineCloudTtsService(
        credentials: VolcengineTtsCredentials(
            appId: 'x',
            accessToken: 'x',
            voice: 'zh_male_shenyeboke_moon_bigtts'),
        httpClient: mockClient,
      );
      await expectLater(
        () => service.fetchAudio('hi', 0.0, 'zh_male_shenyeboke_moon_bigtts'),
        throwsA(predicate((e) =>
            e is CloudTtsException && e.kind == CloudTtsErrorKind.quota)),
      );
    });

    test('HTTP 500 -> server error (transient)', () async {
      final mockClient = MockClient((request) async =>
          http.Response('internal server error', 500));
      final service = VolcengineCloudTtsService(
        credentials: VolcengineTtsCredentials(
            appId: 'x',
            accessToken: 'x',
            voice: 'zh_male_shenyeboke_moon_bigtts'),
        httpClient: mockClient,
      );
      await expectLater(
        () => service.fetchAudio('hi', 0.0, 'zh_male_shenyeboke_moon_bigtts'),
        throwsA(predicate((e) =>
            e is CloudTtsException && e.kind == CloudTtsErrorKind.server)),
      );
    });

    // ----- Network failure -----
    test('network exception -> network error', () async {
      final mockClient = MockClient(
          (request) async => throw http.ClientException('connection refused'));
      final service = VolcengineCloudTtsService(
        credentials: VolcengineTtsCredentials(
            appId: 'x',
            accessToken: 'x',
            voice: 'zh_male_shenyeboke_moon_bigtts'),
        httpClient: mockClient,
      );
      await expectLater(
        () => service.fetchAudio('hi', 0.0, 'zh_male_shenyeboke_moon_bigtts'),
        throwsA(predicate((e) =>
            e is CloudTtsException && e.kind == CloudTtsErrorKind.network)),
      );
    });

    // ----- V3 SSE error code classification -----
    test('SSE code 3001 -> auth error', () async {
      final sseBody = 'data: {"code":3001,"message":"load grant not found"}\n\n';
      final mockClient =
          MockClient((request) async => http.Response(sseBody, 200));
      final service = VolcengineCloudTtsService(
        credentials: VolcengineTtsCredentials(
            appId: 'x',
            accessToken: 'x',
            voice: 'zh_male_shenyeboke_moon_bigtts'),
        httpClient: mockClient,
      );
      await expectLater(
        () => service.fetchAudio('hi', 0.0, 'zh_male_shenyeboke_moon_bigtts'),
        throwsA(predicate((e) =>
            e is CloudTtsException && e.kind == CloudTtsErrorKind.auth)),
      );
    });

    test('SSE code 4293 -> invalidRequest (sensitive text)', () async {
      final sseBody =
          'data: {"code":4293,"message":"sensitive word detected"}\n\n';
      final mockClient =
          MockClient((request) async => http.Response(sseBody, 200));
      final service = VolcengineCloudTtsService(
        credentials: VolcengineTtsCredentials(
            appId: 'x',
            accessToken: 'x',
            voice: 'zh_male_shenyeboke_moon_bigtts'),
        httpClient: mockClient,
      );
      await expectLater(
        () => service.fetchAudio('hi', 0.0, 'zh_male_shenyeboke_moon_bigtts'),
        throwsA(predicate((e) =>
            e is CloudTtsException && e.kind == CloudTtsErrorKind.invalidRequest)),
      );
    });

    test('SSE code 4295 -> invalidRequest (text too long)', () async {
      final sseBody = 'data: {"code":4295,"message":"text exceeds limit"}\n\n';
      final mockClient =
          MockClient((request) async => http.Response(sseBody, 200));
      final service = VolcengineCloudTtsService(
        credentials: VolcengineTtsCredentials(
            appId: 'x',
            accessToken: 'x',
            voice: 'zh_male_shenyeboke_moon_bigtts'),
        httpClient: mockClient,
      );
      await expectLater(
        () => service.fetchAudio('hi', 0.0, 'zh_male_shenyeboke_moon_bigtts'),
        throwsA(predicate((e) =>
            e is CloudTtsException && e.kind == CloudTtsErrorKind.invalidRequest)),
      );
    });

    // ----- V3 SSE parser (from Task 4 — kept intact) -----
    test('fetchAudio parses V3 SSE multi-event response correctly', () async {
      // Simulate V3 SSE: 2 audio frames + 1 end-of-stream frame
      final chunk1 = base64Encode([0x49, 0x44, 0x33]); // 'ID3' MP3 header
      final chunk2 = base64Encode([0xAB, 0xCD, 0xEF, 0x12]);
      final sseBody = 'data: {"data":"$chunk1"}\n\n'
          'data: {"data":"$chunk2"}\n\n'
          'data: {"code":20000000,"message":"ok"}\n\n';

      final mockClient = MockClient((request) async {
        return http.Response(sseBody, 200,
            headers: {'Content-Type': 'text/event-stream'});
      });

      final service = VolcengineCloudTtsService(
        credentials: VolcengineTtsCredentials(
            appId: 'test',
            accessToken: 'test',
            voice: 'zh_male_shenyeboke_moon_bigtts'),
        httpClient: mockClient,
      );

      final bytes =
          await service.fetchAudio('hello', 0.0, 'zh_male_shenyeboke_moon_bigtts');
      expect(bytes.length, 7); // 3 + 4
      expect(bytes.sublist(0, 3), [0x49, 0x44, 0x33]);
      expect(bytes.sublist(3), [0xAB, 0xCD, 0xEF, 0x12]);
    });

    test('fetchAudio throws on V3 SSE error frame with code 55000000', () async {
      final sseBody =
          'data: {"code":55000000,"message":"resource ID mismatched with speaker related resource"}\n\n';

      final mockClient = MockClient((request) async {
        return http.Response(sseBody, 200,
            headers: {'Content-Type': 'text/event-stream'});
      });

      final service = VolcengineCloudTtsService(
        credentials: VolcengineTtsCredentials(
            appId: 'x',
            accessToken: 'x',
            voice: 'zh_male_shenyeboke_moon_bigtts'),
        httpClient: mockClient,
      );

      await expectLater(
        () => service.fetchAudio('hi', 0.0, 'zh_male_shenyeboke_moon_bigtts'),
        throwsA(predicate((e) =>
            e is CloudTtsException &&
            e.kind == CloudTtsErrorKind.invalidRequest &&
            e.message.contains('55000000'))),
      );
    });
  });
}
