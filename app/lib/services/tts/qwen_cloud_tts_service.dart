// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'base_cloud_tts_service.dart';
import 'cloud_tts_credentials.dart';
import 'cloud_tts_exception.dart';
import 'voice_preset.dart';

/// Qwen / CosyVoice (阿里云百炼) cloud TTS via DashScope HTTP non-streaming API.
///
/// API reference: https://help.aliyun.com/zh/model-studio/cosyvoice-tts-http-api
///
/// Endpoint: https://dashscope.aliyuncs.com/api/v1/services/audio/tts/generate
/// Auth: Authorization: Bearer <apiKey>
/// Response: JSON { output: { audio: { url } } }
///
/// Note: API returns an audio URL, not base64 bytes — service issues a
/// second HTTP GET to fetch the MP3 bytes. Adds ~100-200ms latency.
class QwenCloudTtsService extends BaseCloudTtsService {
  QwenCloudTtsService({
    required this.credentials,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final QwenTtsCredentials credentials;
  final http.Client _httpClient;

  static const _endpoint =
      'https://dashscope.aliyuncs.com/api/v1/services/audio/tts/generate';

  @override
  String get engineName => 'qwen';

  @override
  List<VoicePreset> get supportedVoices => CloudTtsVoicePresets.qwen;

  @override
  String get defaultVoice => QwenTtsCredentials.defaultVoice;

  @override
  Future<QwenTtsCredentials?> loadCredentials() async {
    if (credentials.apiKey.isEmpty) return null;
    return credentials;
  }

  /// Maps our normalized rate (-1.0..1.0) to Qwen rate (0.5..2.0).
  double _mapRate(double normalized) {
    return (normalized + 1.0) * 0.75 + 0.5;
  }

  @override
  Future<Uint8List> fetchAudio(String text, double rate, String voice) async {
    final body = jsonEncode({
      'model': credentials.model,
      'input': {
        'text': text,
        'voice': voice,
        'format': 'mp3',
        'sample_rate': 24000,
        'rate': _mapRate(rate),
        'volume': 50,
      },
    });

    http.Response postResponse;
    try {
      postResponse = await _httpClient.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer ${credentials.apiKey}',
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.network,
        message: 'POST failed: $e',
      );
    }

    if (postResponse.statusCode != 200) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.fromHttpStatus(postResponse.statusCode),
        message: 'HTTP ${postResponse.statusCode}: ${postResponse.body}',
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(postResponse.body) as Map<String, dynamic>;
    } catch (e) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.invalidRequest,
        message: 'Invalid JSON: ${postResponse.body}',
      );
    }

    final output = decoded['output'];
    if (output is! Map) {
      throw const CloudTtsException(
        kind: CloudTtsErrorKind.invalidRequest,
        message: 'Missing output in response',
      );
    }
    final audio = output['audio'];
    final url = audio is Map ? audio['url'] as String? : null;
    if (url == null || url.isEmpty) {
      throw const CloudTtsException(
        kind: CloudTtsErrorKind.invalidRequest,
        message: 'Missing audio.url in response',
      );
    }

    // Second HTTP GET to fetch the actual bytes.
    http.Response getResponse;
    try {
      getResponse = await _httpClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.network,
        message: 'GET audio URL failed: $e',
      );
    }

    if (getResponse.statusCode != 200) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.fromHttpStatus(getResponse.statusCode),
        message: 'Audio GET ${getResponse.statusCode}',
      );
    }

    return getResponse.bodyBytes;
  }

  @override
  Future<void> dispose() async {
    _httpClient.close();
    await super.dispose();
  }
}
