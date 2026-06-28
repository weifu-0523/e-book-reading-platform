import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhiyue/services/ai/open_ai_compatible_client.dart';

http.Client _client(int status, {String body = '', List<int>? rawBody}) {
  return MockClient.streaming((request, byteStream) async {
    final bytes = rawBody ?? utf8.encode(body);
    final stream = Stream.fromIterable([Uint8List.fromList(bytes)]);
    return http.StreamedResponse(stream, status,
        headers: {'content-type': 'text/event-stream'});
  });
}

String _sseLine(String json) => 'data: $json\n\n';
String _sseDone() => 'data: [DONE]\n\n';

void main() {
  test('streamChat parses delta.content chunks', () async {
    final sse = _sseLine(
            jsonEncode({'choices': [{'delta': {'content': 'hello'}}]})) +
        _sseLine(jsonEncode({'choices': [{'delta': {'content': ' world'}}]})) +
        _sseDone();
    final client = OpenAiCompatibleClient(
      baseUrl: 'https://api.deepseek.com',
      apiKey: 'sk-test',
      httpClient: _client(200, rawBody: utf8.encode(sse)),
    );
    final chunks = await client.streamChat(prompt: 'test').toList();
    expect(chunks, ['hello', ' world']);
  });

  test('401 throws AiAuthException', () async {
    final client = OpenAiCompatibleClient(
      baseUrl: 'https://api.deepseek.com',
      apiKey: 'bad',
      httpClient: _client(401, body: 'unauthorized'),
    );
    expect(
      () => client.streamChat(prompt: 'x').toList(),
      throwsA(isA<AiAuthException>()),
    );
  });

  test('429 throws AiRateLimitException', () async {
    final client = OpenAiCompatibleClient(
      baseUrl: 'https://api.deepseek.com',
      apiKey: 'k',
      httpClient: _client(429, body: 'rate limited'),
    );
    expect(
      () => client.streamChat(prompt: 'x').toList(),
      throwsA(isA<AiRateLimitException>()),
    );
  });

  test('5xx throws AiServerException', () async {
    final client = OpenAiCompatibleClient(
      baseUrl: 'https://api.deepseek.com',
      apiKey: 'k',
      httpClient: _client(503, body: 'unavailable'),
    );
    expect(
      () => client.streamChat(prompt: 'x').toList(),
      throwsA(isA<AiServerException>()),
    );
  });

  test('request body contains model, messages, stream=true', () async {
    Map<String, String>? capturedHeaders;
    String? capturedBody;
    final mock = MockClient.streaming((request, byteStream) async {
      capturedHeaders = request.headers;
      capturedBody = await byteStream.toBytes().then(utf8.decode);
      final stream = Stream.fromIterable(
          [Uint8List.fromList(utf8.encode(_sseDone()))]);
      return http.StreamedResponse(stream, 200);
    });
    final client = OpenAiCompatibleClient(
      baseUrl: 'https://api.deepseek.com',
      apiKey: 'sk-test',
      model: 'deepseek-chat',
      httpClient: mock,
    );
    await client.streamChat(prompt: 'hello').toList();
    expect(capturedHeaders!['authorization'], 'Bearer sk-test');
    final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
    expect(body['model'], 'deepseek-chat');
    expect(body['stream'], true);
    expect((body['messages'] as List).first['content'], 'hello');
  });
}
