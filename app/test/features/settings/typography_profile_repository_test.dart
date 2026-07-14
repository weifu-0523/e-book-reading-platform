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
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/repositories/typography_profile_repository.dart';
import 'package:reader_engine/core/typography_settings.dart';

void main() {
  late AppDatabase db;
  late TypographyProfileRepository repo;

  setUp(() {
    db = AppDatabase.forTesting();
    repo = TypographyProfileRepository(db);
  });

  tearDown(() => db.close());

  test('seedDefaultIfEmpty creates exactly one default profile when empty', () async {
    final profile = await repo.seedDefaultIfEmpty();
    expect(profile.isDefault, isTrue);
    // seedDefaultIfEmpty seeds TypographySettings.defaults(); fontSize was
    // bumped 16→18 in M3a/任务7 (see typography_settings.dart). Assert the
    // current default, not a stale literal.
    expect(profile.settings.fontSize, TypographySettings.defaults().fontSize);

    final again = await repo.seedDefaultIfEmpty();
    expect(again.id, profile.id); // not duplicated
  });

  test('setDefault toggles isDefault flag', () async {
    final p1 = await repo.seedDefaultIfEmpty();
    final p2 = await repo.insert(name: 'P2', settings: TypographySettings.defaults(), isDefault: false);

    await repo.setDefault(p2.id);
    final after = await repo.getAll();
    expect(after.firstWhere((p) => p.id == p2.id).isDefault, isTrue);
    expect(after.firstWhere((p) => p.id == p1.id).isDefault, isFalse);
  });

  test('findProfilesReferencingFont returns matching profiles', () async {
    final s = TypographySettings.defaults().copyWith(fontFamily: 'MyFont');
    await repo.insert(name: 'WithFont', settings: s, isDefault: false);
    await repo.insert(name: 'NoFont', settings: TypographySettings.defaults(), isDefault: false);

    final refs = await repo.findProfilesReferencingFont('MyFont');
    expect(refs.length, 1);
    expect(refs.first.name, 'WithFont');
  });

  test('CRUD roundtrip preserves settings JSON', () async {
    final original = TypographySettings.defaults().copyWith(fontSize: 20.0, lineHeight: 1.8);
    final p = await repo.insert(name: 'Big', settings: original, isDefault: false);

    final fetched = await repo.getAll();
    expect(fetched.firstWhere((x) => x.id == p.id).settings, original);

    await repo.update(p.id, name: 'BigRenamed');
    final renamed = await repo.getAll();
    expect(renamed.firstWhere((x) => x.id == p.id).name, 'BigRenamed');
  });

  test('getById returns the profile when found', () async {
    final inserted = await repo.insert(
        name: 'FindMe',
        settings: TypographySettings.defaults(),
        isDefault: false);
    final fetched = await repo.getById(inserted.id);
    expect(fetched, isNotNull);
    expect(fetched!.name, 'FindMe');
  });

  test('getById returns null when id does not exist', () async {
    final fetched = await repo.getById('nonexistent-id');
    expect(fetched, isNull);
  });

  test('delete removes the profile', () async {
    final p = await repo.insert(
        name: 'ToDelete',
        settings: TypographySettings.defaults(),
        isDefault: false);
    await repo.delete(p.id);
    final fetched = await repo.getById(p.id);
    expect(fetched, isNull);
  });

  test('update can change settings, not just name', () async {
    final p = await repo.insert(
        name: 'Original',
        settings: TypographySettings.defaults(),
        isDefault: false);
    final newSettings =
        TypographySettings.defaults().copyWith(fontSize: 22.0);
    await repo.update(p.id, settings: newSettings);
    final fetched = await repo.getById(p.id);
    expect(fetched!.settings.fontSize, 22.0);
  });
}
