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

http.Client _chunkedClient(int status, List<List<int>> chunks) {
  return MockClient.streaming((request, byteStream) async {
    final stream =
        Stream.fromIterable(chunks.map((c) => Uint8List.fromList(c)));
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

  test('P0: SSE event split across TCP chunks does not crash', () async {
    // Real-world SSE: long delta JSON lines (1-2KB with metadata) routinely
    // get split mid-line by TCP. Without line buffering, the partial line
    // fails jsonDecode → AiParseException → stream terminates mid-response,
    // discarding accumulated content (and the user has already paid for it).
    final fullJson = jsonEncode({'choices': [{'delta': {'content': 'hello'}}]});
    final fullEvent = 'data: $fullJson\n\n';
    // Split at byte 12 — inside the JSON payload, not on a \n boundary.
    final splitAt = 12;
    final chunk1Bytes = utf8.encode(fullEvent.substring(0, splitAt));
    final chunk2Bytes = utf8.encode(fullEvent.substring(splitAt));
    final doneBytes = utf8.encode(_sseDone());

    final client = OpenAiCompatibleClient(
      baseUrl: 'https://api.deepseek.com',
      apiKey: 'sk-test',
      httpClient: _chunkedClient(200, [chunk1Bytes, chunk2Bytes, doneBytes]),
    );
    final chunks = await client.streamChat(prompt: 'test').toList();
    expect(chunks, ['hello']);
  });

  test('P0: SSE event split across three TCP chunks', () async {
    // Even more pathological: split across 3 chunks at arbitrary offsets.
    final fullJson =
        jsonEncode({'choices': [{'delta': {'content': 'world'}}]});
    final fullEvent = 'data: $fullJson\n\n';
    final splitA = 5;
    final splitB = 30;
    final a = utf8.encode(fullEvent.substring(0, splitA));
    final b = utf8.encode(fullEvent.substring(splitA, splitB));
    final c = utf8.encode(fullEvent.substring(splitB));
    final done = utf8.encode(_sseDone());

    final client = OpenAiCompatibleClient(
      baseUrl: 'https://api.deepseek.com',
      apiKey: 'sk-test',
      httpClient: _chunkedClient(200, [a, b, c, done]),
    );
    final chunks = await client.streamChat(prompt: 'test').toList();
    expect(chunks, ['world']);
  });
}
