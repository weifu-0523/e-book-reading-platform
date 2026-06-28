import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/services/sync/sync_credentials.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage storage;
  late SyncCredentials creds;

  setUp(() {
    storage = _MockSecureStorage();
    creds = SyncCredentials(storage);
    registerFallbackValue(const AndroidOptions());
    when(() => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
          aOptions: any(named: 'aOptions'),
        )).thenAnswer((_) async {});
    when(() => storage.delete(
          key: any(named: 'key'),
          aOptions: any(named: 'aOptions'),
        )).thenAnswer((_) async {});
  });

  test('save writes username + password + deviceId', () async {
    await creds.save(
      username: 'user@example.com',
      password: 'app-password',
      deviceId: 'device-uuid-1',
    );
    verify(() => storage.write(
        key: 'zhiyue.sync.username', value: 'user@example.com')).called(1);
    verify(() => storage.write(
        key: 'zhiyue.sync.password', value: 'app-password')).called(1);
    verify(() => storage.write(
        key: 'zhiyue.sync.deviceId', value: 'device-uuid-1')).called(1);
  });

  test('load returns null when nothing stored', () async {
    when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    final result = await creds.load();
    expect(result.username, isNull);
    expect(result.password, isNull);
    expect(result.deviceId, isNull);
  });

  test('load returns stored values', () async {
    when(() => storage.read(key: 'zhiyue.sync.username'))
        .thenAnswer((_) async => 'u@e.com');
    when(() => storage.read(key: 'zhiyue.sync.password'))
        .thenAnswer((_) async => 'pw');
    when(() => storage.read(key: 'zhiyue.sync.deviceId'))
        .thenAnswer((_) async => 'dev1');
    final result = await creds.load();
    expect(result.username, 'u@e.com');
    expect(result.password, 'pw');
    expect(result.deviceId, 'dev1');
  });

  test('clear removes all keys', () async {
    await creds.clear();
    verify(() => storage.delete(key: 'zhiyue.sync.username')).called(1);
    verify(() => storage.delete(key: 'zhiyue.sync.password')).called(1);
    verify(() => storage.delete(key: 'zhiyue.sync.deviceId')).called(1);
  });
}
