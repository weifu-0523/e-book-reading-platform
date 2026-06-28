import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiCredentialsDefaults {
  const ApiCredentialsDefaults._();
  static const String baseUrl = 'https://api.deepseek.com';
  static const String model = 'deepseek-chat';
}

class AiCredentials {
  const AiCredentials({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });

  final String apiKey;
  final String baseUrl;
  final String model;
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

  final FlutterSecureStorage _storage;

  @override
  Future<AiCredentials?> load() async {
    final apiKey = await _storage.read(key: _kApiKey);
    if (apiKey == null || apiKey.isEmpty) return null;
    final baseUrl = await _storage.read(key: _kBaseUrl);
    final model = await _storage.read(key: _kModel);
    return AiCredentials(
      apiKey: apiKey,
      baseUrl: (baseUrl == null || baseUrl.isEmpty)
          ? ApiCredentialsDefaults.baseUrl
          : baseUrl,
      model: (model == null || model.isEmpty)
          ? ApiCredentialsDefaults.model
          : model,
    );
  }

  Future<void> save(AiCredentials c) async {
    await _storage.write(key: _kApiKey, value: c.apiKey);
    await _storage.write(key: _kBaseUrl, value: c.baseUrl);
    await _storage.write(key: _kModel, value: c.model);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kApiKey);
    await _storage.delete(key: _kBaseUrl);
    await _storage.delete(key: _kModel);
  }
}
