// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'base_cloud_tts_service.dart';
import 'cloud_tts_credentials.dart';
import 'cloud_tts_exception.dart';
import 'voice_preset.dart';

/// Volcengine (火山引擎 / 豆包语音合成 2.0) cloud TTS via V3 HTTP SSE.
///
/// API reference: https://docs.volcengine.com/docs/6561/1598757
///
/// Endpoint: https://openspeech.bytedance.com/api/v3/tts/sse
/// Auth (legacy console): X-Api-App-Id + X-Api-Access-Key + X-Api-Resource-Id=seed-tts-2.0 + X-Api-Request-Id (uuid v4)
/// Response: SSE event stream, each event = JSON frame
///   - Audio: {"data": "<base64-mp3-chunk>"}
///   - End-of-stream: {"code": 20000000, "message": "ok"}
///   - Error: {"code": <non-20000000>, "message": "..."}
class VolcengineCloudTtsService extends BaseCloudTtsService {
  VolcengineCloudTtsService({
    required this.credentials,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final VolcengineTtsCredentials credentials;
  final http.Client _httpClient;

  static const _endpoint =
      'https://openspeech.bytedance.com/api/v3/tts/sse';

  @override
  String get engineName => 'volcengine';

  @override
  List<VoicePreset> get supportedVoices => CloudTtsVoicePresets.volcengine;

  @override
  String get defaultVoice => VolcengineTtsCredentials.defaultVoice;

  @override
  Future<VolcengineTtsCredentials?> loadCredentials() async {
    if (credentials.appId.isEmpty || credentials.accessToken.isEmpty) {
      return null;
    }
    return credentials;
  }

  /// Maps normalized rate [-1.0, 1.0] → V3 speech_rate int [-50, 50].
  /// -1.0 → -50 (0.5x), 0.0 → 0 (1.0x), 1.0 → 50 (1.5x).
  /// V3 allows [-50, 100] (up to 2.0x) but UI slider upper limit caps at 1.5x.
  /// v1.17 can widen UI slider if user needs faster playback.
  int _mapRate(double normalized) {
    return (normalized * 50).round().clamp(-50, 100);
  }

  @override
  Future<Uint8List> fetchAudio(
      String text, double rate, String voice) async {
    final body = jsonEncode({
      'user': {'uid': 'zhiyue'},
      'req_params': {
        'text': text,
        'speaker': voice,
        'audio_params': {
          'format': 'mp3',
          'sample_rate': 24000,
          'speech_rate': _mapRate(rate),
        },
      },
    });

    http.Response response;
    try {
      response = await _httpClient.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          'X-Api-App-Id': credentials.appId,
          'X-Api-Access-Key': credentials.accessToken,
          'X-Api-Resource-Id': 'seed-tts-2.0',
          'X-Api-Request-Id': const Uuid().v4(),
        },
        body: body,
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.network,
        message: 'HTTP request failed: $e',
        cause: e.toString(),
      );
    }

    if (response.statusCode != 200) {
      // V3 HTTP non-200 body is JSON {code, message, reqid}
      throw CloudTtsException(
        kind: CloudTtsErrorKind.fromHttpStatus(response.statusCode),
        message: 'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    // V3 SSE response: multiple `data: <JSON>` events + termination frame.
    // Each event ends with \n\n. JSON payload is one frame per event.
    // Audio frames: {"data": "<base64>"}
    // End-of-stream: {"code": 20000000, "message": "ok"}
    // Error frame: {"code": <non-20000000>, "message": "..."}

    final bodyString = response.body;
    debugPrint('[VolcengineV3] raw response head 500: '
        '${bodyString.length > 500 ? bodyString.substring(0, 500) : bodyString}');

    final chunks = <int>[];
    final events = bodyString.split('\n\n');

    for (final event in events) {
      if (!event.startsWith('data: ')) continue;
      final payload = event.substring(6).trim();
      if (payload.isEmpty) continue;

      // Try JSON decode first (V3 documented format)
      Map<String, dynamic>? jsonFrame;
      try {
        jsonFrame = jsonDecode(payload) as Map<String, dynamic>;
      } catch (_) {
        // Fallback: maybe raw base64 (undocumented but defensive)
        try {
          chunks.addAll(base64Decode(payload));
          continue;
        } catch (_) {
          throw CloudTtsException(
            kind: CloudTtsErrorKind.invalidRequest,
            message: 'Unparseable SSE event: $payload',
          );
        }
      }

      // JSON frame: check for code field
      final code = jsonFrame['code'];
      if (code != null) {
        if (code == 20000000) {
          // End-of-stream marker — stop reading
          break;
        }
        // Non-20000000 code = error frame
        final message = jsonFrame['message'] ?? 'unknown';
        throw CloudTtsException(
          kind: _classifyErrorCode(code as int),
          message: '$message (code=$code)',
        );
      }

      // JSON frame without code: audio frame, extract data field
      final dataField = jsonFrame['data'];
      if (dataField is String && dataField.isNotEmpty) {
        try {
          chunks.addAll(base64Decode(dataField));
        } catch (e) {
          throw CloudTtsException(
            kind: CloudTtsErrorKind.invalidRequest,
            message: 'Invalid base64 in audio frame: $e',
          );
        }
      }
    }

    if (chunks.isEmpty) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.invalidRequest,
        message: 'Empty audio data in SSE response: $bodyString',
      );
    }

    return Uint8List.fromList(chunks);
  }

  /// Maps V3 error code to CloudTtsErrorKind.
  /// See task 1 notes Section 7 for full table.
  CloudTtsErrorKind _classifyErrorCode(int code) {
    switch (code) {
      case 3001:
        return CloudTtsErrorKind.auth;
      case 4293:
      case 4295:
      case 4296:
      case 55000000:
        return CloudTtsErrorKind.invalidRequest;
      default:
        // Unknown codes default to server error (transient)
        return CloudTtsErrorKind.server;
    }
  }

  @override
  Future<void> dispose() async {
    _httpClient.close();
    await super.dispose();
  }
}
