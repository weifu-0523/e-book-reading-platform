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
