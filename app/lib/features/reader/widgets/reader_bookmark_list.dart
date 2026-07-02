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
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;

import '../../../data/local/database.dart';
import '../controllers/bookmark_controller.dart';

/// 书签列表 widget（M2.5/T12）。
///
/// 用在两处：
/// - **Drawer 书签 tab**：用户在 reader 内打开抽屉时点击书签跳回原位，
///   宿主 ([ReaderDrawer]) 通过 [onJump] 把 [BookmarkEntry] 抛给
///   reader_body，由后者反序列化 locator 并调用 `engine.gotoLocator`。
/// - **`BookmarksPage`**：独立路由 `/book/:id/bookmarks`，复用同一 widget，
///   跳转后由 `BookmarksPage` 自行处理（通常 push 阅读器路由）。
///
/// v1 简化（per plan）：
/// - 不做「当前位置是否已加书签」的检测（locator 类型分散，比较复杂）。
/// - 列表内不提供编辑/删除入口（编辑延后；删除走 long-press 菜单，T13+）。
/// - 空状态文案保持「本书暂无书签」，与 T7 占位实现一致（drawer_test 依赖）。
class ReaderBookmarkList extends ConsumerWidget {
  const ReaderBookmarkList({
    required this.bookId,
    required this.onJump,
    super.key,
  });

  final String bookId;

  /// 用户点击书签条目时的回调。本 widget 仅负责把 [BookmarkEntry] 抛出，
  /// locator 反序列化 + `engine.gotoLocator` 由调用方负责（drawer / page
  /// 所在 widget tree 持有 engine 引用）。
  final ValueChanged<BookmarkEntry> onJump;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookmarkControllerProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '书签加载失败：$e',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (state) {
        final items = state.bookmarks;
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '本书暂无书签',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final e = items[i];
            return ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: Text(e.label),
              subtitle: e.note != null && e.note!.isNotEmpty
                  ? Text(
                      e.note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              onTap: () => onJump(e),
            );
          },
        );
      },
    );
  }
}
