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
import 'package:zhiyue/data/local/database.dart' hide UserFont;
import 'package:zhiyue/data/models/user_font.dart';
import 'package:zhiyue/data/repositories/user_font_repository.dart';

void main() {
  late AppDatabase db;
  late UserFontRepository repo;

  setUp(() {
    db = AppDatabase.forTesting();
    repo = UserFontRepository(db);
  });

  tearDown(() => db.close());

  test('insert + getAll roundtrip', () async {
    final font = _makeFont();
    await repo.insert(font);
    final all = await repo.getAll();
    expect(all.length, 1);
    expect(all.first.displayName, 'Test');
    expect(all.first.hashSha1, 'abc');
  });

  test('findByHash returns matching font', () async {
    final font = _makeFont(hash: 'sha-1-hash');
    await repo.insert(font);
    final found = await repo.findByHash('sha-1-hash');
    expect(found, isNotNull);
    expect(found!.id, 'test-id');
  });

  test('findByHash returns null when no match', () async {
    final found = await repo.findByHash('nonexistent');
    expect(found, isNull);
  });

  test('delete removes font', () async {
    await repo.insert(_makeFont());
    await repo.delete('test-id');
    final all = await repo.getAll();
    expect(all, isEmpty);
  });

  test('rename updates display name', () async {
    await repo.insert(_makeFont(displayName: 'Original'));
    await repo.rename('test-id', 'Renamed');
    final all = await repo.getAll();
    expect(all.first.displayName, 'Renamed');
  });

  test('multiple inserts return ordered list', () async {
    await repo.insert(_makeFont(
      id: 'a', displayName: 'A', familyName: 'A', fileName: 'a.ttf', hash: 'h-a', path: '/tmp/a.ttf'));
    await repo.insert(_makeFont(
      id: 'b', displayName: 'B', familyName: 'B', fileName: 'b.ttf', hash: 'h-b', path: '/tmp/b.ttf'));
    final all = await repo.getAll();
    expect(all.length, 2);
  });
}

/// Helper that builds a model [UserFont] for tests.
///
/// Both drift-generated `database.dart` and `models/user_font.dart` define
/// `UserFont`. We `hide UserFont` on the database import so this code only
/// sees the immutable model type.
UserFont _makeFont({
  String id = 'test-id',
  String displayName = 'Test',
  String fileName = 'test.ttf',
  String familyName = 'Test',
  String hash = 'abc',
  String path = '/tmp/test.ttf',
}) {
  return UserFont(
    id: id,
    displayName: displayName,
    fileName: fileName,
    familyName: familyName,
    hashSha1: hash,
    absolutePath: path,
    addedAt: DateTime(2026, 6, 27),
  );
}
