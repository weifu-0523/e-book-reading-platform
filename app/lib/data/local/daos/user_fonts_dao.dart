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

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/user_fonts.dart';

part 'user_fonts_dao.g.dart';

@DriftAccessor(tables: [UserFonts])
class UserFontsDao extends DatabaseAccessor<AppDatabase>
    with _$UserFontsDaoMixin {
  UserFontsDao(super.db);

  Future<List<UserFont>> getAll() => select(userFonts).get();

  Future<UserFont?> getById(String id) =>
      (select(userFonts)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// 按 hash 去重查询。FontImportService 在写文件前先查此方法。
  Future<UserFont?> findByHash(String hash) =>
      (select(userFonts)..where((t) => t.hashSha1.equals(hash)))
          .getSingleOrNull();

  Future<int> insert(UserFontsCompanion entry) => into(userFonts).insert(entry);

  Future<int> deleteById(String id) =>
      (delete(userFonts)..where((t) => t.id.equals(id))).go();

  Future<int> updateDisplayName(String id, String name) =>
      (update(userFonts)..where((t) => t.id.equals(id)))
          .write(UserFontsCompanion(displayName: Value(name)));
}
