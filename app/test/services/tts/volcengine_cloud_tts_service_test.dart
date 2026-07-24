import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhiyue/services/tts/cloud_tts_credentials.dart';
import 'package:zhiyue/services/tts/cloud_tts_exception.dart';
import 'package:zhiyue/services/tts/volcengine_cloud_tts_service.dart';

void main() {
  group('VolcengineCloudTtsService.fetchAudio', () {
    final creds = const VolcengineTtsCredentials(
      appId: 'app1',
      accessToken: 'tok1',
      voice: 'BV001_streaming',
    );

    test('parses successful 200 + code=3000 + base64 data', () async {
      final mp3Bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final body = jsonEncode({
        'code': 3000,
        'message': 'success',
        'data': base64Encode(mp3Bytes),
      });
      final client = MockClient((request) async {
        expect(request.url.toString(),
            'https://openspeech.bytedance.com/api/v1/tts');
        expect(request.headers['Authorization'], 'Bearer;tok1');
        final bodyMap = jsonDecode(request.body) as Map<String, dynamic>;
        expect(bodyMap['app']['appid'], 'app1');
        expect(bodyMap['audio']['voice_type'], 'BV001_streaming');
        expect(bodyMap['audio']['encoding'], 'mp3');
        expect(bodyMap['request']['text'], 'hello');
        return http.Response(body, 200);
      });

      final service = VolcengineCloudTtsService(
        credentials: creds,
        httpClient: client,
      );
      final result = await service.fetchAudio('hello', 0.0, 'BV001_streaming');
      expect(result, mp3Bytes);
    });

    test('HTTP 401 → CloudTtsException auth', () async {
      final client = MockClient((_) async => http.Response('{}', 401));
      final service = VolcengineCloudTtsService(
        credentials: creds,
        httpClient: client,
      );
      expect(
        () => service.fetchAudio('hi', 0.0, 'BV001_streaming'),
        throwsA(predicate(
            (e) => e is CloudTtsException && e.kind == CloudTtsErrorKind.auth)),
      );
    });

    test('HTTP 429 → CloudTtsException quota', () async {
      final client = MockClient((_) async => http.Response('{}', 429));
      final service = VolcengineCloudTtsService(
        credentials: creds,
        httpClient: client,
      );
      expect(
        () => service.fetchAudio('hi', 0.0, 'BV001_streaming'),
        throwsA(predicate((e) =>
            e is CloudTtsException && e.kind == CloudTtsErrorKind.quota)),
      );
    });

    test('code != 3000 → CloudTtsException invalidRequest', () async {
      final body = jsonEncode({'code': 3001, 'message': 'voice not found'});
      final client = MockClient((_) async => http.Response(body, 200));
      final service = VolcengineCloudTtsService(
        credentials: creds,
        httpClient: client,
      );
      expect(
        () => service.fetchAudio('hi', 0.0, 'BV001_streaming'),
        throwsA(predicate((e) =>
            e is CloudTtsException &&
            e.kind == CloudTtsErrorKind.invalidRequest &&
            e.message.contains('voice not found'))),
      );
    });

    test('SocketException → CloudTtsException network', () async {
      final client = MockClient((_) async => throw Exception('SocketException'));
      final service = VolcengineCloudTtsService(
        credentials: creds,
        httpClient: client,
      );
      expect(
        () => service.fetchAudio('hi', 0.0, 'BV001_streaming'),
        throwsA(predicate((e) =>
            e is CloudTtsException && e.kind == CloudTtsErrorKind.network)),
      );
    });

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
            appId: 'test', accessToken: 'test', voice: 'zh_male_shenyeboke_moon_bigtts'),
        httpClient: mockClient,
      );

      final bytes = await service.fetchAudio(
          'hello', 0.0, 'zh_male_shenyeboke_moon_bigtts');
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
        credentials:
            VolcengineTtsCredentials(appId: 'x', accessToken: 'x', voice: 'zh_male_shenyeboke_moon_bigtts'),
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
