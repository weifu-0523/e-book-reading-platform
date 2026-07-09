// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:convert';

import 'package:reader_engine/core/typography_settings.dart';

import '../local/database.dart';

/// 按书籍持久化用户当前实际使用的 [TypographySettings]。
///
/// 与 [TypographyProfileRepository] 的区别：profile 是用户保存的"命名预设"
/// （可被多本书引用、可设全局默认），override 是"这本书最后一次关闭时的
/// 真实排版"，每次用户调字号面板就覆盖。打开书时优先级最高。
class BookTypographyRepository {
  BookTypographyRepository(this._db);

  final AppDatabase _db;

  /// 返回该书最后一次保存的 [TypographySettings]；没有记录则返回 null。
  Future<TypographySettings?> getForBook(String bookId) async {
    final row = await _db.typographyDao.getOverride(bookId);
    if (row == null) return null;
    if (row.customSettings == null) return null;
    return TypographySettings.fromJson(
        jsonDecode(row.customSettings!) as Map<String, dynamic>);
  }

  /// 把当前 [settings] upsert 到该书的 override。
  Future<void> saveForBook(String bookId, TypographySettings settings) async {
    await _db.typographyDao.upsertOverride(
      bookId: bookId,
      customSettingsJson: jsonEncode(settings.toJson()),
    );
  }
}
