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

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Base type for all AI client exceptions. Maps to [AiGuideError] in the
/// orchestrator (T10).
abstract class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => '$runtimeType: $message';
}

class AiAuthException extends AiException {
  const AiAuthException(super.message);
}

class AiRateLimitException extends AiException {
  const AiRateLimitException(super.message);
}

class AiServerException extends AiException {
  const AiServerException(super.message);
}

class AiNetworkException extends AiException {
  const AiNetworkException(super.message);
}

class AiParseException extends AiException {
  const AiParseException(super.message);
}

/// Minimal OpenAI-compatible chat completions client with SSE streaming.
///
/// Constructor accepts an optional [httpClient] for testability — production
/// lets the default client be constructed.
///
/// v1.12.2-alpha P2: [temperature] / [topP] surfaced as constructor params
/// sourced from [AiCredentials]. Defaults match the OpenAI / DeepSeek server
/// defaults (1.0 / 1.0), so existing behavior is unchanged when the user
/// hasn't customized these.
class OpenAiCompatibleClient {
  OpenAiCompatibleClient({
    required this.baseUrl,
    required this.apiKey,
    this.model = 'deepseek-chat',
    this.temperature = 1.0,
    this.topP = 1.0,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final String model;
  final double temperature;
  final double topP;
  final Duration timeout;
  final http.Client _httpClient;

  /// POST `{baseUrl}/v1/chat/completions` with `stream=true`.
  /// Yields incremental content chunks parsed from SSE `delta.content`.
  ///
  /// Throws:
  /// - [AiAuthException] on 401/403
  /// - [AiRateLimitException] on 429
  /// - [AiServerException] on other 4xx/5xx
  /// - [AiNetworkException] on socket/timeout
  /// - [AiParseException] on malformed SSE payload
  Stream<String> streamChat({required String prompt}) async* {
    final uri = Uri.parse('$baseUrl/v1/chat/completions');
    final request = http.Request('POST', uri)
      ..headers['authorization'] = 'Bearer $apiKey'
      ..headers['content-type'] = 'application/json; charset=utf-8'
      ..body = jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'stream': true,
        // v1.12.2-alpha P2: sampling params from AiCredentials. Always sent
        // (server defaults match our defaults, so behavior is identical to
        // pre-P2 when the user hasn't customized).
        'temperature': temperature,
        'top_p': topP,
      });

    final http.StreamedResponse response;
    try {
      response = await _httpClient.send(request).timeout(timeout);
    } catch (e) {
      throw AiNetworkException('request failed: $e');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AiAuthException('HTTP ${response.statusCode}');
    }
    if (response.statusCode == 429) {
      throw const AiRateLimitException('HTTP 429');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiServerException('HTTP ${response.statusCode}');
    }

    // P0 fix: buffer partial lines across TCP chunk boundaries. Long SSE
    // delta JSON lines (1-2KB with metadata) routinely get split mid-line
    // by TCP. Without buffering, the partial line fails jsonDecode →
    // AiParseException → stream terminates, discarding accumulated content
    // (user has already paid for those tokens). Solution: keep the last
    // partial segment (no trailing \n) in _pending and prepend it to the
    // next chunk. utf8.decoder already handles partial UTF-8 sequences
    // across chunks; this layer handles partial lines.
    var pending = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      pending = '$pending$chunk';
      final lines = pending.split('\n');
      // If chunk ends with \n, split yields a trailing '' that we can
      // process. If not, the last segment is partial — hold it back.
      pending = lines.removeLast();
      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (!line.startsWith('data: ')) continue;
        final payload = line.substring(6).trim();
        if (payload == '[DONE]') return;
        try {
          final json = jsonDecode(payload) as Map<String, dynamic>;
          final choices = json['choices'] as List?;
          if (choices == null || choices.isEmpty) continue;
          final delta = choices[0]['delta'] as Map<String, dynamic>?;
          final content = delta?['content'];
          if (content is String && content.isNotEmpty) yield content;
        } catch (e) {
          throw AiParseException('failed to parse SSE payload: $e');
        }
      }
    }
    // Flush any final partial line held in pending (rare: server may close
    // connection without trailing \n).
    if (pending.trim().startsWith('data: ')) {
      final payload = pending.trim().substring(6).trim();
      if (payload == '[DONE]') return;
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final choices = json['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final delta = choices[0]['delta'] as Map<String, dynamic>?;
          final content = delta?['content'];
          if (content is String && content.isNotEmpty) yield content;
        }
      } catch (e) {
        throw AiParseException('failed to parse SSE payload: $e');
      }
    }
  }
}
