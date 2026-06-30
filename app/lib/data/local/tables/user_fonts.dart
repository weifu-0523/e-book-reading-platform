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

/// schema v5：用户自定义字体。
///
/// 存储通过 FontImportService 导入的 .ttf/.otf 字体的元数据。字体文件本身
/// 复制到 FileStorage.fontsDir 下，本表只记录指向该副本的 absolutePath。
///
/// SHA-1 用作去重键：同一字体重复导入返回已有的 [UserFont]，
/// 不再复制文件、不再写入新行。
class UserFonts extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get fileName => text()();
  TextColumn get familyName => text()();
  TextColumn get hashSha1 => text()();
  TextColumn get absolutePath => text()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
