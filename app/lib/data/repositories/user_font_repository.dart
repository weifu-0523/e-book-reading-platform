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

import '../local/database.dart';
import '../models/user_font.dart' as model;

/// 用户自定义字体的持久化仓储。
///
/// 把 drift 的 [UserFontsDao] 行数据映射为不可变的 `model.UserFont`，
/// 让上层 service / provider 不直接依赖 drift 运行时类型。
///
/// 注意：drift 也会为表行生成同名 `UserFont` 类，故把模型库 `as model` 引入，
/// 用 `model.UserFont` 引用不可变模型。
class UserFontRepository {
  UserFontRepository(this._db);

  final AppDatabase _db;

  Future<List<model.UserFont>> getAll() async {
    final rows = await _db.userFontsDao.getAll();
    return rows
        .map((r) => model.UserFont(
              id: r.id,
              displayName: r.displayName,
              fileName: r.fileName,
              familyName: r.familyName,
              hashSha1: r.hashSha1,
              absolutePath: r.absolutePath,
              addedAt: r.addedAt,
            ))
        .toList();
  }

  Future<model.UserFont?> findByHash(String hash) async {
    final r = await _db.userFontsDao.findByHash(hash);
    if (r == null) return null;
    return model.UserFont(
      id: r.id,
      displayName: r.displayName,
      fileName: r.fileName,
      familyName: r.familyName,
      hashSha1: r.hashSha1,
      absolutePath: r.absolutePath,
      addedAt: r.addedAt,
    );
  }

  Future<void> insert(model.UserFont font) async {
    await _db.userFontsDao.insert(UserFontsCompanion.insert(
      id: font.id,
      displayName: font.displayName,
      fileName: font.fileName,
      familyName: font.familyName,
      hashSha1: font.hashSha1,
      absolutePath: font.absolutePath,
      addedAt: Value(font.addedAt),
    ));
  }

  Future<void> delete(String id) async {
    await _db.userFontsDao.deleteById(id);
  }

  Future<void> rename(String id, String newName) async {
    await _db.userFontsDao.updateDisplayName(id, newName);
  }
}
