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
class OpenAiCompatibleClient {
  OpenAiCompatibleClient({
    required this.baseUrl,
    required this.apiKey,
    this.model = 'deepseek-chat',
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final String model;
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

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      // SSE events separated by `\n\n`; each event may span multiple data: lines.
      // Simple line-by-line parse works for OpenAI/DeepSeek's wire format.
      for (final rawLine in chunk.split('\n')) {
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
  }
}
