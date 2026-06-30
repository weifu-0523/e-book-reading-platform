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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart' show userFontRepositoryProvider;
import '../../../data/models/user_font.dart';

/// 用户已导入字体的只读列表（autoDispose，每次进入字体管理页重新查 DB）。
final fontLibraryProvider =
    FutureProvider.autoDispose<List<UserFont>>((ref) async {
  final repo = ref.watch(userFontRepositoryProvider);
  return repo.getAll();
});
