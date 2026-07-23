import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/services/tts/cloud_tts_credentials.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('VolcengineTtsCredentials', () {
    test('persists appId + accessToken to secure storage', () async {
      final storage = _MockSecureStorage();
      when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      final store = VolcengineTtsCredentialStore(storage);
      await store.save(const VolcengineTtsCredentials(
        appId: 'app123',
        accessToken: 'tok456',
        voice: 'BV001_streaming',
      ));
      verify(() => storage.write(key: 'zhiyue.tts.volcengine.appId', value: 'app123')).called(1);
      verify(() => storage.write(key: 'zhiyue.tts.volcengine.token', value: 'tok456')).called(1);
      verify(() => storage.write(key: 'zhiyue.tts.volcengine.voice', value: 'BV001_streaming')).called(1);
    });

    test('load returns null when appId missing', () async {
      final storage = _MockSecureStorage();
      when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
      final store = VolcengineTtsCredentialStore(storage);
      expect(await store.load(), isNull);
    });

    test('load returns credentials when all keys present', () async {
      final storage = _MockSecureStorage();
      when(() => storage.read(key: 'zhiyue.tts.volcengine.appId')).thenAnswer((_) async => 'app123');
      when(() => storage.read(key: 'zhiyue.tts.volcengine.token')).thenAnswer((_) async => 'tok456');
      when(() => storage.read(key: 'zhiyue.tts.volcengine.voice')).thenAnswer((_) async => 'BV001_streaming');
      final store = VolcengineTtsCredentialStore(storage);
      final c = await store.load();
      expect(c?.appId, 'app123');
      expect(c?.accessToken, 'tok456');
      expect(c?.voice, 'BV001_streaming');
    });
  });

  group('QwenTtsCredentials', () {
    test('persists apiKey + model + voice', () async {
      final storage = _MockSecureStorage();
      when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      final store = QwenTtsCredentialStore(storage);
      await store.save(const QwenTtsCredentials(
        apiKey: 'sk-xxx',
        model: 'qwen-audio-3.0-tts-flash',
        voice: 'longxiaoxia_v2',
      ));
      verify(() => storage.write(key: 'zhiyue.tts.qwen.apiKey', value: 'sk-xxx')).called(1);
      verify(() => storage.write(key: 'zhiyue.tts.qwen.model', value: 'qwen-audio-3.0-tts-flash')).called(1);
      verify(() => storage.write(key: 'zhiyue.tts.qwen.voice', value: 'longxiaoxia_v2')).called(1);
    });

    test('load returns null when apiKey missing', () async {
      final storage = _MockSecureStorage();
      when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
      expect(await QwenTtsCredentialStore(storage).load(), isNull);
    });
  });
}
