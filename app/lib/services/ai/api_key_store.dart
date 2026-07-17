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

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiCredentialsDefaults {
  const ApiCredentialsDefaults._();
  static const String baseUrl = 'https://api.deepseek.com';
  static const String model = 'deepseek-chat';

  /// v1.12.2-alpha P2: defaults for the new AI tuning fields. See
  /// [AiCredentials.contextTurns] / [AiCredentials.topP] /
  /// [AiCredentials.temperature] for the rationale.
  static const int contextTurns = 6;
  static const double topP = 1.0;
  static const double temperature = 1.0;
}

/// Sampling + context-window tuning for the AI chat.
///
/// **contextTurns** (v1.12.2-alpha P2, default 6): how many recent
/// turns (user + AI pairs) are loaded from `chat_messages` and fed to
/// the LLM as history. 6 turns = 12 messages. Older messages stay in
/// the database (visible in the scroll-back UI) but don't enter the
/// prompt — keeps long-running sessions from blowing past the model's
/// context window and reduces per-request cost.
///
/// **topP** (default 1.0 = API server default): nucleus sampling
/// cutoff. Range [0, 1]. Lower = more focused / deterministic; higher
/// = more diverse. DeepSeek's docs recommend adjusting EITHER
/// temperature OR top_p, not both — the UI shows a hint to that
/// effect.
///
/// **temperature** (default 1.0 = API server default): sampling
/// temperature. Range [0, 2]. Lower = more deterministic; higher =
/// more random.
///
/// All three live alongside apiKey/baseUrl/model in
/// `flutter_secure_storage` — device-local preference, NOT synced
/// across devices (intentional: a user may want aggressive sampling
/// on desktop and conservative sampling on mobile).
class AiCredentials {
  const AiCredentials({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    this.contextTurns = ApiCredentialsDefaults.contextTurns,
    this.topP = ApiCredentialsDefaults.topP,
    this.temperature = ApiCredentialsDefaults.temperature,
  });

  final String apiKey;
  final String baseUrl;
  final String model;
  final int contextTurns;
  final double topP;
  final double temperature;

  AiCredentials copyWith({
    String? apiKey,
    String? baseUrl,
    String? model,
    int? contextTurns,
    double? topP,
    double? temperature,
  }) {
    return AiCredentials(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      contextTurns: contextTurns ?? this.contextTurns,
      topP: topP ?? this.topP,
      temperature: temperature ?? this.temperature,
    );
  }
}

/// Abstraction over [ApiKeyStore] so tests can inject an in-memory stub
/// when driving [AiGuide] without going through flutter_secure_storage.
abstract class ApiKeyStoreLike {
  Future<AiCredentials?> load();
}

class ApiKeyStore implements ApiKeyStoreLike {
  ApiKeyStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kApiKey = 'zhiyue.ai.apiKey';
  static const _kBaseUrl = 'zhiyue.ai.baseUrl';
  static const _kModel = 'zhiyue.ai.model';
  // v1.12.2-alpha P2: stored as string (secure-storage only supports string);
  // load() parses back to int/double with safe defaults on parse failure.
  static const _kContextTurns = 'zhiyue.ai.contextTurns';
  static const _kTopP = 'zhiyue.ai.topP';
  static const _kTemperature = 'zhiyue.ai.temperature';

  final FlutterSecureStorage _storage;

  @override
  Future<AiCredentials?> load() async {
    final apiKey = await _storage.read(key: _kApiKey);
    if (apiKey == null || apiKey.isEmpty) return null;
    final baseUrl = await _storage.read(key: _kBaseUrl);
    final model = await _storage.read(key: _kModel);
    final contextTurnsRaw = await _storage.read(key: _kContextTurns);
    final topPRaw = await _storage.read(key: _kTopP);
    final temperatureRaw = await _storage.read(key: _kTemperature);
    return AiCredentials(
      apiKey: apiKey,
      baseUrl: (baseUrl == null || baseUrl.isEmpty)
          ? ApiCredentialsDefaults.baseUrl
          : baseUrl,
      model: (model == null || model.isEmpty)
          ? ApiCredentialsDefaults.model
          : model,
      contextTurns: _parseIntOrDefault(
          contextTurnsRaw, ApiCredentialsDefaults.contextTurns),
      topP: _parseDoubleOrDefault(topPRaw, ApiCredentialsDefaults.topP),
      temperature: _parseDoubleOrDefault(
          temperatureRaw, ApiCredentialsDefaults.temperature),
    );
  }

  Future<void> save(AiCredentials c) async {
    await _storage.write(key: _kApiKey, value: c.apiKey);
    await _storage.write(key: _kBaseUrl, value: c.baseUrl);
    await _storage.write(key: _kModel, value: c.model);
    await _storage.write(key: _kContextTurns, value: c.contextTurns.toString());
    await _storage.write(key: _kTopP, value: c.topP.toString());
    await _storage.write(key: _kTemperature, value: c.temperature.toString());
  }

  Future<void> clear() async {
    await _storage.delete(key: _kApiKey);
    await _storage.delete(key: _kBaseUrl);
    await _storage.delete(key: _kModel);
    await _storage.delete(key: _kContextTurns);
    await _storage.delete(key: _kTopP);
    await _storage.delete(key: _kTemperature);
  }

  int _parseIntOrDefault(String? raw, int fallback) {
    if (raw == null || raw.isEmpty) return fallback;
    return int.tryParse(raw) ?? fallback;
  }

  double _parseDoubleOrDefault(String? raw, double fallback) {
    if (raw == null || raw.isEmpty) return fallback;
    return double.tryParse(raw) ?? fallback;
  }
}
