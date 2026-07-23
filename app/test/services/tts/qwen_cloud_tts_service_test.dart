// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhiyue/services/tts/cloud_tts_credentials.dart';
import 'package:zhiyue/services/tts/cloud_tts_exception.dart';
import 'package:zhiyue/services/tts/qwen_cloud_tts_service.dart';

void main() {
  group('QwenCloudTtsService.fetchAudio', () {
    const creds = QwenTtsCredentials(
      apiKey: 'sk-xxx',
      model: 'qwen-audio-3.0-tts-flash',
      voice: 'longxiaoxia_v2',
    );

    test('POST returns URL, then GET returns bytes', () async {
      final mp3Bytes = Uint8List.fromList([10, 20, 30, 40]);
      int callIndex = 0;
      final client = MockClient((request) async {
        callIndex++;
        if (callIndex == 1) {
          expect(request.url.toString(),
              'https://dashscope.aliyuncs.com/api/v1/services/audio/tts/generate');
          expect(request.headers['Authorization'], 'Bearer sk-xxx');
          final bodyMap = jsonDecode(request.body) as Map<String, dynamic>;
          expect(bodyMap['model'], 'qwen-audio-3.0-tts-flash');
          expect(bodyMap['input']['voice'], 'longxiaoxia_v2');
          expect(bodyMap['input']['text'], 'hello');
          return http.Response(
            jsonEncode({
              'output': {'audio': {'url': 'https://oss.example.com/a.mp3'}},
              'request_id': 'req-1',
            }),
            200,
          );
        } else {
          expect(request.url.toString(), 'https://oss.example.com/a.mp3');
          return http.Response.bytes(mp3Bytes, 200);
        }
      });

      final service = QwenCloudTtsService(credentials: creds, httpClient: client);
      final result = await service.fetchAudio('hello', 0.0, 'longxiaoxia_v2');
      expect(result, mp3Bytes);
      expect(callIndex, 2);
    });

    test('HTTP 401 on POST → CloudTtsException auth', () async {
      final client = MockClient((_) async => http.Response('{}', 401));
      final service = QwenCloudTtsService(credentials: creds, httpClient: client);
      expect(
        () => service.fetchAudio('hi', 0.0, 'longxiaoxia_v2'),
        throwsA(predicate((e) =>
            e is CloudTtsException && e.kind == CloudTtsErrorKind.auth)),
      );
    });

    test('POST 200 but missing URL → invalidRequest', () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode({'output': {}}), 200));
      final service = QwenCloudTtsService(credentials: creds, httpClient: client);
      expect(
        () => service.fetchAudio('hi', 0.0, 'longxiaoxia_v2'),
        throwsA(predicate((e) =>
            e is CloudTtsException &&
            e.kind == CloudTtsErrorKind.invalidRequest)),
      );
    });

    test('SocketException on POST → network', () async {
      final client = MockClient((_) async => throw Exception('SocketException'));
      final service = QwenCloudTtsService(credentials: creds, httpClient: client);
      expect(
        () => service.fetchAudio('hi', 0.0, 'longxiaoxia_v2'),
        throwsA(predicate((e) =>
            e is CloudTtsException && e.kind == CloudTtsErrorKind.network)),
      );
    });
  });
}
