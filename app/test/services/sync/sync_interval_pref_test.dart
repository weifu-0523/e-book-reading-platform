import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/services/sync/sync_interval_pref.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage storage;
  late SyncIntervalPref pref;

  setUp(() {
    storage = _MockSecureStorage();
    pref = SyncIntervalPref(storage);
    registerFallbackValue(const AndroidOptions());
    when(() => storage.read(
          key: any(named: 'key'),
          aOptions: any(named: 'aOptions'),
        )).thenAnswer((_) async => null);
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

  test('default load returns 5 minutes when unset', () async {
    when(() => storage.read(key: 'zhiyue.sync.intervalMinutes'))
        .thenAnswer((_) async => null);
    final d = await pref.load();
    expect(d, const Duration(minutes: 5));
  });

  test('save and reload round-trips', () async {
    await pref.save(const Duration(minutes: 15));
    verify(() => storage.write(
        key: 'zhiyue.sync.intervalMinutes', value: '15')).called(1);

    when(() => storage.read(key: 'zhiyue.sync.intervalMinutes'))
        .thenAnswer((_) async => '15');
    final d = await pref.load();
    expect(d, const Duration(minutes: 15));
  });

  test('save Duration.zero persists as "0"', () async {
    await pref.save(Duration.zero);
    verify(() => storage.write(
        key: 'zhiyue.sync.intervalMinutes', value: '0')).called(1);

    when(() => storage.read(key: 'zhiyue.sync.intervalMinutes'))
        .thenAnswer((_) async => '0');
    expect(await pref.load(), Duration.zero);
  });

  test('clear removes preference (reverts to default)', () async {
    await pref.save(const Duration(minutes: 30));
    await pref.clear();
    verify(() => storage.delete(key: 'zhiyue.sync.intervalMinutes')).called(1);

    when(() => storage.read(key: 'zhiyue.sync.intervalMinutes'))
        .thenAnswer((_) async => null);
    expect(await pref.load(), const Duration(minutes: 5));
  });
}
