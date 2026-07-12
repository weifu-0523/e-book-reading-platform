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

import 'package:http/http.dart' as http;

/// Thrown when WebDAV returns a non-success status.
class WebDavException implements Exception {
  WebDavException(this.statusCode, this.path, this.body);
  final int statusCode;
  final String path;
  final String body;

  @override
  String toString() => 'WebDavException($statusCode at $path): $body';
}

/// Minimal WebDAV HTTP client (PROPFIND / GET / PUT / DELETE).
///
/// Constructor accepts an [httpClient] for testability — production passes
/// nothing (uses default) and tests inject `http.MockClient`.
class WebDavClient {
  WebDavClient({
    required this.baseUrl,
    required this.username,
    required this.password,
    http.Client? httpClient,
    this.debugLog,
  }) : _httpClient = httpClient ?? http.Client();

  /// Base URL up to (and including) the user-specific path segment,
  /// e.g. `https://dav.jianguoyun.com/dav/user@example.com`.
  final String baseUrl;
  final String username;
  final String password;
  final http.Client _httpClient;

  /// Optional debug log sink. When set, [ensureAncestors] reports each
  /// MKCOL segment's status on failure. Null = no logging (production
  /// default if caller doesn't wire it).
  final void Function(String)? debugLog;

  Uri _uri(String path) {
    final clean = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$clean');
  }

  Map<String, String> get _authHeader {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return {'authorization': 'Basic $credentials'};
  }

  /// PROPFIND on a directory, return list of file names (not directories).
  Future<List<String>> listFiles(String dirPath) async {
    final response = await _httpClient.send(http.Request('PROPFIND', _uri(dirPath))
      ..headers['authorization'] = _authHeader['authorization']!
      ..headers['depth'] = '1'
      ..headers['content-type'] = 'application/xml; charset=utf-8'
      ..body = '''<?xml version="1.0" encoding="utf-8"?>
<D:propfind xmlns:D="DAV:"><D:prop><D:getcontentlength/></D:prop></D:propfind>''');
    final body = await response.stream.bytesToString();
    if (response.statusCode != 207) {
      throw WebDavException(response.statusCode, dirPath, body);
    }
    return _parsePropfindFilenames(body);
  }

  /// PROPFIND on a directory, return map of `{filename: sizeInBytes}` for
  /// each file (not directory). Used by T9 BookFileSyncService for quota
  /// display + progress UI.
  ///
  /// Entries are skipped when:
  /// - `<resourcetype>` contains `<collection/>` (it's a directory)
  /// - `<getcontentlength>` is absent (some servers omit for unknown size)
  /// - `<getcontentlength>` is not parseable as int
  Future<Map<String, int>> listFilesWithSize(String dirPath) async {
    final response = await _httpClient.send(http.Request('PROPFIND', _uri(dirPath))
      ..headers['authorization'] = _authHeader['authorization']!
      ..headers['depth'] = '1'
      ..headers['content-type'] = 'application/xml; charset=utf-8'
      ..body = '''<?xml version="1.0" encoding="utf-8"?>
<D:propfind xmlns:D="DAV:"><D:prop><D:resourcetype/><D:getcontentlength/></D:prop></D:propfind>''');
    final body = await response.stream.bytesToString();
    if (response.statusCode != 207) {
      throw WebDavException(response.statusCode, dirPath, body);
    }
    return _parsePropfindFilesWithSize(body);
  }

  /// GET a file's content as UTF-8 string.
  Future<String> getString(String path) async {
    final response = await _httpClient.get(_uri(path), headers: _authHeader);
    _ensureOk(response.statusCode, path, response.body);
    return response.body;
  }

  /// GET a file's content as raw bytes (binary). For EPUB / PDF / image
  /// files where UTF-8 decoding would corrupt the payload.
  Future<Uint8List> getBytes(String path) async {
    final response = await _httpClient.get(_uri(path), headers: _authHeader);
    _ensureOk(response.statusCode, path, response.body);
    return response.bodyBytes;
  }

  /// PUT a string to a file. Creates or overwrites.
  Future<void> putString(String path, String body) async {
    final response = await _httpClient.put(
      _uri(path),
      headers: _authHeader,
      body: body,
    );
    _ensureOk(response.statusCode, path, response.body);
  }

  /// PUT raw bytes to a file. Creates or overwrites. For binary content
  /// (EPUB / PDF / images) — sends `Content-Type: application/octet-stream`.
  ///
  /// On 507 Insufficient Storage (quota exceeded) the [WebDavException]
  /// propagates with `statusCode == 507`; caller decides retry / user
  /// messaging. We do NOT special-case it here.
  Future<void> putBytes(String path, List<int> bytes) async {
    final response = await _httpClient.put(
      _uri(path),
      headers: {
        ..._authHeader,
        'content-type': 'application/octet-stream',
      },
      body: bytes,
    );
    _ensureOk(response.statusCode, path, response.body);
  }

  /// DELETE a file. No-op (returns silently) if the file doesn't exist (404).
  Future<void> delete(String path) async {
    final response = await _httpClient.delete(_uri(path), headers: _authHeader);
    if (response.statusCode != 204 && response.statusCode != 404) {
      throw WebDavException(response.statusCode, path, response.body);
    }
  }

  /// MKCOL a directory. Idempotent — succeeds silently if the directory
  /// already exists.
  ///
  /// Status code semantics (RFC 4918 §9.3 + jianguoyun observed behavior):
  /// - 201 Created: directory created
  /// - 200 OK: rare
  /// - 405 Method Not Allowed: directory already exists (RFC 4918 §9.3)
  /// - 409 Conflict: jianguoyun deviation — may mean "already exists" OR
  ///   "parent missing". Disambiguate via PROPFIND: if PROPFIND 207 → dir
  ///   actually exists, treat MKCOL as no-op; otherwise rethrow original
  ///   409 so caller sees the real error.
  ///
  /// Any other status throws [WebDavException] without PROPFIND.
  Future<void> mkcol(String path) async {
    final request = http.Request('MKCOL', _uri(path))
      ..headers['authorization'] = _authHeader['authorization']!;
    final response = await _httpClient.send(request);
    final body = await response.stream.bytesToString();
    final status = response.statusCode;
    if (status == 201 || status == 200 || status == 405) return;
    if (status == 409) {
      try {
        await listFiles(path);
        return; // PROPFIND succeeded → dir actually exists
      } on WebDavException {
        throw WebDavException(status, path, body);
      }
    }
    throw WebDavException(status, path, body);
  }

  /// Ensure every ancestor directory of [filePath] exists. [filePath] is a
  /// full remote path like `/zhiyue/snapshots/device.jsonl`; this MKCOLs
  /// `/zhiyue` and `/zhiyue/snapshots` (every directory segment except the
  /// trailing file name), in order from root outward.
  ///
  /// Workaround for jianguoyun WebDAV returning 409 AncestorsNotFound when
  /// PUT targets a file whose parent directory doesn't exist (Bug #1,
  /// 2026-07-10). Unlike Nextcloud / ownCloud, jianguoyun does not auto-create
  /// parent directories on PUT.
  ///
  /// Idempotent: each MKCOL succeeds silently if the directory already
  /// exists (405). Safe to call before every PUT if you don't want to track
  /// "first push" state, at the cost of extra round-trips.
  Future<void> ensureAncestors(String filePath) async {
    final segments = filePath.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length <= 1) return;
    var path = '';
    for (final seg in segments.take(segments.length - 1)) {
      path += '/$seg';
      try {
        await mkcol(path);
      } on WebDavException catch (e) {
        debugLog?.call('ensureAncestors MKCOL $path → ${e.statusCode}: ${e.body}');
        rethrow;
      }
    }
  }

  void _ensureOk(int status, String path, String body) {
    if (status < 200 || status >= 300) {
      throw WebDavException(status, path, body);
    }
  }

  /// Extract `<D:href>` values from multistatus response and return the
  /// trailing path segment (the file name).
  List<String> _parsePropfindFilenames(String xmlBody) {
    final result = <String>[];
    final hrefRegex = RegExp(r'<(?:D|d):href>([^<]+)</(?:D|d):href>');
    for (final match in hrefRegex.allMatches(xmlBody)) {
      final href = Uri.decodeFull(match.group(1)!);
      final segments = href.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) continue;
      final last = segments.last;
      // Skip directory entries (href ends with /) and the dir itself.
      if (last.endsWith('.jsonl')) {
        result.add(last);
      }
    }
    return result;
  }

  /// Parse a PROPFIND multistatus body into `{filename: sizeInBytes}`.
  ///
  /// Splits on `<D:response>` blocks, then for each block extracts href +
  /// resourcetype + getcontentlength. Skips:
  /// - collection entries (directories)
  /// - entries without a parseable getcontentlength
  ///
  /// Regex-based (consistent with [_parsePropfindFilenames]) — avoids adding
  /// a `package:xml` dependency. WebDAV XML is well-structured enough that
  /// regex is reliable for this scope; a streaming XML parser would be
  /// over-engineering until we see real-world breakage.
  Map<String, int> _parsePropfindFilesWithSize(String xmlBody) {
    final result = <String, int>{};
    final responseRegex = RegExp(
      r'<(?:D|d):response>([\s\S]*?)</(?:D|d):response>',
    );
    final hrefRegex = RegExp(r'<(?:D|d):href>([^<]+)</(?:D|d):href>');
    final collectionRegex =
        RegExp(r'<(?:D|d):collection\s*/?>');
    final sizeRegex =
        RegExp(r'<(?:D|d):getcontentlength>([^<]+)</(?:D|d):getcontentlength>');

    for (final match in responseRegex.allMatches(xmlBody)) {
      final block = match.group(1)!;
      // Skip directory entries.
      if (collectionRegex.hasMatch(block)) continue;
      final hrefMatch = hrefRegex.firstMatch(block);
      if (hrefMatch == null) continue;
      final href = Uri.decodeFull(hrefMatch.group(1)!);
      final segments = href.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) continue;
      final filename = segments.last;
      final sizeMatch = sizeRegex.firstMatch(block);
      if (sizeMatch == null) continue;
      final size = int.tryParse(sizeMatch.group(1)!.trim());
      if (size == null) continue;
      result[filename] = size;
    }
    return result;
  }
}
