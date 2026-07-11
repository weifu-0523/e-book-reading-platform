import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/ai/api_key_store.dart';

class _FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _map = {};

  @override
  Future<String?> read({required String key, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async => _map[key];

  @override
  Future<void> write({required String key, required String? value, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async {
    _map[key] = value ?? '';
  }

  @override
  Future<void> delete({required String key, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async {
    _map.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeSecureStorage storage;
  late ApiKeyStore store;

  setUp(() {
    storage = _FakeSecureStorage();
    store = ApiKeyStore(storage);
  });

  test('load returns null when empty', () async {
    expect(await store.load(), isNull);
  });

  test('save then load round-trips all fields', () async {
    await store.save(const AiCredentials(
      apiKey: 'sk-abc',
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-chat',
    ));
    final c = await store.load();
    expect(c, isNotNull);
    expect(c!.apiKey, 'sk-abc');
    expect(c.baseUrl, 'https://api.deepseek.com');
    expect(c.model, 'deepseek-chat');
  });

  test('load applies defaults when baseUrl/model empty', () async {
    await storage.write(key: 'zhiyue.ai.apiKey', value: 'sk-x');
    final c = await store.load();
    expect(c, isNotNull);
    expect(c!.apiKey, 'sk-x');
    expect(c.baseUrl, ApiCredentialsDefaults.baseUrl);
    expect(c.model, ApiCredentialsDefaults.model);
  });

  test('clear removes all keys', () async {
    await store.save(const AiCredentials(apiKey: 'k', baseUrl: 'u', model: 'm'));
    await store.clear();
    expect(await store.load(), isNull);
  });
}
