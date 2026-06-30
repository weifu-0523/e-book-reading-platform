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

import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../local/database.dart';
import 'package:reader_engine/core/typography_settings.dart';
import '../models/typography_profile.dart' as model;

class TypographyProfileRepository {
  TypographyProfileRepository(this._db);

  final AppDatabase _db;

  Future<List<model.TypographyProfile>> getAll() async {
    final rows = await _db.typographyDao.getAllProfiles();
    return rows
        .map((r) => model.TypographyProfile(
              id: r.id,
              name: r.name,
              settings: TypographySettings.fromJson(
                  jsonDecode(r.settings) as Map<String, dynamic>),
              isDefault: r.isDefault,
            ))
        .toList();
  }

  Future<model.TypographyProfile?> getDefault() async {
    final all = await getAll();
    return all.firstWhere(
      (p) => p.isDefault,
      orElse: () => all.first,
    );
  }

  Future<model.TypographyProfile?> getById(String id) async {
    final r = await _db.typographyDao.getProfile(id);
    if (r == null) return null;
    return model.TypographyProfile(
      id: r.id,
      name: r.name,
      settings: TypographySettings.fromJson(
          jsonDecode(r.settings) as Map<String, dynamic>),
      isDefault: r.isDefault,
    );
  }

  Future<model.TypographyProfile> seedDefaultIfEmpty() async {
    final all = await getAll();
    if (all.isNotEmpty) return all.first;
    return insert(
      name: '默认',
      settings: TypographySettings.defaults(),
      isDefault: true,
    );
  }

  Future<model.TypographyProfile> insert({
    required String name,
    required TypographySettings settings,
    required bool isDefault,
  }) async {
    final id = const Uuid().v4();
    await _db.typographyDao.insertProfile(
      id: id,
      name: name,
      settingsJson: jsonEncode(settings.toJson()),
      isDefault: isDefault,
    );
    return model.TypographyProfile(
        id: id, name: name, settings: settings, isDefault: isDefault);
  }

  Future<void> update(String id,
      {String? name, TypographySettings? settings, bool? isDefault}) async {
    await _db.typographyDao.updateProfile(
      id: id,
      name: name,
      settingsJson: settings == null ? null : jsonEncode(settings.toJson()),
      isDefault: isDefault,
    );
  }

  Future<void> setDefault(String id) => _db.typographyDao.setDefault(id);

  Future<void> delete(String id) => _db.typographyDao.deleteProfile(id);

  Future<List<model.TypographyProfile>> findProfilesReferencingFont(
      String familyName) async {
    final all = await getAll();
    return all.where((p) => p.settings.fontFamily == familyName).toList();
  }
}
