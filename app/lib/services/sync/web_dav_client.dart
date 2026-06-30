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
  }) : _httpClient = httpClient ?? http.Client();

  /// Base URL up to (and including) the user-specific path segment,
  /// e.g. `https://dav.jianguoyun.com/dav/user@example.com`.
  final String baseUrl;
  final String username;
  final String password;
  final http.Client _httpClient;

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

  /// GET a file's content as UTF-8 string.
  Future<String> getString(String path) async {
    final response = await _httpClient.get(_uri(path), headers: _authHeader);
    _ensureOk(response.statusCode, path, response.body);
    return response.body;
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

  /// DELETE a file. No-op (returns silently) if the file doesn't exist (404).
  Future<void> delete(String path) async {
    final response = await _httpClient.delete(_uri(path), headers: _authHeader);
    if (response.statusCode != 204 && response.statusCode != 404) {
      throw WebDavException(response.statusCode, path, response.body);
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
}
