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
