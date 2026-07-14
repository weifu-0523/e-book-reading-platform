// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhiyue/services/sync/web_dav_client.dart';

const _propfindWithSizeResponse = '''<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>/dav/user/zhiyue/files/</D:href>
    <D:propstat>
      <D:prop>
        <D:resourcetype><D:collection/></D:resourcetype>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
  <D:response>
    <D:href>/dav/user/zhiyue/files/book1.epub</D:href>
    <D:propstat>
      <D:prop>
        <D:resourcetype/>
        <D:getcontentlength>1024</D:getcontentlength>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
  <D:response>
    <D:href>/dav/user/zhiyue/files/book2.pdf</D:href>
    <D:propstat>
      <D:prop>
        <D:resourcetype/>
        <D:getcontentlength>2048</D:getcontentlength>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>''';

const _propfindEmptyDirResponse = '''<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>/dav/user/zhiyue/files/</D:href>
    <D:propstat>
      <D:prop>
        <D:resourcetype><D:collection/></D:resourcetype>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>''';

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

    // Regression test for 2026-07-12 user-reported bug:
    //   "在新电脑同步后，出现了之前电脑的书籍，但书名是乱码"
    // Root cause: jianguoyun returns snapshots with
    //   Content-Type: application/octet-stream (no charset parameter).
    // The Dart http package's Response.body getter decodes bodyBytes using
    // the encoding inferred from the Content-Type header; without an
    // explicit charset it falls back to latin1, which corrupts multibyte
    // UTF-8 sequences (Chinese title bytes decode as isolated Mojibake
    // chars). Fix: getString uses utf8.decode(response.bodyBytes) directly.
    test(
        'Bug B (2026-07-12): decodes UTF-8 even when Content-Type '
        'lacks charset (application/octet-stream)', () async {
      final mock = MockClient((request) async {
        return http.Response.bytes(
          Uint8List.fromList(utf8.encode('{"title":"华为主世界"}')),
          200,
          headers: {'content-type': 'application/octet-stream'},
        );
      });
      client = build(mock);
      final result = await client.getString('/zhiyue/snapshots/x.jsonl');
      expect(result, '{"title":"华为主世界"}');
    });

    test(
        'Bug B (2026-07-12): decodes UTF-8 when Content-Type has explicit '
        'charset=utf-8', () async {
      final mock = MockClient((request) async {
        return http.Response.bytes(
          Uint8List.fromList(utf8.encode('{"title":"华为主世界"}')),
          200,
          headers: {'content-type': 'application/octet-stream; charset=utf-8'},
        );
      });
      client = build(mock);
      final result = await client.getString('/zhiyue/snapshots/x.jsonl');
      expect(result, '{"title":"华为主世界"}');
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

  group('mkcol 409 disambiguation', () {
    test('swallows 409 when PROPFIND verifies existence', () async {
      final calls = <String>[];
      final client = WebDavClient(
        baseUrl: 'https://example.com/dav/user',
        username: 'u',
        password: 'p',
        httpClient: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.method == 'MKCOL') {
            return http.Response(
              '<?xml version="1.0"?><d:error xmlns:d="DAV:"><s:exception>AncestorsNotFound</s:exception></d:error>',
              409,
            );
          }
          // PROPFIND
          return http.Response(
            '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:"><d:response><d:href>/dav/user/zhiyue/</d:href></d:response></d:multistatus>',
            207,
            headers: {'content-type': 'application/xml'},
          );
        }),
      );
      await client.mkcol('/zhiyue');
      expect(calls, contains('MKCOL /dav/user/zhiyue'));
      expect(calls, contains('PROPFIND /dav/user/zhiyue'));
    });

    test('rethrows 409 when PROPFIND also fails (truly missing)', () async {
      final client = WebDavClient(
        baseUrl: 'https://example.com/dav/user',
        username: 'u',
        password: 'p',
        httpClient: MockClient((request) async {
          if (request.method == 'MKCOL') {
            return http.Response('<error>AncestorsNotFound</error>', 409);
          }
          return http.Response('<error>Not Found</error>', 404);
        }),
      );
      await expectLater(
        client.mkcol('/zhiyue'),
        throwsA(isA<WebDavException>()),
      );
    });

    test('still throws on 401/403/500 without PROPFIND', () async {
      for (final status in [401, 403, 500]) {
        final client = WebDavClient(
          baseUrl: 'https://example.com/dav/user',
          username: 'u',
          password: 'p',
          httpClient: MockClient((request) async {
            expect(request.method, 'MKCOL'); // No PROPFIND expected
            return http.Response('<error/>', status);
          }),
        );
        await expectLater(
          client.mkcol('/zhiyue'),
          throwsA(isA<WebDavException>()),
        );
      }
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

    test('ensureAncestors logs each segment status on failure', () async {
      final logMessages = <String>[];
      final client = WebDavClient(
        baseUrl: 'https://example.com/dav/user',
        username: 'u',
        password: 'p',
        httpClient: MockClient((request) async {
          // /zhiyue → MKCOL 409 + PROPFIND 404 (truly missing per T2 logic)
          if (request.method == 'MKCOL' && request.url.path.endsWith('/zhiyue')) {
            return http.Response('<err>AncestorsNotFound</err>', 409);
          }
          if (request.method == 'PROPFIND' && request.url.path.endsWith('/zhiyue')) {
            return http.Response('<err>Not Found</err>', 404);
          }
          return http.Response('', 500);
        }),
        debugLog: logMessages.add,
      );
      await expectLater(
        client.ensureAncestors('/zhiyue/snapshots/device.jsonl'),
        throwsA(isA<WebDavException>()),
      );
      // Verify log captured the failure context
      expect(
        logMessages.any((m) => m.contains('MKCOL') && m.contains('/zhiyue')),
        isTrue,
      );
      expect(logMessages.any((m) => m.contains('409')), isTrue);
    });
  });

  group('getBytes', () {
    test('returns binary content as bytes', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, contains('/zhiyue/files/book1.epub'));
        return http.Response.bytes(
          Uint8List.fromList([0x50, 0x4B, 0x03, 0x04]),
          200,
          headers: {'content-type': 'application/octet-stream'},
        );
      });
      client = build(mock);
      final bytes = await client.getBytes('/zhiyue/files/book1.epub');
      expect(bytes, [0x50, 0x4B, 0x03, 0x04]);
    });

    test('sends basic auth header', () async {
      String? capturedAuth;
      final mock = MockClient((request) async {
        capturedAuth = request.headers['authorization'];
        return http.Response.bytes(Uint8List.fromList([0x01]), 200);
      });
      client = build(mock);
      await client.getBytes('/zhiyue/files/book.epub');
      expect(capturedAuth, startsWith('Basic '));
    });

    test('throws WebDavException on 404', () async {
      final mock = MockClient((request) async =>
          http.Response('Not Found', 404));
      client = build(mock);
      await expectLater(
        client.getBytes('/zhiyue/files/missing.epub'),
        throwsA(isA<WebDavException>()),
      );
    });
  });

  group('putBytes', () {
    test('issues PUT with binary body', () async {
      String? capturedMethod;
      String? capturedContentType;
      List<int>? capturedBody;
      final mock = MockClient((request) async {
        capturedMethod = request.method;
        capturedContentType = request.headers['content-type'];
        capturedBody = request.bodyBytes;
        return http.Response('', 201);
      });
      client = build(mock);
      await client.putBytes(
        '/zhiyue/files/book1.epub',
        Uint8List.fromList([0x50, 0x4B, 0x03, 0x04]),
      );
      expect(capturedMethod, 'PUT');
      expect(capturedContentType, 'application/octet-stream');
      expect(capturedBody, [0x50, 0x4B, 0x03, 0x04]);
    });

    test('sends basic auth header', () async {
      String? capturedAuth;
      final mock = MockClient((request) async {
        capturedAuth = request.headers['authorization'];
        return http.Response('', 201);
      });
      client = build(mock);
      await client.putBytes('/zhiyue/files/book.epub', Uint8List.fromList([0x01]));
      expect(capturedAuth, startsWith('Basic '));
    });

    test('throws WebDavException on 507 Insufficient Storage', () async {
      final mock = MockClient((request) async =>
          http.Response('Insufficient Storage', 507));
      client = build(mock);
      try {
        await client.putBytes('/zhiyue/files/big.epub', Uint8List.fromList([0x00]));
        fail('expected WebDavException');
      } on WebDavException catch (e) {
        expect(e.statusCode, 507);
      }
    });

    test('throws WebDavException on 401 unauthorized', () async {
      final mock = MockClient((request) async =>
          http.Response('Unauthorized', 401));
      client = build(mock);
      await expectLater(
        client.putBytes('/zhiyue/files/book.epub', Uint8List.fromList([0x00])),
        throwsA(isA<WebDavException>()),
      );
    });
  });

  group('listFilesWithSize', () {
    test('parses PROPFIND response with sizes', () async {
      String? capturedMethod;
      String? capturedDepth;
      final mock = MockClient((request) async {
        capturedMethod = request.method;
        capturedDepth = request.headers['depth'];
        return http.Response(
          _propfindWithSizeResponse,
          207,
          headers: {'content-type': 'application/xml; charset=utf-8'},
        );
      });
      client = build(mock);
      final result = await client.listFilesWithSize('/zhiyue/files/');
      expect(capturedMethod, 'PROPFIND');
      expect(capturedDepth, '1');
      expect(result, {
        'book1.epub': 1024,
        'book2.pdf': 2048,
      });
    });

    test('skips collection (directory) entries', () async {
      final mock = MockClient((request) async =>
          http.Response(_propfindWithSizeResponse, 207,
              headers: {'content-type': 'application/xml'}));
      client = build(mock);
      final result = await client.listFilesWithSize('/zhiyue/files/');
      // The directory entry itself (href ends with /) must NOT be in result.
      expect(result, isNot(contains('files')));
      expect(result, isNot(contains('')));
      expect(result.length, 2);
    });

    test('returns empty map for directory with no files', () async {
      final mock = MockClient((request) async =>
          http.Response(_propfindEmptyDirResponse, 207,
              headers: {'content-type': 'application/xml'}));
      client = build(mock);
      final result = await client.listFilesWithSize('/zhiyue/files/');
      expect(result, isEmpty);
    });

    test('throws WebDavException on non-207 status', () async {
      final mock = MockClient((request) async =>
          http.Response('Not Found', 404));
      client = build(mock);
      await expectLater(
        client.listFilesWithSize('/zhiyue/missing/'),
        throwsA(isA<WebDavException>()),
      );
    });

    test('skips entries without getcontentlength', () async {
      const response = '''<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>/dav/user/zhiyue/files/no-size.bin</D:href>
    <D:propstat>
      <D:prop>
        <D:resourcetype/>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
  <D:response>
    <D:href>/dav/user/zhiyue/files/with-size.bin</D:href>
    <D:propstat>
      <D:prop>
        <D:resourcetype/>
        <D:getcontentlength>512</D:getcontentlength>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>''';
      final mock = MockClient((request) async =>
          http.Response(response, 207,
              headers: {'content-type': 'application/xml'}));
      client = build(mock);
      final result = await client.listFilesWithSize('/zhiyue/files/');
      expect(result, {'with-size.bin': 512});
    });
  });
}
