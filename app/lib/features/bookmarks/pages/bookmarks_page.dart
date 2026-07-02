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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:go_router/go_router.dart';
import 'package:reader_engine/core/locator.dart';

import '../../../data/local/database.dart';
import '../../reader/widgets/reader_bookmark_list.dart';

/// 独立书签页（M2.5/T12）：`/book/:id/bookmarks`。
///
/// 复用 [ReaderBookmarkList] 渲染列表。点击书签后：
/// - 若 [onJump] 由父组件注入（测试用），透传给列表。
/// - 否则默认行为：把 [BookmarkEntry.locatorJson] 反序列化为 [Locator]，
///   并 push 到 `/book/:id` 路由（extra = locator），让 reader 跳到该书签。
///
/// 不直接持有 `ReaderEngine` —— page 是路由栈顶层，无法访问 reader_body 的
/// engine 实例，因此采用「重新 push 阅读器路由」的模式（与 NotesPage 一致）。
class BookmarksPage extends ConsumerWidget {
  const BookmarksPage({
    required this.bookId,
    super.key,
    this.onJump,
  });

  final String bookId;

  /// 测试 / 宿主注入的 jump 回调。生产代码通常为 null（走默认 push 行为）。
  final ValueChanged<BookmarkEntry>? onJump;

  void _defaultJump(BuildContext context, BookmarkEntry entry) {
    final onJump = this.onJump;
    if (onJump != null) {
      onJump(entry);
      return;
    }
    final json = entry.locatorJson;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return;
      final locator = Locator.fromJson(decoded);
      context.push('/book/$bookId', extra: locator);
    } catch (_) {
      // 静默忽略：旧版/损坏的 locator 不应让用户看到红色错误。
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法跳转到该书签')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书签'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: ReaderBookmarkList(
        bookId: bookId,
        onJump: (entry) => _defaultJump(context, entry),
      ),
    );
  }
}
