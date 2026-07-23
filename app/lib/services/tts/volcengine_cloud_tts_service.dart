// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'base_cloud_tts_service.dart';
import 'cloud_tts_credentials.dart';
import 'cloud_tts_exception.dart';
import 'voice_preset.dart';

/// Volcengine (火山引擎 / 豆包语音) cloud TTS via HTTP API v1.
///
/// API reference: https://www.volcengine.com/docs/6561/1257584
///
/// Endpoint: https://openspeech.bytedance.com/api/v1/tts
/// Auth: Authorization: Bearer;<token>
/// Response: JSON { code: 3000, data: <base64 mp3> }
class VolcengineCloudTtsService extends BaseCloudTtsService {
  VolcengineCloudTtsService({
    required this.credentials,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final VolcengineTtsCredentials credentials;
  final http.Client _httpClient;

  static const _endpoint =
      'https://openspeech.bytedance.com/api/v1/tts';

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

  /// Maps our normalized rate (-1.0..1.0) to Volcengine speed_ratio (0.5..2.0).
  /// -1.0 → 0.5 (slowest), 0.0 → 1.0 (normal), 1.0 → 2.0 (fastest)
  double _mapRate(double normalized) {
    return (normalized + 1.0) * 0.75 + 0.5;
  }

  @override
  Future<Uint8List> fetchAudio(
      String text, double rate, String voice) async {
    final body = jsonEncode({
      'app': {
        'appid': credentials.appId,
        'token': credentials.accessToken,
        'cluster': 'volcano_tts',
      },
      'user': {'uid': 'zhiyue'},
      'audio': {
        'voice_type': voice,
        'speed_ratio': _mapRate(rate),
        'encoding': 'mp3',
        'rate': 24000,
      },
      'request': {
        'reqid': DateTime.now().microsecondsSinceEpoch.toString(),
        'text': text,
        'operation': 'query',
      },
    });

    http.Response response;
    try {
      response = await _httpClient.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer;${credentials.accessToken}',
          'Content-Type': 'application/json',
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
      throw CloudTtsException(
        kind: CloudTtsErrorKind.fromHttpStatus(response.statusCode),
        message: 'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.invalidRequest,
        message: 'Invalid JSON response: ${response.body}',
      );
    }

    final code = decoded['code'];
    if (code != 3000) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.invalidRequest,
        message: '${decoded['message'] ?? 'unknown'} (code=$code)',
      );
    }

    final data = decoded['data'] as String?;
    if (data == null || data.isEmpty) {
      throw CloudTtsException(
        kind: CloudTtsErrorKind.invalidRequest,
        message: 'Empty audio data in response',
      );
    }

    return base64Decode(data);
  }

  @override
  Future<void> dispose() async {
    _httpClient.close();
    await super.dispose();
  }
}
