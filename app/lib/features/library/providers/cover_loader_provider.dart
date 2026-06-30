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

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// 按 bookId 查询书籍的封面文件。
/// 返回 null 的情况：book 不存在、coverPath 为 null、文件在磁盘上不存在。
/// UI 用此 provider 决定显示真实封面还是占位图。
final coverLoaderProvider =
    FutureProvider.family<File?, String>((ref, bookId) async {
  final book = await ref.watch(bookRepositoryProvider).getById(bookId);
  final path = book?.coverPath;
  if (path == null) return null;
  final file = File(path);
  return file.existsSync() ? file : null;
});
