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

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/settings_dao.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late SettingsDao dao;

  setUp(() {
    db = createTestDatabase();
    dao = SettingsDao(db);
  });

  tearDown(() async => db.close());

  test('get returns null for unknown key', () async {
    expect(await dao.get('missing'), isNull);
  });

  test('upsert then get', () async {
    await dao.upsert('theme', 'dark');
    expect(await dao.get('theme'), 'dark');

    await dao.upsert('theme', 'light');
    expect(await dao.get('theme'), 'light');
  });
}
