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

import 'package:flutter/material.dart';

/// 占位的抽屉书签 tab 内容。T12 (M2.5) 会用真实的书签列表
/// （基于 [BookmarkController]）替换此 widget。
///
/// 单独抽出 widget 是为了让 T12 可以独立替换实现而不需要触碰
/// [ReaderDrawer] 容器逻辑。
class ReaderBookmarkList extends StatelessWidget {
  const ReaderBookmarkList({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '暂无书签',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
