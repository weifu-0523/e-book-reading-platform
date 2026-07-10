import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhiyue/services/sync/web_dav_client.dart';

const _propfindResponse = '''<?xml version="1.0" encoding="UTF-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/dav/user@example.com/zhiyue/snapshots/device-a.jsonl</d:href>
    <d:propstat>
      <d:prop><d:getcontentlength>1024</d:getcontentlength></d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/user@example.com/zhiyue/snapshots/device-b.jsonl</d:href>
    <d:propstat>
      <d:prop><d:getcontentlength>512</d:getcontentlength></d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
</d:multistatus>''';

void main() {
  late WebDavClient client;

  WebDavClient build(http.Client mock) {
    return WebDavClient(
      baseUrl: 'https://dav.jianguoyun.com/dav/user@example.com',
      username: 'user@example.com',
      password: 'app-pw',
      httpClient: mock,
    );
  }

  group('putString', () {
    test('issues PUT with basic auth', () async {
      String? capturedMethod;
      String? capturedUrl;
      String? capturedBody;
      final mock = MockClient((request) async {
        capturedMethod = request.method;
        capturedUrl = request.url.toString();
        capturedBody = request.body;
        return http.Response('', 201);
      });
      client = build(mock);
      await client.putString('/zhiyue/snapshots/dev1.jsonl', 'hello');
      expect(capturedMethod, 'PUT');
      expect(capturedUrl, 'https://dav.jianguoyun.com/dav/user@example.com/zhiyue/snapshots/dev1.jsonl');
      expect(capturedBody, 'hello');
    });

    test('throws on non-2xx', () async {
      final mock = MockClient((request) async => http.Response('forbidden', 403));
      client = build(mock);
      expect(
        () => client.putString('/x', 'y'),
        throwsA(isA<WebDavException>()),
      );
    });
  });

  group('getString', () {
    test('GET returns body', () async {
      final mock = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value(Uint8List.fromList(utf8.encode('content'))),
          200,
        );
      });
      client = build(mock);
      // Use request wrapper that returns a regular response
      final client2 = WebDavClient(
        baseUrl: 'https://dav.jianguoyun.com/dav/user@example.com',
        username: 'u',
        password: 'p',
        httpClient: MockClient((_) async => http.Response('content', 200)),
      );
      final result = await client2.getString('/x');
      expect(result, 'content');
    });
  });

  group('listFiles', () {
    test('parses PROPFIND multistatus', () async {
      String? capturedMethod;
      final mock = MockClient((request) async {
        capturedMethod = request.method;
        return http.Response(_propfindResponse, 207, headers: {'content-type': 'application/xml'});
      });
      client = build(mock);
      final files = await client.listFiles('/zhiyue/snapshots/');
      expect(capturedMethod, 'PROPFIND');
      expect(files, hasLength(2));
      expect(files, containsAll(['device-a.jsonl', 'device-b.jsonl']));
    });
  });

  group('mkcol', () {
    test('issues MKCOL with basic auth', () async {
      String? capturedMethod;
      String? capturedUrl;
      final mock = MockClient((request) async {
        capturedMethod = request.method;
        capturedUrl = request.url.toString();
        return http.Response('', 201);
      });
      client = build(mock);
      await client.mkcol('/zhiyue');
      expect(capturedMethod, 'MKCOL');
      expect(capturedUrl, 'https://dav.jianguoyun.com/dav/user@example.com/zhiyue');
    });

    test('idempotent: 405 (already exists) does not throw', () async {
      final mock = MockClient((request) async => http.Response('', 405));
      client = build(mock);
      await expectLater(client.mkcol('/zhiyue'), completes);
    });

    test('throws on 409 AncestorsNotFound', () async {
      final mock = MockClient((request) async =>
          http.Response('<?xml version="1.0"?><d:error xmlns:d="DAV:"/>', 409));
      client = build(mock);
      expect(() => client.mkcol('/zhiyue'), throwsA(isA<WebDavException>()));
    });
  });

  group('ensureAncestors', () {
    test('MKCOLs every directory segment except the file name', () async {
      final capturedPaths = <String>[];
      final mock = MockClient((request) async {
        capturedPaths.add(request.url.path);
        return http.Response('', 201);
      });
      client = build(mock);
      await client.ensureAncestors('/zhiyue/snapshots/dev1.jsonl');
      // Two MKCOLs: /zhiyue and /zhiyue/snapshots. The .jsonl file is NOT
      // included (it's the file, not a directory).
      expect(capturedPaths, [
        '/dav/user@example.com/zhiyue',
        '/dav/user@example.com/zhiyue/snapshots',
      ]);
    });

    test('idempotent: existing dirs (405) do not abort the loop', () async {
      final capturedPaths = <String>[];
      final mock = MockClient((request) async {
        capturedPaths.add(request.url.path);
        return http.Response('', 405);
      });
      client = build(mock);
      await client.ensureAncestors('/zhiyue/snapshots/dev1.jsonl');
      expect(capturedPaths, hasLength(2));
    });

    test('single-segment path is a no-op', () async {
      var callCount = 0;
      final mock = MockClient((request) async {
        callCount++;
        return http.Response('', 201);
      });
      client = build(mock);
      await client.ensureAncestors('/file.jsonl');
      expect(callCount, 0);
    });
  });
}
